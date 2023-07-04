## [2.3.0] - Added measure real time upload speed

- Added Upload Speed measure optional parameter

## [2.2.3] - Added onStart function and using TusFileStore

- Added better cancel upload method.
- Added TusClientBase abstract class.
- Changed ProtocolExceptions to include code as optional parameter.

## [2.2.2] - Change TusClient upload function

- Added onStart function with TusClient as argument.
- Added cancelUpload function.
- Deleted unused variables.
- Correct typing of functions.
- Changed ProtocolException model to separate code from message.
- Added error handling on requests.

## [2.2.1+3] - Added onStart function and using TusFileStore

- Added onStart function after initiating upload.
- Using TusFileStore for saving video locally (fixes resume-upload function).

## [2.2.1+2] - Fixed metadata and better example

- Fixed generateMetadata() function and improved example.

## [2.2.1+1] - Deleted path dependency

- Deleted path package as dependency.

## [2.2.1] - Change TusClient upload function

- Changed TusClient initialization, headers and metadata are passed now through upload function.

## [2.2.0+1] - Use http client again

- Updated dependencies.
- Now passing reference to the current TusClient in the onProgress function.

## [2.2.0] - Use http client again

- We don't use Dio anymore.

## [2.1.0] - HTTP Package updated

- Now the package uses Dio to manage HTTP Requests.
- Estimated time added.
- Chunk size issue with big files and names fixed.

## [2.0.1] - Added Persistent Store

- Users can now use TusFileStore to create persistent state of uploads.

## [1.0.3] - Updating dependencies

- Updating dependencies.
- Migrating to a native dart package.

## [1.0.2] - Fixed issue with not parsing the http port number

- Fixed issue with not parsing the http port number.
- Fixing formatting.

## [1.0.1] - Fixing custom chunk size

- Fixing handling file as chunks correctly.
- Fixing null safety warnings.
- Updating dependencies.

## [1.0.0] - Migrating to null safety

- Making null safe.
- Increasing minimum Dart SDK.
- Fixing deprecated APIs.

## [0.1.3] - Updating dependencies

- Updating dependencies.
- Removing deadcode.

## [0.1.2] - Many improvements

- Fixing server returns partial url & double header.
- Fixing immediate pause even when uploading with large chunks by timing out the future.
- Removing unused exceptions (deadcode).
- Updating dependencies.

## [0.1.1] - Better file persistence documentation

- Have better documentation on using tus_client_file_store.

## [0.1.0] - Web support

- This is update breaks backwards compatibility.
- Adding cross_file Flutter plugin to manage reading files across platforms.
- Refactoring example to show use with XFile on Android/iOS vs web.

## [0.0.4] - Feature request

- Changing example by adding copying file to be uploaded to application temp directory before uploading.

## [0.0.3] - Bug fix

- Fixing missing Tus-Resumable headers in all requests.

## [0.0.2] - Bug fix

- Fixing failure when offset for server is missing or null.

## [0.0.1] - Initial release

- Support for TUS 1.0.0 protocol.
- Uploading in chunks.
- Basic protocol support.
- **TODO**: Add support for multiple file upload.
- **TODO**: Add support for partial file uploads.
