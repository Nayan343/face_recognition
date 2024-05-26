import 'dart:io';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:face_recognition/face_detector_painter.dart';
import 'package:face_recognition/tflite_utils.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img_lib;

import 'detector_view.dart';

class FaceDetectorView extends StatefulWidget {
  const FaceDetectorView({super.key});

  @override
  State<FaceDetectorView> createState() => _FaceDetectorViewState();
}

class _FaceDetectorViewState extends State<FaceDetectorView> {
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
        enableTracking: true,
        performanceMode: FaceDetectorMode.accurate,
    ),
  );
  bool _canProcess = true;
  bool _isBusy = false;
  CustomPaint? _customPaint;
  List<MapEntry<String, Face>>? faceList;
  var _cameraLensDirection = CameraLensDirection.front;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, () async {
      TfliteUtils.getInstance();
    });
  }

  @override
  void dispose() {
    _canProcess = false;
    _faceDetector.close();
    TfliteUtils.getInstance().dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DetectorView(
      title: 'Face Detector',
      customPaint: _customPaint,
      faces: faceList,
      onImage: _processImage,
      initialCameraLensDirection: _cameraLensDirection,
      onCameraLensDirectionChanged: (value) => _cameraLensDirection = value,
      onCapture: _registerImage,
    );
  }

  Future<void> _processImage(InputImage inputImage) async {
    if (!_canProcess) return;
    if (_isBusy) return;
    _isBusy = true;
    setState(() {
      faceList = [];
    });
    final faces = await _faceDetector.processImage(inputImage);
    if (inputImage.metadata?.size != null &&
        inputImage.metadata?.rotation != null &&
        faces.isNotEmpty) {
      img_lib.Image? image = Platform.isIOS
          ? _convertBGRA8888(inputImage)
          : _convertNV21(inputImage, _cameraLensDirection);
      List<MapEntry<String, Face>> mapList = [];
      for (var face in faces) {
        final x = (face.boundingBox.left);
        final y = (face.boundingBox.top);
        final w = (face.boundingBox.width);
        final h = (face.boundingBox.height);
        img_lib.Image croppedImage = img_lib.copyCrop(image,
            x: x.round(), y: y.round(), width: w.round(), height: h.round());
        String name = await TfliteUtils.getInstance().recognizeFaceFromImage(croppedImage);
        mapList.add(MapEntry(name, face));
      }
      final painter = FaceDetectorPainter(faces, inputImage.metadata!.size,
          inputImage.metadata!.rotation, _cameraLensDirection, mapList);
      _customPaint = CustomPaint(painter: painter);
    } else if(faces.isNotEmpty){
      debugPrint("${inputImage.filePath}");
      img_lib.Image? image = await img_lib.decodeImageFile("${inputImage.filePath}");
      if(image != null) {
        List<MapEntry<String, Face>> mapList = [];
        for (var face in faces) {
          final x = (face.boundingBox.left);
          final y = (face.boundingBox.top);
          final w = (face.boundingBox.width);
          final h = (face.boundingBox.height);
          img_lib.Image croppedImage = img_lib.copyCrop(image,
              x: x.round(), y: y.round(), width: w.round(), height: h.round());
          String name = await TfliteUtils.getInstance().recognizeFaceFromImage(croppedImage);
          mapList.add(MapEntry(name, face));
        }
        faceList = mapList;
      }else{
        faceList = faces.map((e) => MapEntry("", e)).toList();
      }
      // TODO: set _customPaint to draw boundingRect on top of image
      _customPaint = null;
    }
    _isBusy = false;
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _registerImage(InputImage inputImage) async {
    if (!_canProcess) return;
    _isBusy = true;
    if (mounted) {
      setState(() {});
    }
    final faces = await _faceDetector.processImage(inputImage);
    if (faces.isNotEmpty) {
      img_lib.Image? image = Platform.isIOS
          ? _convertBGRA8888(inputImage)
          : _convertNV21(inputImage, _cameraLensDirection);
      final x = (faces.first.boundingBox.left);
      final y = (faces.first.boundingBox.top);
      final w = (faces.first.boundingBox.width);
      final h = (faces.first.boundingBox.height);
      img_lib.Image croppedImage = img_lib.copyCrop(image,
          x: x.round(), y: y.round(), width: w.round(), height: h.round());
      final name = await showRegisterFaceDialog(croppedImage);
      if (name != null && name.isNotEmpty) {
        await TfliteUtils.getInstance().handleWriteJSONFromImage(name, croppedImage);
      }
    }
    _isBusy = false;
    if (mounted) {
      setState(() {});
    }
  }

  Future<String?> showRegisterFaceDialog(img_lib.Image croppedImage) async {
    return await showDialog(
        context: context,
        builder: (context) {
          String? name;
          return AlertDialog(
            scrollable: true,
            title: const Text("Add Face"),
            content: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                    ),
                    child: Image(
                      height: 200,
                      image: MemoryImage(img_lib.encodePng(croppedImage)),
                    )),
                TextField(
                  autofocus: true,
                  decoration: const InputDecoration(
                      labelText: "Name", icon: Icon(Icons.face)),
                  onChanged: (val) {
                    name = val;
                  },
                )
              ],
            ),
            actions: <Widget>[
              TextButton(
                  child: const Text("Save"),
                  onPressed: () {
                    Navigator.pop(context, name);
                  }),
              TextButton(
                child: const Text("Cancel"),
                onPressed: () {
                  Navigator.pop(context, name);
                },
              )
            ],
          );
        });
  }

  img_lib.Image _convertBGRA8888(InputImage image) {
    var img = img_lib.Image.fromBytes(
      width: image.metadata!.size.width.toInt(),
      height: image.metadata!.size.height.toInt(),
      bytes: image.bytes!.buffer,
    );
    return img;
  }

  img_lib.Image _convertNV21(InputImage image, CameraLensDirection dir) {
    final width = image.metadata!.size.width.toInt();
    final height = image.metadata!.size.height.toInt();
    Uint8List yuv420sp = image.bytes ?? Uint8List(0);

    // Initial conversion from NV21 to RGB
    final outImg = img_lib.Image(height: height, width: width);
    final int frameSize = width * height;

    for (int j = 0, yp = 0; j < height; j++) {
      int uvp = frameSize + (j ~/ 2) * width,
          u = 0,
          v = 0; // Use integer division (~/)
      for (int i = 0; i < width; i++, yp++) {
        int y = (0xff & yuv420sp[yp]) - 16;
        if (y < 0) y = 0;
        if ((i & 1) == 0) {
          v = (0xff & yuv420sp[uvp++]) - 128;
          u = (0xff & yuv420sp[uvp++]) - 128;
        }
        int y1192 = 1192 * y;
        int r = (y1192 + 1634 * v);
        int g = (y1192 - 833 * v - 400 * u);
        int b = (y1192 + 2066 * u);

        if (r < 0) {
          r = 0;
        } else if (r > 262143) {
          r = 262143;
        }
        if (g < 0) {
          g = 0;
        } else if (g > 262143) {
          g = 262143;
        }
        if (b < 0) {
          b = 0;
        } else if (b > 262143) {
          b = 262143;
        }

        // Corrected pixel coordinates
        outImg.setPixelRgb(i, j, ((r << 6) & 0xff0000) >> 16,
            ((g >> 2) & 0xff00) >> 8, (b >> 10) & 0xff);
      }
    }
    return dir == CameraLensDirection.front
        ? img_lib.copyRotate(outImg, angle: -90)
        : img_lib.copyRotate(outImg, angle: 90);
  }
}
