import 'dart:async';

import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:orbit_app/core/constants/app_colors.dart';
import 'package:orbit_app/core/database/database.dart';
import 'package:orbit_app/core/services/sync_service.dart';
import 'package:orbit_app/core/widgets/orbit_property_chip.dart';
import 'package:orbit_app/core/widgets/orbit_status_badge.dart';

class OrbitTimeTrackerBlock extends StatefulWidget {
  final String taskId;
  final int? estimateMinutes;
  final VoidCallback? onChanged;

  const OrbitTimeTrackerBlock({
    super.key,
    required this.taskId,
    this.estimateMinutes,
    this.onChanged,
  });

  @override
  State<OrbitTimeTrackerBlock> createState() => _OrbitTimeTrackerBlockState();
}

class _OrbitTimeTrackerBlockState extends State<OrbitTimeTrackerBlock> {
  static const int _pomodoroDefaultSeconds = 25 * 60;

  String _mode = 'pomodoro'; // pomodoro | stopwatch | manual
  bool _running = false;
  int _elapsedSeconds = 0;
  DateTime? _sessionStartedAt;
  Timer? _ticker;
  bool _saving = false;

  final TextEditingController _noteCtrl = TextEditingController();
  final TextEditingController _manualMinutesCtrl = TextEditingController(
    text: '30',
  );

  List<LocalTaskTimeLog> _logs = const [];

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _ticker = null;
    _noteCtrl.dispose();
    _manualMinutesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadLogs() async {
    try {
      final rows =
          await (AppDatabase.shared.select(AppDatabase.shared.localTaskTimeLogs)
                ..where(
                  (l) => l.taskId.equals(widget.taskId) & l.deletedAt.isNull(),
                )
                ..orderBy([(l) => drift.OrderingTerm.desc(l.startedAt)]))
              .get();
      if (!mounted) return;
      setState(() => _logs = rows);
    } catch (_) {
      // Abaikan jika widget sedang ditutup
    }
  }

