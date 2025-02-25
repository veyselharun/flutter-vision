// Object detection exmaple using YOLO.
//
// https://docs.ultralytics.com/modes/export/
// https://docs.ultralytics.com/models/yolo11/
// https://docs.ultralytics.com/models/yolov8/

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:logger/logger.dart';
import 'package:object_detector/detection.dart';
import 'package:object_detector/detection_panel.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class DetectionService {
  Interpreter? _interpreter;
  DetectionPanel? detectionPanel;
  final _logger = Logger();

  // Constants
  final double confidenceThreshold = 0.25;
  final double iouThreshold = 0.45;

  Future<List<Detection>> startDetection(File imageFile) async {
    // Initialize interpreter
    _interpreter = await Interpreter.fromAsset('assets/yolo11l_float32.tflite');
    _logger.d('Input tensor shape: ${_interpreter!.getInputTensor(0).shape}');
    _logger.d('Output tensor shape: ${_interpreter!.getOutputTensor(0).shape}');

    // Create input tensor
    // Convert the image to YOLO input tensor
    // Input tensor is a 4D array with shape [1, 640, 640, 3]
    final List<List<List<List<double>>>> inputTensor =
        await _createYOLOInputTensor(imageFile);

    // Create output tensor
    // Output tensor is a 3D array with shape [1, 84, 8400]
    final List<List<List<double>>> outputTensor = List.generate(
        1, (_) => List.generate(84, (_) => List.filled(8400, 0.0)));

    // Run inference
    _interpreter!.run(inputTensor, outputTensor);

    // Process output tensor
    List<Detection> detections = processModelOutput(outputTensor, imageFile);

    for (final detection in detections) {
      _logger.d({
        'class': detection.classId,
        'confidence': detection.confidence,
        'boundingBox': detection.boundingBox,
      });
    }

    // Close interpreter
    _interpreter?.close();

    return detections;
  }

  Future<List<List<List<List<double>>>>> _createYOLOInputTensor(
      File imageFile) async {
    // Load the image using the `image` package
    final bytes = await imageFile.readAsBytes();
    img.Image? image = img.decodeImage(bytes);

    // Define the YOLO input size
    // For YOLO classification input size should be 640
    const int inputSize = 640;

    // Resize the image to YOLO input size (640x640)
    // Should we make this linear?
    final img.Image resizedImage =
        img.copyResize(image!, width: inputSize, height: inputSize);

    // Normalize and convert the image to a 4D tensor
    // The tensor shape should be [1, 640, 640, 3] and normalized between 0 and 1
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

  List<Detection> processModelOutput(
      List<List<List<double>>> modelOutput, File imageFile) {
    // modelOutput shape: [1, 84, 8400]
    // modelOutput[0] shape: [84, 8400]
    final outputs = modelOutput[0]; // Get first batch

    // Separate box coordinates and class scores
    final boxes = <Rect>[];
    final scores = <double>[];
    final classes = <int>[];

    // For each of the 8400 predictions
    for (var i = 0; i < 8400; i++) {
      // Extract box coordinates (first 4 values)
      final x = outputs[0][i];
      final y = outputs[1][i];
      final w = outputs[2][i];
      final h = outputs[3][i];

      // Convert to Rect
      final rect = Rect.fromLTWH(
          x - w / 2, // Convert from center to top-left
          y - h / 2,
          w,
          h);

      // Find class with highest score
      var maxScore = 0.0;
      var maxClass = 0;
      for (var c = 0; c < 80; c++) {
        final score = outputs[c + 4][i];
        if (score > maxScore) {
          maxScore = score;
          maxClass = c;
        }
      }

      if (maxScore > confidenceThreshold) {
        final absoluteRect =
            Rect.fromLTWH(rect.left, rect.top, rect.width, rect.height);

        boxes.add(absoluteRect);
        scores.add(maxScore);
        classes.add(maxClass);
      }
    }

    // Apply Non-Max Suppression
    final indices = nonMaxSuppression(boxes, scores, iouThreshold);

    // Unnormalize bounding box coordinates to model input size (640x640)
    // The bounding box coordinates are returned between 0 and 1
    // Our input image size to the model is 640x640. We are multiplying each value with 640 to normalize it.
    for (int i = 0; i < boxes.length; i++) {
      final absoluteRect = Rect.fromLTWH(boxes[i].left * 640,
          boxes[i].top * 640, boxes[i].width * 640, boxes[i].height * 640);
      boxes[i] = absoluteRect;
    }

    final image = img.decodeImage(imageFile.readAsBytesSync())!;
    Size originalImageSize =
        Size(image.width.toDouble(), image.height.toDouble());

    // Calculate scaling factors from model input (640x640) to original image size
    final modelToOriginalScaleX = originalImageSize.width / 640;
    final modelToOriginalScaleY = originalImageSize.height / 640;

    // Scale from model input size (640x640) to original image size
    for (int i = 0; i < boxes.length; i++) {
      final originalRect = Rect.fromLTWH(
          boxes[i].left * modelToOriginalScaleX,
          boxes[i].top * modelToOriginalScaleY,
          boxes[i].width * modelToOriginalScaleX,
          boxes[i].height * modelToOriginalScaleY);
      boxes[i] = originalRect;
    }

    // Create the detections list
    List<Detection> detections = indices
        .map((i) => Detection(
            boundingBox: boxes[i], confidence: scores[i], classId: classes[i]))
        .toList();

    return detections;
  }

  // Non-Max Suppression implementation
  List<int> nonMaxSuppression(
      List<Rect> boxes, List<double> scores, double iouThreshold) {
    final indices = <int>[];

    // Create list of indices
    final indexList = List<int>.generate(scores.length, (i) => i);

    // Sort indices by scores in descending order
    indexList.sort((a, b) => scores[b].compareTo(scores[a]));

    while (indexList.isNotEmpty) {
      final index = indexList[0];
      indices.add(index);

      indexList.removeAt(0);

      // Remove boxes with high IoU
      indexList.removeWhere((compareIndex) {
        final overlap = _calculateIoU(boxes[index], boxes[compareIndex]);
        return overlap >= iouThreshold;
      });
    }

    return indices;
  }

  // Calculate Intersection over Union (IoU)
  double _calculateIoU(Rect box1, Rect box2) {
    final intersectionRect = box1.intersect(box2);

    if (intersectionRect.isEmpty) return 0.0;

    final intersectionArea = intersectionRect.width * intersectionRect.height;
    final box1Area = box1.width * box1.height;
    final box2Area = box2.width * box2.height;
    final unionArea = box1Area + box2Area - intersectionArea;

    return intersectionArea / unionArea;
  }
}
