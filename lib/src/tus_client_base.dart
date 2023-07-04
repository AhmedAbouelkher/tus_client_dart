import 'dart:convert';

import 'package:cross_file/cross_file.dart';
import 'package:tus_client_dart/tus_client_dart.dart';

abstract class TusClientBase {
  /// Version of the tus protocol used by the client. The remote server needs to
  /// support this version, too.
  final tusVersion = "1.0.0";

  /// The tus server Uri
  Uri? url;

  Map<String, String>? metadata;

  /// Any additional headers
  Map<String, String>? headers;

  /// Upload speed in Mb/s
  double? uploadSpeed;

  TusClientBase(
    this.file, {
    this.store,
    this.maxChunkSize = 512 * 1024,
  });

  /// Create a new upload URL
  Future<void> createUpload();

  /// Checks if upload can be resumed.
  Future<bool> isResumable();

  /// Starts an upload
  Future<void> upload({
    void Function(double progress, Duration timeEstimate)? onProgress,
    void Function(TusClient client, Duration? timeEstimate)? onStart,
    void Function()? onComplete,
    required Uri uri,
    Map<String, String>? metadata = const {},
    Map<String, String>? headers = const {},
  });

  /// Pauses the upload
  Future<void> pauseUpload();

  /// Cancels the upload
  Future<void> cancelUpload();

  /// Function to be called after completing upload
  Future<void> onCompleteUpload();

  /// Override this method to customize creating file fingerprint
  String? generateFingerprint() {
    return file.path.replaceAll(RegExp(r"\W+"), '.');
  }

  /// Override this to customize creating 'Upload-Metadata'
  String generateMetadata() {
    final meta = Map<String, String>.from(metadata ?? {});

    if (!meta.containsKey("filename")) {
      // Add the filename to the metadata from the whole directory path.
      //I.e: /home/user/file.txt -> file.txt
      // meta["filename"] = file.path.split('/').last;
      meta["filename"] = file.name;
    }

    return meta.entries.map((entry) => entry.key + " " + base64.encode(utf8.encode(entry.value))).join(",");
  }

  /// Storage used to save and retrieve upload URLs by its fingerprint.
  final TusStore? store;

  /// File to upload, must be in[XFile] type
  final XFile file;

  /// The maximum payload size in bytes when uploading the file in chunks (512KB)
  final int maxChunkSize;

  /// Whether the client supports resuming
  bool get resumingEnabled => store != null;
}
