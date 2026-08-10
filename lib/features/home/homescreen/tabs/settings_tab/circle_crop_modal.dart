import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../core/theme/app_colors.dart';

/// Full-screen modal that lets the user pan and pinch-to-zoom an image within
/// a circular crop frame. Returns the cropped image bytes (PNG) on confirm,
/// or null on cancel.
///
/// Usage:
/// ```dart
/// final croppedBytes = await showCircleCropModal(context, imageFile);
/// ```
Future<Uint8List?> showCircleCropModal(
    BuildContext context, File imageFile) async {
  return Navigator.of(context).push<Uint8List?>(
    PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black87,
      pageBuilder: (_, __, ___) => _CircleCropModal(imageFile: imageFile),
      transitionsBuilder: (_, animation, __, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    ),
  );
}

class _CircleCropModal extends StatefulWidget {
  const _CircleCropModal({required this.imageFile});

  final File imageFile;

  @override
  State<_CircleCropModal> createState() => _CircleCropModalState();
}

class _CircleCropModalState extends State<_CircleCropModal> {
  // Transform state for the image (pan + zoom).
  final TransformationController _controller = TransformationController();
  late final ui.Image _uiImage;
  bool _loaded = false;
  bool _cropping = false;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    final bytes = await widget.imageFile.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    if (mounted) {
      setState(() {
        _uiImage = frame.image;
        _loaded = true;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onConfirm() async {
    if (_cropping) return;
    setState(() => _cropping = true);

    try {
      final cropped = await _cropCircle();
      if (mounted) Navigator.of(context).pop(cropped);
    } catch (_) {
      if (mounted) Navigator.of(context).pop(null);
    }
  }

  /// Renders the visible portion of the image inside the circle into a PNG.
  Future<Uint8List> _cropCircle() async {
    final screenSize = MediaQuery.sizeOf(context);
    final cropDiameter = screenSize.width * 0.75;
    final outputSize = cropDiameter.toInt();

    // The circle is centered on screen.
    final circleCenterScreen = Offset(
      screenSize.width / 2,
      screenSize.height / 2,
    );

    // The InteractiveViewer applies a transform to the image. We need to find
    // what part of the *original* image is visible inside the circle.
    final matrix = _controller.value;
    final inverseMatrix = Matrix4.inverted(matrix);

    // Image widget is laid out to fill the screen width originally, then
    // transformed. Figure out the scale from image pixels → screen pixels.
    final imgWidth = _uiImage.width.toDouble();
    final imgHeight = _uiImage.height.toDouble();
    final fitScale = screenSize.width / imgWidth;
    final fittedHeight = imgHeight * fitScale;

    // The image is centered vertically in the InteractiveViewer viewport.
    final imageTopOnScreen = (screenSize.height - fittedHeight) / 2;

    // Convert circle bounds from screen space → image space.
    final cropRadius = cropDiameter / 2;

    // Top-left of the crop rect in screen coords (before InteractiveViewer transform).
    final cropTopLeftScreen = Offset(
      circleCenterScreen.dx - cropRadius,
      circleCenterScreen.dy - cropRadius,
    );

    // Apply inverse of the interactive viewer transform to get image-widget coords.
    final transformedTL = MatrixUtils.transformPoint(
      inverseMatrix,
      cropTopLeftScreen,
    );
    final transformedBR = MatrixUtils.transformPoint(
      inverseMatrix,
      Offset(
        circleCenterScreen.dx + cropRadius,
        circleCenterScreen.dy + cropRadius,
      ),
    );

    // Convert from widget coords → original image pixel coords.
    final srcLeft = (transformedTL.dx / fitScale).clamp(0.0, imgWidth);
    final srcTop =
        ((transformedTL.dy - imageTopOnScreen) / fitScale).clamp(0.0, imgHeight);
    final srcRight = (transformedBR.dx / fitScale).clamp(0.0, imgWidth);
    final srcBottom =
        ((transformedBR.dy - imageTopOnScreen) / fitScale).clamp(0.0, imgHeight);

    final srcRect =
        Rect.fromLTRB(srcLeft, srcTop, srcRight, srcBottom);

    // Draw into a square canvas with a circular clip.
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final size = Size(outputSize.toDouble(), outputSize.toDouble());

    final destRect = Rect.fromLTWH(0, 0, size.width, size.height);

    // Clip to circle.
    final circlePath = Path()
      ..addOval(destRect);
    canvas.clipPath(circlePath);

    // Draw the image portion.
    canvas.drawImageRect(
      _uiImage,
      srcRect,
      destRect,
      Paint()..filterQuality = FilterQuality.high,
    );

    final picture = recorder.endRecording();
    final img = await picture.toImage(outputSize, outputSize);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final cropDiameter = screenSize.width * 0.75;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Image with InteractiveViewer for pan + zoom.
          if (_loaded)
            Center(
              child: InteractiveViewer(
                transformationController: _controller,
                minScale: 0.5,
                maxScale: 4.0,
                clipBehavior: Clip.none,
                child: Image.file(
                  widget.imageFile,
                  width: screenSize.width,
                  fit: BoxFit.fitWidth,
                ),
              ),
            )
          else
            const Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
                strokeWidth: 2.5,
              ),
            ),

          // Dark overlay with circular cutout.
          if (_loaded)
            IgnorePointer(
              child: CustomPaint(
                size: screenSize,
                painter: _CircleOverlayPainter(
                  cropDiameter: cropDiameter,
                  overlayColor: Colors.black.withValues(alpha: 0.6),
                  borderColor: AppColors.white,
                ),
              ),
            ),

          // Top bar with cancel.
          Positioned(
            top: MediaQuery.paddingOf(context).top + 12,
            left: 16,
            child: IconButton(
              onPressed: () => Navigator.of(context).pop(null),
              icon: const Icon(Icons.close_rounded, color: AppColors.white),
              iconSize: 28,
            ),
          ),

          // Bottom confirm button.
          Positioned(
            bottom: MediaQuery.paddingOf(context).bottom + 24,
            left: 0,
            right: 0,
            child: Center(
              child: SizedBox(
                width: 180,
                height: 48,
                child: ElevatedButton(
                  onPressed: _cropping ? null : _onConfirm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    elevation: 4,
                  ),
                  child: _cropping
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.white,
                          ),
                        )
                      : const Text(
                          'Confirm',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Paints a dark overlay with a transparent circular cutout in the center,
/// a dashed white border around the circle, and subtle rule-of-thirds grid
/// lines inside the crop area for a professional framing guide.
class _CircleOverlayPainter extends CustomPainter {
  const _CircleOverlayPainter({
    required this.cropDiameter,
    required this.overlayColor,
    required this.borderColor,
  });

  final double cropDiameter;
  final Color overlayColor;
  final Color borderColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = cropDiameter / 2;

    // Draw overlay with hole.
    final overlayPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addOval(Rect.fromCircle(center: center, radius: radius))
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(overlayPath, Paint()..color = overlayColor);

    // Dashed circle border.
    const dashLength = 8.0;
    const gapLength = 5.0;
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final circumference = 3.14159265 * 2 * radius;
    final dashCount = (circumference / (dashLength + gapLength)).floor();
    final anglePerDash = (3.14159265 * 2) / dashCount;
    final sweepAngle = anglePerDash * (dashLength / (dashLength + gapLength));

    for (var i = 0; i < dashCount; i++) {
      final startAngle = i * anglePerDash - 1.5708; // offset by -90°
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        borderPaint,
      );
    }

    // Rule-of-thirds grid lines (clipped to circle).
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: center, radius: radius)));

    final gridPaint = Paint()
      ..color = borderColor.withValues(alpha: 0.25)
      ..strokeWidth = 0.8;

    // Vertical thirds.
    final thirdW = cropDiameter / 3;
    for (var i = 1; i < 3; i++) {
      final x = center.dx - radius + (thirdW * i);
      canvas.drawLine(
        Offset(x, center.dy - radius),
        Offset(x, center.dy + radius),
        gridPaint,
      );
    }

    // Horizontal thirds.
    final thirdH = cropDiameter / 3;
    for (var i = 1; i < 3; i++) {
      final y = center.dy - radius + (thirdH * i);
      canvas.drawLine(
        Offset(center.dx - radius, y),
        Offset(center.dx + radius, y),
        gridPaint,
      );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CircleOverlayPainter oldDelegate) =>
      cropDiameter != oldDelegate.cropDiameter;
}
