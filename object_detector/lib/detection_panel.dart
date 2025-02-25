
import 'package:flutter/material.dart';
import 'package:object_detector/detection.dart';

class DetectionPanel extends StatelessWidget {
  final List<Detection> detections;
  final Image image;
  final Size originalImageSize;
  final List<String> labels;

  const DetectionPanel({
    super.key,
    required this.detections,
    required this.image,
    required this.originalImageSize,
    required this.labels,
  });


  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        
        return CustomPaint(
          foregroundPainter: BoundingBoxPainter(
            detections: detections,
            originalImageSize: originalImageSize,
            labels: labels,
          ),
          child: image,
        );
      },
    );
  }
}

class BoundingBoxPainter extends CustomPainter {
  final List<Detection> detections;
  final Size originalImageSize;
  final List<String> labels;

  BoundingBoxPainter({
    required this.detections,
    required this.originalImageSize,
    required this.labels,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = Colors.red;

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.left,
    );

    // Calculate aspect ratios
    final double imageAspectRatio = originalImageSize.width / originalImageSize.height;
    final double containerAspectRatio = size.width / size.height;

    double newWidth, newHeight;
    double leftMargin = 0.0;
    double topMargin = 0.0;

    // Calculate new dimensions to maintain aspect ratio
    if (imageAspectRatio > containerAspectRatio) {
      // Image is wider than container
      newWidth = size.width;
      newHeight = size.width / imageAspectRatio;
      topMargin = (size.height - newHeight) / 2;
    } else {
      // Image is taller than container
      newHeight = size.height;
      newWidth = size.height * imageAspectRatio;
      leftMargin = (size.width - newWidth) / 2;
    }

    final Size displaySize = Size(newWidth, newHeight);

    // Calculate scaling factors from original to display size
    final originalToDisplayScaleX = displaySize.width / originalImageSize.width;
    final originalToDisplayScaleY = displaySize.height / originalImageSize.height;

    for (final detection in detections) {
      // Scale to display size and apply margins
      final displayRect = Rect.fromLTWH(
        (detection.boundingBox.left * originalToDisplayScaleX) + leftMargin,
        (detection.boundingBox.top * originalToDisplayScaleY) + topMargin,
        detection.boundingBox.width * originalToDisplayScaleX,
        detection.boundingBox.height * originalToDisplayScaleY,
      );

      // Draw bounding box
      canvas.drawRect(displayRect, paint);

      // Draw label
      final label = '${labels[detection.classId]} ${(detection.confidence * 100).toStringAsFixed(1)}%';
      textPainter.text = TextSpan(
        text: label,
        style: const TextStyle(
          color: Colors.white,
          backgroundColor: Colors.red,
          fontSize: 14,
        ),
      );
      textPainter.layout();

      // Draw label background
      final textBgPaint = Paint()..color = Colors.red;
      canvas.drawRect(
        Rect.fromLTWH(
          displayRect.left,
          displayRect.top - textPainter.height,
          textPainter.width,
          textPainter.height
        ),
        textBgPaint,
      );

      // Draw text
      textPainter.paint(
        canvas,
        Offset(displayRect.left, displayRect.top - textPainter.height),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}