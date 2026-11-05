import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/error_handler.dart';
import '../../../core/utils/navigation_extensions.dart';
import '../../../shared/widgets/wh_alert.dart';
import '../../../shared/widgets/wh_button.dart';
import '../../../shared/widgets/wh_logo_header.dart';
import '../../../shared/widgets/wh_text_field.dart';
import '../providers/auth_provider.dart';
import '../repositories/auth_repository.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  final String? initialToken;
  final String? initialEmail;

  const ResetPasswordScreen({
    super.key,
    this.initialToken,
    this.initialEmail,
  });

  @override
  ConsumerState<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  late final TextEditingController _emailController;
  late final TextEditingController _tokenController;
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  bool _isSuccess = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail ?? '');
    _tokenController = TextEditingController(text: widget.initialToken ?? '');

    // Smart token listener: If user pastes a full URL, automatically extract token and email
    _tokenController.addListener(_handleTokenInputChanged);
  }

  void _handleTokenInputChanged() {
    final text = _tokenController.text.trim();
    if (text.contains('http') || text.contains('token=') || text.contains('://')) {
      final parsed = _extractTokenAndEmail(text);
      if (parsed != null) {
        final extractedToken = parsed.token;
        final extractedEmail = parsed.email;

        // Temporarily remove listener to avoid recursive triggers
        _tokenController.removeListener(_handleTokenInputChanged);
        _tokenController.text = extractedToken;
        _tokenController.selection = TextSelection.collapsed(offset: extractedToken.length);
        _tokenController.addListener(_handleTokenInputChanged);

        if (extractedEmail != null && extractedEmail.isNotEmpty && _emailController.text.trim().isEmpty) {
          _emailController.text = extractedEmail;
        }

        if (mounted) {
          WHAlert.showSuccess(context, 'Reset code extracted from link!');
        }
      }
    }
  }

  ({String token, String? email})? _extractTokenAndEmail(String raw) {
    try {
      final uri = Uri.tryParse(raw);
      if (uri != null && uri.queryParameters.containsKey('token')) {
        return (
          token: uri.queryParameters['token']!.trim(),
          email: uri.queryParameters['email']?.trim(),
        );
      }
      // Regex fallback if query parameters parsing failed
      final tokenMatch = RegExp(r'[?&]token=([^&\s]+)').firstMatch(raw);
      if (tokenMatch != null) {
        final token = Uri.decodeComponent(tokenMatch.group(1)!);
        final emailMatch = RegExp(r'[?&]email=([^&\s]+)').firstMatch(raw);
        final email = emailMatch != null ? Uri.decodeComponent(emailMatch.group(1)!) : null;
        return (token: token, email: email);
      }
    } catch (_) {}
    return null;
  }

  @override
  void dispose() {
    _tokenController.removeListener(_handleTokenInputChanged);
    _emailController.dispose();
    _tokenController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  bool get _hasMinLength => _newPasswordController.text.length >= 8;
  bool get _hasUpperLower =>
      _newPasswordController.text.contains(RegExp(r'[a-z]')) &&
      _newPasswordController.text.contains(RegExp(r'[A-Z]'));
  bool get _hasNumber => _newPasswordController.text.contains(RegExp(r'[0-9]'));
  bool get _passwordsMatch =>
      _newPasswordController.text.isNotEmpty &&
      _newPasswordController.text == _confirmPasswordController.text;

  bool get _isValidPassword => _hasMinLength && _hasUpperLower && _hasNumber && _passwordsMatch;

  Future<void> _handlePasteToken() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text != null && text.isNotEmpty) {
      _tokenController.text = text;
    }
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
              'Reset Password Help',
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
              '1. Finding your code',
              style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textPrimary),
            ),
            SizedBox(height: 3),
            Text(
              'Check your email inbox (and Spam/Junk folder) for an email from WatchersHive. It contains your reset link and code.',
              style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.textSecondary),
            ),
            SizedBox(height: 12),
            Text(
              '2. Easy paste',
              style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textPrimary),
            ),
            SizedBox(height: 3),
            Text(
              'You can copy the entire link from your email and paste it into the Reset Code box — we will automatically extract your token and email.',
              style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.textSecondary),
            ),
            SizedBox(height: 12),
            Text(
              '3. Password rules',
              style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textPrimary),
            ),
            SizedBox(height: 3),
            Text(
              'Your new password must be at least 8 characters long, and contain at least one uppercase letter, one lowercase letter, and one number.',
              style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.textSecondary),
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

  Future<void> _submitReset() async {
    final email = _emailController.text.trim();
    final token = _tokenController.text.trim();
    final newPassword = _newPasswordController.text;

    if (email.isEmpty) {
      setState(() => _errorMessage = 'Please enter your email address.');
      return;
    }
    if (token.isEmpty) {
      setState(() => _errorMessage = 'Please enter the reset code or token from your email.');
      return;
    }
    if (!_isValidPassword) {
      setState(() => _errorMessage = 'Please make sure your new password meets all security requirements.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ref.read(authRepositoryProvider).resetPassword(
            token: token,
            email: email,
            newPassword: newPassword,
          );

      if (!mounted) return;
      setState(() {
        _isSuccess = true;
        _isLoading = false;
      });

      // Smart auto-sign-in: Attempt to automatically log in the user with their new password
      try {
        await ref.read(authStateProvider.notifier).login(
              email: email,
              password: newPassword,
            );
        if (mounted) {
          WHAlert.showSuccess(context, 'Password reset! Welcome back to WatchersHive.');
          try {
            context.go('/feed');
          } catch (_) {}
        }
      } catch (loginErr) {
        // If auto-login fails (e.g. network blip), the user can still tap "Sign In Now"
        debugPrint('[ResetPassword] Auto-sign-in fallback: $loginErr');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = AppErrorHandler.toUserFriendlyMessage(
            e,
            defaultMessage: 'Invalid or expired reset link. Please request a new one.',
          );
          _isLoading = false;
        });
      }
    }
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
            tooltip: 'Reset Password Help',
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
              if (!_isSuccess) ...[
                const WHLogoHeader(
                  title: 'Set New Password',
                  subtitle: 'Enter your reset code and choose a secure new password',
                ),
                const SizedBox(height: 28),

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
                              if (_errorMessage!.contains('expired') || _errorMessage!.contains('Invalid')) ...[
                                const SizedBox(height: 6),
                                GestureDetector(
                                  onTap: () => context.pushReplacement('/forgot-password'),
                                  child: const Text(
                                    'Request a new reset link →',
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

                // Email Address Field
                WHTextField(
                  controller: _emailController,
                  label: 'Email Address',
                  hint: 'you@example.com',
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),

                // Reset Token / Code Field with Paste button
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Reset Token / Code',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        GestureDetector(
                          onTap: _handlePasteToken,
                          child: const Row(
                            children: [
                              Icon(Icons.content_paste_rounded, size: 14, color: AppColors.primaryDark),
                              SizedBox(width: 4),
                              Text(
                                'Paste link/code',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primaryDark,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _tokenController,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Paste reset code or full reset link here',
                        hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                        filled: true,
                        fillColor: AppColors.surface,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: AppColors.primary, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // New Password Field
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'New Password',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _newPasswordController,
                      obscureText: _obscureNewPassword,
                      onChanged: (_) => setState(() {}),
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Create strong password',
                        hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                        filled: true,
                        fillColor: AppColors.surface,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: AppColors.primary, width: 2),
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureNewPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            color: AppColors.textMuted,
                          ),
                          onPressed: () => setState(() => _obscureNewPassword = !_obscureNewPassword),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Confirm Password Field
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Confirm New Password',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirmPassword,
                      onChanged: (_) => setState(() {}),
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Re-enter new password',
                        hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                        filled: true,
                        fillColor: AppColors.surface,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: AppColors.primary, width: 2),
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirmPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            color: AppColors.textMuted,
                          ),
                          onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Password Requirements Checklist Card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'PASSWORD REQUIREMENTS',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.6,
                          color: AppColors.primaryDark,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _RequirementItem(label: 'At least 8 characters', met: _hasMinLength),
                      const SizedBox(height: 4),
                      _RequirementItem(label: 'Uppercase and lowercase letters', met: _hasUpperLower),
                      const SizedBox(height: 4),
                      _RequirementItem(label: 'At least one number (0-9)', met: _hasNumber),
                      const SizedBox(height: 4),
                      _RequirementItem(label: 'Passwords match', met: _passwordsMatch),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // Submit Button
                WHButton(
                  label: 'Reset Password & Sign In',
                  isLoading: _isLoading,
                  onPressed: _submitReset,
                ),
                const SizedBox(height: 16),

                // Back to Forgot Password option
                Center(
                  child: TextButton(
                    onPressed: () => context.pushReplacement('/forgot-password'),
                    child: const Text(
                      'Need a new code? Request reset link',
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
                // Success State View
                const SizedBox(height: 40),
                Center(
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.success.withValues(alpha: 0.15),
                      border: Border.all(color: AppColors.success, width: 2),
                    ),
                    child: const Icon(Icons.check_rounded, color: AppColors.success, size: 44),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Password Reset Successfully!',
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
                  'Your password for ${_emailController.text.trim()} has been updated. You can now sign in with your new password.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 36),
                WHButton(
                  label: 'Sign In Now',
                  onPressed: () => context.go('/login'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RequirementItem extends StatelessWidget {
  final String label;
  final bool met;

  const _RequirementItem({required this.label, required this.met});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          met ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
          size: 15,
          color: met ? AppColors.success : AppColors.textMuted,
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            fontWeight: met ? FontWeight.w700 : FontWeight.w500,
            color: met ? AppColors.textPrimary : AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
