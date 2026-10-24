import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/navigation_extensions.dart';
import '../../../shared/widgets/wh_alert.dart';
import '../../auth/providers/auth_provider.dart';

enum SupportCategory {
  bug(
    label: 'Bug / Glitch',
    icon: Icons.bug_report_rounded,
    badgeColor: Color(0xFFEF4444),
    placeholder: 'Describe what went wrong, what you expected, and steps to reproduce...',
  ),
  movieData(
    label: 'Movie / Data Issue',
    icon: Icons.movie_filter_rounded,
    badgeColor: Color(0xFFF59E0B),
    placeholder: 'Tell us the title, year, or TMDB link and what details need updating...',
  ),
  feature(
    label: 'Feature Request',
    icon: Icons.lightbulb_rounded,
    badgeColor: Color(0xFF10B981),
    placeholder: 'What feature or improvement would make WatchersHive even better for you?',
  ),
  account(
    label: 'Account & Login',
    icon: Icons.manage_accounts_rounded,
    badgeColor: Color(0xFF3B82F6),
    placeholder: 'Describe your login, OAuth, or profile issue...',
  ),
  other(
    label: 'General Feedback',
    icon: Icons.chat_bubble_outline_rounded,
    badgeColor: Color(0xFF8B5CF6),
    placeholder: 'Share your thoughts, suggestions, or general questions with the hive team...',
  );

  final String label;
  final IconData icon;
  final Color badgeColor;
  final String placeholder;

  const SupportCategory({
    required this.label,
    required this.icon,
    required this.badgeColor,
    required this.placeholder,
  });
}

class SupportScreen extends ConsumerStatefulWidget {
  static const String supportEmail = 'watchershive@gmail.com';
  final SupportCategory initialCategory;
  final String? prefillSubject;
  final String? prefillMessage;

  const SupportScreen({
    super.key,
    this.initialCategory = SupportCategory.bug,
    this.prefillSubject,
    this.prefillMessage,
  });

