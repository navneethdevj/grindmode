import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import 'onboarding_screen.dart';
import 'home_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLogin = true;
  bool _loading = false;
  bool _googleLoading = false;
  String? _error;
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _auth = AuthService();

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() { _loading = true; _error = null; });
    try {
      if (_isLogin) {
        await _auth.signInWithEmail(
          email: _emailCtrl.text.trim(),
          password: _passCtrl.text.trim(),
        );
        if (mounted) Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const HomeScreen()));
      } else {
        if (_userCtrl.text.trim().isEmpty) {
          setState(() { _error = 'Username is required'; _loading = false; });
          return;
        }
        await _auth.signUpWithEmail(
          email: _emailCtrl.text.trim(),
          password: _passCtrl.text.trim(),
          username: _userCtrl.text.trim(),
        );
        if (mounted) Navigator.pushReplacement(
          context, MaterialPageRoute(
            builder: (_) => OnboardingScreen(name: _userCtrl.text.trim())));
      }
    } catch (e) {
      setState(() { _error = _friendlyError(e.toString()); });
    }
    if (mounted) setState(() => _loading = false);
  }

 Future<void> _handleGoogleSignIn() async {
  FocusScope.of(context).unfocus();
  await Future.delayed(const Duration(milliseconds: 200));
  if (!mounted) return;
  setState(() { _googleLoading = true; _error = null; });
  try {
    final cred = await _auth.signInWithGoogle();
    if (cred != null && mounted) {
      // FIX: check onboardingDone before deciding where to navigate
      final doc = await FirebaseFirestore.instance
          .collection('users').doc(cred.user!.uid).get();
      final onboardingDone = doc.data()?['onboardingDone'] ?? false;
      final name = doc.data()?['name'] ?? '';
      if (!mounted) return;
      if (onboardingDone) {
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => const HomeScreen()));
      } else {
        Navigator.pushReplacement(context,
            MaterialPageRoute(
                builder: (_) => OnboardingScreen(name: name)));
      }
    }
  } catch (e) {
    if (mounted) setState(() { _error = _friendlyError(e.toString()); });
  }
  if (mounted) setState(() => _googleLoading = false);
}
  String _friendlyError(String error) {
    if (error.contains('user-not-found'))
      return "U sure you were here before? We don't know you";
    if (error.contains('wrong-password') || error.contains('invalid-credential'))
      return "Email or password is wrong. Try again";
    if (error.contains('invalid-email'))
      return "That's not even a real email bro";
    if (error.contains('email-already-in-use'))
      return "Someone already claimed that email. Identity thief?";
    if (error.contains('weak-password'))
      return "Password123 is NOT a password. Try harder";
    if (error.contains('too-many-requests'))
      return "Calm down. Too many failed attempts, take a break";
    if (error.contains('network-request-failed'))
      return "No internet? How are you even here rn";
    return "Something went wrong. Classic. Try again";
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Column(children: [
                const Text('\u26a1', style: TextStyle(fontSize: 56)),
                const SizedBox(height: 8),
                const Text('GrindMode', style: TextStyle(
                  fontSize: 32, fontWeight: FontWeight.w900,
                  color: AppColors.staticAccent, fontFamily: 'Nunito')),
                const SizedBox(height: 4),
                const Text('STUDY HARD. GET ROASTED. CLIMB THE RANKS.',
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800,
                    color: AppColors.mutedLight, letterSpacing: 1.4)),
              ])),
              const SizedBox(height: 32),
              Container(
                decoration: BoxDecoration(color: AppColors.surface2Light,
                  borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.all(4),
                child: Row(children: [
                  _tab('Log In', _isLogin,
                    () => setState(() { _isLogin = true; _error = null; })),
                  _tab('Sign Up', !_isLogin,
                    () => setState(() { _isLogin = false; _error = null; })),
                ]),
              ),
              const SizedBox(height: 20),
              if (!_isLogin) ...[
                _label('USERNAME'),
                const SizedBox(height: 6),
                _input(_userCtrl, 'e.g. grindmaster99', false),
                const SizedBox(height: 14),
              ],
              _label('EMAIL'),
              const SizedBox(height: 6),
              _input(_emailCtrl, 'you@email.com', false),
              const SizedBox(height: 14),
              _label('PASSWORD'),
              const SizedBox(height: 6),
              _input(_passCtrl, '********', true),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: const TextStyle(
                  color: AppColors.staticRed, fontSize: 13)),
              ],
              const SizedBox(height: 24),
              SizedBox(width: double.infinity,
                child: ElevatedButton(
                  onPressed: (_loading || _googleLoading) ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.staticAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
                  child: _loading
                    ? const SizedBox(height: 20, width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                    : Text(_isLogin ? 'Log In' : 'Create Account',
                        style: const TextStyle(fontSize: 15,
                          fontWeight: FontWeight.w800, fontFamily: 'Nunito')),
                )),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: Divider(color: AppColors.borderLight)),
                Padding(padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text('or', style: TextStyle(
                    color: AppColors.mutedLight, fontSize: 13))),
                Expanded(child: Divider(color: AppColors.borderLight)),
              ]),
              const SizedBox(height: 16),
              SizedBox(width: double.infinity,
                child: OutlinedButton(
                  onPressed: (_loading || _googleLoading)
                    ? null : _handleGoogleSignIn,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: AppColors.borderLight),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
                  child: _googleLoading
                    ? const SizedBox(height: 20, width: 20,
                        child: CircularProgressIndicator(
                          color: AppColors.staticAccent, strokeWidth: 2))
                    : Row(mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(width: 20, height: 20,
                            decoration: BoxDecoration(color: AppColors.staticAccent,
                              borderRadius: BorderRadius.circular(4)),
                            child: const Center(child: Text('G',
                              style: TextStyle(color: Colors.white,
                                fontSize: 12, fontWeight: FontWeight.w900)))),
                          const SizedBox(width: 10),
                          const Text('Continue with Google',
                            style: TextStyle(fontWeight: FontWeight.w700,
                              fontSize: 14, color: AppColors.textLight)),
                        ]),
                )),
              const SizedBox(height: 16),
              Center(child: GestureDetector(
                onTap: () => setState(() { _isLogin = !_isLogin; _error = null; }),
                child: Text(
                  _isLogin ? 'New here? Create account' : 'Already have an account? Log in',
                  style: const TextStyle(color: AppColors.staticAccent,
                    fontWeight: FontWeight.w700, fontSize: 13)),
              )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tab(String label, bool active, VoidCallback onTap) {
    return Expanded(child: GestureDetector(onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? AppColors.surfaceLight : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          boxShadow: active ? [BoxShadow(
            color: Colors.black.withOpacity(0.08), blurRadius: 8)] : null),
        child: Text(label, textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13,
            color: active ? AppColors.staticAccent : AppColors.mutedLight,
            fontFamily: 'Nunito')))));
  }

  Widget _label(String text) => Text(text, style: const TextStyle(
    fontSize: 10, fontWeight: FontWeight.w800,
    color: AppColors.mutedLight, letterSpacing: 1.2));

  Widget _input(TextEditingController ctrl, String hint, bool obscure) {
    return TextField(
      controller: ctrl, obscureText: obscure,
      style: const TextStyle(fontSize: 15, color: AppColors.textLight),
      decoration: InputDecoration(hintText: hint,
        hintStyle: TextStyle(color: AppColors.mutedLight, fontSize: 14),
        filled: true, fillColor: AppColors.surfaceLight,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.borderLight)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.borderLight)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.staticAccent, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14)));
  }
}