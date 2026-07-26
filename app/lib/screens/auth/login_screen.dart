import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../constants/app_colors.dart';
import '../../services/connectivity_service.dart';
import '../../services/local_db_service.dart';
import '../../services/supabase_service.dart';
import 'signup_screen.dart';
import 'forgot_password_screen.dart';
import '../billing/billing_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _googleLoading = false;

  void _signInWithGoogle() async {
    setState(() => _googleLoading = true);
    try {
      await SupabaseService.signInWithGoogle();
      // Navigation handled by deep-link callback in main.dart
    } catch (e) {
      _showError('Google sign-in failed. Please try again.');
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  static const _navy = Color(0xFF1B2B4B);

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final exists = await SupabaseService.emailExists(_emailController.text);
      if (!exists) {
        _showError('No account found for this email. Please sign up first.');
        setState(() => _isLoading = false);
        return;
      }
    } catch (_) {}

    try {
      final response = await SupabaseService.signIn(
        _emailController.text.trim(),
        _passwordController.text,
      );
      if (!mounted) return;
      final userId = response.user?.id;
      if (userId != null) {
        // Only wipe local data when a different account signs in; the same user
        // re-authenticating must keep any not-yet-synced local changes.
        final switchingAccount = LocalDbService.currentUserId != null &&
            LocalDbService.currentUserId != userId;
        await LocalDbService.initForUser(userId);
        if (switchingAccount) {
          await LocalDbService.clearAll();
        }
        await ConnectivityService.instance.pullFromCloud();
      }
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const BillingScreen()),
      );
    } on AuthException catch (e) {
      _showError(e.message.contains('Invalid login credentials')
          ? 'Incorrect password. Please try again.'
          : e.message);
    } catch (e) {
      _showError('Connection error. Please check your internet.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.inter(color: Colors.white)),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Row(
        children: [
          // Left panel — dark navy
          Expanded(
            flex: 55,
            child: Container(
              color: _navy,
              child: Stack(
                children: [
                  // Top-left logo
                  Positioned(
                    top: 40,
                    left: 48,
                    child: Row(
                      children: [
                        const Icon(Icons.point_of_sale_rounded,
                            color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        Text('BillCat',
                            style: GoogleFonts.manrope(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            )),
                      ],
                    ),
                  ),
                  // Center headline
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 64),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Precision tools\nfor the modern\nentrepreneur.',
                            style: GoogleFonts.manrope(
                              fontSize: 40,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              height: 1.15,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Manage your sales, inventory,\nand reports — all in one place.',
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w300,
                              color: Colors.white54,
                              height: 1.65,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Bottom terminal tag
                  Positioned(
                    bottom: 40,
                    left: 48,
                    right: 48,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                                width: 28, height: 1, color: Colors.white24),
                            const SizedBox(width: 12),
                            Text('TERMINAL 01',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white30,
                                  letterSpacing: 2.5,
                                )),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text('Analytical precision. Bespoke experience.',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w300,
                              fontStyle: FontStyle.italic,
                              color: Colors.white30,
                            )),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Right panel — white form
          Expanded(
            flex: 45,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 64, vertical: 48),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 380),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Welcome back',
                            style: GoogleFonts.manrope(
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0F172A),
                            )),
                        const SizedBox(height: 6),
                        Text('Access your business dashboard',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w300,
                              color: const Color(0xFF64748B),
                            )),
                        const SizedBox(height: 40),
                        _fieldLabel('EMAIL ADDRESS'),
                        const SizedBox(height: 8),
                        _buildField(
                          controller: _emailController,
                          hint: 'manager@business.com',
                          validator: (v) =>
                              v != null && v.contains('@') ? null : 'Enter a valid email',
                        ),
                        const SizedBox(height: 22),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _fieldLabel('PASSWORD'),
                            GestureDetector(
                              onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => const ForgotPasswordScreen())),
                              child: Text('Forgot password?',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: _navy,
                                  )),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _buildField(
                          controller: _passwordController,
                          hint: '••••••••',
                          obscure: _obscurePassword,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: const Color(0xFF94A3B8),
                              size: 18,
                            ),
                            onPressed: () =>
                                setState(() => _obscurePassword = !_obscurePassword),
                          ),
                          validator: (v) =>
                              v != null && v.length >= 6 ? null : 'Minimum 6 characters',
                        ),
                        const SizedBox(height: 28),
                        // Sign In / Send OTP button
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _navy,
                              disabledBackgroundColor: _navy.withValues(alpha: 0.6),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                              elevation: 0,
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2.5))
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'SIGN IN',
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 1.8,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      const Icon(Icons.arrow_forward_rounded,
                                          size: 17),
                                    ],
                                  ),
                          ),
                        ),
                        const SizedBox(height: 28),
                        // Divider
                        Row(
                          children: [
                            const Expanded(child: Divider(color: Color(0xFFE2E8F0))),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              child: Text('Or continue with',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: const Color(0xFF94A3B8),
                                  )),
                            ),
                            const Expanded(child: Divider(color: Color(0xFFE2E8F0))),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Google button
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: OutlinedButton(
                            onPressed: (_isLoading || _googleLoading)
                                ? null
                                : _signInWithGoogle,
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFFE2E8F0)),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                              foregroundColor: const Color(0xFF0F172A),
                            ),
                            child: _googleLoading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Color(0xFF4285F4)))
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text('G',
                                          style: GoogleFonts.inter(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFF4285F4),
                                          )),
                                      const SizedBox(width: 10),
                                      Text('Sign in with Google',
                                          style: GoogleFonts.inter(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                            color: const Color(0xFF334155),
                                          )),
                                    ],
                                  ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('New to BillCat? ',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: const Color(0xFF94A3B8),
                                  )),
                              GestureDetector(
                                onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => const SignupScreen())),
                                child: Text('Create an account',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: _navy,
                                    )),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fieldLabel(String text) {
    return Text(text,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF475569),
          letterSpacing: 1.2,
        ));
  }

  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    bool obscure = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      validator: validator,
      style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF0F172A)),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle:
            GoogleFonts.inter(color: const Color(0xFFCBD5E1), fontSize: 14),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF1B2B4B), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}