  /// Displays the support interface as a convenient bottom sheet modal.
  static Future<void> showBottomSheet(
    BuildContext context, {
    SupportCategory initialCategory = SupportCategory.bug,
    String? prefillSubject,
    String? prefillMessage,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.92,
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        clipBehavior: Clip.antiAlias,
        child: SupportScreen(
          initialCategory: initialCategory,
          prefillSubject: prefillSubject,
          prefillMessage: prefillMessage,
        ),
      ),
    );
  }

  @override
  ConsumerState<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends ConsumerState<SupportScreen> {
  late SupportCategory _selectedCategory;
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  final _emailController = TextEditingController();
  bool _includeDiagnostics = true;
  bool _showDiagnosticsDetails = false;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory;
    if (widget.prefillSubject != null) {
      _subjectController.text = widget.prefillSubject!;
    }
    if (widget.prefillMessage != null) {
      _messageController.text = widget.prefillMessage!;
    }

    // Prefill user email if authenticated
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(authStateProvider).value?.user;
      if (user?.email != null && _emailController.text.isEmpty) {
        _emailController.text = user!.email ?? '';
      }
    });
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  String _getPlatformSummary() {
    if (kIsWeb) return 'Web PWA';
    try {
      if (Platform.isAndroid) return 'Android';
      if (Platform.isIOS) return 'iOS';
      if (Platform.isMacOS) return 'macOS';
      return Platform.operatingSystem;
    } catch (_) {
      return 'Mobile';
    }
  }

  String _formatDiagnosticsText() {
    final user = ref.read(authStateProvider).value?.user;
    final size = MediaQuery.maybeOf(context)?.size;
    final sizeStr = size != null ? '${size.width.toInt()}x${size.height.toInt()} pt' : 'Unknown';
    final userStr = user != null ? '@${user.username} (ID: ${user.id})' : 'Unauthenticated Guest';

    return '''
------------------------------------------------
App Diagnostics:
- App: WatchersHive Mobile v1.0.30 (Build 31)
- Platform: ${_getPlatformSummary()}
- Screen Size: $sizeStr
- User: $userStr
- Contact Email: ${_emailController.text.trim().isNotEmpty ? _emailController.text.trim() : (user?.email ?? 'Not provided')}
- Timestamp: ${DateTime.now().toUtc().toIso8601String()}
------------------------------------------------''';
  }

  String _generateFullReportText() {
    final subject = _subjectController.text.trim().isNotEmpty
        ? _subjectController.text.trim()
        : 'Support Request: ${_selectedCategory.label}';
    final message = _messageController.text.trim().isNotEmpty
        ? _messageController.text.trim()
        : '(No message text provided)';

    final buffer = StringBuffer();
    buffer.writeln('Subject: [WatchersHive] [${_selectedCategory.label}] $subject');
    buffer.writeln('Category: ${_selectedCategory.label}');
    buffer.writeln();
    buffer.writeln('Details / Description:');
    buffer.writeln(message);
    buffer.writeln();
    if (_includeDiagnostics) {
      buffer.writeln(_formatDiagnosticsText());
    }
    return buffer.toString();
  }

  Future<void> _sendViaEmail() async {
    final subject = _subjectController.text.trim().isNotEmpty
        ? _subjectController.text.trim()
        : '${_selectedCategory.label} report';
    final fullSubject = '[WatchersHive Support - ${_selectedCategory.label}] $subject';

    final bodyBuffer = StringBuffer();
    final message = _messageController.text.trim();
    if (message.isNotEmpty) {
      bodyBuffer.writeln(message);
      bodyBuffer.writeln();
    } else {
      bodyBuffer.writeln('Hi WatchersHive Team,\n');
      bodyBuffer.writeln('I am reporting an issue regarding ${_selectedCategory.label}.\n');
    }

    if (_includeDiagnostics) {
      bodyBuffer.writeln(_formatDiagnosticsText());
    }

    final emailUri = Uri(
      scheme: 'mailto',
      path: SupportScreen.supportEmail,
      queryParameters: {
        'subject': fullSubject,
        'body': bodyBuffer.toString(),
      },
    );

    setState(() => _isSending = true);
    try {
      HapticFeedback.lightImpact();
      final launched = await launchUrl(emailUri, mode: LaunchMode.externalApplication);
      if (!launched) {
        // Fallback to normal launch
        await launchUrl(emailUri);
      }
    } catch (_) {
      if (mounted) {
        WHAlert.showWarning(
          context,
          'Could not open email app directly. We copied the support email to your clipboard!',
        );
        _copySupportEmail();
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _copySupportEmail() {
    HapticFeedback.selectionClick();
    Clipboard.setData(const ClipboardData(text: SupportScreen.supportEmail));
    WHAlert.showSuccess(context, 'Copied ${SupportScreen.supportEmail} to clipboard.');
  }

  void _copyFullReport() {
    HapticFeedback.selectionClick();
    final report = _generateFullReportText();
    Clipboard.setData(ClipboardData(text: report));
    WHAlert.showSuccess(context, 'Support report copied to clipboard.');
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).value?.user;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => context.safePop(fallbackRoute: '/profile'),
          tooltip: 'Back',
        ),
        title: const Text(
          'Help & Support',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_rounded, color: AppColors.textSecondary, size: 20),
            onPressed: _copySupportEmail,
            tooltip: 'Copy support email',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppColors.border, height: 1),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Welcome Card
            _buildHeroCard(),
            const SizedBox(height: 20),

            // Category Picker
            const Text(
              'Select Topic',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            _buildCategorySelector(),
            const SizedBox(height: 20),

            // Subject Field
            const Text(
              'Subject',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _subjectController,
              hintText: 'e.g., Cannot view movie poster in feed',
              prefixIcon: Icons.title_rounded,
            ),
            const SizedBox(height: 16),

            // Message / Description Field
            const Text(
              'Description / Details',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _messageController,
              hintText: _selectedCategory.placeholder,
              maxLines: 5,
              prefixIcon: Icons.description_outlined,
            ),
            const SizedBox(height: 16),

            // Contact Email (editable)
            const Text(
              'Your Contact Email',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _emailController,
              hintText: user?.email ?? 'name@example.com',
              keyboardType: TextInputType.emailAddress,
              prefixIcon: Icons.email_outlined,
            ),
            const SizedBox(height: 16),

            // Diagnostics Card
            _buildDiagnosticsToggleCard(user != null ? '@${user.username}' : 'Guest'),
            const SizedBox(height: 24),

            // Primary Action Buttons
            _buildActionButtons(),
            const SizedBox(height: 32),

            // Instant Answers & FAQ Section
            _buildFaqSection(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.support_agent_rounded, color: AppColors.primaryDark, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'We are here to help!',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Flag an issue, suggest a feature, or reach the WatchersHive team directly at ${SupportScreen.supportEmail}.',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 10),
                InkWell(
                  onTap: _copySupportEmail,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.mail_outline_rounded, size: 14, color: AppColors.primaryDark),
                        SizedBox(width: 6),
                        Text(
                          SupportScreen.supportEmail,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(Icons.copy_rounded, size: 12, color: AppColors.textMuted),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: SupportCategory.values.map((cat) {
        final isSelected = _selectedCategory == cat;
        return InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _selectedCategory = cat);
          },
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? cat.badgeColor.withValues(alpha: 0.12) : AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected ? cat.badgeColor : AppColors.border,
                width: isSelected ? 1.8 : 1.0,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: cat.badgeColor.withValues(alpha: 0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  cat.icon,
                  size: 16,
                  color: isSelected ? cat.badgeColor : AppColors.textSecondary,
                ),
                const SizedBox(width: 8),
                Text(
                  cat.label,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected ? cat.badgeColor : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    int maxLines = 1,
    TextInputType? keyboardType,
    IconData? prefixIcon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            color: AppColors.textMuted,
            fontWeight: FontWeight.normal,
          ),
          prefixIcon: prefixIcon != null
              ? Padding(
                  padding: EdgeInsets.only(bottom: maxLines > 1 ? 60 : 0),
                  child: Icon(prefixIcon, color: AppColors.textMuted, size: 20),
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildDiagnosticsToggleCard(String userLabel) {
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            leading: Icon(
              Icons.phonelink_setup_rounded,
              color: _includeDiagnostics ? AppColors.primaryDark : AppColors.textMuted,
            ),
            title: const Text(
              'Attach System Diagnostics',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            subtitle: Text(
              'Platform (${_getPlatformSummary()}), App Version, User: $userLabel',
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                color: AppColors.textMuted,
              ),
            ),
            trailing: Switch.adaptive(
              value: _includeDiagnostics,
              activeTrackColor: AppColors.primary,
              onChanged: (val) {
                HapticFeedback.lightImpact();
                setState(() => _includeDiagnostics = val);
              },
            ),
          ),
          if (_includeDiagnostics) ...[
            const Divider(height: 1, color: AppColors.border),
            InkWell(
              onTap: () => setState(() => _showDiagnosticsDetails = !_showDiagnosticsDetails),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Row(
                  children: [
                    Text(
                      _showDiagnosticsDetails ? 'Hide technical summary' : 'Preview diagnostic payload',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      _showDiagnosticsDetails
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: AppColors.primaryDark,
                    ),
                  ],
                ),
              ),
            ),
            if (_showDiagnosticsDetails)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: SelectableText(
                  _formatDiagnosticsText(),
                  style: const TextStyle(
                    fontFamily: 'Courier',
                    fontSize: 10,
                    color: AppColors.textPrimary,
                    height: 1.3,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        // Primary Send via Email button
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _isSending ? null : _sendViaEmail,
            icon: _isSending
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                  )
                : const Icon(Icons.send_rounded, color: Colors.black, size: 20),
            label: Text(
              _isSending ? 'Opening Email...' : 'Send via Email App ✉️',
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: Colors.black,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 2,
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Secondary Copy Report & Email buttons
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 44,
                child: OutlinedButton.icon(
                  onPressed: _copySupportEmail,
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: const Text(
                    'Copy Email',
                    style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SizedBox(
                height: 44,
                child: OutlinedButton.icon(
                  onPressed: _copyFullReport,
                  icon: const Icon(Icons.assignment_outlined, size: 16),
                  label: const Text(
                    'Copy Report',
                    style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFaqSection() {
    final faqs = [
      (
        'Missing movie poster or incorrect title?',
        'WatchersHive syncs movie & TV metadata with TMDB. If a title was released very recently or has alternate local titles, try searching with its official English title or check back in a few hours.',
      ),
      (
        'Trouble signing in with Google?',
        'Ensure you have a reliable network connection. If using an external browser or custom ROM, ensure popups/redirects are allowed. You can also sign in or recover your account via your registered email.',
      ),
      (
        'Where does imported watch history go?',
        'Export/Import is saved directly into your personal library and MindLens statistics. To protect community feeds, imported entries are not broadcast into your followers\' feeds.',
      ),
      (
        'How do I recommend titles to friends?',
        'Tap the "+" quick action button on the feed to choose "Suggest to Friends", or select a friend in the "Recommended by a friend" section when logging an entry.',
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.quiz_outlined, size: 20, color: AppColors.primaryDark),
              SizedBox(width: 8),
              Text(
                'Frequently Asked Questions',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...faqs.map(
            (faq) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: AppColors.surfaceElevated,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: AppColors.border.withValues(alpha: 0.7)),
                ),
                child: Theme(
                  data: ThemeData(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                  childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                  leading: const Icon(Icons.help_outline_rounded, size: 18, color: AppColors.primaryDark),
                  title: Text(
                    faq.$1,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  children: [
                    Text(
                      faq.$2,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
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
