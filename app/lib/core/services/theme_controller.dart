import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum OrbitAccent {
  ocean(
    id: 'ocean',
    label: 'Biru Orbit',
    lightPrimary: Color(0xFF0284C7),
    darkPrimary: Color(0xFF38BDF8),
    lightSubtle: Color(0xFFE0F2FE),
    darkSubtle: Color(0xFF0C4A6E),
    lightGradientEnd: Color(0xFF0369A1),
    darkGradientEnd: Color(0xFF0284C7),
  ),
  emerald(
    id: 'emerald',
    label: 'Zamrud',
    lightPrimary: Color(0xFF059669),
    darkPrimary: Color(0xFF34D399),
    lightSubtle: Color(0xFFD1FAE5),
    darkSubtle: Color(0xFF064E3B),
    lightGradientEnd: Color(0xFF047857),
    darkGradientEnd: Color(0xFF10B981),
  ),
  violet(
    id: 'violet',
    label: 'Violet',
    lightPrimary: Color(0xFF7C3AED),
    darkPrimary: Color(0xFFA78BFA),
    lightSubtle: Color(0xFFEDE9FE),
    darkSubtle: Color(0xFF3B0764),
    lightGradientEnd: Color(0xFF6D28D9),
    darkGradientEnd: Color(0xFF8B5CF6),
  ),
  amber(
    id: 'amber',
    label: 'Amber',
    lightPrimary: Color(0xFFD97706),
    darkPrimary: Color(0xFFFBBF24),
    lightSubtle: Color(0xFFFEF3C7),
    darkSubtle: Color(0xFF451A03),
    lightGradientEnd: Color(0xFFB45309),
    darkGradientEnd: Color(0xFFF59E0B),
  );

  final String id;
  final String label;
  final Color lightPrimary;
  final Color darkPrimary;
  final Color lightSubtle;
  final Color darkSubtle;
  final Color lightGradientEnd;
  final Color darkGradientEnd;

  const OrbitAccent({
    required this.id,
    required this.label,
    required this.lightPrimary,
    required this.darkPrimary,
    required this.lightSubtle,
    required this.darkSubtle,
    required this.lightGradientEnd,
    required this.darkGradientEnd,
  });

  static OrbitAccent fromId(String? id) {
    for (final item in OrbitAccent.values) {
      if (item.id == id) return item;
    }
    return OrbitAccent.ocean;
  }
}

class OrbitThemeController extends ChangeNotifier {
  OrbitThemeController._();
  static final OrbitThemeController instance = OrbitThemeController._();

  static const String _prefAccentKey = 'orbit_theme_accent';
  static const String _prefModeKey = 'orbit_theme_mode';

  OrbitAccent _accent = OrbitAccent.ocean;
  ThemeMode _themeMode = ThemeMode.system;
  Future<void> Function()? _onThemeSyncHook;

  OrbitAccent get accent => _accent;
  ThemeMode get themeMode => _themeMode;

  void registerSyncHook(Future<void> Function() hook) {
    _onThemeSyncHook = hook;
  }

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _accent = OrbitAccent.fromId(prefs.getString(_prefAccentKey));
      final modeStr = prefs.getString(_prefModeKey);
      _themeMode = switch (modeStr) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
      notifyListeners();
    } catch (_) {}
  }

  Future<void> setAccent(OrbitAccent next) async {
    if (_accent == next) return;
    _accent = next;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefAccentKey, next.id);
    } catch (_) {}
    await _onThemeSyncHook?.call();
  }

  Future<void> setThemeMode(ThemeMode next) async {
    if (_themeMode == next) return;
    _themeMode = next;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final val = switch (next) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      };
      await prefs.setString(_prefModeKey, val);
    } catch (_) {}
  }

  static Future<void> showPickerSheet(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => const _OrbitThemePickerSheet(),
    );
  }
}

class _OrbitThemePickerSheet extends StatelessWidget {
  const _OrbitThemePickerSheet();

  @override
  Widget build(BuildContext context) {
    final controller = OrbitThemeController.instance;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final currentAccent = controller.accent;
        final currentMode = controller.themeMode;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Tema & Aksen Command Center',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  'Sesuaikan suasana tampilan dan warna aksen untuk aplikasi & widget.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Mode Tampilan',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                SegmentedButton<ThemeMode>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: ThemeMode.system,
                      icon: Icon(Icons.brightness_auto_outlined, size: 16),
                      label: Text('Sistem'),
                    ),
                    ButtonSegment(
                      value: ThemeMode.light,
                      icon: Icon(Icons.light_mode_outlined, size: 16),
                      label: Text('Terang'),
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      icon: Icon(Icons.dark_mode_outlined, size: 16),
                      label: Text('Gelap'),
                    ),
                  ],
                  selected: {currentMode},
                  onSelectionChanged: (sel) {
                    controller.setThemeMode(sel.first);
                  },
                ),
                const SizedBox(height: 16),
                const Text(
                  'Warna Aksen Interaktif',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: OrbitAccent.values.map((item) {
                    final selected = item == currentAccent;
                    final swatch = isDark ? item.darkPrimary : item.lightPrimary;
                    return InkWell(
                      onTap: () => controller.setAccent(item),
                      borderRadius: BorderRadius.circular(12),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? swatch.withValues(alpha: 0.14)
                              : Theme.of(context).colorScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selected
                                ? swatch
                                : Theme.of(context).dividerColor,
                            width: selected ? 1.8 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                color: swatch,
                                shape: BoxShape.circle,
                              ),
                              child: selected
                                  ? const Icon(
                                      Icons.check,
                                      size: 12,
                                      color: Colors.white,
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              item.label,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
