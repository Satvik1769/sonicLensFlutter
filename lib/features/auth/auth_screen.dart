import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/providers/app_provider.dart';
import '../../core/theme/app_theme.dart';

// ignore_for_file: use_build_context_synchronously

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isLogin = true;

  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _obscurePass = true;
  bool _obscureConfirm = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  void _switchMode() {
    setState(() {
      _isLogin = !_isLogin;
      _error = null;
      _passCtrl.clear();
      _confirmCtrl.clear();
    });
  }

  Future<void> _submit(AppProvider provider) async {
    final email = _userCtrl.text.trim();
    final password = _passCtrl.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Please fill in all fields.');
      return;
    }

    if (!_isLogin) {
      if (password != _confirmCtrl.text) {
        setState(() => _error = 'Passwords do not match.');
        return;
      }
      if (password.length < 6) {
        setState(() => _error = 'Password must be at least 6 characters.');
        return;
      }
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      if (_isLogin) {
        final token = await provider.login(email, password);
        if (!mounted) return;
        if (token == null) setState(() => _error = 'Invalid email or password.');
      } else {
        final ok = await provider.register(email, password);
        if (!mounted) return;
        if (ok) {
          // Auto-login after register
          final token = await provider.login(email, password);
          if (!mounted) return;
          if (token == null) {
            setState(() {
              _isLogin = true;
              _error = 'Registered! Please log in.';
            });
          }
        } else {
          setState(() => _error = 'Registration failed. Username may be taken.');
        }
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();

    return Scaffold(
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF0A1628), Color(0xFF080C14)],
              ),
            ),
          ),

          // Subtle glow behind logo
          Positioned(
            top: -60,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 320,
                height: 320,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppTheme.radarInner.withValues(alpha: 0.12),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  const SizedBox(height: 56),

                  // Logo
                  _Logo(),

                  const SizedBox(height: 48),

                  // Card
                  _AuthCard(
                    isLogin: _isLogin,
                    userCtrl: _userCtrl,
                    passCtrl: _passCtrl,
                    confirmCtrl: _confirmCtrl,
                    obscurePass: _obscurePass,
                    obscureConfirm: _obscureConfirm,
                    onTogglePass: () =>
                        setState(() => _obscurePass = !_obscurePass),
                    onToggleConfirm: () =>
                        setState(() => _obscureConfirm = !_obscureConfirm),
                    busy: _busy,
                    error: _error,
                    onSubmit: () => _submit(provider),
                    onSwitch: _switchMode,
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Logo ─────────────────────────────────────────────────────────────────────

class _Logo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const RadialGradient(
              colors: [AppTheme.radarGlow, AppTheme.radarInner],
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.radarInner.withValues(alpha: 0.5),
                blurRadius: 28,
                spreadRadius: 4,
              ),
            ],
          ),
          child: const Icon(Icons.graphic_eq_rounded,
              color: Colors.white, size: 36),
        ),
        const SizedBox(height: 16),
        const Text(
          'SonicLens',
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Identify any song around you',
          style: TextStyle(color: Colors.white38, fontSize: 13),
        ),
      ],
    );
  }
}

// ── Auth Card ─────────────────────────────────────────────────────────────────

class _AuthCard extends StatelessWidget {
  final bool isLogin;
  final TextEditingController userCtrl;
  final TextEditingController passCtrl;
  final TextEditingController confirmCtrl;
  final bool obscurePass;
  final bool obscureConfirm;
  final VoidCallback onTogglePass;
  final VoidCallback onToggleConfirm;
  final bool busy;
  final String? error;
  final VoidCallback onSubmit;
  final VoidCallback onSwitch;

  const _AuthCard({
    required this.isLogin,
    required this.userCtrl,
    required this.passCtrl,
    required this.confirmCtrl,
    required this.obscurePass,
    required this.obscureConfirm,
    required this.onTogglePass,
    required this.onToggleConfirm,
    required this.busy,
    required this.error,
    required this.onSubmit,
    required this.onSwitch,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF111827),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isLogin ? 'Welcome back' : 'Create account',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              isLogin
                  ? 'Sign in to continue'
                  : 'Join SonicLens today',
              style: const TextStyle(color: Colors.white38, fontSize: 13),
            ),

            const SizedBox(height: 24),

            // Username
            _Field(
              controller: userCtrl,
              label: 'Username',
              hint: 'your_username',
              prefixIcon: Icons.person_outline,
            ),

            const SizedBox(height: 14),

            // Password
            _Field(
              controller: passCtrl,
              label: 'Password',
              hint: '••••••••',
              prefixIcon: Icons.lock_outline,
              obscure: obscurePass,
              suffixIcon: IconButton(
                icon: Icon(
                  obscurePass ? Icons.visibility_off : Icons.visibility,
                  color: Colors.white24,
                  size: 18,
                ),
                onPressed: onTogglePass,
              ),
            ),

            // Confirm password (register only)
            if (!isLogin) ...[
              const SizedBox(height: 14),
              _Field(
                controller: confirmCtrl,
                label: 'Confirm password',
                hint: '••••••••',
                prefixIcon: Icons.lock_outline,
                obscure: obscureConfirm,
                suffixIcon: IconButton(
                  icon: Icon(
                    obscureConfirm ? Icons.visibility_off : Icons.visibility,
                    color: Colors.white24,
                    size: 18,
                  ),
                  onPressed: onToggleConfirm,
                ),
              ),
            ],

            // Error
            if (error != null) ...[
              const SizedBox(height: 14),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border:
                      Border.all(color: Colors.red.withValues(alpha: 0.35)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline,
                        color: Colors.redAccent, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        error!,
                        style: const TextStyle(
                            color: Colors.redAccent, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Submit
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: busy ? null : onSubmit,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.radarInner,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        isLogin ? 'Log in' : 'Create account',
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600),
                      ),
              ),
            ),

            const SizedBox(height: 16),

            // Switch mode
            Center(
              child: GestureDetector(
                onTap: onSwitch,
                child: RichText(
                  text: TextSpan(
                    style: const TextStyle(fontSize: 13),
                    children: [
                      TextSpan(
                        text: isLogin
                            ? "Don't have an account? "
                            : 'Already have an account? ',
                        style: const TextStyle(color: Colors.white38),
                      ),
                      TextSpan(
                        text: isLogin ? 'Register' : 'Log in',
                        style: const TextStyle(
                          color: AppTheme.radarGlow,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData prefixIcon;
  final bool obscure;
  final Widget? suffixIcon;

  const _Field({
    required this.controller,
    required this.label,
    required this.hint,
    required this.prefixIcon,
    this.obscure = false,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(color: Colors.white54, fontSize: 12)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: obscure,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white24),
            prefixIcon:
                Icon(prefixIcon, color: Colors.white24, size: 18),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: const Color(0xFF0F172A),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.white12),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.white12),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                  color: AppTheme.radarGlow, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}