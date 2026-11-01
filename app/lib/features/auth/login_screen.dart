import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:orbit_app/core/constants/app_colors.dart';
import 'package:orbit_app/core/storage/secure_storage_service.dart';
import 'package:orbit_app/features/home/home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _totpController = TextEditingController();

  // Mode: 'login', 'signup', 'forgot'
  String _mode = 'login';
  bool _loading = false;
  bool _obscurePassword = true;
  String? _errorMessage;
  String? _successMessage;
  String? _mfaFactorId;
  String? _mfaChallengeId;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _totpController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty) {
      setState(() => _errorMessage = 'Alamat email wajib diisi.');
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    if (_mode == 'forgot') {
      try {
        await Supabase.instance.client.auth.resetPasswordForEmail(
          email,
          redirectTo: 'io.supabase.orbit://login-callback/',
        );
        if (mounted) {
          setState(() {
            _loading = false;
            _successMessage =
                'Tautan reset kata sandi telah dikirim ke email Anda. Silakan cek kotak masuk atau folder spam.';
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _loading = false;
            _errorMessage = 'Gagal mengirim tautan pemulihan: $e';
          });
        }
      }
      return;
    }

    if (password.length < 6) {
      setState(() {
        _loading = false;
        _errorMessage = 'Kata sandi minimal harus 6 karakter.';
      });
      return;
    }

    if (_mode == 'signup') {
      try {
        final res = await Supabase.instance.client.auth.signUp(
          email: email,
          password: password,
          emailRedirectTo: 'io.supabase.orbit://login-callback/',
        );

        final session = res.session;
        if (session != null) {
          await SecureStorageService.saveSessionToken(session.accessToken);
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const HomeScreen()),
            );
          }
        } else {
          if (mounted) {
            setState(() {
              _loading = false;
              _mode = 'login';
              _successMessage =
                  'Pendaftaran berhasil! Silakan cek email untuk verifikasi atau masuk langsung.';
            });
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _loading = false;
            _errorMessage = 'Gagal mendaftar: $e';
          });
        }
      }
      return;
    }

    // Mode: login
    try {
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final session = response.session;
      if (session != null) {
        await SecureStorageService.saveSessionToken(session.accessToken);

        // Periksa apakah memerlukan 2FA
        final mfaResponse =
            Supabase.instance.client.auth.mfa.getAuthenticatorAssuranceLevel();
        if (mfaResponse.nextLevel == AuthenticatorAssuranceLevels.aal2 &&
            mfaResponse.currentLevel == AuthenticatorAssuranceLevels.aal1) {
          final factors = await Supabase.instance.client.auth.mfa.listFactors();
          final totpFactor = factors.totp.firstOrNull;
          if (totpFactor != null) {
            final challenge = await Supabase.instance.client.auth.mfa.challenge(
              factorId: totpFactor.id,
            );
            setState(() {
              _mfaFactorId = totpFactor.id;
              _mfaChallengeId = challenge.id;
              _loading = false;
            });
            return;
          }
        }

        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Kombinasi email atau kata sandi tidak valid.';
        _loading = false;
      });
    }
  }

  Future<void> _handleGoogleLogin() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'io.supabase.orbit://login-callback/',
      );
      if (mounted) {
        setState(() => _loading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _errorMessage = 'Gagal membuka autentikasi Google: $e';
        });
      }
    }
  }

  Future<void> _handleVerifyTotp() async {
    if (_mfaFactorId == null || _mfaChallengeId == null) return;

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      await Supabase.instance.client.auth.mfa.verify(
        factorId: _mfaFactorId!,
        challengeId: _mfaChallengeId!,
        code: _totpController.text.trim(),
      );

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Kode 2FA tidak valid atau sudah kedaluwarsa.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Container(
                padding: const EdgeInsets.all(24.0),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Theme.of(context).dividerColor,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.brandIndigo.withValues(alpha: isDark ? 0.12 : 0.08),
                      blurRadius: 32,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Logo Orbit
                    Center(
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.brandIndigo.withValues(alpha: 0.35),
                              blurRadius: 20,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Image.asset(
                            'assets/images/orbit_icon.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ShaderMask(
                      shaderCallback: (bounds) =>
                          AppColors.brandGradient.createShader(bounds),
                      child: const Text(
                        'ORBIT',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'PRODUCTIVITY & FINANCE',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 2.0,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _mode == 'login'
                          ? 'Masuk ke pusat kendali keuangan & kerja Anda'
                          : _mode == 'signup'
                              ? 'Buat akun baru untuk mulai mengelola Orbit'
                              : 'Masukkan email untuk mengatur ulang kata sandi',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Toggle Mode Masuk / Daftar Baru
                    if (_mfaFactorId == null && _mode != 'forgot') ...[
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).scaffoldBackgroundColor,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Theme.of(context).dividerColor),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() {
                                  _mode = 'login';
                                  _errorMessage = null;
                                  _successMessage = null;
                                }),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: _mode == 'login'
                                        ? Theme.of(context).cardColor
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    'Masuk',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: _mode == 'login'
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() {
                                  _mode = 'signup';
                                  _errorMessage = null;
                                  _successMessage = null;
                                }),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: _mode == 'signup'
                                        ? Theme.of(context).cardColor
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    'Daftar Baru',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: _mode == 'signup'
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.expense.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.expense.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline,
                                color: AppColors.expense, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(
                                  color: AppColors.expense,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    if (_successMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.income.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.income.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_outline,
                                color: AppColors.income, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _successMessage!,
                                style: const TextStyle(
                                  color: AppColors.income,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    if (_mfaFactorId != null) ...[
                      const Text(
                        'Masukkan 6 digit kode dari aplikasi autentikator Anda',
                        style: TextStyle(fontSize: 13),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _totpController,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 20, letterSpacing: 4),
                        decoration: const InputDecoration(
                          hintText: '000000',
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _loading ? null : _handleVerifyTotp,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.brandIndigo,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          _loading ? 'Memverifikasi...' : 'Verifikasi & Masuk',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ] else ...[
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Alamat Email',
                          prefixIcon: Icon(Icons.email_outlined, size: 20),
                        ),
                      ),
                      if (_mode != 'forgot') ...[
                        const SizedBox(height: 14),
                        TextField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            labelText: 'Kata Sandi',
                            prefixIcon: const Icon(Icons.lock_outline, size: 20),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                size: 20,
                              ),
                              onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                            ),
                          ),
                        ),
                      ],
                      if (_mode == 'login') ...[
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => setState(() {
                              _mode = 'forgot';
                              _errorMessage = null;
                              _successMessage = null;
                            }),
                            child: const Text(
                              'Lupa kata sandi?',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.brandIndigo,
                              ),
                            ),
                          ),
                        ),
                      ] else ...[
                        const SizedBox(height: 20),
                      ],

                      // Primary Gradient Submit Button
                      Container(
                        decoration: BoxDecoration(
                          gradient: AppColors.brandGradient,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.brandIndigo.withValues(alpha: 0.35),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: _loading ? null : _handleSubmit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            _loading
                                ? 'Memproses...'
                                : _mode == 'signup'
                                    ? 'Buat Akun Orbit'
                                    : _mode == 'forgot'
                                        ? 'Kirim Tautan Reset Sandi'
                                        : 'Masuk ke Orbit',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),

                      if (_mode == 'forgot') ...[
                        const SizedBox(height: 12),
                        TextButton.icon(
                          onPressed: () => setState(() {
                            _mode = 'login';
                            _errorMessage = null;
                            _successMessage = null;
                          }),
                          icon: const Icon(Icons.arrow_back, size: 16),
                          label: const Text(
                            'Kembali ke Halaman Masuk',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ] else ...[
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: Divider(color: Theme.of(context).dividerColor),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Text(
                                'ATAU',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1.2,
                                  color: Theme.of(context).colorScheme.outline,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Divider(color: Theme.of(context).dividerColor),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: _loading ? null : _handleGoogleLogin,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: BorderSide(color: Theme.of(context).dividerColor),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: Container(
                            width: 20,
                            height: 20,
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                            ),
                            child: const Text(
                              'G',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                                color: Color(0xFF4285F4),
                              ),
                            ),
                          ),
                          label: const Text(
                            'Masuk dengan Google',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
