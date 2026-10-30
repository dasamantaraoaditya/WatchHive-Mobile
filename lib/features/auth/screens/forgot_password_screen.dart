import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/error_handler.dart';
import '../../../core/utils/navigation_extensions.dart';
import '../repositories/auth_repository.dart';
import '../../../shared/widgets/wh_text_field.dart';
import '../../../shared/widgets/wh_button.dart';
import '../../../shared/widgets/wh_logo_header.dart';
import '../../../shared/widgets/wh_alert.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  final String? initialEmail;

  const ForgotPasswordScreen({super.key, this.initialEmail});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  late final TextEditingController _emailController;
  bool _isLoading = false;
  bool _sent = false;
  String? _errorMessage;
  String? _resetCode;

  int _resendCooldownSeconds = 0;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail ?? '');
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _emailController.dispose();
    super.dispose();
  }

  void _startCooldownTimer() {
    setState(() => _resendCooldownSeconds = 30);
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendCooldownSeconds <= 1) {
        timer.cancel();
        setState(() => _resendCooldownSeconds = 0);
      } else {
        setState(() => _resendCooldownSeconds--);
      }
    });
  }

  void _showHelpDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.help_outline_rounded, color: AppColors.primary),
            SizedBox(width: 10),
            Text(
              'Password Reset Help',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'How to reset your password:',
              style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textPrimary),
            ),
            SizedBox(height: 6),
            Text(
              '1. Enter your registered email address and tap "Send Reset Link".\n'
              '2. Check your inbox (and Spam folder) for the reset email.\n'
              '3. You can either tap the link in the email or copy the code and enter it on the next screen.\n'
              '4. If you already have a code, you can tap "Enter code directly" anytime without requesting a new one.',
              style: TextStyle(fontFamily: 'Inter', fontSize: 12.5, color: AppColors.textSecondary, height: 1.4),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: const Color(0xFF2D2926),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Got it', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  Future<void> _sendReset() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _errorMessage = 'Please enter your email address.');
      return;
    }

    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      setState(() => _errorMessage = 'Please enter a valid email address (e.g. name@example.com).');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await ref.read(authRepositoryProvider).forgotPassword(email);
      if (!mounted) return;
      final code = (result['resetCode'] ?? result['devToken'] ?? result['resetToken'])?.toString();
      setState(() {
        _sent = true;
        _isLoading = false;
        _resetCode = code;
      });
      _startCooldownTimer();
    } catch (e) {
      if (!mounted) return;
      final msg = AppErrorHandler.toUserFriendlyMessage(
        e,
        defaultMessage: 'Unable to send reset link. Please check your connection and try again.',
      );
      setState(() {
        _isLoading = false;
        _errorMessage = msg;
      });
    }
  }

  void _navigateToResetPassword([String? token]) {
    final email = _emailController.text.trim();
    final queryParams = <String>[];
    if (email.isNotEmpty) {
      queryParams.add('email=${Uri.encodeComponent(email)}');
    }
    if (token != null && token.isNotEmpty) {
      queryParams.add('token=${Uri.encodeComponent(token)}');
    }
    final query = queryParams.isNotEmpty ? '?${queryParams.join('&')}' : '';
    context.push('/reset-password$query');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => context.safePop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline_rounded, color: AppColors.textSecondary),
            tooltip: 'Password Reset Help',
            onPressed: _showHelpDialog,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!_sent) ...[
                const WHLogoHeader(
                  title: 'Reset password',
                  subtitle: "Enter your email and we'll send you a password reset link",
                ),
                const SizedBox(height: 32),

                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _errorMessage!,
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.error,
                                  height: 1.35,
                                ),
                              ),
                              if (_errorMessage!.contains('requests') || _errorMessage!.contains('slow down')) ...[
                                const SizedBox(height: 6),
                                GestureDetector(
                                  onTap: () => _navigateToResetPassword(),
                                  child: const Text(
                                    'Already have a code? Enter it directly →',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.primaryDark,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                WHTextField(
                  controller: _emailController,
                  label: 'Email Address',
                  hint: 'you@example.com',
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 24),

                WHButton(
                  label: 'Send Reset Link',
                  isLoading: _isLoading,
                  onPressed: _sendReset,
                ),
                const SizedBox(height: 20),

                // Direct jump to token entry for users who already received email
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Already received a reset code or email link?',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF2D2926),
                          side: const BorderSide(color: AppColors.primary, width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                        onPressed: () => _navigateToResetPassword(),
                        icon: const Icon(Icons.key_rounded, size: 16, color: AppColors.primaryDark),
                        label: const Text(
                          'Enter Reset Code / Token',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                Center(
                  child: TextButton(
                    onPressed: () => context.go('/login'),
                    child: const Text(
                      'Back to Sign In',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ] else ...[
                // Success / Confirmation State
                const SizedBox(height: 20),
                Center(
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.success.withValues(alpha: 0.15),
                      border: Border.all(color: AppColors.success, width: 2),
                    ),
                    child: const Icon(Icons.mark_email_read_outlined, color: AppColors.success, size: 38),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Check your inbox!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'If an account exists for ${_emailController.text.trim()}, a password reset link and code has been sent.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),

                // Generated Reset Code Card (if code is available)
                if (_resetCode != null) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.primary, width: 1.5),
                    ),
                    child: Column(
                      children: [
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.lock_reset_rounded, size: 18, color: AppColors.primaryDark),
                            SizedBox(width: 6),
                            Text(
                              'YOUR RESET CODE',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2,
                                color: AppColors.primaryDark,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _resetCode!,
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: _resetCode!.length > 10 ? 16 : 26,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: _resetCode!.length > 10 ? 1 : 4,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(width: 10),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                icon: const Icon(Icons.copy_rounded, size: 18, color: AppColors.primaryDark),
                                tooltip: 'Copy Code',
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: _resetCode!));
                                  WHAlert.showSuccess(context, 'Reset code copied to clipboard!');
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        WHButton(
                          label: 'Reset Password with this Code →',
                          onPressed: () => _navigateToResetPassword(_resetCode),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  // Primary Next Step: Enter code directly in-app
                  WHButton(
                    label: 'Enter Reset Code / Token',
                    onPressed: () => _navigateToResetPassword(),
                  ),
                  const SizedBox(height: 16),
                ],

                // Resend Button
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _resendCooldownSeconds > 0 ? AppColors.textMuted : AppColors.textPrimary,
                    side: BorderSide(
                      color: _resendCooldownSeconds > 0 ? AppColors.border : AppColors.primary,
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: _resendCooldownSeconds > 0 ? null : _sendReset,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: Text(
                    _resendCooldownSeconds > 0
                        ? 'Resend link in ${_resendCooldownSeconds}s'
                        : 'Resend Reset Link',
                    style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w800, fontSize: 13.5),
                  ),
                ),
                const SizedBox(height: 16),

                Center(
                  child: TextButton(
                    onPressed: () => context.go('/login'),
                    child: const Text(
                      'Back to Sign In',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
