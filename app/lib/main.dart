import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:orbit_app/core/constants/app_colors.dart';
import 'package:orbit_app/core/database/database.dart';
import 'package:orbit_app/core/services/home_widget_bridge.dart';
import 'package:orbit_app/core/services/notification_service.dart';
import 'package:orbit_app/core/services/privacy_and_lock_service.dart';
import 'package:orbit_app/core/widgets/orbit_privacy_widgets.dart';
import 'package:orbit_app/features/auth/login_screen.dart';
import 'package:orbit_app/features/home/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await NotificationService.initialize();
  } catch (_) {}

  await PrivacyModeController.instance.load();
  await AppLockService.instance.init();
  PrivacyModeController.instance.registerSyncHook(() async {
    await HomeWidgetBridge.syncFromDatabase(AppDatabase.shared);
  });

  await Supabase.initialize(
    url: const String.fromEnvironment(
      'SUPABASE_URL',
      defaultValue: 'https://kpsfdqswoerzkicocvre.supabase.co',
    ),
    anonKey: const String.fromEnvironment(
      'SUPABASE_ANON_KEY',
      defaultValue:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imtwc2ZkcXN3b2VyemtpY29jdnJlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTM1MDE3NjQsImV4cCI6MjEwOTA3Nzc2NH0.FkCf95BO0rEWixYlbNVvWOBj72kdWFiaXRg444mdEYc',
    ),
  );

  runApp(const ProviderScope(child: OrbitApp()));
}

class OrbitApp extends StatelessWidget {
  const OrbitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Orbit',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: const _OrbitAuthRootGate(),
      onUnknownRoute: (_) => MaterialPageRoute<void>(
        builder: (_) => const _OrbitAuthRootGate(),
      ),
    );
  }
}

class _OrbitAuthRootGate extends StatelessWidget {
  const _OrbitAuthRootGate();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session =
            snapshot.data?.session ?? Supabase.instance.client.auth.currentSession;
        if (session != null) {
          return const OrbitAppLockGate(child: HomeScreen());
        }
        return const LoginScreen();
      },
    );
  }
}
