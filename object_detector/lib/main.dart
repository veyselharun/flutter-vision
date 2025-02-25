// Object detection exmaple using YOLO.
//
// https://docs.ultralytics.com/modes/export/
// https://docs.ultralytics.com/models/yolo11/
// https://docs.ultralytics.com/models/yolov8/

import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:logger/logger.dart';

import 'package:object_detector/detection.dart';
import 'package:object_detector/detection_panel.dart';
import 'package:object_detector/detection_service.dart';

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
  String _detectionResult = "No Detection";
  DetectionPanel? detectionPanel;
  final _logger = Logger();

  @override
  void initState() {
    super.initState();
    _loadLabels();
  }

  // Load labels from the asset file
  Future<void> _loadLabels() async {
    final labelsData = await DefaultAssetBundle.of(context)
        .loadString('assets/coco_labels_2014_2017.txt');
    setState(() {
      _labels = labelsData.split('\n');
    });
  }

  Future<void> _detectObjects(File imageFile) async {
    DetectionService detectionService = DetectionService();

    List<Detection> detections =
        await detectionService.startDetection(imageFile);

    for (final detection in detections) {
      _logger.d({
        'class': detection.classId,
        'confidence': detection.confidence,
        'boundingBox': detection.boundingBox,
      });
    }

    final image = img.decodeImage(imageFile.readAsBytesSync())!;
    Size imageSize =
        Size(image.width.toDouble(), image.height.toDouble());
    setState(() {
      detectionPanel = DetectionPanel(
        detections: detections,
        image: Image.file(imageFile),
        originalImageSize: imageSize,
        labels: _labels!,
      );
      _detectionResult = 'Detection Complete';
    });
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
        _detectionResult = 'Detecting';
      });
      await _detectObjects(_image!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('YOLO Object Detection')),
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
              child: _image != null
                  ? Image.file(_image!)
                  : Text('No image selected.'),
            ),
            SizedBox(height: 16),
            Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
              ),
              child: detectionPanel != null
                  ? detectionPanel!
                  : Text('No image selected.'),
            ),
            SizedBox(height: 16),
            Text(
              _detectionResult,
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
