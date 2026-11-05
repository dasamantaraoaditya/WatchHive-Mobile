import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/error_handler.dart';
import '../../../shared/widgets/wh_alert.dart';
import '../../../shared/widgets/wh_button.dart';
import '../../../shared/widgets/wh_logo_header.dart';
import '../../../shared/widgets/wh_text_field.dart';
import '../../../shared/widgets/wh_bee_loader.dart';
import '../../onboarding/services/onboarding_service.dart';
import '../../onboarding/widgets/watch_preferences_onboarding_dialog.dart';
import '../providers/auth_provider.dart';

class VerifyEmailScreen extends ConsumerStatefulWidget {
  final String? initialToken;
  final String? initialEmail;

  const VerifyEmailScreen({
    super.key,
    this.initialToken,
    this.initialEmail,
  });

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  late final TextEditingController _emailController;
  late final TextEditingController _codeController;
  final List<TextEditingController> _digitControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  bool _isLoading = false;
  bool _isResending = false;
  bool _isHandlingPostAuth = false;
  String? _errorMessage;
  String? _successMessage;

  int _resendCooldownSeconds = 45;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail ?? '');
    _codeController = TextEditingController(text: widget.initialToken ?? '');

    _startCooldownTimer();

    // If initialToken is provided (from deep link), prefill digits or verify
    if (widget.initialToken != null && widget.initialToken!.isNotEmpty) {
      final token = widget.initialToken!.trim();
      if (token.length == 6 && int.tryParse(token) != null) {
        for (int i = 0; i < 6; i++) {
          _digitControllers[i].text = token[i];
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _verifyWithCode(token);
        });
      } else {
        _codeController.text = token;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _verifyWithCode(token);
        });
      }
    }
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _emailController.dispose();
    _codeController.dispose();
    for (final c in _digitControllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _startCooldownTimer() {
    _cooldownTimer?.cancel();
    setState(() => _resendCooldownSeconds = 45);
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

  String _getCombinedCode() {
    return _digitControllers.map((c) => c.text.trim()).join();
  }

  void _onDigitChanged(int index, String value) {
    if (value.length > 1) {
      // Pasted multi-digit code
      final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
      if (digits.isNotEmpty) {
        for (int i = 0; i < 6 && i < digits.length; i++) {
          _digitControllers[i].text = digits[i];
        }
        final nextIndex = digits.length < 6 ? digits.length : 5;
        _focusNodes[nextIndex].requestFocus();
        if (digits.length >= 6) {
          _verifyWithCode(digits.substring(0, 6));
        }
        return;
      }
    }

    if (value.isNotEmpty && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }

    if (index == 5 && value.isNotEmpty) {
      final code = _getCombinedCode();
      if (code.length == 6) {
        _verifyWithCode(code);
      }
    }
  }

  Future<void> _verifyWithCode(String codeToVerify) async {
    if (_isLoading || _isHandlingPostAuth) return;
    final email = _emailController.text.trim();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      if (email.isNotEmpty) {
        await ref.read(authStateProvider.notifier).verifyEmailOtp(
              email: email,
              code: codeToVerify,
            );
      } else {
        await ref.read(authStateProvider.notifier).verifyEmail(
              token: codeToVerify,
              email: null,
            );
      }

      if (mounted) {
        setState(() {
          _successMessage = 'Authentication successful! Preparing your hive...';
        });
        await _handlePostAuthFlow();
      }
    } catch (e) {
      if (mounted) {
        String msg = 'Verification failed. Please check the code and try again.';
        if (e is DioException && e.response?.data is Map) {
          final data = e.response!.data as Map;
          if (data['error'] is String) {
            msg = data['error'];
          } else if (data['message'] is String) {
            msg = data['message'];
          }
        }
        setState(() {
          _errorMessage = msg;
        });
        WHAlert.showError(context, msg);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handlePostAuthFlow() async {
    if (_isHandlingPostAuth) return;
    _isHandlingPostAuth = true;

    try {
      final user = ref.read(authStateProvider).value?.user;
      if (user != null) {
        final onboardingService = ref.read(onboardingServiceProvider);
        final shouldPrompt = await onboardingService.shouldPromptUser(user);
        if (shouldPrompt && mounted) {
          onboardingService.markPrompted(user.id);
          await WatchPreferencesOnboardingDialog.show(context);
          await onboardingService.markPreferencesCompleted(user.id);
        }
      }
      if (mounted) {
        context.go('/feed');
      }
    } catch (e) {
      debugPrint('[VerifyEmailScreen] Post-auth preferences check error: $e');
      if (mounted) {
        context.go('/feed');
      }
    }
  }

  Future<void> _resendCode() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _errorMessage = 'Please enter your email address to resend.');
      return;
    }
    setState(() {
      _isResending = true;
      _errorMessage = null;
    });

    try {
      await ref.read(authStateProvider.notifier).requestEmailOtp(email);
      if (mounted) {
        _startCooldownTimer();
        WHAlert.showSuccess(
          context,
          'A new 6-digit login code has been sent to your email.',
        );
      }
    } catch (e) {
      if (mounted) {
        final msg = AppErrorHandler.toUserFriendlyMessage(
          e,
          defaultMessage: 'Failed to resend code. Please try again shortly.',
        );
        setState(() => _errorMessage = msg);
        WHAlert.showError(context, msg);
      }
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = _emailController.text.trim();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 20),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/login');
            }
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              const Center(child: WHLogoHeader(title: 'WatchersHive')),
              const SizedBox(height: 24),
              Center(
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                  ),
                  child: const Icon(
                    Icons.mark_email_read_outlined,
                    color: AppColors.primary,
                    size: 30,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Enter 6-Digit Code',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                email.isNotEmpty
                    ? "We've sent a 6-digit login code to $email. Enter it below to continue."
                    : 'Enter the 6-digit code sent to your email address to sign in or create your account.',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                  height: 1.45,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),

              if (widget.initialEmail == null || widget.initialEmail!.isEmpty) ...[
                WHTextField(
                  controller: _emailController,
                  label: 'Email Address',
                  hint: 'Enter your email address',
                  keyboardType: TextInputType.emailAddress,
                  prefixIcon: const Icon(Icons.email_outlined),
                ),
                const SizedBox(height: 20),
              ],

              // 6-digit OTP Input Boxes
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (index) {
                  return SizedBox(
                    width: 48,
                    height: 58,
                    child: KeyboardListener(
                      focusNode: FocusNode(),
                      onKeyEvent: (event) {
                        if (event is KeyDownEvent &&
                            event.logicalKey == LogicalKeyboardKey.backspace &&
                            _digitControllers[index].text.isEmpty &&
                            index > 0) {
                          _focusNodes[index - 1].requestFocus();
                        }
                      },
                      child: TextFormField(
                        controller: _digitControllers[index],
                        focusNode: _focusNodes[index],
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        maxLength: 1,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: InputDecoration(
                          counterText: '',
                          contentPadding: EdgeInsets.zero,
                          filled: true,
                          fillColor: AppColors.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: AppColors.primary.withValues(alpha: 0.3),
                              width: 1.5,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: AppColors.primary,
                              width: 2,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: AppColors.primary.withValues(alpha: 0.25),
                              width: 1.5,
                            ),
                          ),
                        ),
                        onChanged: (val) => _onDigitChanged(index, val),
                      ),
                    ),
                  );
                }),
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline_rounded, color: Colors.red.shade700, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.red.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              if (_successMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_outline_rounded, color: Colors.green.shade700, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _successMessage!,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 28),
              WHButton(
                label: 'Verify & Enter Hive',
                isLoading: _isLoading,
                onPressed: () {
                  final code = _getCombinedCode();
                  if (code.length != 6) {
                    setState(() => _errorMessage = 'Please enter all 6 digits.');
                    return;
                  }
                  _verifyWithCode(code);
                },
              ),

              const SizedBox(height: 20),
              Center(
                child: TextButton.icon(
                  onPressed: (_isResending || _resendCooldownSeconds > 0)
                      ? null
                      : _resendCode,
                  icon: _isResending
                      ? const WHBeeSpinner(size: 14)
                      : const Icon(Icons.refresh_rounded, size: 16),
                  label: Text(
                    _resendCooldownSeconds > 0
                        ? 'Resend code in ${_resendCooldownSeconds}s'
                        : 'Resend Verification Code',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Already verified? ',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      color: AppColors.textSecondary.withValues(alpha: 0.8),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => context.go('/login'),
                    child: const Text(
                      'Sign In',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
