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
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: mainAxisSize,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: logoSize,
            height: logoSize,
            child: Image.asset(
              'assets/images/watchhive-logo.png',
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
              errorBuilder: (_, __, ___) => Icon(
                Icons.hive_rounded,
                size: logoSize * 0.85,
                color: AppColors.primary,
              ),
            ),
          ),
          if (showText) ...[
            const SizedBox(width: 8),
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: 'Watch',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: fontSize,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  TextSpan(
                    text: 'Hive',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: fontSize,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primary,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

