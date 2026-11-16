import 'dart:io';

import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:orbit_app/core/constants/app_colors.dart';
import 'package:orbit_app/core/database/database.dart';
import 'package:orbit_app/core/services/ics_calendar_service.dart';
import 'package:orbit_app/core/services/sync_service.dart';
import 'package:orbit_app/core/widgets/orbit_widgets.dart';
import 'package:orbit_app/features/tasks/orbit_task_detail_page.dart';
import 'package:uuid/uuid.dart';

class ScheduleScreen extends StatefulWidget {
  final bool embedded;
  final bool forceLoading;
  final bool forceError;

  const ScheduleScreen({
    super.key,
    this.embedded = false,
    this.forceLoading = false,
    this.forceError = false,
  });

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  String _viewMode = 'daftar'; // daftar | kalender | linimasa
  String _kindFilter = 'semua'; // semua | intern | freelance | kuliah | pribadi
  DateTime _selectedDate = DateTime.now();
  DateTime _focusedMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    1,
  );

  bool _loading = true;
  String? _errorMessage;

  List<LocalEvent> _events = const [];
  List<LocalTask> _dueTasks = const [];
  List<LocalCalendarConnection> _calendarConnections = const [];
  Set<String> _conflictingEventIds = const {};

  @override
  void initState() {
    super.initState();
    if (widget.forceLoading) {
      _loading = true;
    } else if (widget.forceError) {
      _loading = false;
      _errorMessage = 'Gagal memuat data jadwal lokal.';
    } else {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final db = AppDatabase.shared;
      final events =
          await (db.select(db.localEvents)
                ..where((e) => e.deletedAt.isNull())
                ..orderBy([(e) => drift.OrderingTerm.asc(e.startsAt)]))
              .get();

      final tasks =
          await (db.select(db.localTasks)
                ..where((t) => t.deletedAt.isNull() & t.dueAt.isNotNull())
                ..orderBy([(t) => drift.OrderingTerm.asc(t.dueAt)]))
              .get();

      final connections = await db.select(db.localCalendarConnections).get();

      final conflicts = _detectConflicts(events);

      if (!mounted) return;
      setState(() {
        _events = events;
        _dueTasks = tasks;
        _calendarConnections = connections;
        _conflictingEventIds = conflicts;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = 'Gagal memuat jadwal: $e';
      });
    }
  }

  Set<String> _detectConflicts(List<LocalEvent> events) {
    final conflicts = <String>{};
    final timed = events.where((e) => !e.allDay).toList();
    for (var i = 0; i < timed.length; i++) {
      for (var j = i + 1; j < timed.length; j++) {
        final a = timed[i];
        final b = timed[j];
        if (a.startsAt.isBefore(b.endsAt) && b.startsAt.isBefore(a.endsAt)) {
          conflicts.add(a.id);
          conflicts.add(b.id);
        }
      }
    }
    return conflicts;
  }

  List<LocalEvent> get _filteredEvents {
    if (_kindFilter == 'semua') return _events;
    return _events.where((e) => e.kind == _kindFilter).toList();
  }

  List<LocalTask> get _filteredTasks {
    if (_kindFilter == 'semua') return _dueTasks;
    return _dueTasks.where((t) => t.kind == _kindFilter).toList();
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _eventOccursOnDay(LocalEvent e, DateTime day) {
    final dayStart = DateTime(day.year, day.month, day.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    final localStart = e.startsAt.toLocal();
    final localEnd = e.endsAt.toLocal();
    return localStart.isBefore(dayEnd) &&
        (localEnd.isAfter(dayStart) || _isSameDay(localStart, dayStart));
  }

  List<LocalEvent> _eventsForDay(DateTime day) {
    return _filteredEvents.where((e) => _eventOccursOnDay(e, day)).toList()
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
  }

  List<LocalTask> _tasksForDay(DateTime day) {
    return _filteredTasks
        .where((t) => t.dueAt != null && _isSameDay(t.dueAt!.toLocal(), day))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final hasShell = !widget.embedded && OrbitShellScope.maybeOf(context) != null;

    final body = Column(
      children: [
        _buildTopControls(context),
        Expanded(child: _buildBody(context)),
      ],
    );

    if (widget.embedded) {
      return Container(
        color: AppColors.canvasColor(context),
        child: body,
      );
    }

    return Scaffold(
      backgroundColor: AppColors.canvasColor(context),
      appBar: AppBar(
        leading: hasShell ? const OrbitShellMenuButton() : null,
        title: const Text('Agenda'),
        actions: [
          if (hasShell) const OrbitShellSearchButton(),
          IconButton(
            tooltip: 'Sinkron Google Calendar & .ics',
            constraints: const BoxConstraints(
              minWidth: AppTokens.minTouchTarget,
              minHeight: AppTokens.minTouchTarget,
            ),
            onPressed: _showCalendarSyncSheet,
            icon: const Icon(Icons.sync_outlined),
          ),
          IconButton(
            tooltip: 'Tambah Acara',
            constraints: const BoxConstraints(
              minWidth: AppTokens.minTouchTarget,
              minHeight: AppTokens.minTouchTarget,
            ),
            onPressed: _showAddEventSheet,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: body,
    );
  }

  Widget _buildTopControls(BuildContext context) {
    final activeConn = _calendarConnections.where((c) => c.enabled).toList();
    final syncConnected = activeConn.isNotEmpty;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppTokens.space4,
        AppTokens.space3,
        AppTokens.space4,
        AppTokens.space2,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceColor(context),
        border: Border(
          bottom: BorderSide(color: AppColors.borderColor(context)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OrbitViewSwitcher(
            activeViewMode: _viewMode,
            onChanged: (mode) => setState(() => _viewMode = mode),
            options: const [
              OrbitViewOption(
                id: 'daftar',
                label: 'Daftar',
                icon: Icons.view_list_outlined,
              ),
              OrbitViewOption(
                id: 'kalender',
                label: 'Kalender',
                icon: Icons.calendar_month_outlined,
              ),
              OrbitViewOption(
                id: 'linimasa',
                label: 'Linimasa',
                icon: Icons.view_timeline_outlined,
              ),
            ],
          ),
          const SizedBox(height: AppTokens.space2),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _ActionPillButton(
                  icon: Icons.sync_outlined,
                  label: syncConnected ? 'GCal Terhubung' : 'Sinkron / .ics',
                  highlighted: syncConnected,
                  onTap: _showCalendarSyncSheet,
                ),
                const SizedBox(width: AppTokens.space2),
                _ActionPillButton(
                  icon: Icons.add,
                  label: 'Acara Baru',
                  highlighted: false,
                  onTap: _showAddEventSheet,
                ),
                const SizedBox(width: AppTokens.space2),
                for (final kind in const [
                  ('semua', 'Semua'),
                  ('intern', 'Intern'),
                  ('freelance', 'Freelance'),
                  ('kuliah', 'Kuliah'),
                  ('pribadi', 'Pribadi'),
                ]) ...[
                  _FilterChipButton(
                    label: kind.$2,
                    selected: _kindFilter == kind.$1,
                    onTap: () => setState(() => _kindFilter = kind.$1),
                  ),
                  const SizedBox(width: AppTokens.space1),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return ListView(
        padding: const EdgeInsets.all(AppTokens.space4),
        children: const [
          OrbitSkeleton(height: 68),
          SizedBox(height: AppTokens.space3),
          OrbitSkeleton(height: 84),
          SizedBox(height: AppTokens.space3),
          OrbitSkeleton(height: 84),
        ],
      );
    }

    if (_errorMessage != null) {
      return OrbitErrorState(message: _errorMessage!, onRetry: _loadData);
    }

    switch (_viewMode) {
      case 'kalender':
        return _buildCalendarView(context);
      case 'linimasa':
        return _buildTimelineView(context);
      default:
        return _buildListView(context);
    }
  }

  Widget _buildListView(BuildContext context) {
    final events = _filteredEvents;
    final tasks = _filteredTasks;

    if (events.isEmpty && tasks.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          children: [
            const SizedBox(height: 36),
            OrbitEmptyState(
              icon: Icons.event_note_outlined,
              title: 'Belum ada agenda terjadwal',
              description:
                  'Tambahkan acara baru atau impor jadwal dari file .ics Google Calendar.',
              actionLabel: 'Tambah Acara',
              onAction: _showAddEventSheet,
            ),
          ],
        ),
      );
    }

    // Gabungkan acara & pengingat tugas terurut kronologis
    final timelineEntries = <_AgendaEntry>[];
    for (final e in events) {
      timelineEntries.add(
        _AgendaEntry(sortTime: e.startsAt.toLocal(), event: e),
      );
    }
    for (final t in tasks) {
      if (t.dueAt != null) {
        timelineEntries.add(
          _AgendaEntry(sortTime: t.dueAt!.toLocal(), task: t),
        );
      }
    }
    timelineEntries.sort((a, b) => a.sortTime.compareTo(b.sortTime));

    final conflictCount = events
        .where((e) => _conflictingEventIds.contains(e.id))
        .length;

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(AppTokens.space4),
        children: [
          _CalendarSyncBanner(
            connections: _calendarConnections,
            onTapSync: _showCalendarSyncSheet,
          ),
          if (conflictCount > 0) ...[
            const SizedBox(height: AppTokens.space3),
            _ConflictBanner(conflictCount: conflictCount),
          ],
          const SizedBox(height: AppTokens.space3),
          ...timelineEntries.map((entry) {
            if (entry.event != null) {
              final e = entry.event!;
              return Padding(
                padding: const EdgeInsets.only(bottom: AppTokens.space2),
                child: _NotionEventCard(
                  event: e,
                  hasConflict: _conflictingEventIds.contains(e.id),
                  onTap: () => _showEventDetailSheet(e),
                ),
              );
            }
            final t = entry.task!;
            return Padding(
              padding: const EdgeInsets.only(bottom: AppTokens.space2),
              child: _TaskDeadlineCard(
                task: t,
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => OrbitTaskDetailPage(taskId: t.id),
                    ),
                  );
                  _loadData();
                },
              ),
            );
          }),
          const SizedBox(height: AppTokens.space8),
        ],
      ),
    );
  }

  Widget _buildCalendarView(BuildContext context) {
    final firstOfMonth = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final daysInMonth = DateUtils.getDaysInMonth(
      _focusedMonth.year,
      _focusedMonth.month,
    );
    // Monday = 1 -> offset 0, Sunday = 7 -> offset 6
    final leadingEmpty = (firstOfMonth.weekday - 1) % 7;
    final totalCells = leadingEmpty + daysInMonth;
    final rows = (totalCells / 7).ceil();

    final dayEvents = _eventsForDay(_selectedDate);
    final dayTasks = _tasksForDay(_selectedDate);

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(AppTokens.space4),
        children: [
          OrbitCard(
            padding: const EdgeInsets.all(AppTokens.space3),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Bulan Sebelumnya',
                      constraints: const BoxConstraints(
                        minWidth: AppTokens.minTouchTarget,
                        minHeight: AppTokens.minTouchTarget,
                      ),
                      onPressed: () {
                        setState(() {
                          _focusedMonth = DateTime(
                            _focusedMonth.year,
                            _focusedMonth.month - 1,
                            1,
                          );
                        });
                      },
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Expanded(
                      child: Text(
                        _formatMonthYear(_focusedMonth),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimaryColor(context),
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        final now = DateTime.now();
                        setState(() {
                          _selectedDate = now;
                          _focusedMonth = DateTime(now.year, now.month, 1);
                        });
                      },
                      style: TextButton.styleFrom(
                        minimumSize: const Size(64, AppTokens.minTouchTarget),
                      ),
                      child: const Text('Hari Ini'),
                    ),
                    IconButton(
                      tooltip: 'Bulan Berikutnya',
                      constraints: const BoxConstraints(
                        minWidth: AppTokens.minTouchTarget,
                        minHeight: AppTokens.minTouchTarget,
                      ),
                      onPressed: () {
                        setState(() {
                          _focusedMonth = DateTime(
                            _focusedMonth.year,
                            _focusedMonth.month + 1,
                            1,
                          );
                        });
                      },
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
                const SizedBox(height: AppTokens.space1),
                Row(
                  children: const [
                    'Sen',
                    'Sel',
                    'Rab',
                    'Kam',
                    'Jum',
                    'Sab',
                    'Min',
                  ].map((label) {
                    return Expanded(
                      child: Center(
                        child: Text(
                          label,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: AppTokens.space1),
                for (var r = 0; r < rows; r++)
                  Row(
                    children: [
                      for (var c = 0; c < 7; c++)
                        _buildCalendarDayCell(
                          context,
                          r * 7 + c - leadingEmpty + 1,
                          daysInMonth,
                        ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppTokens.space4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Agenda ${_formatDateIndo(_selectedDate)}',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimaryColor(context),
                  ),
                ),
              ),
              const SizedBox(width: AppTokens.space2),
              Flexible(
                child: Text(
                  '${dayEvents.length} acara, ${dayTasks.length} tugas',
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontSize: 12,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: AppColors.textMutedColor(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.space2),
          if (dayEvents.isEmpty && dayTasks.isEmpty)
            OrbitCard(
              padding: const EdgeInsets.all(AppTokens.space4),
              child: Row(
                children: [
                  Icon(
                    Icons.event_available_outlined,
                    size: 20,
                    color: AppColors.textMutedColor(context),
                  ),
                  const SizedBox(width: AppTokens.space3),
                  Expanded(
                    child: Text(
                      'Tidak ada acara atau tenggat tugas pada tanggal ini.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondaryColor(context),
                      ),
                    ),
                  ),
                ],
              ),
            )
          else ...[
            for (final e in dayEvents) ...[
              _NotionEventCard(
                event: e,
                hasConflict: _conflictingEventIds.contains(e.id),
                onTap: () => _showEventDetailSheet(e),
              ),
              const SizedBox(height: AppTokens.space2),
            ],
            for (final t in dayTasks) ...[
              _TaskDeadlineCard(
                task: t,
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => OrbitTaskDetailPage(taskId: t.id),
                    ),
                  );
                  _loadData();
                },
              ),
              const SizedBox(height: AppTokens.space2),
            ],
          ],
          const SizedBox(height: AppTokens.space8),
        ],
      ),
    );
  }

  Widget _buildCalendarDayCell(
    BuildContext context,
    int dayNum,
    int daysInMonth,
  ) {
    if (dayNum < 1 || dayNum > daysInMonth) {
      return const Expanded(child: SizedBox(height: AppTokens.minTouchTarget));
    }

    final cellDate = DateTime(_focusedMonth.year, _focusedMonth.month, dayNum);
    final isToday = _isSameDay(cellDate, DateTime.now());
    final isSelected = _isSameDay(cellDate, _selectedDate);
    final hasEvent = _eventsForDay(cellDate).isNotEmpty;
    final hasTask = _tasksForDay(cellDate).isNotEmpty;

    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedDate = cellDate),
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        child: Container(
          height: AppTokens.minTouchTarget,
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary
                : (isToday
                    ? AppColors.subtleColor(context)
                    : Colors.transparent),
            borderRadius: BorderRadius.circular(AppTokens.radiusMd),
            border: isToday && !isSelected
                ? Border.all(color: AppColors.primary)
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$dayNum',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected || isToday
                      ? FontWeight.w700
                      : FontWeight.w500,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: isSelected
                      ? Colors.white
                      : AppColors.textPrimaryColor(context),
                ),
              ),
              const SizedBox(height: 3),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (hasEvent)
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected ? Colors.white : AppColors.primary,
                      ),
                    ),
                  if (hasEvent && hasTask) const SizedBox(width: 3),
                  if (hasTask)
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected
                            ? Colors.white70
                            : AppColors.warningColor(context),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimelineView(BuildContext context) {
    final dayEvents = _eventsForDay(_selectedDate);
    final dayTasks = _tasksForDay(_selectedDate);
    final allDayEvents = dayEvents.where((e) => e.allDay).toList();
    final timedEvents = dayEvents.where((e) => !e.allDay).toList();

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(AppTokens.space4),
        children: [
          OrbitCard(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTokens.space2,
              vertical: AppTokens.space1,
            ),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Hari Sebelumnya',
                  constraints: const BoxConstraints(
                    minWidth: AppTokens.minTouchTarget,
                    minHeight: AppTokens.minTouchTarget,
                  ),
                  onPressed: () {
                    setState(() {
                      _selectedDate = _selectedDate.subtract(
                        const Duration(days: 1),
                      );
                    });
                  },
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        'Linimasa Harian (06:00 - 22:00)',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textMutedColor(context),
                        ),
                      ),
                      Text(
                        _formatDateIndo(_selectedDate),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimaryColor(context),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Hari Berikutnya',
                  constraints: const BoxConstraints(
                    minWidth: AppTokens.minTouchTarget,
                    minHeight: AppTokens.minTouchTarget,
                  ),
                  onPressed: () {
                    setState(() {
                      _selectedDate = _selectedDate.add(
                        const Duration(days: 1),
                      );
                    });
                  },
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),
          if (allDayEvents.isNotEmpty) ...[
            const SizedBox(height: AppTokens.space3),
            Text(
              'Sepanjang Hari',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondaryColor(context),
              ),
            ),
            const SizedBox(height: AppTokens.space1),
            for (final e in allDayEvents) ...[
              _NotionEventCard(
                event: e,
                hasConflict: false,
                onTap: () => _showEventDetailSheet(e),
              ),
              const SizedBox(height: AppTokens.space2),
            ],
          ],
          const SizedBox(height: AppTokens.space3),
          OrbitCard(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTokens.space3,
              vertical: AppTokens.space2,
            ),
            child: Column(
              children: [
                for (var hour = 6; hour <= 22; hour++)
                  _buildTimelineHourRow(
                    context,
                    hour: hour,
                    timedEvents: timedEvents,
                    dayTasks: dayTasks,
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppTokens.space8),
        ],
      ),
    );
  }

  Widget _buildTimelineHourRow(
    BuildContext context, {
    required int hour,
    required List<LocalEvent> timedEvents,
    required List<LocalTask> dayTasks,
  }) {
    final slotStart = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      hour,
      0,
    );
    final slotEnd = slotStart.add(const Duration(hours: 1));

    final startingEvents = timedEvents.where((e) {
      final start = e.startsAt.toLocal();
      final end = e.endsAt.toLocal();
      if (_isSameDay(start, _selectedDate)) {
        return start.hour == hour;
      }
      // Acara lintas hari dimulai jam 06:00 pada hari berikutnya
      return hour == 6 && start.isBefore(slotStart) && end.isAfter(slotStart);
    }).toList();

    final hourTasks = dayTasks.where((t) {
      final due = t.dueAt?.toLocal();
      if (due == null) return false;
      if (t.dueIsDateOnly) return hour == 9;
      return due.hour == hour;
    }).toList();

    final hourLabel = '${hour.toString().padLeft(2, '0')}:00';
    final hasItems = startingEvents.isNotEmpty || hourTasks.isNotEmpty;

    return Container(
      constraints: BoxConstraints(minHeight: hasItems ? 56 : 36),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: AppColors.borderColor(context),
            width: 0.75,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 50,
            child: Text(
              hourLabel,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                fontFeatures: const [FontFeature.tabularFigures()],
                color: AppColors.textMutedColor(context),
              ),
            ),
          ),
          Expanded(
            child: !hasItems
                ? const SizedBox(height: 20)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final e in startingEvents)
                        _TimelineEventBlock(
                          event: e,
                          hasConflict: _conflictingEventIds.contains(e.id),
                          overlapsPrevious: timedEvents.any(
                            (other) =>
                                other.id != e.id &&
                                other.startsAt.isBefore(slotEnd) &&
                                other.endsAt.isAfter(slotStart) &&
                                e.startsAt.isBefore(other.endsAt) &&
                                other.startsAt.isBefore(e.endsAt),
                          ),
                          onTap: () => _showEventDetailSheet(e),
                        ),
                      for (final t in hourTasks)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: _TaskDeadlineCard(
                            task: t,
                            onTap: () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      OrbitTaskDetailPage(taskId: t.id),
                                ),
                              );
                              _loadData();
                            },
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _showCalendarSyncSheet() async {
    final icsController = TextEditingController();
    var importKind = 'pribadi';
    String? feedbackMsg;
    String? exportedIcsPreview;
    List<IcsParsedEvent> parsedPreview = const [];

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final activeConns = _calendarConnections;
            final gcalConnected = activeConns.any((c) => c.enabled);

            Future<void> handleExportIcs() async {
              final ics = IcsCalendarService.exportEventsToIcs(_events);
              await Clipboard.setData(ClipboardData(text: ics));
              String? tempFilePath;
              try {
                final file = File(
                  '${Directory.systemTemp.path}${Platform.pathSeparator}'
                  'orbit_agenda_${DateTime.now().millisecondsSinceEpoch}.ics',
                );
                await file.writeAsString(ics);
                tempFilePath = file.path;
              } catch (_) {
                tempFilePath = null;
              }
              setSheetState(() {
                exportedIcsPreview = ics;
                feedbackMsg = tempFilePath != null
                    ? 'Ekspor .ics berhasil disalin ke clipboard dan disimpan di: $tempFilePath'
                    : 'Ekspor .ics berhasil disalin ke clipboard.';
              });
            }

            Future<void> handleImportIcs() async {
              final wsId = (await SyncService.instance.getWorkspaceId()) ?? 'personal-ws';
              final parsed = IcsCalendarService.parseIcsEvents(
                icsController.text,
                workspaceId: wsId,
              );
              if (parsed.isEmpty) {
                setSheetState(() {
                  feedbackMsg =
                      'Tidak ada VEVENT valid ditemukan pada teks .ics tersebut.';
                });
                return;
              }

              final db = AppDatabase.shared;
              var importedCount = 0;
              for (final item in parsed) {
                final existing =
                    await (db.select(db.localEvents)..where(
                          (e) =>
                              e.workspaceId.equals(wsId) &
                              e.externalProvider.equals('google') &
                              e.externalEventId.equals(item.uid) &
                              e.deletedAt.isNull(),
                        ))
                        .getSingleOrNull();
                final id = existing?.id ?? const Uuid().v4();
                await db.into(db.localEvents).insertOnConflictUpdate(
                  item.toLocalEventCompanion(
                    id: id,
                    workspaceId: wsId,
                    kindOverride: importKind,
                  ),
                );
                await SyncService.instance.pushRecord(
                  tableName: 'events',
                  recordId: id,
                  action: existing == null ? 'insert' : 'update',
                  payload: item.toSyncPayload(
                    id: id,
                    workspaceId: wsId,
                    kindOverride: importKind,
                  ),
                );
                importedCount++;
              }

              if (!ctx.mounted) return;
              Navigator.of(ctx).pop();
              await _loadData();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '$importedCount acara .ics disimpan ke Agenda dan diantrekan untuk sinkronisasi.',
                    ),
                  ),
                );
              }
            }

            return Padding(
              padding: EdgeInsets.fromLTRB(
                AppTokens.space4,
                AppTokens.space4,
                AppTokens.space4,
                MediaQuery.of(ctx).viewInsets.bottom + AppTokens.space4,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Sinkron Google Calendar & .ics',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimaryColor(ctx),
                      ),
                    ),
                    const SizedBox(height: AppTokens.space2),
                    Container(
                      padding: const EdgeInsets.all(AppTokens.space3),
                      decoration: BoxDecoration(
                        color: AppColors.subtleColor(ctx),
                        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                        border: Border.all(color: AppColors.borderColor(ctx)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: AppTokens.space2,
                            runSpacing: AppTokens.space1,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              OrbitStatusBadge(
                                label: gcalConnected
                                    ? 'Google Calendar Aktif'
                                    : 'Belum Terhubung',
                                variant: gcalConnected
                                    ? OrbitBadgeVariant.income
                                    : OrbitBadgeVariant.warning,
                              ),
                              Text(
                                gcalConnected
                                    ? activeConns.first.externalCalendarId
                                    : 'Mode Offline / .ics Manual',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondaryColor(ctx),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppTokens.space2),
                          Text(
                            'OAuth sinkronisasi dua arah Google Calendar dikonfigurasi di Orbit Web. '
                            'Di perangkat ini Anda dapat mengekspor dan mengimpor file kalender .ics (RFC 5545) secara langsung.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondaryColor(ctx),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppTokens.space3),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: handleExportIcs,
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(
                                0,
                                AppTokens.minTouchTarget,
                              ),
                            ),
                            icon: const Icon(Icons.download_outlined, size: 18),
                            label: const Text('Ekspor .ics'),
                          ),
                        ),
                        const SizedBox(width: AppTokens.space2),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final data = await Clipboard.getData(
                                Clipboard.kTextPlain,
                              );
                              final text = data?.text ?? '';
                              final wsId =
                                  (await SyncService.instance.getWorkspaceId()) ?? 'personal-ws';
                              setSheetState(() {
                                icsController.text = text;
                                parsedPreview = IcsCalendarService.parseIcsEvents(
                                  text,
                                  workspaceId: wsId,
                                );
                              });
                            },
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(
                                0,
                                AppTokens.minTouchTarget,
                              ),
                            ),
                            icon: const Icon(
                              Icons.content_paste_outlined,
                              size: 18,
                            ),
                            label: const Text('Tempel'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTokens.space2),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () async {
                          final wsId =
                              (await SyncService.instance.getWorkspaceId()) ?? 'personal-ws';
                          setSheetState(() {
                            icsController.text =
                                IcsCalendarService.sampleGoogleCalendarIcs;
                            parsedPreview = IcsCalendarService.parseIcsEvents(
                              icsController.text,
                              workspaceId: wsId,
                            );
                          });
                        },
                        style: TextButton.styleFrom(
                          minimumSize: const Size(0, AppTokens.minTouchTarget),
                        ),
                        icon: const Icon(Icons.auto_awesome_outlined, size: 16),
                        label: const Text('Muat Contoh .ics Google Calendar'),
                      ),
                    ),
                    TextField(
                      controller: icsController,
                      minLines: 4,
                      maxLines: 6,
                      onChanged: (value) async {
                        final wsId =
                            (await SyncService.instance.getWorkspaceId()) ?? 'personal-ws';
                        setSheetState(() {
                          parsedPreview = IcsCalendarService.parseIcsEvents(
                            value,
                            workspaceId: wsId,
                          );
                        });
                      },
                      decoration: const InputDecoration(
                        labelText: 'Isi File .ics (BEGIN:VCALENDAR ...)',
                        hintText: 'Tempel konten .ics dari Google Calendar di sini',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: AppTokens.space2),
                    Row(
                      children: [
                        Text(
                          'Kategori impor:',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondaryColor(ctx),
                          ),
                        ),
                        const SizedBox(width: AppTokens.space2),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: importKind,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'pribadi',
                                child: Text('Pribadi'),
                              ),
                              DropdownMenuItem(
                                value: 'freelance',
                                child: Text('Freelance'),
                              ),
                              DropdownMenuItem(
                                value: 'intern',
                                child: Text('Intern'),
                              ),
                              DropdownMenuItem(
                                value: 'kuliah',
                                child: Text('Kuliah'),
                              ),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setSheetState(() => importKind = val);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    if (parsedPreview.isNotEmpty) ...[
                      const SizedBox(height: AppTokens.space2),
                      Text(
                        'Pratinjau impor: ${parsedPreview.length} acara ditemukan (${parsedPreview.map((e) => e.title).take(3).join(', ')})',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.incomeColor(ctx),
                        ),
                      ),
                    ],
                    if (feedbackMsg != null) ...[
                      const SizedBox(height: AppTokens.space2),
                      Text(
                        feedbackMsg!,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                    if (exportedIcsPreview != null) ...[
                      const SizedBox(height: AppTokens.space2),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 110),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.subtleColor(ctx),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.borderColor(ctx)),
                        ),
                        child: SingleChildScrollView(
                          child: Text(
                            exportedIcsPreview!,
                            style: const TextStyle(
                              fontSize: 11,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: AppTokens.space3),
                    ElevatedButton.icon(
                      onPressed:
                          icsController.text.trim().isEmpty ? null : handleImportIcs,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(0, AppTokens.minTouchTarget),
                      ),
                      icon: const Icon(Icons.file_upload_outlined, size: 18),
                      label: const Text('Impor .ics ke Agenda'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showAddEventSheet() async {
    final titleController = TextEditingController();
    final locationController = TextEditingController();
    final descController = TextEditingController();
    var kind = 'pribadi';
    var date = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    var startHour = 9;
    var durationHours = 1;
    var allDay = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                AppTokens.space4,
                AppTokens.space4,
                AppTokens.space4,
                MediaQuery.of(ctx).viewInsets.bottom + AppTokens.space4,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Tambah Acara Agenda',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimaryColor(ctx),
                      ),
                    ),
                    const SizedBox(height: AppTokens.space3),
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Judul Acara',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: AppTokens.space2),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: kind,
                            decoration: const InputDecoration(
                              labelText: 'Kategori',
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'intern',
                                child: Text('Intern'),
                              ),
                              DropdownMenuItem(
                                value: 'freelance',
                                child: Text('Freelance'),
                              ),
                              DropdownMenuItem(
                                value: 'kuliah',
                                child: Text('Kuliah'),
                              ),
                              DropdownMenuItem(
                                value: 'pribadi',
                                child: Text('Pribadi'),
                              ),
                            ],
                            onChanged: (v) {
                              if (v != null) setSheetState(() => kind = v);
                            },
                          ),
                        ),
                        const SizedBox(width: AppTokens.space2),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: ctx,
                                initialDate: date,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2035),
                              );
                              if (picked != null) {
                                setSheetState(() => date = picked);
                              }
                            },
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(
                                0,
                                AppTokens.minTouchTarget,
                              ),
                            ),
                            icon: const Icon(Icons.calendar_today_outlined, size: 16),
                            label: Text(_formatDateIndo(date)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTokens.space2),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Sepanjang Hari'),
                      value: allDay,
                      onChanged: (v) => setSheetState(() => allDay = v),
                    ),
                    if (!allDay)
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              initialValue: startHour,
                              decoration: const InputDecoration(
                                labelText: 'Mulai Jam',
                                border: OutlineInputBorder(),
                              ),
                              items: [
                                for (var h = 6; h <= 21; h++)
                                  DropdownMenuItem(
                                    value: h,
                                    child: Text(
                                      '${h.toString().padLeft(2, '0')}:00',
                                    ),
                                  ),
                              ],
                              onChanged: (v) {
                                if (v != null) {
                                  setSheetState(() => startHour = v);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: AppTokens.space2),
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              initialValue: durationHours,
                              decoration: const InputDecoration(
                                labelText: 'Durasi',
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(value: 1, child: Text('1 Jam')),
                                DropdownMenuItem(value: 2, child: Text('2 Jam')),
                                DropdownMenuItem(value: 3, child: Text('3 Jam')),
                              ],
                              onChanged: (v) {
                                if (v != null) {
                                  setSheetState(() => durationHours = v);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: AppTokens.space2),
                    TextField(
                      controller: locationController,
                      decoration: const InputDecoration(
                        labelText: 'Lokasi (Opsional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: AppTokens.space2),
                    TextField(
                      controller: descController,
                      decoration: const InputDecoration(
                        labelText: 'Catatan (Opsional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: AppTokens.space3),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(0, AppTokens.minTouchTarget),
                      ),
                      onPressed: () async {
                        final title = titleController.text.trim();
                        if (title.isEmpty) return;

                        final startsAt = allDay
                            ? DateTime(date.year, date.month, date.day)
                            : DateTime(
                                date.year,
                                date.month,
                                date.day,
                                startHour,
                              );
                        final endsAt = allDay
                            ? DateTime(
                                date.year,
                                date.month,
                                date.day,
                                23,
                                59,
                                59,
                              )
                            : startsAt.add(Duration(hours: durationHours));

                        final wsId =
                            (await SyncService.instance.getWorkspaceId()) ?? 'personal-ws';
                        final id = const Uuid().v4();
                        final db = AppDatabase.shared;

                        await db.into(db.localEvents).insertOnConflictUpdate(
                          LocalEventsCompanion.insert(
                            id: id,
                            workspaceId: wsId,
                            kind: kind,
                            title: title,
                            description: drift.Value(
                              descController.text.trim().isEmpty
                                  ? null
                                  : descController.text.trim(),
                            ),
                            location: drift.Value(
                              locationController.text.trim().isEmpty
                                  ? null
                                  : locationController.text.trim(),
                            ),
                            startsAt: startsAt,
                            endsAt: endsAt,
                            allDay: drift.Value(allDay),
                          ),
                        );

                        await SyncService.instance.pushRecord(
                          tableName: 'events',
                          recordId: id,
                          action: 'insert',
                          payload: {
                            'id': id,
                            'workspace_id': wsId,
                            'kind': kind,
                            'title': title,
                            'description': descController.text.trim().isEmpty
                                ? null
                                : descController.text.trim(),
                            'location': locationController.text.trim().isEmpty
                                ? null
                                : locationController.text.trim(),
                            'starts_at': startsAt.toUtc().toIso8601String(),
                            'ends_at': endsAt.toUtc().toIso8601String(),
                            'all_day': allDay,
                            'timezone': 'Asia/Jakarta',
                          },
                        );

                        if (!ctx.mounted) return;
                        Navigator.of(ctx).pop();
                        _loadData();
                      },
                      child: const Text('Simpan Acara'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showEventDetailSheet(LocalEvent event) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(AppTokens.space4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  OrbitKindBadge(kind: event.kind),
                  if (event.externalProvider == 'google') ...[
                    const SizedBox(width: AppTokens.space2),
                    const OrbitStatusBadge(
                      label: 'Google/.ics',
                      variant: OrbitBadgeVariant.neutral,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: AppTokens.space2),
              Text(
                event.title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimaryColor(ctx),
                ),
              ),
              const SizedBox(height: AppTokens.space2),
              Text(
                event.allDay
                    ? '${_formatDateIndo(event.startsAt.toLocal())} (Sepanjang hari)'
                    : '${_formatDateIndo(event.startsAt.toLocal())} '
                        '${DateFormat('HH:mm').format(event.startsAt.toLocal())} - '
                        '${DateFormat('HH:mm').format(event.endsAt.toLocal())}',
                style: TextStyle(
                  fontSize: 13,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: AppColors.textSecondaryColor(ctx),
                ),
              ),
              if (event.location != null && event.location!.isNotEmpty) ...[
                const SizedBox(height: AppTokens.space2),
                Text(
                  'Lokasi: ${event.location}',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondaryColor(ctx),
                  ),
                ),
              ],
              if (event.description != null && event.description!.isNotEmpty) ...[
                const SizedBox(height: AppTokens.space2),
                Text(
                  event.description!,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textPrimaryColor(ctx),
                  ),
                ),
              ],
              const SizedBox(height: AppTokens.space4),
              OutlinedButton.icon(
                onPressed: () async {
                  final now = DateTime.now().toUtc();
                  await (AppDatabase.shared.update(AppDatabase.shared.localEvents)
                        ..where((e) => e.id.equals(event.id)))
                      .write(
                        LocalEventsCompanion(deletedAt: drift.Value(now)),
                      );
                  await SyncService.instance.pushRecord(
                    tableName: 'events',
                    recordId: event.id,
                    action: 'delete',
                    payload: {'deleted_at': now.toIso8601String()},
                  );
                  if (!ctx.mounted) return;
                  Navigator.of(ctx).pop();
                  _loadData();
                },
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, AppTokens.minTouchTarget),
                  foregroundColor: AppColors.expenseColor(ctx),
                ),
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Hapus Acara'),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDateIndo(DateTime dt) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  String _formatMonthYear(DateTime dt) {
    const months = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    return '${months[dt.month - 1]} ${dt.year}';
  }
}

class _AgendaEntry {
  final DateTime sortTime;
  final LocalEvent? event;
  final LocalTask? task;

  const _AgendaEntry({
    required this.sortTime,
    this.event,
    this.task,
  });
}

class _ActionPillButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool highlighted;
  final VoidCallback onTap;

  const _ActionPillButton({
    required this.icon,
    required this.label,
    required this.highlighted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTokens.radiusMd),
      child: Container(
        constraints: const BoxConstraints(minHeight: AppTokens.minTouchTarget),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: highlighted
              ? AppColors.primary.withValues(alpha: 0.1)
              : AppColors.surfaceColor(context),
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          border: Border.all(
            color: highlighted
                ? AppColors.primary
                : AppColors.borderColor(context),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: highlighted
                  ? AppColors.primary
                  : AppColors.textPrimaryColor(context),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: highlighted
                    ? AppColors.primary
                    : AppColors.textPrimaryColor(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChipButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChipButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTokens.radiusMd),
      child: Container(
        constraints: const BoxConstraints(minHeight: AppTokens.minTouchTarget),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.subtleColor(context)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          border: Border.all(
            color: selected
                ? AppColors.primary
                : AppColors.borderColor(context),
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected
                  ? AppColors.primary
                  : AppColors.textSecondaryColor(context),
            ),
          ),
        ),
      ),
    );
  }
}

