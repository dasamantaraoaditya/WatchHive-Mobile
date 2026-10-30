import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/app_update_service.dart';
import '../../../shared/widgets/app_update_dialog.dart';
import '../../../shared/widgets/shared_widgets.dart';
import '../providers/auth_provider.dart';
import '../../../core/utils/error_handler.dart';
import '../../onboarding/services/onboarding_service.dart';
import '../../onboarding/widgets/watch_preferences_onboarding_dialog.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final updateService = ref.read(appUpdateServiceProvider);
        final info = await updateService.checkUpdate();
        if (mounted && info != null && info.forceUpdate) {
          AppUpdateDialog.show(context, info: info, updateService: updateService);
        }
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_emailController.text.trim().isEmpty || _passwordController.text.isEmpty) {
      WHAlert.showWarning(context, 'Please enter both your email and password');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await ref.read(authStateProvider.notifier).login(
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

  Future<void> _googleSignIn() async {
    if (_isLoading) return;
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

      debugPrint('[GoogleSignIn] Starting Google Sign-In with serverClientId=$effectiveClientId, iosClientId=$effectiveIosClientId');

      final googleSignIn = GoogleSignIn(
        clientId: effectiveIosClientId,
        serverClientId: effectiveClientId,
        scopes: const ['email', 'profile'],
      );

      // Reset previous session state to ensure fresh picker
      await googleSignIn.signOut().catchError((_) => null);

      final account = await googleSignIn.signIn();
      if (account == null) {
        debugPrint('[GoogleSignIn] User canceled account selection picker');
        return;
      }

      debugPrint('[GoogleSignIn] Account selected: ${account.email}. Fetching auth tokens...');
      final auth = await account.authentication;
      final idToken = auth.idToken;

      if (idToken == null || idToken.isEmpty) {
        debugPrint('[GoogleSignIn] Error: idToken was null or empty from Google authentication');
        if (mounted) {
          WHAlert.showError(
            context,
            'Google Sign-In could not be completed. Please try again or sign in with your email and password.',
          );
        }
        return;
      }

      debugPrint('[GoogleSignIn] Successfully retrieved idToken. Authenticating with WatchersHive backend...');
      await ref.read(authStateProvider.notifier).googleSignIn(idToken);
      if (mounted && ref.read(authStateProvider).value?.isAuthenticated == true) {
        debugPrint('[GoogleSignIn] Successfully authenticated with backend.');
        await _handlePostAuthFlow();
      }
    } catch (e) {
      debugPrint('[GoogleSignIn] Error during sign-in flow: $e');
      if (mounted) {
        WHAlert.showError(context, _formatGoogleError(e));
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
            'Apple Sign-In could not be completed. Please try again or sign in with your email and password.',
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
                : 'Sign in with Apple failed. Please try again or use email sign-in.',
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
    }
  }

  String _formatGoogleError(dynamic e) {
    final str = e.toString();
    if (str.contains('7:')) {
      return 'Network error during Google Sign-In. Please check your internet connection.';
    } else if (str.contains('10:') || str.contains('12500')) {
      return 'Google Sign-In is temporarily unavailable. Please sign in with your email and password.';
    } else if (str.contains('Concurrent')) {
      return 'Google Sign-In is already in progress. Please wait a moment.';
    }
    return _parseError(e);
  }

  String _parseError(dynamic error) {
    return AppErrorHandler.toUserFriendlyMessage(
      error,
      defaultMessage: 'Unable to sign in. Please verify your credentials and try again.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final isBackgroundResolving = authState.isLoading && !_isLoading;

    if (isBackgroundResolving) {
      return WHAppLogoLoader.fullScreen(
        message: 'Signing you in...',
        submessage: 'Connecting to WatchersHive',
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
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
                  title: 'Welcome back',
                  subtitle: 'Sign in to continue tracking',
                ),
                const SizedBox(height: 16),

                // Top Redirection to Sign Up
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Don't have an account? ",
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                    GestureDetector(
                      onTap: () => context.push('/signup'),
                      child: const Text(
                        'Sign up',
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

                // Divider: or continue with email
                Row(children: [
                  const Expanded(child: Divider(color: AppColors.border)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'or continue with email',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ),
                  const Expanded(child: Divider(color: AppColors.border)),
                ]),
                const SizedBox(height: 24),

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
                  hint: '••••••••',
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _login(),
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
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // Forgot Password
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => context.push('/forgot-password'),
                    child: const Text('Forgot password?'),
                  ),
                ),
                const SizedBox(height: 20),

                // Login Button
                WHButton(
                  label: 'Sign In',
                  isLoading: _isLoading,
                  onPressed: _login,
                ),
                const SizedBox(height: 28),

                // Terms & Privacy acceptance (Apple Guideline 1.2 & 5.1.1)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text.rich(
                    TextSpan(
                      text: 'By continuing, you acknowledge our ',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                      children: [
                        WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: GestureDetector(
                            onTap: () => context.push('/privacy-policy'),
                            child: const Text(
                              'Terms & Privacy Policy',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
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
                const SizedBox(height: 16),

                // Support & Help link
                Center(
                  child: TextButton.icon(
                    onPressed: () => context.push('/support'),
                    icon: const Icon(Icons.help_outline_rounded, size: 15, color: AppColors.textMuted),
                    label: const Text(
                      'Need help? Contact Support',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted,
                      ),
                    ),
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
          message: 'Signing you into WatchersHive...',
          submessage: 'Authenticating your account',
        ),
    ],
  ),
);
  }
}
