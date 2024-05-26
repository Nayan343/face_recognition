import 'dart:convert';
import 'dart:math';

import 'package:face_recognition/shared_prefs.dart';
import 'package:face_recognition/tflite_user_model.dart';
import 'package:flutter/cupertino.dart' hide Image;
import 'package:image/image.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class TfliteUtils {
  Interpreter? _interpreter;
  List<TfLiteUserModel> _data = [];
  final double _threshold = 0.75;

  static TfliteUtils? _tfliteUtils;

  TfliteUtils._() {
    loadModel();
  }
  static TfliteUtils getInstance() {
    _tfliteUtils ??= TfliteUtils._();
    return _tfliteUtils!;
  }

  Future<void> loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset('tflite/facenet.tflite');
      debugPrint(
          '**********\n Loaded successfully model facenet.tflite \n*********\n');
      final data = await SharedPrefs.getValue("savedFaces", defaultValue: null);
      if(data != null && data.isNotEmpty){
        final json = jsonDecode(data);
        for (var item in json) {
          _data.add(TfLiteUserModel.fromJson(item));
        }
      }
    } catch (e) {
      debugPrint('Failed to load model. $e');
    }
  }

  Future<String> recognizeFaceFromImage(Image img) async {
    List<dynamic> predictedData = _generateEmbedding(img);
    return _compareExistSavedFaces(predictedData);
  }

  String _compareExistSavedFaces(List<dynamic> currEmb) {
    if (_data.isEmpty == true) return "";
    double minDist = 999;
    double currDist = 0.0;
    String producedRes = "Person not found";
    for (TfLiteUserModel item in _data) {
      currDist = _euclideanDistance(item.embedding ?? [], currEmb);
      if (currDist <= _threshold && currDist < minDist) {
        minDist = currDist;
        producedRes = item.name ?? "";
      }
    }
    debugPrint("$currDist $minDist $producedRes");
    return producedRes;
  }

  Future<void> handleWriteJSONFromImage(String name, Image img) async {
    try {
      List<dynamic> predictedData = _generateEmbedding(img);
      final existsEmp = _data.firstWhere((element) => element.name == name, orElse: () => TfLiteUserModel());
      if(existsEmp.embedding != null){
        final index = _data.indexOf(existsEmp);
        existsEmp.embedding = predictedData;
        existsEmp.image = base64Encode(encodePng(img));
        _data[index] = existsEmp;
      }else {
        final user = TfLiteUserModel(name: name, embedding: predictedData, image: base64Encode(encodePng(img)));
        _data.add(user);
      }
      SharedPrefs.setValue("savedFaces", json.encode(_data));
    }catch(e){
      debugPrint('Error writing to file: $e');
    }
  }

  List<double> _imageToByteList(
      Image image, int inputSize, double mean, double std) {
    // Resize the image to the desired input size
    image = copyResize(image, width: inputSize, height: inputSize);

    // Create an empty list to store normalized pixel values
    List<double> pixelValues = [];

    // Iterate over each pixel in the resized image
    for (var y = 0; y < inputSize; y++) {
      for (var x = 0; x < inputSize; x++) {
        // Get the pixel color at (x, y)
        var pixel = image.getPixel(x, y);

        // Normalize pixel values between -1 and 1
        double normalizedR = (pixel.r.toDouble() - mean) / std;
        double normalizedG = (pixel.g.toDouble() - mean) / std;
        double normalizedB = (pixel.b.toDouble() - mean) / std;

        // Add normalized pixel values to the list
        pixelValues.add(normalizedR);
        pixelValues.add(normalizedG);
        pixelValues.add(normalizedB);
      }
    }

    return pixelValues;
  }

  List<double> _normalizeImage(List<double> image) {
    // Find the min and max values in the input list
    double minVal = image.reduce((min, val) => val < min ? val : min);
    double maxVal = image.reduce((max, val) => val > max ? val : max);

    // Scale the pixel values to the range [-1, 1]
    List<double> normalizedInput = image.map((val) => (val - minVal) / (maxVal - minVal)).toList();

    return normalizedInput;
  }

  double _euclideanDistance(List<dynamic> e1, List<dynamic> e2) {
    if(e1.length != e2.length) return 1.0;
    double sum = 0.0;
    for (int i = 0; i < e1.length; i++) {
      sum += pow((e1[i] - e2[i]), 2);
    }
    return sqrt(sum);
  }

  List<dynamic> _generateEmbedding(Image img) {
    img = copyResizeCropSquare(img, size: _interpreter!.getInputTensors().first.shape[1]);
    List<double> input = _imageToByteList(img, _interpreter!.getInputTensors().first.shape[1], 128, 128);
    input = _normalizeImage(input);
    List input1 = input.reshape(_interpreter!.getInputTensors().first.shape);
    List output = List.generate(1, (index) => List.filled(512, 0));

    _interpreter?.run(input1, output);
    output = output.reshape([512]);
    final predictedData = List.from(output);
    return predictedData;
  }

  bool checkUserRegistered(String name){
    return _data.any((element) => element.name == name);
  }

  List<TfLiteUserModel> getAllUser() {
    return _data;
  }

  void dispose() {
    _interpreter?.close();
    _data = [];
  }
}
