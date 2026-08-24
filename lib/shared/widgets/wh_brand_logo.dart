import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class WHBrandLogo extends StatelessWidget {
  final double logoSize;
  final double fontSize;
  final bool showText;
  final MainAxisSize mainAxisSize;

  const WHBrandLogo({
    super.key,
    this.logoSize = 32,
    this.fontSize = 20,
    this.showText = true,
    this.mainAxisSize = MainAxisSize.min,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: mainAxisSize,
      children: [
        Container(
          width: logoSize,
          height: logoSize,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(logoSize * 0.25),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Image.asset(
            'assets/images/watchhive-logo.png',
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Icon(
              Icons.hive_rounded,
              size: logoSize * 0.8,
              color: AppColors.primary,
            ),
          ),
        ),
        if (showText) ...[
          SizedBox(width: logoSize * 0.3),
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [
                Color(0xFFFFC83B),
                Color(0xFFFFB700),
                Color(0xFFE6A300),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ).createShader(bounds),
            child: Text(
              'WatchHive',
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: fontSize,
                fontWeight: FontWeight.w900,
                color: Colors.white, // Required for ShaderMask
                letterSpacing: -0.5,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
