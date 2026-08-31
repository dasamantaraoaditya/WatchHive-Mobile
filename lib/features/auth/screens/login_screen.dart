import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/shared_widgets.dart';
import '../providers/auth_provider.dart';

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
        context.go('/feed');
      }
    } catch (e) {
      if (mounted) {
        WHAlert.showError(context, _parseError(e.toString()));
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

      final googleSignIn = GoogleSignIn(
        serverClientId: effectiveClientId,
        scopes: const ['email', 'profile'],
      );

      // Reset previous session state to ensure fresh picker
      await googleSignIn.signOut().catchError((_) => null);

      final account = await googleSignIn.signIn();
      if (account == null) return; // User cancelled picker

      final auth = await account.authentication;
      final idToken = auth.idToken;

      if (idToken == null || idToken.isEmpty) {
        if (mounted) {
          WHAlert.showError(
            context,
            'Google Sign-In failed: No ID Token returned. Ensure GOOGLE_WEB_CLIENT_ID is set in .env',
          );
        }
        return;
      }

      await ref.read(authStateProvider.notifier).googleSignIn(idToken);
      if (mounted && ref.read(authStateProvider).value?.isAuthenticated == true) {
        context.go('/feed');
      }
    } catch (e) {
      debugPrint('Google Sign-In Error: $e');
      if (mounted) {
        WHAlert.showError(context, _formatGoogleError(e));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatGoogleError(dynamic e) {
    final str = e.toString();
    if (str.contains('7:')) {
      return 'Google Sign-In error (7): Network error. Please ensure a Google account is logged into the device Settings > Accounts and internet is connected.';
    } else if (str.contains('10:')) {
      return 'Google Sign-In error (10): SHA-1 fingerprint or Web Client ID mismatch in Google Cloud Console.';
    } else if (str.contains('12500')) {
      return 'Google Sign-In error (12500): Check Google Play Services and OAuth configuration.';
    } else if (str.contains('Concurrent')) {
      return 'Google Sign-In is already in progress. Please wait a moment.';
    }
    return _parseError(str);
  }

  String _parseError(String error) {
    if (error.contains('401') || error.contains('Invalid')) return 'Invalid email or password.';
    if (error.contains('network') || error.contains('connection')) return 'Network error. Check your connection.';
    return error.length > 80 ? '${error.substring(0, 80)}...' : error;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 60),
                const WHLogoHeader(
                  title: 'Welcome back',
                  subtitle: 'Sign in to continue tracking',
                ),
                const SizedBox(height: 40),

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
                const SizedBox(height: 24),

                // Login Button
                WHButton(
                  label: 'Sign In',
                  isLoading: _isLoading,
                  onPressed: _login,
                ),
                const SizedBox(height: 20),

                // Divider
                Row(children: [
                  const Expanded(child: Divider(color: AppColors.border)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'or',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  const Expanded(child: Divider(color: AppColors.border)),
                ]),
                const SizedBox(height: 20),

                // Google Sign-In
                OutlinedButton.icon(
                  onPressed: _googleSignIn,
                  icon: const Text('G', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.primary)),
                  label: const Text('Continue with Google'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
                const SizedBox(height: 32),

                // Sign Up Link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Don't have an account? ",
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                    TextButton(
                      onPressed: () => context.push('/signup'),
                      child: const Text('Sign up'),
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
