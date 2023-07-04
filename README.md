# A tus client

[![Pub Version](https://img.shields.io/pub/v/tus_client_dart)](https://pub.dev/packages/tus_client_dart)
[![Build Status](https://app.travis-ci.com/tomassasovsky/tus_client.svg?branch=master)](https://travis-ci.org/tomassasovsky/tus_client)

---

A tus client in pure dart. [Resumable uploads using tus protocol](https://tus.io/)
Forked from [tus_client](https://pub.dev/packages/tus_client)

> **tus** is a protocol based on HTTP for _resumable file uploads_. Resumable
> means that an upload can be interrupted at any moment and can be resumed without
> re-uploading the previous data again. An interruption may happen willingly, if
> the user wants to pause, or by accident in case of a network issue or server
> outage.

- [A tus client](#a-tus-client)
  - [Usage](#usage)
    - [Using Persistent URL Store](#using-persistent-url-store)
    - [Adding Extra Headers](#adding-extra-headers)
    - [Adding extra data](#adding-extra-data)
    - [Changing chunk size](#changing-chunk-size)
    - [Pausing upload](#pausing-upload)
  - [Example](#example)
  - [Maintainers](#maintainers)

## Usage

```dart
import 'package:cross_file/cross_file.dart' show XFile;

// File to be uploaded
final file = XFile("/path/to/my/pic.jpg");

// Create a client
final client = TusClient(
    Uri.parse("https://master.tus.io/files/"),
    file,
    store: TusMemoryStore(),
);

// Starts the upload
await client.upload(
    onStart:(TusClient client, Duration? estimate){
        // If estimate is not null, it will provide the estimate time for completion
        // it will only be not null if measuring upload speed
        print('This is the client to be used $client and $estimate time');
    },
    onComplete: () {
        print("Complete!");

        // Prints the uploaded file URL
        print(client.uploadUrl.toString());
    },
    onProgress: (double progress, Duration estimate, TusClient client) {
        print("Progress: $progress, Estimated time: ${estimate.inSeconds}");
    },

    // Set this to true if you want to measure upload speed at the start of the upload
    measureUploadSpeed: true,
);
```

### Using Persistent URL Store

This is only supported on Flutter Android, iOS, desktop and web.
You need to add to your `pubspec.yaml`:

```dart
import 'package:path_provider/path_provider.dart';

//creates temporal directory to store the upload progress
final tempDir = await getTemporaryDirectory();
final tempDirectory = Directory('${tempDir.path}/${gameId}_uploads');
if (!tempDirectory.existsSync()) {
    tempDirectory.createSync(recursive: true);
}

// Create a client
final client = TusClient(
    Uri.parse("https://example.com/tus"),
    file,
    store: TusFileStore(tempDirectory),
);

// Start upload
// Don't forget to delete the tempDirectory
await client.upload();
```

### Adding Extra Headers

```dart
final client = TusClient(
    Uri.parse("https://master.tus.io/files/"),
    file,
    headers: {"Authorization": "..."},
);
```

### Adding extra data

```dart
final client = TusClient(
    Uri.parse("https://master.tus.io/files/"),
    file,
    metadata: {"for-gallery": "..."},
);
```

### Changing chunk size

The file is uploaded in chunks. Default size is 512KB. This should be set considering `speed of upload` vs `device memory constraints`

```dart
final client = TusClient(
    Uri.parse("https://master.tus.io/files/"),
    file,
    maxChunkSize: 10 * 1024 * 1024,  // chunk is 10MB
);
```

### Pausing upload

Pausing upload can be done after current uploading in chunk is completed.

```dart
final client = TusClient(
    Uri.parse("https://master.tus.io/files/"),
    file
);

// Pause after 5 seconds
Future.delayed(Duration(seconds: 5)).then((_) =>client.pause());

// Starts the upload
await client.upload(
    onComplete: () {
        print("Complete!");
    },
    onProgress: (double progress, Duration estimate, TusClient client) {
        print("Progress: $progress, Estimated time: ${estimate.inSeconds}");
    },
);
```

## Example

For an example of usage in a Flutter app (using file picker) see: [/example](https://github.com/tomassasovsky/tus_client/tree/master/example/lib/main.dart)

## Maintainers

- [Nazareno Cavazzon](https://github.com/NazarenoCavazzon)
- [Jorge Rincon](https://github.com/jorger5)
- [Tomás Sasovsky](https://github.com/tomassasovsky)
