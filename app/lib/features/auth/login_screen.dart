import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:orbit_app/core/constants/app_colors.dart';
import 'package:orbit_app/core/widgets/orbit_widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoginScreen extends StatefulWidget {
  final String? initialError;
  final String? initialSuccess;

  const LoginScreen({
    super.key,
    this.initialError,
    this.initialSuccess,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String _mode = 'login'; // 'login' | 'signup' | 'forgot'
  bool _loading = false;
  bool _googleLoading = false;
  String? _error;
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    _error = widget.initialError;
    _successMessage = widget.initialSuccess;
  }

  SupabaseClient? get _supabaseOrNull {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty) {
      setState(() => _error = 'Alamat email wajib diisi.');
      return;
    }

    if (_mode != 'forgot' && password.isEmpty) {
      setState(() => _error = 'Kata sandi wajib diisi.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _successMessage = null;
    });

    final client = _supabaseOrNull;
    if (client == null) {
      setState(() {
        _loading = false;
        _error = 'Layanan autentikasi belum siap. Periksa koneksi Anda.';
      });
      return;
    }

    try {
      if (_mode == 'forgot') {
        await client.auth.resetPasswordForEmail(email);
        setState(() {
          _successMessage =
              'Tautan pemulihan kata sandi telah dikirim ke email Anda.';
        });
      } else if (_mode == 'signup') {
        await client.auth.signUp(
          email: email,
          password: password,
        );
        setState(() {
          _successMessage =
              'Pendaftaran berhasil. Silakan periksa email Anda atau masuk langsung.';
          _mode = 'login';
        });
      } else {
        await client.auth.signInWithPassword(
          email: email,
          password: password,
        );
      }
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Gagal terhubung ke server autentikasi.');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _googleLoading = true;
      _error = null;
      _successMessage = null;
    });

    final client = _supabaseOrNull;
    if (client == null) {
      setState(() {
        _googleLoading = false;
        _error = 'Layanan autentikasi belum siap.';
      });
      return;
    }

    try {
      await client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: kIsWeb ? null : 'io.supabase.orbit://login-callback/',
      );
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(
        () => _error =
            'Pastikan provider Google OAuth telah diaktifkan di Supabase Dashboard.',
      );
    } finally {
      if (mounted) {
        setState(() => _googleLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondaryColor =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppTokens.space6),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ClipRRect(
                        borderRadius:
                            BorderRadius.circular(AppTokens.radiusMd),
                        child: Image.asset(
                          'assets/images/logo.png',
                          width: 40,
                          height: 40,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => Container(
                            width: 40,
                            height: 40,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.accentColor(context),
                              borderRadius:
                                  BorderRadius.circular(AppTokens.radiusMd),
                            ),
                            child: const Text(
                              'O',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppTokens.space3),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'ORBIT',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.3,
                              ),
                            ),
                            Text(
                              'Produktivitas & Keuangan Pribadi',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: secondaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTokens.space6),
                  OrbitCard(
                    padding: const EdgeInsets.all(AppTokens.space5),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_mode != 'forgot') ...[
                          SegmentedButton<String>(
                            showSelectedIcon: false,
                            segments: const [
                              ButtonSegment(
                                value: 'login',
                                label: Text('Masuk'),
                              ),
                              ButtonSegment(
                                value: 'signup',
                                label: Text('Daftar Baru'),
                              ),
                            ],
                            selected: {_mode},
                            onSelectionChanged: (selection) {
                              setState(() {
                                _mode = selection.first;
                                _error = null;
                                _successMessage = null;
                              });
                            },
                          ),
                          const SizedBox(height: AppTokens.space4),
                        ] else ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Reset Kata Sandi',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    _mode = 'login';
                                    _error = null;
                                    _successMessage = null;
                                  });
                                },
                                child: const Text('Kembali Masuk'),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppTokens.space3),
                        ],

                        if (_error != null) ...[
                          Container(
                            padding: const EdgeInsets.all(AppTokens.space3),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppColors.expenseSubtleDark
                                  : AppColors.expenseSubtleLight,
                              borderRadius:
                                  BorderRadius.circular(AppTokens.radiusMd),
                              border: Border.all(
                                color: AppColors.expenseColor(context)
                                    .withValues(alpha: 0.4),
                              ),
                            ),
                            child: Text(
                              _error!,
                              style: TextStyle(
                                color: AppColors.expenseColor(context),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(height: AppTokens.space3),
                        ],

                        if (_successMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.all(AppTokens.space3),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppColors.incomeSubtleDark
                                  : AppColors.incomeSubtleLight,
                              borderRadius:
                                  BorderRadius.circular(AppTokens.radiusMd),
                              border: Border.all(
                                color: AppColors.incomeColor(context)
                                    .withValues(alpha: 0.4),
                              ),
                            ),
                            child: Text(
                              _successMessage!,
                              style: TextStyle(
                                color: AppColors.incomeColor(context),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(height: AppTokens.space3),
                        ],

                        const Text(
                          'Alamat Email',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: AppTokens.space1),
                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            hintText: 'nama@email.com',
                            prefixIcon: Icon(Icons.email_outlined, size: 18),
                          ),
                        ),

                        if (_mode != 'forgot') ...[
                          const SizedBox(height: AppTokens.space3),
                          Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              const Text(
                                'Kata Sandi',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (_mode == 'login')
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      _mode = 'forgot';
                                      _error = null;
                                      _successMessage = null;
                                    });
                                  },
                                  style: TextButton.styleFrom(
                                    minimumSize: const Size(
                                      AppTokens.minTouchTarget,
                                      AppTokens.minTouchTarget,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: AppTokens.space2,
                                    ),
                                  ),
                                  child: const Text(
                                    'Lupa kata sandi?',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: AppTokens.space1),
                          TextField(
                            controller: _passwordController,
                            obscureText: true,
                            decoration: const InputDecoration(
                              hintText: 'Minimal 8 karakter',
                              prefixIcon: Icon(Icons.lock_outline, size: 18),
                            ),
                          ),
                        ],

                        const SizedBox(height: AppTokens.space4),
                        SizedBox(
                          height: AppTokens.minTouchTarget,
                          child: FilledButton(
                            onPressed: _loading ? null : _submit,
                            child: Text(
                              _loading
                                  ? 'Memproses...'
                                  : _mode == 'forgot'
                                      ? 'Kirim Tautan Pemulihan'
                                      : _mode == 'signup'
                                          ? 'Buat Akun Orbit'
                                          : 'Masuk ke Orbit',
                            ),
                          ),
                        ),

                        if (_mode != 'forgot') ...[
                          const SizedBox(height: AppTokens.space4),
                          Row(
                            children: [
                              const Expanded(child: Divider()),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppTokens.space3,
                                ),
                                child: Text(
                                  'ATAU',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: secondaryColor,
                                  ),
                                ),
                              ),
                              const Expanded(child: Divider()),
                            ],
                          ),
                          const SizedBox(height: AppTokens.space4),
                          SizedBox(
                            height: AppTokens.minTouchTarget,
                            child: OutlinedButton.icon(
                              onPressed:
                                  _googleLoading ? null : _signInWithGoogle,
                              icon: const Icon(Icons.account_circle_outlined,
                                  size: 18),
                              label: Text(
                                _googleLoading
                                    ? 'Menghubungkan...'
                                    : 'Lanjutkan dengan Google',
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
          ),
        ),
      ),
    );
  }
}
