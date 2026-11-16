import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_app/core/constants/app_colors.dart';
import 'package:orbit_app/core/database/database.dart';
import 'package:orbit_app/core/services/home_widget_bridge.dart';
import 'package:orbit_app/core/services/privacy_and_lock_service.dart';
import 'package:orbit_app/core/services/theme_controller.dart';
import 'package:orbit_app/core/widgets/today_command_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PrivacyModeController.instance.setEnabled(false);
    await PrivacyModeController.instance.setHideWidgetBalance(false);
    await OrbitThemeController.instance.setAccent(OrbitAccent.ocean);
  });

  test('OrbitThemeController mengubah aksen & menyertakannya dalam HomeWidgetSnapshot', () async {
    final db = AppDatabase.forExecutor(NativeDatabase.memory());
    addTearDown(db.close);

    await OrbitThemeController.instance.setAccent(OrbitAccent.emerald);
    expect(OrbitThemeController.instance.accent, OrbitAccent.emerald);

    await db.into(db.localRecurringBills).insert(
          LocalRecurringBillsCompanion.insert(
            id: 'bill-1',
            workspaceId: 'ws-1',
            name: 'Internet Fiber',
            amount: 350000,
            categoryId: 'cat-1',
            accountId: 'acc-1',
          ),
        );

    final snap = await HomeWidgetBridge.buildSnapshotFromDatabase(db);
    expect(snap.accentId, 'emerald');
    expect(snap.activeBillCount, 1);
    expect(
      HomeWidgetBridge.parseQuickAddTypeFromUri(
        Uri.parse('io.supabase.orbit://quick-add?type=event'),
      ),
      'event',
    );
  });

  testWidgets('TodayHeroCommandCard, TodayFocusTimerCard, dan TodayPlanningHubCard interaktif', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(accent: OrbitAccent.violet),
        home: Scaffold(
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const TodayHeroCommandCard(
                doneTasks: 2,
                totalTasks: 4,
                todayEventsCount: 3,
                todayFocusMinutes: 45,
                todayNetCashflow: 120000,
              ),
              const SizedBox(height: 12),
              TodayFocusTimerCard(
                activeTasks: const [
                  {'id': 't1', 'title': 'Desain Dashboard Orbit'},
                ],
                selectedTaskId: 't1',
              ),
              const SizedBox(height: 12),
              TodayPlanningHubCard(
                bills: const [],
                budgets: const [],
                goals: const [],
                spentByCategory: const {},
                categoryNames: const {},
                onMutated: () {},
              ),
            ],
          ),
        ),
      ),
    );

    await tester.pump();
    expect(find.text('50%'), findsOneWidget);
    expect(find.text('2/4 Tugas • 45 mnt Fokus'), findsOneWidget);
    expect(find.text('Focus Timer'), findsOneWidget);
    expect(find.text('25:00'), findsOneWidget);

    await tester.tap(find.text('Stopwatch'));
    await tester.pump();
    expect(find.text('00:00'), findsOneWidget);

    await tester.tap(find.text('Anggaran (0)'));
    await tester.pump();
    expect(find.text('Belum ada anggaran bulanan.'), findsOneWidget);
  });
}
