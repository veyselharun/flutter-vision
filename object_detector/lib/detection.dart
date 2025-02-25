
import 'package:flutter/material.dart';

class Detection {
  final Rect boundingBox;
  final double confidence;
  final int classId;

  Detection({
    required this.boundingBox,
    required this.confidence,
    required this.classId,
  });
}
