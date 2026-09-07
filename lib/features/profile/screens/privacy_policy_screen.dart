import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  static const String webPrivacyPolicyUrl = 'https://watchhive-web.vercel.app/privacy';
  static const String contactEmail = 'privacy@watchhive.app';

  const PrivacyPolicyScreen({super.key});

  Future<void> _openWebPolicy(BuildContext context) async {
    final uri = Uri.parse(webPrivacyPolicyUrl);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch web browser.')),
        );
      }
    }
  }

  Future<void> _sendEmail(BuildContext context) async {
    final uri = Uri.parse('mailto:$contactEmail?subject=WatchHive%20Privacy%20Inquiry');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reach us at privacy@watchhive.app')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Privacy Policy',
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_new_rounded, size: 20, color: AppColors.primaryDark),
            tooltip: 'Open Web Version',
            onPressed: () => _openWebPolicy(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with Last Updated badge
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.history_rounded, size: 14, color: AppColors.primaryDark),
                    SizedBox(width: 6),
                    Text(
                      'LAST UPDATED: JUNE 2, 2026',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 1. Introduction
            _buildSection(
              number: '1',
              title: 'Introduction',
              content:
                  'Welcome to WatchHive. We respect your privacy and are committed to protecting your personal data. This privacy policy explains how we handle your personal data when you use the WatchHive mobile app, our web application, and engage with other members of the hive.',
            ),

            // 2. The Data We Collect
            _buildSection(
              number: '2',
              title: 'The Data We Collect',
              content:
                  'We may collect, use, store, and transfer different kinds of personal data grouped as follows:',
              extra: Column(
                children: [
                  const SizedBox(height: 10),
                  _buildDataCard(
                    title: 'Identity Data',
                    description: 'Username, display name, and custom profile avatar.',
                    icon: Icons.badge_outlined,
                  ),
                  const SizedBox(height: 8),
                  _buildDataCard(
                    title: 'Contact Data',
                    description: 'Email address associated with your account.',
                    icon: Icons.mail_outline_rounded,
                  ),
                  const SizedBox(height: 8),
                  _buildDataCard(
                    title: 'Profile & Watch Data',
                    description: 'Watch history, ratings, reviews, custom tags, and ranked stacks.',
                    icon: Icons.movie_filter_outlined,
                  ),
                  const SizedBox(height: 8),
                  _buildDataCard(
                    title: 'Psychology Metrics',
                    description: 'MindLens mood and atmosphere attributes correlating to your watch patterns.',
                    icon: Icons.psychology_outlined,
                  ),
                ],
              ),
            ),

            // 3. MindLens Psychological Profile Guarantee
            _buildSection(
              number: '3',
              title: 'Core Feature Analytics & MindLens',
              content:
                  'WatchHive processes your cinematic logs to formulate the MindLens Psychological Profile:',
              extra: Container(
                margin: const EdgeInsets.only(top: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.psychology_rounded, size: 22, color: AppColors.primaryDark),
                        SizedBox(width: 8),
                        Text(
                          'MindLens Data Guarantee',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      'We utilize mood correlations, genre frequencies, and atmosphere ratings to construct visualization metrics. This assessment is computed securely and used solely to build your dashboard insights.\n\nWe do NOT sell, rent, or distribute your MindLens datasets or watch history to advertisers or third-party marketing services.',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12.5,
                        height: 1.45,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 4. Social Visibility Controls
            _buildSection(
              number: '4',
              title: 'Swarm Feed & Visibility Controls',
              content:
                  'Your logs and reviews are shared with the community strictly according to the Privacy & Visibility level you choose in your Profile settings:',
              extra: Column(
                children: [
                  const SizedBox(height: 10),
                  _buildVisibilityCard(
                    tier: 'Public Visibility',
                    desc: 'Any user of the hive can view your posts, reviews, ratings, and stacks.',
                    icon: Icons.public_rounded,
                  ),
                  const SizedBox(height: 8),
                  _buildVisibilityCard(
                    tier: 'Followers Only Visibility',
                    desc: 'Only approved followers can browse your entries or see your activity on the Swarm Feed.',
                    icon: Icons.group_outlined,
                  ),
                  const SizedBox(height: 8),
                  _buildVisibilityCard(
                    tier: 'Strict Private Visibility',
                    desc: 'Your watch history, lists, and MindLens profile are strictly visible only to you.',
                    icon: Icons.lock_outline_rounded,
                  ),
                ],
              ),
            ),

            // 5. Local Cache & Offline Logging
            _buildSection(
              number: '5',
              title: 'Local Cache & Offline Logging',
              content:
                  'To ensure high resilience, WatchHive stores entries in local app storage when you log offline. Once network connectivity is restored, these records sync automatically to our secure database servers.',
            ),

            // 6. Google OAuth Integration
            _buildSection(
              number: '6',
              title: 'Google OAuth Integration',
              content:
                  'WatchHive allows you to sign in using Google. When you use Google OAuth, we receive only your email address, name, and profile picture to create and manage your WatchHive account. We do not access contacts, files, or any other Google service data.',
            ),

            // 7. Data Security & Encryption
            _buildSection(
              number: '7',
              title: 'Data Security & Encryption',
              content:
                  'All data transmissions between your mobile device and our backend servers are secured using industry-standard Transport Layer Security (TLS 1.3) encryption protocols. Passwords are protected using salted one-way hashing algorithms.',
            ),

            // 8. Your Data Rights & Deletion
            _buildSection(
              number: '8',
              title: 'Your Data Rights & Deletion',
              content:
                  'You retain complete ownership of your cinematic logs. At any time in the app, you can:\n• Export all your entries and reviews as JSON via Data Management.\n• Permanently delete your account and all associated logs in Settings.',
            ),

            const SizedBox(height: 16),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 20),

            // Contact Us Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Questions about your data?',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Our team is committed to transparency. Reach out anytime with privacy or data concerns.',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12.5,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.black,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () => _sendEmail(context),
                      icon: const Icon(Icons.mail_outline_rounded, size: 18),
                      label: const Text(
                        'Contact $contactEmail',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
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

  Widget _buildSection({
    required String number,
    required String title,
    required String content,
    Widget? extra,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Center(
                  child: Text(
                    number,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              height: 1.45,
              color: AppColors.textSecondary,
            ),
          ),
          if (extra != null) extra,
        ],
      ),
    );
  }

  Widget _buildDataCard({
    required String title,
    required String description,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primaryDark),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w800,
                    fontSize: 12.5,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  description,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVisibilityCard({
    required String tier,
    required String desc,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primaryDark),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tier,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