  void _startTimer() {
    if (_running) return;
    _ticker?.cancel();
    _sessionStartedAt ??= DateTime.now().toUtc();
    setState(() => _running = true);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _elapsedSeconds++;
        if (_mode == 'pomodoro' && _elapsedSeconds >= _pomodoroDefaultSeconds) {
          _running = false;
          _ticker?.cancel();
        }
      });
    });
  }

  void _pauseTimer() {
    _ticker?.cancel();
    _ticker = null;
    if (!mounted) return;
    setState(() => _running = false);
  }

  void _resetTimer() {
    _ticker?.cancel();
    _ticker = null;
    if (!mounted) return;
    setState(() {
      _running = false;
      _elapsedSeconds = 0;
      _sessionStartedAt = null;
    });
  }

  void _switchMode(String nextMode) {
    if (_mode == nextMode) return;
    _pauseTimer();
    setState(() {
      _mode = nextMode;
      _elapsedSeconds = 0;
      _sessionStartedAt = null;
    });
  }

  Future<void> _saveActiveSession() async {
    final secondsToSave = _elapsedSeconds > 0
        ? _elapsedSeconds
        : (_mode == 'pomodoro' ? 60 : 0);
    if (secondsToSave <= 0 || _saving) return;

    _pauseTimer();
    setState(() => _saving = true);
    final endedAt = DateTime.now().toUtc();
    final startedAt =
        _sessionStartedAt ?? endedAt.subtract(Duration(seconds: secondsToSave));

    await SyncService.instance.createTaskTimeLog(
      taskId: widget.taskId,
      startedAt: startedAt,
      endedAt: endedAt,
      durationSeconds: secondsToSave,
      mode: _mode == 'pomodoro' ? 'pomodoro' : 'stopwatch',
      note: _noteCtrl.text,
    );

    if (!mounted) return;
    _noteCtrl.clear();
    setState(() {
      _saving = false;
      _elapsedSeconds = 0;
      _sessionStartedAt = null;
    });
    await _loadLogs();
    widget.onChanged?.call();
  }

  Future<void> _saveManualLog() async {
    final mins = int.tryParse(_manualMinutesCtrl.text.trim()) ?? 0;
    if (mins <= 0 || _saving) return;

    setState(() => _saving = true);
    final endedAt = DateTime.now().toUtc();
    final startedAt = endedAt.subtract(Duration(minutes: mins));

    await SyncService.instance.createTaskTimeLog(
      taskId: widget.taskId,
      startedAt: startedAt,
      endedAt: endedAt,
      durationSeconds: mins * 60,
      mode: 'manual',
      note: _noteCtrl.text,
    );

    if (!mounted) return;
    _noteCtrl.clear();
    setState(() => _saving = false);
    await _loadLogs();
    widget.onChanged?.call();
  }

  int get _totalLoggedSeconds {
    return _logs.fold<int>(0, (sum, l) => sum + l.durationSeconds);
  }

  @override
  Widget build(BuildContext context) {
    final loggedMinutes = (_totalLoggedSeconds / 60).round();
    final estMinutes = widget.estimateMinutes ?? 0;
    final displaySeconds = _mode == 'pomodoro'
        ? (_pomodoroDefaultSeconds - _elapsedSeconds).clamp(
            0,
            _pomodoroDefaultSeconds,
          )
        : _elapsedSeconds;

    return OrbitBlockContainer(
      title: 'Pelacak Waktu & Mode Fokus',
      trailing: OrbitStatusBadge(
        label: estMinutes > 0
            ? '${_formatShortMinutes(loggedMinutes)} / ${_formatShortMinutes(estMinutes)}'
            : _formatShortMinutes(loggedMinutes),
        variant: estMinutes > 0 && loggedMinutes > estMinutes
            ? OrbitBadgeVariant.warning
            : OrbitBadgeVariant.neutral,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: AppColors.subtleColor(context),
              borderRadius: BorderRadius.circular(AppTokens.radiusMd),
              border: Border.all(color: AppColors.borderColor(context)),
            ),
            child: Row(
              children: [
                _ModeTabButton(
                  label: 'Pomodoro',
                  selected: _mode == 'pomodoro',
                  onTap: () => _switchMode('pomodoro'),
                ),
                _ModeTabButton(
                  label: 'Stopwatch',
                  selected: _mode == 'stopwatch',
                  onTap: () => _switchMode('stopwatch'),
                ),
                _ModeTabButton(
                  label: 'Catat Manual',
                  selected: _mode == 'manual',
                  onTap: () => _switchMode('manual'),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTokens.space3),
          if (_mode != 'manual') ...[
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTokens.space4,
                vertical: AppTokens.space3,
              ),
              decoration: BoxDecoration(
                color: AppColors.subtleColor(context),
                borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                border: Border.all(color: AppColors.borderColor(context)),
              ),
              child: Column(
                children: [
                  Text(
                    _mode == 'pomodoro'
                        ? 'Sesi Fokus Pomodoro (25 menit)'
                        : 'Stopwatch Berjalan',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondaryColor(context),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _formatClock(displaySeconds),
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: _running
                          ? AppColors.primary
                          : AppColors.textPrimaryColor(context),
                    ),
                  ),
                  const SizedBox(height: AppTokens.space3),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _running ? _pauseTimer : _startTimer,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(
                            110,
                            AppTokens.minTouchTarget,
                          ),
                        ),
                        icon: Icon(
                          _running
                              ? Icons.pause_outlined
                              : Icons.play_arrow_outlined,
                          size: 18,
                        ),
                        label: Text(_running ? 'Jeda' : 'Mulai'),
                      ),
                      const SizedBox(width: AppTokens.space2),
                      OutlinedButton(
                        onPressed:
                            (_elapsedSeconds > 0 || _running) ? _resetTimer : null,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(84, AppTokens.minTouchTarget),
                        ),
                        child: const Text('Reset'),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTokens.space2),
                  TextField(
                    controller: _noteCtrl,
                    decoration: const InputDecoration(
                      isDense: true,
                      labelText: 'Catatan Sesi (Opsional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: AppTokens.space2),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed:
                          (_elapsedSeconds > 0 && !_saving)
                              ? _saveActiveSession
                              : null,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, AppTokens.minTouchTarget),
                      ),
                      icon: const Icon(Icons.save_outlined, size: 18),
                      label: Text(_saving ? 'Menyimpan...' : 'Simpan Sesi'),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            Row(
              children: [
                SizedBox(
                  width: 112,
                  child: TextField(
                    controller: _manualMinutesCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      isDense: true,
                      labelText: 'Durasi (mnt)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: AppTokens.space2),
                Expanded(
                  child: TextField(
                    controller: _noteCtrl,
                    decoration: const InputDecoration(
                      isDense: true,
                      labelText: 'Catatan Aktivitas',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTokens.space2),
            ElevatedButton.icon(
              onPressed: _saving ? null : _saveManualLog,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(0, AppTokens.minTouchTarget),
              ),
              icon: const Icon(Icons.add_task_outlined, size: 18),
              label: Text(_saving ? 'Menyimpan...' : 'Simpan Catatan Waktu'),
            ),
          ],
          if (_logs.isNotEmpty) ...[
            const SizedBox(height: AppTokens.space3),
            Text(
              'Riwayat Sesi (${_logs.length})',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondaryColor(context),
              ),
            ),
            const SizedBox(height: AppTokens.space1),
            for (final log in _logs.take(5))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(
                      log.mode == 'pomodoro'
                          ? Icons.timer_outlined
                          : (log.mode == 'manual'
                              ? Icons.edit_note_outlined
                              : Icons.av_timer_outlined),
                      size: 16,
                      color: AppColors.textMutedColor(context),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        log.note?.isNotEmpty == true
                            ? log.note!
                            : 'Sesi ${log.mode}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textPrimaryColor(context),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatDurationVerbose(log.durationSeconds),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        color: AppColors.textSecondaryColor(context),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Hapus log waktu',
                      constraints: const BoxConstraints(
                        minWidth: AppTokens.minTouchTarget,
                        minHeight: AppTokens.minTouchTarget,
                      ),
                      iconSize: 16,
                      onPressed: () async {
                        await SyncService.instance.deleteTaskTimeLog(log.id);
                        await _loadLogs();
                        widget.onChanged?.call();
                      },
                      icon: Icon(
                        Icons.close,
                        color: AppColors.textMutedColor(context),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  static String _formatClock(int totalSeconds) {
    final m = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  static String _formatShortMinutes(int mins) {
    if (mins < 60) return '$mins mnt';
    final h = mins ~/ 60;
    final rem = mins % 60;
    return rem == 0 ? '$h jam' : '${h}j ${rem}m';
  }

  static String _formatDurationVerbose(int seconds) {
    if (seconds < 60) return '${seconds}d';
    final mins = (seconds / 60).round();
    return _formatShortMinutes(mins);
  }
}

class _ModeTabButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ModeTabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
        child: Container(
          constraints: const BoxConstraints(minHeight: AppTokens.minTouchTarget),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.surfaceColor(context)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppTokens.radiusSm),
            border: selected
                ? Border.all(color: AppColors.borderColor(context))
                : null,
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected
                  ? AppColors.textPrimaryColor(context)
                  : AppColors.textSecondaryColor(context),
            ),
          ),
        ),
      ),
    );
  }
}
