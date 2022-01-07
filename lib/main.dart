import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:amplify_flutter/amplify.dart';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:amplify_storage_s3/amplify_storage_s3.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'amplifyconfiguration.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final picker = ImagePicker();

  //PRIVATE ACCESS
  ///Create an options object specifying the
  ///private access level to only allow an object
  ///to be accessed by the creating user
  final optionsUploadFile =
      S3UploadFileOptions(accessLevel: StorageAccessLevel.private);
  final optionsDownloadFile =
      S3DownloadFileOptions(accessLevel: StorageAccessLevel.private);

  bool _isAmplifyConfigured = false;
  String _uploadFileResult = '';
  String? _getUrlResult;
  String _removeResult = '';

  @override
  void initState() {
    super.initState();
  }

  //amplify configs
  void configureAmplify() async {
    // First add plugins (Amplify native requirements)
    AmplifyStorageS3 storage = AmplifyStorageS3();
    AmplifyAuthCognito auth = AmplifyAuthCognito();
    Amplify.addPlugins([auth, storage]);

    try {
      // Configure
      await Amplify.configure(amplifyconfig);
    } on AmplifyAlreadyConfiguredException {
      if (kDebugMode) {
        print(
          'Amplify was already configured. Looks like app restarted on android.');
      }
    }

    setState(() {
      _isAmplifyConfigured = true;
    });
  }

  //upload files with options
  Future<void> createAndUploadFileWithOptions() async {
    // Create a dummy file
    const exampleString = 'Example file contents';
    final tempDir = await getTemporaryDirectory();
    final exampleFile = File(tempDir.path + '/example.txt')
      ..createSync()
      ..writeAsStringSync(exampleString);

    // Set options
    final options = S3UploadFileOptions(
      accessLevel: StorageAccessLevel.guest,
      contentType: 'text/plain',
      metadata: <String, String>{
        'project': 'ExampleProject',
      },
    );

    // Upload the file to S3 with options
    try {
      final UploadFileResult result = await Amplify.Storage.uploadFile(
          local: exampleFile,
          key: 'ExampleKey',
          options: options,
          onProgress: (progress) {
            if (kDebugMode) {
              print("Fraction completed: " +
                progress.getFractionCompleted().toString());
            }
          });
      if (kDebugMode) {
        print('Successfully uploaded file: ${result.key}');
      }
    } on StorageException catch (e) {
      if (kDebugMode) {
        print('Error uploading file: $e');
      }
    }
  }

  /// To upload to S3 from a data object,
  /// specify the key and the file to be uploaded.
  /// A file can be created locally,
  /// or retrieved from the user's device using
  /// a package such as image_picker or file_picker.
  //upload image
  Future<void> uploadImage() async {
    // Select image from user's gallery
    final PickedFile? pickedFile =
        (await picker.pickImage(source: ImageSource.gallery)) as PickedFile?;

    if (pickedFile == null) {
      if (kDebugMode) {
        print('No image selected');
      }
      return;
    }

    // Upload image with the current time as the key
    final key = DateTime.now().toString();
    final file = File(pickedFile.path);
    try {
      final UploadFileResult result = await Amplify.Storage.uploadFile(
          local: file,
          key: key,
          onProgress: (progress) {
            if (kDebugMode) {
              print("Fraction completed: " +
                progress.getFractionCompleted().toString());
            }
          });
      if (kDebugMode) {
        print('Successfully uploaded image: ${result.key}');
      }
    } on StorageException catch (e) {
      if (kDebugMode) {
        print('Error uploading image: $e');
      }
    }
  }

  //upload file
  Future<void> uploadFile() async {
    // Select a file from the device
    final FilePickerResult? result = await FilePicker.platform.pickFiles();

    if (result == null) {
      if (kDebugMode) {
        print('No file selected');
      }
      return;
    }

    // Upload file with its filename as the key
    final platformFile = result.files.single;
    final path = platformFile.path!;
    final key = platformFile.name;
    final file = File(path);
    try {
      final UploadFileResult result = await Amplify.Storage.uploadFile(
          local: file,
          key: key,
          onProgress: (progress) {
            if (kDebugMode) {
              print("Fraction completed: " +
                progress.getFractionCompleted().toString());
            }
          });
      if (kDebugMode) {
        print('Successfully uploaded file: ${result.key}');
      }
    } on StorageException catch (e) {
      if (kDebugMode) {
        print('Error uploading file: $e');
      }
    }
  }

  ///If you uploaded the data using the key ExampleKey, you can retrieve
  ///the data using Amplify.Storage.downloadFile.
  //download file
  Future<void> downloadFile() async {
    final documentsDir = await getApplicationDocumentsDirectory();
    final filepath = documentsDir.path + '/example.txt';
    final file = File(filepath);

    try {
      await Amplify.Storage.downloadFile(
          key: 'ExampleKey',
          local: file,
          onProgress: (progress) {
            if (kDebugMode) {
              print("Fraction completed: " +
                progress.getFractionCompleted().toString());
            }
          });
      final String contents = file.readAsStringSync();
      if (kDebugMode) {
        print('Downloaded contents: $contents');
      }
    } on StorageException catch (e) {
      if (kDebugMode) {
        print('Error downloading file: $e');
      }
    }
  }

  //generate a download URL
  Future<void> getDownloadUrl() async {
    try {
      final GetUrlResult result =
          await Amplify.Storage.getUrl(key: 'ExampleKey');
      // NOTE: This code is only for demonstration
      // Your debug console may truncate the printed url string
      if (kDebugMode) {
        print('Got URL: ${result.url}');
      }
    } on StorageException catch (e) {
      if (kDebugMode) {
        print('Error getting download URL: $e');
      }
    }
  }

  ///You can list all of the objects uploaded under a given prefix.
  ///This will list all public files (i.e. those with guest access level):
  //list files
  Future<void> listItems() async {
    try {
      if (kDebugMode) {
        print('In list');
      }
      S3ListOptions options =
          S3ListOptions(accessLevel: StorageAccessLevel.guest);
      ListResult result = await Amplify.Storage.list(options: options);
      if (kDebugMode) {
        print('List Result:');
      }
      for (StorageItem item in result.items) {
        if (kDebugMode) {
          print(
            'Item: { key:${item.key}, eTag:${item.eTag}, lastModified:${item.lastModified}, size:${item.size}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('List Err: ' + e.toString());
      }
    }
  }

  ///To delete an object uploaded to S3,
  ///use Amplify.Storage.remove and specify the key:
  //remove files
  Future<void> deleteFile() async {
    try {
      if (kDebugMode) {
        print('In remove');
      }
      String key = _uploadFileResult;
      RemoveOptions options =
          RemoveOptions(accessLevel: StorageAccessLevel.guest);
      RemoveResult result =
          await Amplify.Storage.remove(key: key, options: options);

      setState(() {
        _removeResult = result.key;
      });
      if (kDebugMode) {
        print('_removeResult:' + _removeResult);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Remove Err: ' + e.toString());
      }
    }
  }

  //upload file or image or else
  void upload() async {
    try {
      if (kDebugMode) {
        print('In upload');
      }
      // Uploading the file with options
      FilePickerResult? pickResult =
          await FilePicker.platform.pickFiles(type: FileType.image);
      if (pickResult == null) {
        if (kDebugMode) {
          print('User canceled upload.');
        }
        return;
      }
      File local = File(pickResult.files.single.path!);
      final key = DateTime.now().toString();
      Map<String, String> metadata = <String, String>{};
      metadata['name'] = 'filename';
      metadata['desc'] = 'A test file';
      S3UploadFileOptions options = S3UploadFileOptions(
          accessLevel: StorageAccessLevel.guest, metadata: metadata);

      UploadFileResult result = await Amplify.Storage.uploadFile(
          key: key,
          local: local,
          options: options,
          onProgress: (progress) {
            if (kDebugMode) {
              print("PROGRESS: " + progress.getFractionCompleted().toString());
            }
          });

      setState(() {
        _uploadFileResult = result.key;
      });
    } catch (e) {
      if (kDebugMode) {
        print('UploadFile Err: ' + e.toString());
      }
    }
  }

  ///get the uploaded image url and display the url image
  //Get URL
  void getUrl() async {
    try {
      if (kDebugMode) {
        print('In getUrl');
      }
      String key = _uploadFileResult;
      S3GetUrlOptions options = S3GetUrlOptions(
          accessLevel: StorageAccessLevel.guest, expires: 10000);
      GetUrlResult result =
          await Amplify.Storage.getUrl(key: key, options: options);

      setState(() {
        _getUrlResult = result.url;
      });
    } catch (e) {
      if (kDebugMode) {
        print('GetUrl Err: ' + e.toString());
      }
    }
  }

  ///After the user has signed in,
  ///create an options object specifying the protected
  ///access level to allow other users to read the object:
  //protected access
  Future<void> uploadProtected() async {
    // Create a dummy file
    const exampleString = 'Example file contents';
    final tempDir = await getTemporaryDirectory();
    final exampleFile = File(tempDir.path + '/example.txt')
      ..createSync()
      ..writeAsStringSync(exampleString);

    // Set the access level to `protected` for the current user
    // Note: A user must be logged in through Cognito Auth
    // for this to work.
    final uploadOptions = S3UploadFileOptions(
      accessLevel: StorageAccessLevel.protected,
    );

    // Upload the file to S3 with protected access
    try {
      final UploadFileResult result = await Amplify.Storage.uploadFile(
          local: exampleFile,
          key: 'ExampleKey',
          options: uploadOptions,
          onProgress: (progress) {
            if (kDebugMode) {
              print("Fraction completed: " +
                progress.getFractionCompleted().toString());
            }
          });
      if (kDebugMode) {
        print('Successfully uploaded file: ${result.key}');
      }
    } on StorageException catch (e) {
      if (kDebugMode) {
        print('Error uploading protected file: $e');
      }
    }
  }

  ///For other users to read the file, you must specify the user ID
  ///of the creating user in the passed options.
  //download protected
  Future<void> downloadProtected(String cognitoIdentityId) async {
    // Create a file to store downloaded contents
    final documentsDir = await getApplicationDocumentsDirectory();
    final filepath = documentsDir.path + '/example.txt';
    final file = File(filepath);

    // Set access level and Cognito Identity ID.
    // Note: `targetIdentityId` is only needed when downloading
    // protected files of a user other than the one currently
    // logged in.
    final downloadOptions = S3DownloadFileOptions(
      accessLevel: StorageAccessLevel.protected,

      // e.g. us-west-2:2f41a152-14d1-45ff-9715-53e20751c7ee
      targetIdentityId: cognitoIdentityId,
    );

    // Download protected file and read contents
    try {
      await Amplify.Storage.downloadFile(
        key: 'ExampleKey',
        local: file,
        options: downloadOptions,
      );
      final contents = file.readAsStringSync();
      if (kDebugMode) {
        print('Got protected file with contents: $contents');
      }
    } on StorageException catch (e) {
      if (kDebugMode) {
        print('Error downloading protected file: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text('Storage S3 Plugin Example'),
        ),
        body: ListView(
          padding: const EdgeInsets.all(10.0),
          children: <Widget>[
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const Padding(padding: EdgeInsets.all(10.0)),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isAmplifyConfigured ? null : configureAmplify,
                    child: const Text('Configure'),
                  ),
                ),
                const Padding(padding: EdgeInsets.all(5.0)),
                Text('Amplify Configured: $_isAmplifyConfigured'),
                const Padding(padding: EdgeInsets.all(10.0)),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: upload,
                    child: const Text('Upload File'),
                  ),
                ),
                const Padding(padding: EdgeInsets.all(5.0)),
                Text('Uploaded File: $_uploadFileResult'),
                const Padding(padding: EdgeInsets.all(5.0)),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: deleteFile,
                    child: const Text('Remove uploaded File'),
                  ),
                ),
                const Padding(padding: EdgeInsets.all(5.0)),
                Text('Removed File: $_removeResult'),
                const Padding(padding: EdgeInsets.all(5.0)),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: getUrl,
                    child: const Text('GetUrl for uploaded File'),
                  ),
                ),
                const Padding(padding: EdgeInsets.all(5.0)),
                SizedBox(
                  width: double.infinity,
                  height: 200,
                  child: _getUrlResult == null
                      ? Container(color: Colors.white)
                      : Image.network(_getUrlResult!),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
