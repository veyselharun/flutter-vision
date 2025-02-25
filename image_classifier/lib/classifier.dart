// Image classification exmaple using YOLO.
//
// https://docs.ultralytics.com/modes/export/
// https://docs.ultralytics.com/models/yolo11/
// https://docs.ultralytics.com/models/yolov8/

import 'package:flutter/material.dart';
import 'dart:io';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'dart:math';
import 'package:image_picker/image_picker.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  File? _image;
  List<String>? _labels;
  Interpreter? _interpreter;
  String _classificationResult = "No prediction";

  @override
  void initState() {
    super.initState();
    _loadModel();
    _loadLabels();
  }

  Future<void> _loadModel() async {
    final interpreterOptions = InterpreterOptions()..useNnApiForAndroid = true;
    _interpreter =
        await Interpreter.fromAsset('assets/yolo11l-cls_float32.tflite', options: interpreterOptions);
    //_interpreter =
    //    await Interpreter.fromAsset('assets/yolo11l-cls_float32.tflite');
  }

  // Load labels from the asset file
  Future<void> _loadLabels() async {
    final labelsData =
        await DefaultAssetBundle.of(context).loadString('assets/image_net_labels.txt');
    setState(() {
      _labels = labelsData.split('\n');
    });
  }

  Future<void> _classifyImage(File imageFile) async {
    // Create input tensor
    // Convert the image to YOLO input tensor
    // Input tensor is a 4D array with shape [1, 224, 224, 3]
    final List<List<List<List<double>>>> inputTensor = await _createYOLOInputTensor(imageFile);

    // Create output tensor
    // Output tensor is a 2D array with shape [1, 1000]
    final List<List<double>> outputTensor = List.generate(1, (_) => List.filled(_labels!.length, 0.0));

    // Run inference
    _interpreter!.run(inputTensor, outputTensor);

    // Get the index of the highest probability
    List<double> probabilities = outputTensor.first;
    int highestProbabilityIndex = probabilities
      .indexWhere((element) => element == probabilities.reduce(max));
     
    // Get the label and value of the highest probability
    final label = _labels![highestProbabilityIndex];
    final confidence = probabilities[highestProbabilityIndex];

    setState(() {
      // Convert confidence to percentage and display the result
      _classificationResult =
          "$label: ${(confidence * 100).toStringAsFixed(2)}%";
    });
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
        _classificationResult = 'Classifying';
      });
      await _classifyImage(_image!);
    }
  }

  Future<List<List<List<List<double>>>>> _createYOLOInputTensor(
      File imageFile) async {
    // Load the image using the `image` package
    final bytes = await imageFile.readAsBytes();
    img.Image? image = img.decodeImage(bytes);

    // Define the YOLO input size
    // For YOLO classification input size should be 224
    const int inputSize = 224;

    // Resize the image to YOLO input size (224x224)
    // Should we make this linear?
    final img.Image resizedImage =
        img.copyResize(image!, width: inputSize, height: inputSize);
    /*
    final resizedImage = img.copyResize(image,
        width: inputSize,
        height: inputSize,
        interpolation: img.Interpolation.linear);*/

    // Normalize and convert the image to a 4D tensor
    // The tensor shape should be [1, 224, 224, 3] and normalized between 0 and 1
    // We can use List<dynamic>. If we choose to do that we also need to change the return value.
    List<List<List<List<double>>>> inputTensor = List.generate(
      1,
      (_) => List.generate(
        inputSize,
        (y) => List.generate(
          inputSize,
          (x) {
            // Get pixel values
            final pixel = resizedImage.getPixel(x, y);
            // Normalize pixel values between 0 and -1.
            // If you want to normalize between -1 and 1 the formula should be like
            // (pixel_value - 127.5) / 127.5
            final r = pixel.r / 255.0;
            final g = pixel.g / 255.0;
            final b = pixel.b / 255.0;
            return [r, g, b];
          },
        ),
      ),
    );

    return inputTensor;
  }
  
  @override
  void dispose() {
    _interpreter?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('YOLO Image Classification')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
              ),
              child: _image != null ? Image.file(_image!) : Text('No image selected.'),
            ),
            SizedBox(height: 16),
            Text(
              _classificationResult,
              style: TextStyle(fontSize: 20),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _pickImage,
              child: Text('Pick Image'),
            ),
          ],
        ),
      ),
    );
  }
}