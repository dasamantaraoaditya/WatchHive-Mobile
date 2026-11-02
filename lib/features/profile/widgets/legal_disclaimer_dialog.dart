import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';

/// Modal dialog displaying WatchersHive's legal, licensing, and non-commercial disclaimer.
class LegalDisclaimerDialog extends StatelessWidget {
  const LegalDisclaimerDialog({super.key});

  static Future<void> show(BuildContext context) {
    HapticFeedback.lightImpact();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const LegalDisclaimerDialog(),
    );
  }

  Future<void> _openTmdbTerms(BuildContext context) async {
    final uri = Uri.parse('https://www.themoviedb.org/documentation/api/terms-of-use');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open external link.')),
        );
      }
    }
  }

  Future<void> _sendEmail(BuildContext context) async {
    final uri = Uri.parse('mailto:watchershive@gmail.com?subject=WatchersHive%20Legal%20Inquiry');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contact us at watchershive@gmail.com')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.gavel_rounded,
                      color: AppColors.primaryDark,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Legal & Non-Commercial Disclaimer',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Licenses, TMDb attribution & copyright notice',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),
            const Divider(height: 1, color: AppColors.border),

            // Content
            Flexible(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _buildSectionCard(
                    icon: Icons.volunteer_activism_rounded,
                    title: '1. Strict Non-Commercial Purpose',
                    body:
                        'WatchersHive is an independent, non-commercial, fan-made social movie and TV tracking community application built strictly for educational, personal cataloging, and entertainment purposes.\n\n'
                        'WatchersHive does NOT generate any revenue, does NOT sell any products, merchandise, or user data, displays ZERO commercial advertisements, and charges NO subscription or access fees. We do not make a penny from this platform.',
                    accentColor: const Color(0xFF10B981),
                  ),
                  const SizedBox(height: 14),
                  _buildSectionCard(
                    icon: Icons.movie_creation_outlined,
                    title: '2. TMDb API Attribution',
                    body:
                        'This product uses the TMDB API but is not endorsed or certified by TMDB.\n\n'
                        'Film and television metadata, descriptions, casting details, release dates, and promotional posters are retrieved via The Movie Database (TMDb) API under their standard developer terms of service.',
                    accentColor: const Color(0xFF0284C7),
                    actionLabel: 'TMDb Terms of Use ↗',
                    onAction: () => _openTmdbTerms(context),
                  ),
                  const SizedBox(height: 14),
                  _buildSectionCard(
                    icon: Icons.copyright_rounded,
                    title: '3. Intellectual Property & Copyright (IPR)',
                    body:
                        'All movie titles, series titles, poster imagery, still photos, character names, trademarks, and associated intellectual property remain the exclusive copyright of their respective creators, film studios, production entities, and distribution companies.\n\n'
                        'WatchersHive asserts no ownership over any copyright-protected media. All visual assets and titles are referenced solely under Fair Use / Fair Dealing doctrines for identification, commentary, personal critique, and cataloging.',
                    accentColor: const Color(0xFF8B5CF6),
                  ),
                  const SizedBox(height: 14),
                  _buildSectionCard(
                    icon: Icons.mark_email_read_outlined,
                    title: '4. Copyright Inquiries & Takedown Policy',
                    body:
                        'If you are a copyright owner, producer, or authorized agent and believe that any media referenced within WatchersHive infringes upon your copyright or intellectual property rights, please contact us immediately. We will promptly address and resolve your request.',
                    accentColor: AppColors.primaryDark,
                    actionLabel: 'Contact: watchershive@gmail.com ✉️',
                    onAction: () => _sendEmail(context),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.black,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text(
                        'I Understand',
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
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required IconData icon,
    required String title,
    required String body,
    required Color accentColor,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: accentColor, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            body,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
              height: 1.45,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 10),
            GestureDetector(
              onTap: onAction,
              child: Text(
                actionLabel,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: accentColor,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
