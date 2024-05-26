import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:face_recognition/face_detector_painter.dart';
import 'package:face_recognition/tflite_user_model.dart';
import 'package:face_recognition/tflite_utils.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img_lib;

class GalleryView extends StatefulWidget {
  const GalleryView(
      {Key? key,
      required this.title,
      this.faces,
      required this.onImage,
      required this.onDetectorViewModeChanged})
      : super(key: key);

  final String title;
  final List<MapEntry<String, Face>>? faces;
  final Function(InputImage inputImage) onImage;
  final Function()? onDetectorViewModeChanged;

  @override
  State<GalleryView> createState() => _GalleryViewState();
}

class _GalleryViewState extends State<GalleryView> {
  ui.Image? _image;
  ImagePicker? _imagePicker;

  @override
  void initState() {
    super.initState();
    _imagePicker = ImagePicker();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 20.0),
            child: GestureDetector(
              onTap: widget.onDetectorViewModeChanged,
              child: Icon(
                Platform.isIOS ? Icons.camera_alt_outlined : Icons.camera,
              ),
            ),
          ),
        ],
      ),
      body: _galleryBody(),
    );
  }

  Widget _galleryBody() {
    return ListView(shrinkWrap: true, children: [
      _image != null
          ? SizedBox(
              width: _image?.width.toDouble(),
              height: _image?.height.toDouble(),
              child: CustomPaint(
                painter: FacePainter(_image!, widget.faces ?? []),
              ),
            )
          : const Icon(
              Icons.image,
              size: 200,
            ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: ElevatedButton(
          onPressed: _getAllUser,
          child: const Text('Registered Users'),
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: ElevatedButton(
          child: const Text('From Gallery'),
          onPressed: () => _getImage(ImageSource.gallery),
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: ElevatedButton(
          onPressed: widget.onDetectorViewModeChanged,
          child: const Text('Take a picture'),
        ),
      ),
    ]);
  }

  Future<void> _getImage(ImageSource source) async {
    setState(() {
      _image = null;
    });
    final pickedFile = await _imagePicker?.pickImage(source: source);
    if (pickedFile != null) {
      await _processFile(pickedFile.path);
    }
  }

  Future _getAllUser() async {
    final users = TfliteUtils.getInstance().getAllUser();
    if(users.isNotEmpty) {
      showAllUser(users);
    }else{
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No User is Registered")));
    }
  }

  void showAllUser(List<TfLiteUserModel> users) {
    showModalBottomSheet(
        isScrollControlled: true,
        context: context,
        builder: (BuildContext context) {
          return Dialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30.0)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'All Registered User',
                    style: TextStyle(fontSize: 20),
                  ),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.7),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final user in users)
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: ListTile(
                              title: Text("${user.name}"),
                              trailing: Image.memory(
                                base64Decode("${user.image}"),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel')),
                ],
              ),
            ),
          );
        });
  }

  Future<void> _processFile(String path) async {
    var image = await img_lib.decodeImageFile(path);
    image = img_lib.copyResize(image!, height: 400, width: 400);
    await File(path).writeAsBytes(img_lib.encodeJpg(image));
    final inputImage = InputImage.fromFilePath(path);
    final data = await File(path).readAsBytes();
    _image = await decodeImageFromList(data);
    widget.onImage(inputImage);
  }
}
// https://career.heero.ai/cover-letter-samples/flutter-developer#:~:text=Dear%20Hiring%20Manager%2C,significant%20contribution%20to%20your%20team.