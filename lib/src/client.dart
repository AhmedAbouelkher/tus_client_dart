import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'dart:math' show min;
import 'dart:typed_data' show Uint8List, BytesBuilder;

import 'package:exponential_back_off/exponential_back_off.dart';
import 'package:http/http.dart' as http;
import 'package:tus_client_dart/src/tus_client_base.dart';

import 'exceptions.dart';

/// This class is used for creating or resuming uploads.
class TusClient extends TusClientBase {
  TusClient(
    super.file, {
    super.store,
    super.maxChunkSize = 5 << 20,
  }) {
    _fingerprint = generateFingerprint() ?? "";
  }

  /// Override this method to use a custom Client
  http.Client getHttpClient() => http.Client();

  /// Create a new [upload] throwing [ProtocolException] on server error
  Future<void> createUpload() async {
    final client = getHttpClient();
    try {
      _fileSize = await file.length();

      final createHeaders = Map<String, String>.from(headers ?? {})
        ..addAll({
          "Tus-Resumable": tusVersion,
          "Upload-Metadata": _uploadMetadata ?? "",
          "Upload-Length": "$_fileSize",
        });

      final _url = url;

      if (_url == null) {
        throw ProtocolException('Error in request, URL is incorrect');
      }

      final response = await client.post(_url, headers: createHeaders);

      log(response.body);

      if (!(response.statusCode >= 200 && response.statusCode < 300) && response.statusCode != 404) {
        throw ProtocolException.rsp(
          response: response,
          message: "Unexpected Error while creating upload",
        );
      }

      String urlStr = response.headers["location"] ?? "";
      if (urlStr.isEmpty) {
        throw ProtocolException("missing upload Uri in response for creating upload");
      }

      _uploadUrl = _parseUrl(urlStr);
      store?.set(_fingerprint, _uploadUrl as Uri);
    } on FileSystemException {
      throw Exception('Cannot find file to upload');
    } finally {
      client.close();
    }
  }

  Future<bool> isResumable() async {
    try {
      _fileSize = await file.length();
      _pauseUpload = false;

      if (!resumingEnabled) {
        return false;
      }

      _uploadUrl = await store?.get(_fingerprint);

      if (_uploadUrl == null) {
        return false;
      }
      return true;
    } on FileSystemException {
      throw Exception('Cannot find file to upload');
    } catch (e) {
      return false;
    }
  }

  /// Start or resume an upload in chunks of [maxChunkSize] throwing
  /// [ProtocolException] on server error
  Future<void> upload({
    void Function(double progress, Duration timeEstimate)? onProgress,
    void Function(TusClient client, Duration? timeEstimate)? onStart,
    void Function(String id)? onStarted,
    void Function()? onComplete,
    required Uri uri,
    Map<String, String>? metadata = const {},
    Map<String, String>? headers = const {},
    bool measureUploadSpeed = false,
  }) async {
    setUploadData(uri, headers, metadata);

    final _isResumable = await isResumable();

    if (!_isResumable) {
      await createUpload();
      onStarted?.call(_id);
    }

    // get offset from server
    _offset = await _getOffset();

    // Save the file size as an int in a variable to avoid having to call
    int totalBytes = _fileSize as int;

    // We start a stopwatch to calculate the upload speed
    final uploadStopwatch = Stopwatch()..start();

    // start upload
    final client = getHttpClient();

    if (onStart != null) {
      Duration? estimate;
      if (uploadSpeed != null) {
        final _workedUploadSpeed = uploadSpeed! * 1000000;

        estimate = Duration(
          seconds: (totalBytes / _workedUploadSpeed).round(),
        );
      }
      // The time remaining to finish the upload
      onStart(this, estimate);
    }

    while (!_pauseUpload && _offset < totalBytes) {
      final backOff = ExponentialBackOff(maxAttempts: 1);

      final result = await backOff.start(
        () async {
          final uploadHeaders = Map<String, String>.from(headers ?? {})
            ..addAll({
              "Tus-Resumable": tusVersion,
              "Upload-Offset": "$_offset",
              "Content-Type": "application/offset+octet-stream"
            });

          final request = http.Request("PATCH", _uploadUrl as Uri)
            ..headers.addAll(uploadHeaders)
            ..bodyBytes = await _getData();
          try {
            _response = await client.send(request);
          } on http.ClientException catch (e) {
            throw ProtocolException("Error getting Response from server: $e");
          }

          if (_response == null) {
            throw ProtocolException("Error getting Response from server");
          }
          _response?.stream.listen(
            (newBytes) {},
            onDone: () {
              if (onProgress != null && !_pauseUpload) {
                // Total byte sent
                final totalSent = _offset + maxChunkSize;
                double _workedUploadSpeed = 1.0;

                // If upload speed != null, it means it has been measured
                if (uploadSpeed != null) {
                  // Multiplied by 10^6 to convert from Mb/s to b/s
                  _workedUploadSpeed = uploadSpeed! * 1000000;
                } else {
                  _workedUploadSpeed = totalSent / uploadStopwatch.elapsedMilliseconds;
                }

                // The data that hasn't been sent yet
                final remainData = totalBytes - totalSent;

                // The time remaining to finish the upload
                final estimate = Duration(
                  seconds: (remainData / _workedUploadSpeed).round(),
                );

                final progress = totalSent / totalBytes * 100;
                onProgress((progress).clamp(0, 100), estimate);
              }
            },
          );

          // check if correctly uploaded
          if (!(_response!.statusCode >= 200 && _response!.statusCode < 300)) {
            if (_pauseUpload) return;
            // throw ProtocolException("Error while uploading file", _response!.statusCode);
            // TODO: check if this is the correct way to handle this
            throw ProtocolException.rsp(
              response: await http.Response.fromStream(_response!),
              message: "Error while uploading file",
            );
          }

          int? serverOffset = _parseOffset(_response!.headers["upload-offset"]);
          if (serverOffset == null) {
            throw ProtocolException(
              "Response to PATCH request contains "
              "no or invalid Upload-Offset header",
            );
          }
          if (_offset != serverOffset) {
            throw ProtocolException(
              "Response contains different Upload-Offset "
              " value ($serverOffset) than expected ($_offset)",
            );
          }

          if (_offset == totalBytes && !_pauseUpload) {
            this.onCompleteUpload();
            onComplete?.call();
          }
        },
      );

      if (result.isLeft()) {
        throw result.getLeftValue();
      }
    }
  }

