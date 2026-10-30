import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/shared_widgets.dart';
import '../providers/auth_provider.dart';
import '../../../core/utils/error_handler.dart';
import '../../onboarding/services/onboarding_service.dart';
import '../../onboarding/widgets/watch_preferences_onboarding_dialog.dart';

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
        await _handlePostAuthFlow();
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

  Future<void> _handlePostAuthFlow() async {
    final user = ref.read(authStateProvider).value?.user;
    if (user != null) {
      final onboardingService = ref.read(onboardingServiceProvider);
      final shouldPrompt = await onboardingService.shouldPromptUser(user);
      if (shouldPrompt && mounted) {
        onboardingService.markPrompted();
        await WatchPreferencesOnboardingDialog.show(context);
        await onboardingService.markPreferencesCompleted(user.id);
      }
    }
    if (mounted) {
      context.go('/feed');
      WHAlert.showSuccess(context, 'Welcome to WatchersHive!');
    }
  }

  Future<void> _googleSignIn() async {
    setState(() => _isLoading = true);
    try {
      final webClientId = dotenv.env['GOOGLE_WEB_CLIENT_ID']?.trim();
      final effectiveClientId = (webClientId != null &&
              webClientId.isNotEmpty &&
              !webClientId.contains('your_google_web_client_id'))
          ? webClientId
          : '357857516251-f4gpp8f1j70lu1dcnh405ac0t6lch9tf.apps.googleusercontent.com';

      final iosClientId = dotenv.env['GOOGLE_IOS_CLIENT_ID']?.trim();
      final effectiveIosClientId = (iosClientId != null &&
              iosClientId.isNotEmpty &&
              !iosClientId.contains('your_google_ios_client_id'))
          ? iosClientId
          : null;

      debugPrint('[GoogleSignUp] Starting Google Sign-Up with serverClientId=$effectiveClientId, iosClientId=$effectiveIosClientId');

      final googleSignIn = GoogleSignIn(
        clientId: effectiveIosClientId,
        serverClientId: effectiveClientId,
        scopes: const ['email', 'profile'],
      );

      await googleSignIn.signOut().catchError((_) => null);
      final account = await googleSignIn.signIn();
      if (account == null) {
        debugPrint('[GoogleSignUp] User canceled account selection picker');
        return;
      }

      debugPrint('[GoogleSignUp] Account selected: ${account.email}. Fetching auth tokens...');
      final auth = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null || idToken.isEmpty) {
        debugPrint('[GoogleSignUp] Error: idToken was null or empty');
        if (mounted) {
          WHAlert.showError(
            context,
            'Google Sign-In could not be completed. Please try again or sign up with your email and password.',
          );
        }
        return;
      }

      debugPrint('[GoogleSignUp] Successfully retrieved idToken. Authenticating with backend...');
      await ref.read(authStateProvider.notifier).googleSignIn(idToken);
      if (mounted && ref.read(authStateProvider).value?.isAuthenticated == true) {
        debugPrint('[GoogleSignUp] Successfully authenticated with backend.');
        await _handlePostAuthFlow();
      }
    } catch (e) {
      debugPrint('[GoogleSignUp] Error during sign-up flow: $e');
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
        await _handlePostAuthFlow();
      }
    } on SignInWithAppleAuthorizationException catch (e) {
      debugPrint('[AppleSignIn] AuthorizationException: ${e.code} - ${e.message}');
      if (e.code == AuthorizationErrorCode.canceled) {
        if (mounted) {
          WHAlert.showInfo(
            context,
            'Apple Sign-In was canceled. Note: If testing on an iOS Simulator, please ensure you are signed in to your Apple ID in the Simulator Settings app first.',
          );
        }
      } else {
        if (mounted) {
          WHAlert.showError(
            context,
            e.message.isNotEmpty
                ? 'Sign in with Apple failed: ${e.message}'
                : 'Sign in with Apple failed. Please try again or use email sign-up.',
          );
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
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 48),
                const WHLogoHeader(
                  title: 'Create account',
                  subtitle: 'Start tracking your watch history',
                ),
                const SizedBox(height: 16),

                // Top Redirection to Sign In
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Already have an account? ',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                    GestureDetector(
                      onTap: () => context.pop(),
                      child: const Text(
                        'Sign in',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Social Sign-In (Google & Apple on TOP)
                WHGoogleSignInButton(
                  onPressed: _googleSignIn,
                  isLoading: _isLoading,
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
                const SizedBox(height: 24),

                // Divider: or register with email
                Row(children: [
                  const Expanded(child: Divider(color: AppColors.border)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'or register with email',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ),
                  const Expanded(child: Divider(color: AppColors.border)),
                ]),
                const SizedBox(height: 24),

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
                const SizedBox(height: 28),

                WHButton(
                  label: 'Create Account',
                  isLoading: _isLoading,
                  onPressed: _register,
                ),
                const SizedBox(height: 24),

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
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
      if (_isLoading)
        WHAppLogoLoader.overlay(
          message: 'Creating your WatchersHive account...',
          submessage: 'Setting up your personal hive',
        ),
    ],
  ),
);
  }
}