class _CalendarSyncBanner extends StatelessWidget {
  final List<LocalCalendarConnection> connections;
  final VoidCallback onTapSync;

  const _CalendarSyncBanner({
    required this.connections,
    required this.onTapSync,
  });

  @override
  Widget build(BuildContext context) {
    final active = connections.where((c) => c.enabled).toList();
    final isConnected = active.isNotEmpty;

    return OrbitCard(
      onTap: onTapSync,
      padding: const EdgeInsets.all(AppTokens.space3),
      child: Row(
        children: [
          Icon(
            isConnected
                ? Icons.cloud_done_outlined
                : Icons.calendar_today_outlined,
            size: 20,
            color: isConnected
                ? AppColors.incomeColor(context)
                : AppColors.primary,
          ),
          const SizedBox(width: AppTokens.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isConnected
                      ? 'Google Calendar Terhubung'
                      : 'Google Calendar & Pertukaran .ics',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimaryColor(context),
                  ),
                ),
                Text(
                  isConnected
                      ? 'Kalender: ${active.first.externalCalendarId} (ketuk untuk Ekspor/Impor .ics)'
                      : 'OAuth Web belum tersambung. Ketuk untuk Impor atau Ekspor file .ics.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondaryColor(context),
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right,
            size: 18,
            color: AppColors.textMutedColor(context),
          ),
        ],
      ),
    );
  }
}