  /// Pause the current upload
  Future<void> pauseUpload() async {
    try {
      _pauseUpload = true;
      await _response?.stream.timeout(Duration.zero);
    } catch (e) {
      throw Exception("Error pausing upload");
    }
  }

  Future<void> cancelUpload() async {
    final backOff = ExponentialBackOff();
    final r = await backOff.start(() async {
      try {
        _pauseUpload = true;
        await _response?.stream.timeout(Duration.zero);

        final response = await http.delete(
          _uploadUrl!,
          headers: {
            "Tus-Resumable": tusVersion,
            ...headers ?? {},
          },
        );

        if (response.statusCode != 204) {
          throw ProtocolException.rsp(
            response: response,
            message: "Error cancelling upload",
          );
        }

        await store?.remove(_fingerprint);
      } catch (e) {
        throw Exception("Error cancelling upload $e");
      }
    });
    if (r.isLeft()) {
      throw r.getLeftValue();
    }
  }

  /// Actions to be performed after a successful upload
  Future<void> onCompleteUpload() async {
    await store?.remove(_fingerprint);
  }

  void setUploadData(
    Uri url,
    Map<String, String>? headers,
    Map<String, String>? metadata,
  ) {
    this.url = url;
    this.headers = headers;
    this.metadata = metadata;
    _uploadMetadata = generateMetadata();
  }

  /// Get offset from server throwing [ProtocolException] on error
  Future<int> _getOffset() async {
    final response = await http.head(
      _uploadUrl!,
      headers: {
        "Tus-Resumable": tusVersion,
        ...headers ?? {},
      },
    );

    if (!(response.statusCode >= 200 && response.statusCode < 300)) {
      throw ProtocolException(
        "Unexpected error while resuming upload",
        response.statusCode,
      );
    }

    int? serverOffset = _parseOffset(response.headers["upload-offset"]);
    if (serverOffset == null) {
      throw ProtocolException("missing upload offset in response for resuming upload");
    }
    return serverOffset;
  }

  /// Get data from file to upload

  Future<Uint8List> _getData() async {
    int start = _offset;
    int end = _offset + maxChunkSize;
    end = end > (_fileSize ?? 0) ? _fileSize ?? 0 : end;

    final result = BytesBuilder();
    await for (final chunk in file.openRead(start, end)) {
      result.add(chunk);
    }

    final bytesRead = min(maxChunkSize, result.length);
    _offset = _offset + bytesRead;

    return result.takeBytes();
  }

  int? _parseOffset(String? offset) {
    if (offset == null || offset.isEmpty) {
      return null;
    }
    if (offset.contains(",")) {
      offset = offset.substring(0, offset.indexOf(","));
    }
    return int.tryParse(offset);
  }

  Uri _parseUrl(String urlStr) {
    if (urlStr.contains(",")) {
      urlStr = urlStr.substring(0, urlStr.indexOf(","));
    }
    Uri uploadUrl = Uri.parse(urlStr);
    if (uploadUrl.host.isEmpty) {
      uploadUrl = uploadUrl.replace(host: url?.host, port: url?.port);
    }
    if (uploadUrl.scheme.isEmpty) {
      uploadUrl = uploadUrl.replace(scheme: url?.scheme);
    }
    _id = uploadUrl.pathSegments.last;
    return uploadUrl;
  }

  http.StreamedResponse? _response;

  int? _fileSize;

  String _fingerprint = "";

  String? _uploadMetadata;

  Uri? _uploadUrl;

  int _offset = 0;

  bool _pauseUpload = false;

  String _id = "";

  /// The URI on the server for the file
  Uri? get uploadUrl => _uploadUrl;

  /// The fingerprint of the file being uploaded
  String get fingerprint => _fingerprint;

  /// The 'Upload-Metadata' header sent to server
  String get uploadMetadata => _uploadMetadata ?? "";
}
