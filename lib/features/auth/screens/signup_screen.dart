import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/shared_widgets.dart';
import '../providers/auth_provider.dart';
import '../../../core/utils/error_handler.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {

    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      await ref.read(authStateProvider.notifier).register(
            username: _usernameController.text.trim(),
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );
      if (mounted && ref.read(authStateProvider).value?.isAuthenticated == true) {
        context.go('/feed');
        WHAlert.showSuccess(context, 'Welcome to WatchersHive! 🐝✨');
      }
    } catch (e) {
      if (mounted) {
        WHAlert.showError(context, _parseError(e));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _parseError(dynamic error) {
    return AppErrorHandler.toUserFriendlyMessage(
      error,
      defaultMessage: 'Sign up failed. Please try again.',
    );
  }

  Future<void> _googleSignIn() async {
    setState(() => _isLoading = true);
    try {
      final googleSignIn = GoogleSignIn(
        clientId: kIsWeb
            ? null
            : Platform.isIOS
                ? '357857516251-69f26kdjl6v5n60pvtpdjbiregaodv63.apps.googleusercontent.com'
                : null,
        serverClientId: '357857516251-f4gpp8f1j70lu1dcnh405ac0t6lch9tf.apps.googleusercontent.com',
        scopes: ['email', 'profile'],
      );

      await googleSignIn.signOut().catchError((_) => null);
      final account = await googleSignIn.signIn();
      if (account == null) return;

      final auth = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null || idToken.isEmpty) {
        if (mounted) {
          WHAlert.showError(
            context,
            'Google Sign-In could not be completed. Please try again or sign up with your email and password.',
          );
        }
        return;
      }

      await ref.read(authStateProvider.notifier).googleSignIn(idToken);
      if (mounted && ref.read(authStateProvider).value?.isAuthenticated == true) {
        context.go('/feed');
        WHAlert.showSuccess(context, 'Welcome to WatchersHive! 🐝✨');
      }
    } catch (e) {
      debugPrint('Google Sign-In Error: $e');
      if (mounted) {
        WHAlert.showError(context, _parseError(e));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _appleSignIn() async {
    setState(() => _isLoading = true);
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final identityToken = credential.identityToken;
      if (identityToken == null || identityToken.isEmpty) {
        if (mounted) {
          WHAlert.showError(
            context,
            'Apple Sign-In could not be completed. Please try again or sign up with your email and password.',
          );
        }
        return;
      }

      await ref.read(authStateProvider.notifier).appleSignIn(
            identityToken: identityToken,
            userIdentifier: credential.userIdentifier ?? '',
            email: credential.email,
            givenName: credential.givenName,
            familyName: credential.familyName,
          );

      if (mounted && ref.read(authStateProvider).value?.isAuthenticated == true) {
        context.go('/feed');
        WHAlert.showSuccess(context, 'Welcome to WatchersHive! 🐝✨');
      }
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        debugPrint('[AppleSignIn] User canceled Apple Sign-In flow');
      } else {
        if (mounted) {
          WHAlert.showError(context, 'Sign in with Apple failed: ${e.message}');
        }
      }
    } catch (e) {
      debugPrint('[AppleSignIn] Error: $e');
      if (mounted) {
        WHAlert.showError(context, _parseError(e));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                const WHLogoHeader(
                  title: 'Create account',
                  subtitle: 'Start tracking your watch history',
                ),
                const SizedBox(height: 40),

                // Username
                WHTextField(
                  controller: _usernameController,
                  label: 'Username',
                  hint: 'yourname',
                  textInputAction: TextInputAction.next,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Username is required';
                    if (v.length < 3) return 'At least 3 characters';
                    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(v)) {
                      return 'Only letters, numbers and underscores';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Email
                WHTextField(
                  controller: _emailController,
                  label: 'Email',
                  hint: 'you@example.com',
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Email is required';
                    if (!v.contains('@')) return 'Enter a valid email';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Password
                WHTextField(
                  controller: _passwordController,
                  label: 'Password',
                  hint: 'Min. 8 characters',
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _register(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      color: AppColors.textMuted,
                      size: 20,
                    ),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Password is required';
                    if (v.length < 8) return 'At least 8 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 32),

                WHButton(
                  label: 'Create Account',
                  isLoading: _isLoading,
                  onPressed: _register,
                ),
                const SizedBox(height: 20),

                // Divider
                Row(children: [
                  const Expanded(child: Divider(color: AppColors.border)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'or register with',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  const Expanded(child: Divider(color: AppColors.border)),
                ]),
                const SizedBox(height: 16),

                // Google Sign-In
                OutlinedButton.icon(
                  onPressed: _googleSignIn,
                  icon: const Text('G', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.primary)),
                  label: const Text('Continue with Google'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),

                // Apple Sign-In (Apple App Store Guideline 4.8)
                if (!kIsWeb && (Platform.isIOS || Platform.isMacOS)) ...[
                  const SizedBox(height: 12),
                  SignInWithAppleButton(
                    onPressed: _appleSignIn,
                    style: SignInWithAppleButtonStyle.black,
                    borderRadius: BorderRadius.circular(16),
                    height: 48,
                  ),
                ],
                const SizedBox(height: 20),

                Center(
                  child: Text.rich(
                    TextSpan(
                      text: 'By creating an account, you agree to our ',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11.5,
                        color: AppColors.textMuted,
                      ),
                      children: [
                        WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: GestureDetector(
                            onTap: () => context.push('/privacy-policy'),
                            child: const Text(
                              'Terms of Service & Privacy Policy',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryDark,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 20),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Already have an account? ',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                    TextButton(
                      onPressed: () => context.pop(),
                      child: const Text('Sign in'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
