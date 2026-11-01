import 'package:flutter/material.dart';
import 'package:orbit_app/core/constants/app_colors.dart';
import 'package:orbit_app/features/today/today_screen.dart';
import 'package:orbit_app/features/schedule/schedule_screen.dart';
import 'package:orbit_app/features/tasks/tasks_screen.dart';
import 'package:orbit_app/features/projects/projects_screen.dart';
import 'package:orbit_app/features/transactions/transactions_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final _screens = const [
    TodayScreen(),
    ScheduleScreen(),
    TasksScreen(),
    ProjectsScreen(),
    TransactionsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: Theme.of(context).dividerColor, width: 1),
          ),
        ),
        child: NavigationBar(
          height: 68,
          backgroundColor: Theme.of(context).cardColor,
          indicatorColor: AppColors.brandIndigo.withValues(alpha: 0.16),
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.today_outlined),
              selectedIcon: Icon(Icons.today, color: AppColors.brandIndigo),
              label: 'Hari Ini',
            ),
            NavigationDestination(
              icon: Icon(Icons.calendar_month_outlined),
              selectedIcon: Icon(Icons.calendar_month, color: AppColors.brandIndigo),
              label: 'Jadwal',
            ),
            NavigationDestination(
              icon: Icon(Icons.check_box_outlined),
              selectedIcon: Icon(Icons.check_box, color: AppColors.brandIndigo),
              label: 'Tugas',
            ),
            NavigationDestination(
              icon: Icon(Icons.business_center_outlined),
              selectedIcon: Icon(Icons.business_center, color: AppColors.brandIndigo),
              label: 'Proyek',
            ),
            NavigationDestination(
              icon: Icon(Icons.account_balance_wallet_outlined),
              selectedIcon: Icon(Icons.account_balance_wallet, color: AppColors.brandIndigo),
              label: 'Keuangan',
            ),
          ],
        ),
      ),
    );
  }
}