class _ConflictBanner extends StatelessWidget {
  final int conflictCount;

  const _ConflictBanner({required this.conflictCount});

  @override
  Widget build(BuildContext context) {
    final warn = AppColors.warningColor(context);
    return Container(
      padding: const EdgeInsets.all(AppTokens.space3),
      decoration: BoxDecoration(
        color: warn.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        border: Border.all(color: warn.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, size: 18, color: warn),
          const SizedBox(width: AppTokens.space2),
          Expanded(
            child: Text(
              'Terdeteksi $conflictCount blok acara dengan jadwal bertumpuk.',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimaryColor(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotionEventCard extends StatelessWidget {
  final LocalEvent event;
  final bool hasConflict;
  final VoidCallback onTap;

  const _NotionEventCard({
    required this.event,
    required this.hasConflict,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final start = event.startsAt.toLocal();
    final end = event.endsAt.toLocal();
    final timeStr = event.allDay
        ? 'Sepanjang hari'
        : '${DateFormat('HH:mm').format(start)} - ${DateFormat('HH:mm').format(end)}';
    final dateStr = '${start.day}/${start.month}';

    return OrbitCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppTokens.space3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 3,
            height: 44,
            decoration: BoxDecoration(
              color: hasConflict
                  ? AppColors.warningColor(context)
                  : AppColors.getKindColor(event.kind, isDark: Theme.of(context).brightness == Brightness.dark),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: AppTokens.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '$dateStr  $timeStr',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          fontFeatures: const [FontFeature.tabularFigures()],
                          color: AppColors.textMutedColor(context),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppTokens.space2),
                    OrbitKindBadge(kind: event.kind),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  event.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimaryColor(context),
                  ),
                ),
                if (event.location != null && event.location!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    event.location!,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondaryColor(context),
                    ),
                  ),
                ],
                if (hasConflict || event.externalProvider == 'google') ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      if (hasConflict)
                        const OrbitStatusBadge(
                          label: 'Bentrok Waktu',
                          variant: OrbitBadgeVariant.warning,
                        ),
                      if (event.externalProvider == 'google')
                        const OrbitStatusBadge(
                          label: 'Google/.ics',
                          variant: OrbitBadgeVariant.neutral,
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineEventBlock extends StatelessWidget {
  final LocalEvent event;
  final bool hasConflict;
  final bool overlapsPrevious;
  final VoidCallback onTap;

  const _TimelineEventBlock({
    required this.event,
    required this.hasConflict,
    required this.overlapsPrevious,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final start = event.startsAt.toLocal();
    final end = event.endsAt.toLocal();
    final timeRange =
        '${DateFormat('HH:mm').format(start)} - ${DateFormat('HH:mm').format(end)}';
    final kindColor = AppColors.getKindColor(event.kind, isDark: Theme.of(context).brightness == Brightness.dark);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTokens.radiusMd),
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: kindColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          border: Border.all(
            color: (hasConflict || overlapsPrevious)
                ? AppColors.warningColor(context)
                : kindColor.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimaryColor(context),
                    ),
                  ),
                  Text(
                    timeRange,
                    style: TextStyle(
                      fontSize: 11,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: AppColors.textSecondaryColor(context),
                    ),
                  ),
                ],
              ),
            ),
            if (hasConflict || overlapsPrevious)
              const OrbitStatusBadge(
                label: 'Bentrok',
                variant: OrbitBadgeVariant.warning,
              ),
          ],
        ),
      ),
    );
  }
}

class _TaskDeadlineCard extends StatelessWidget {
  final LocalTask task;
  final VoidCallback onTap;

  const _TaskDeadlineCard({
    required this.task,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final due = task.dueAt?.toLocal();
    final timeStr = due == null
        ? '-'
        : '${due.day}/${due.month}/${due.year} (${task.dueIsDateOnly ? 'Sepanjang hari' : 'Tenggat'})';

    return OrbitCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppTokens.space3),
      child: Row(
        children: [
          Icon(
            Icons.task_alt_outlined,
            size: 18,
            color: AppColors.getKindColor(task.kind, isDark: Theme.of(context).brightness == Brightness.dark),
          ),
          const SizedBox(width: AppTokens.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimaryColor(context),
                  ),
                ),
                Text(
                  'Pengingat tugas: $timeStr',
                  style: TextStyle(
                    fontSize: 11,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: AppColors.textMutedColor(context),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppTokens.space2),
          OrbitTaskStatusBadge(status: task.status, compact: true),
        ],
      ),
    );
  }
}
