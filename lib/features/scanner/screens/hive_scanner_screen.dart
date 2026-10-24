import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../services/qr_payload_parser.dart';
import '../widgets/user_qr_dialog.dart';

/// Full-screen in-app QR Code Scanner for WatchersHive.
/// Seamlessly scans and routes to User Profiles (to follow or send requests)
/// or Movie Details (to view, log, or track on another device).
class HiveScannerScreen extends ConsumerStatefulWidget {
  const HiveScannerScreen({super.key});

  @override
  ConsumerState<HiveScannerScreen> createState() => _HiveScannerScreenState();
}

class _HiveScannerScreenState extends ConsumerState<HiveScannerScreen>
    with SingleTickerProviderStateMixin {
  late final MobileScannerController _controller;
  late final AnimationController _animController;
  late final Animation<double> _scanLineAnimation;

  bool _isProcessing = false;
  bool _isTorchOn = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
      torchEnabled: false,
    );

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _scanLineAnimation = Tween<double>(begin: 0.08, end: 0.92).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleBarcodeDetected(BarcodeCapture capture) async {
    if (_isProcessing) return;

    final barcode = capture.barcodes.firstOrNull;
    final rawValue = barcode?.rawValue;
    if (rawValue == null || rawValue.trim().isEmpty) return;

    setState(() => _isProcessing = true);
    HapticFeedback.mediumImpact();

    final parsed = QrPayloadParser.parse(rawValue);

    if (!mounted) return;

    switch (parsed) {
      case UserQrResult userResult:
        HapticFeedback.heavyImpact();
        // Stop camera controller and navigate directly to target user's profile
        await _controller.stop();
        if (mounted) {
          context.pushReplacement('/profile/${userResult.userId}');
        }
        break;

      case MovieQrResult movieResult:
        HapticFeedback.heavyImpact();
        // Stop camera controller and navigate directly to target movie/series details
        await _controller.stop();
        if (mounted) {
          final queryParams = <String, String>{};
          if (movieResult.suggestedByUserId != null && movieResult.suggestedByUserId!.isNotEmpty) {
            queryParams['suggestedByUserId'] = movieResult.suggestedByUserId!;
          }
          if (movieResult.suggestedByUsername != null && movieResult.suggestedByUsername!.isNotEmpty) {
            queryParams['suggestedByUsername'] = movieResult.suggestedByUsername!;
          }
          final uri = Uri(
            path: '/details/${movieResult.mediaType}/${movieResult.tmdbId}',
            queryParameters: queryParams.isNotEmpty ? queryParams : null,
          );
          context.pushReplacement(uri.toString());
        }
        break;

      case UnknownQrResult unknown:
        _showUnrecognizedSheet(unknown.rawData);
        break;
    }
  }

  void _showUnrecognizedSheet(String rawData) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.info_outline_rounded, color: Colors.amber, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Unrecognized Code',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Text(
                'This QR code does not appear to be a WatchersHive user profile or movie link.',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  rawData.length > 120 ? '${rawData.substring(0, 120)}...' : rawData,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    setState(() => _isProcessing = false);
                  },
                  child: const Text(
                    'Scan Again',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ).then((_) {
      if (mounted) setState(() => _isProcessing = false);
    });
  }

  void _showMyQrCode() {
    final currentUser = ref.read(authStateProvider).value?.user;
    if (currentUser == null) return;

    UserQrDialog.showForUser(context, currentUser, isMe: true);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final scanBoxSize = (size.width * 0.72).clamp(240.0, 320.0);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Live Camera Preview
          MobileScanner(
            controller: _controller,
            onDetect: _handleBarcodeDetected,
            errorBuilder: (context, error) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(28.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.camera_alt_outlined, color: AppColors.textMuted, size: 54),
                      const SizedBox(height: 16),
                      const Text(
                        'Camera Unavailable',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        error.errorDetails?.message ??
                            'Please allow camera permission in your system settings to scan QR codes.',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          color: AppColors.textMuted,
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => context.pop(),
                        child: const Text('Go Back', style: TextStyle(fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // 2. Viewfinder Dimmed Overlay with Cutout
          CustomPaint(
            size: size,
            painter: _ScannerOverlayPainter(
              boxSize: scanBoxSize,
              borderColor: AppColors.primary,
            ),
          ),

          // 3. Animated Laser Scanning Line inside Viewfinder
          Center(
            child: SizedBox(
              width: scanBoxSize,
              height: scanBoxSize,
              child: AnimatedBuilder(
                animation: _scanLineAnimation,
                builder: (context, child) {
                  return Align(
                    alignment: Alignment(0, (_scanLineAnimation.value * 2) - 1),
                    child: Container(
                      width: scanBoxSize - 24,
                      height: 3,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary.withValues(alpha: 0.1),
                            AppColors.primary,
                            AppColors.primary.withValues(alpha: 0.1),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.8),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // 4. Top App Bar Controls
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.black.withValues(alpha: 0.55),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                      tooltip: 'Back',
                      onPressed: () => context.pop(),
                    ),
                  ),
                  const Spacer(),
                  // Flashlight Toggle
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.black.withValues(alpha: 0.55),
                    child: IconButton(
                      icon: Icon(
                        _isTorchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                        color: _isTorchOn ? AppColors.primary : Colors.white,
                        size: 20,
                      ),
                      tooltip: 'Toggle Flashlight',
                      onPressed: () async {
                        await _controller.toggleTorch();
                        setState(() => _isTorchOn = !_isTorchOn);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Camera Flip Toggle
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.black.withValues(alpha: 0.55),
                    child: IconButton(
                      icon: const Icon(Icons.flip_camera_ios_rounded, color: Colors.white, size: 20),
                      tooltip: 'Switch Camera',
                      onPressed: () => _controller.switchCamera(),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 5. Bottom Instructions & My Hive Code Action
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      child: const Text(
                        'Align QR Code within the frame',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Scan to instantly follow users, send requests, or open movies',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.white70,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    // "My Hive Code" Button
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: Colors.black.withValues(alpha: 0.6),
                          side: const BorderSide(color: AppColors.primary, width: 1.5),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: _showMyQrCode,
                        icon: const Icon(Icons.qr_code_2_rounded, color: AppColors.primary, size: 20),
                        label: const Text(
                          'Show My Hive Code',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom painter that dims the area outside the viewfinder box and draws glowing rounded corners.
class _ScannerOverlayPainter extends CustomPainter {
  final double boxSize;
  final Color borderColor;

  _ScannerOverlayPainter({
    required this.boxSize,
    required this.borderColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCenter(center: center, width: boxSize, height: boxSize);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(24));

    // Dim background with cutout
    final bgPaint = Paint()..color = Colors.black.withValues(alpha: 0.65);
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(rrect)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, bgPaint);

    // Subtle guide border
    final borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawRRect(rrect, borderPaint);

    // Corner brackets
    final cornerPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round;

    const cornerLength = 32.0;

    // Top-Left
    canvas.drawLine(Offset(rect.left, rect.top + 24), Offset(rect.left, rect.top + cornerLength), cornerPaint);
    canvas.drawArc(Rect.fromLTWH(rect.left, rect.top, 48, 48), 3.14159, 1.5708, false, cornerPaint);
    canvas.drawLine(Offset(rect.left + 24, rect.top), Offset(rect.left + cornerLength, rect.top), cornerPaint);

    // Top-Right
    canvas.drawLine(Offset(rect.right - cornerLength, rect.top), Offset(rect.right - 24, rect.top), cornerPaint);
    canvas.drawArc(Rect.fromLTWH(rect.right - 48, rect.top, 48, 48), -1.5708, 1.5708, false, cornerPaint);
    canvas.drawLine(Offset(rect.right, rect.top + 24), Offset(rect.right, rect.top + cornerLength), cornerPaint);

    // Bottom-Left
    canvas.drawLine(Offset(rect.left, rect.bottom - cornerLength), Offset(rect.left, rect.bottom - 24), cornerPaint);
    canvas.drawArc(Rect.fromLTWH(rect.left, rect.bottom - 48, 48, 48), 1.5708, 1.5708, false, cornerPaint);
    canvas.drawLine(Offset(rect.left + 24, rect.bottom), Offset(rect.left + cornerLength, rect.bottom), cornerPaint);

    // Bottom-Right
    canvas.drawLine(Offset(rect.right - cornerLength, rect.bottom), Offset(rect.right - 24, rect.bottom), cornerPaint);
    canvas.drawArc(Rect.fromLTWH(rect.right - 48, rect.bottom - 48, 48, 48), 0, 1.5708, false, cornerPaint);
    canvas.drawLine(Offset(rect.right, rect.bottom - cornerLength), Offset(rect.right, rect.bottom - 24), cornerPaint);
  }

  @override
  bool shouldRepaint(covariant _ScannerOverlayPainter oldDelegate) =>
      oldDelegate.boxSize != boxSize || oldDelegate.borderColor != borderColor;
}
