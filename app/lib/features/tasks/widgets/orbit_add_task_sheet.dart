import 'dart:convert';
import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:orbit_app/core/constants/app_colors.dart';
import 'package:orbit_app/core/database/database.dart';
import 'package:orbit_app/core/services/notification_scheduler_service.dart';
import 'package:orbit_app/core/services/sync_service.dart';

/// Membuka bottom sheet Tambah Tugas v2 dengan dukungan template,
/// pengulangan (recurrence_rule), proyek, estimasi durasi, checklist, dan subtugas.
Future<String?> showOrbitAddTaskSheet(
  BuildContext context, {
  String? initialProjectId,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surfaceColor(context),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
    ),
    builder: (ctx) => _OrbitAddTaskSheetBody(
      initialProjectId: initialProjectId,
    ),
  );
}

class _OrbitAddTaskSheetBody extends StatefulWidget {
  final String? initialProjectId;

  const _OrbitAddTaskSheetBody({this.initialProjectId});

  @override
  State<_OrbitAddTaskSheetBody> createState() => _OrbitAddTaskSheetBodyState();
}

class _OrbitAddTaskSheetBodyState extends State<_OrbitAddTaskSheetBody> {
  final _db = AppDatabase.shared;
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _estimateCtrl = TextEditingController();
  final _subtaskInputCtrl = TextEditingController();

  String _kind = 'pribadi';
  String _priority = 'sedang';
  String? _projectId;
  DateTime? _dueAt;
  bool _dueIsDateOnly = false;
  String _recurrenceFreq = 'none'; // none | daily | weekly | monthly
  int _recurrenceInterval = 1;
  String? _selectedTemplateId;
  List<String> _templateChecklist = [];
  List<Map<String, dynamic>>? _templateBlocks;
  final List<String> _initialSubtasks = [];

  List<LocalTaskTemplate> _templates = const [];
  List<LocalProject> _projects = const [];
  bool _saving = false;
  String? _titleError;

  @override
  void initState() {
    super.initState();
    _projectId = widget.initialProjectId;
    _loadOptions();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _estimateCtrl.dispose();
    _subtaskInputCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadOptions() async {
    final templates = await (_db.select(_db.localTaskTemplates)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .get();
    final projects = await (_db.select(_db.localProjects)
          ..where((p) =>
              p.deletedAt.isNull() &
              (p.status.equals('berjalan') | p.status.equals('active')))
          ..orderBy([(p) => OrderingTerm.asc(p.name)]))
        .get();
    if (!mounted) return;
    setState(() {
      _templates = templates;
      _projects = projects;
    });
  }

  void _applyTemplate(LocalTaskTemplate? tpl) {
    setState(() {
      if (tpl == null) {
        _selectedTemplateId = null;
        _templateChecklist = [];
        _templateBlocks = null;
        return;
      }
      _selectedTemplateId = tpl.id;
      _kind = tpl.kind;
      _priority = tpl.defaultPriority;
      if (_titleCtrl.text.trim().isEmpty) {
        _titleCtrl.text = tpl.name;
      }
      if (tpl.defaultEstimateMinutes != null) {
        _estimateCtrl.text = tpl.defaultEstimateMinutes.toString();
      }
      _templateChecklist = _decodeChecklist(tpl.checklistJson);
      _templateBlocks = _decodeBlocks(tpl.blocksJson);
    });
  }

  List<String> _decodeChecklist(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .map((e) {
              if (e is Map && e['text'] != null) return e['text'].toString();
              return e.toString();
            })
            .where((s) => s.trim().isNotEmpty)
            .toList();
      }
    } catch (_) {}
    return [];
  }

  List<Map<String, dynamic>>? _decodeBlocks(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.whereType<Map<String, dynamic>>().toList();
      }
    } catch (_) {}
    return null;
  }

  void _addSubtaskLine() {
    final v = _subtaskInputCtrl.text.trim();
    if (v.isEmpty) return;
    setState(() {
      _initialSubtasks.add(v);
      _subtaskInputCtrl.clear();
    });
  }

  Future<void> _pickDueDate() async {
    final base = _dueAt ?? DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
        _dueAt ?? DateTime(base.year, base.month, base.day, 17),
      ),
    );
    if (!mounted) return;
    setState(() {
      _dueIsDateOnly = time == null;
      _dueAt = DateTime(
        date.year,
        date.month,
        date.day,
        time?.hour ?? 23,
        time?.minute ?? 59,
      );
    });
  }

  Future<void> _submit() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      setState(() => _titleError = 'Judul tugas wajib diisi.');
      return;
    }

    setState(() => _saving = true);
    try {
      final estimate = int.tryParse(_estimateCtrl.text.trim());
      final recRule = _recurrenceFreq == 'none'
          ? null
          : {'freq': _recurrenceFreq, 'interval': _recurrenceInterval};

      final parentId = await SyncService.instance.createTask(
        title: title,
        kind: _kind,
        priority: _priority,
        projectId: _projectId,
        description: _descCtrl.text.trim(),
        descriptionBlocks: _templateBlocks,
        dueAt: _dueAt,
        dueIsDateOnly: _dueIsDateOnly,
        estimateMinutes: (estimate != null && estimate > 0) ? estimate : null,
        recurrenceRule: recRule,
        initialChecklist: _templateChecklist,
      );

      for (final subTitle in _initialSubtasks) {
        await SyncService.instance.createTask(
          title: subTitle,
          kind: _kind,
          projectId: _projectId,
          parentTaskId: parentId,
          priority: 'sedang',
        );
      }

      try {
        await NotificationSchedulerService.rescheduleAll(_db);
      } catch (_) {}

      if (mounted) Navigator.of(context).pop(parentId);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final borderCol = AppColors.borderColor(context);
    final textPrimary = AppColors.textPrimaryColor(context);
    final textSecondary = AppColors.textSecondaryColor(context);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottomInset),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Tambah Tugas Baru',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Tutup',
                    constraints:
                        const BoxConstraints(minWidth: 44, minHeight: 44),
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Pilihan Template Tugas
              if (_templates.isNotEmpty) ...[
                Text(
                  'Gunakan Template',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: const Text('Kosong'),
                          selected: _selectedTemplateId == null,
                          onSelected: (_) => _applyTemplate(null),
                        ),
                      ),
                      ..._templates.map(
                        (tpl) => Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(tpl.name),
                            selected: _selectedTemplateId == tpl.id,
                            onSelected: (_) => _applyTemplate(tpl),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              TextField(
                controller: _titleCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Judul tugas',
                  hintText: 'Contoh: Finalisasi modul Kanban',
                  errorText: _titleError,
                ),
                onChanged: (_) {
                  if (_titleError != null) {
                    setState(() => _titleError = null);
                  }
                },
              ),
              const SizedBox(height: 12),

              TextField(
                controller: _descCtrl,
                minLines: 2,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Catatan ringkas (opsional)',
                ),
              ),
              const SizedBox(height: 12),

              // Konteks & Prioritas
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _kind,
                      decoration: const InputDecoration(labelText: 'Konteks'),
                      items: const [
                        DropdownMenuItem(
                            value: 'pribadi', child: Text('Pribadi')),
                        DropdownMenuItem(
                            value: 'kuliah', child: Text('Kuliah')),
                        DropdownMenuItem(
                            value: 'intern', child: Text('Intern')),
                        DropdownMenuItem(
                            value: 'freelance', child: Text('Freelance')),
                      ],
                      onChanged: (v) {
                        if (v != null) setState(() => _kind = v);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _priority,
                      decoration: const InputDecoration(labelText: 'Prioritas'),
                      items: const [
                        DropdownMenuItem(
                            value: 'tinggi', child: Text('Tinggi')),
                        DropdownMenuItem(
                            value: 'sedang', child: Text('Sedang')),
                        DropdownMenuItem(
                            value: 'rendah', child: Text('Rendah')),
                      ],
                      onChanged: (v) {
                        if (v != null) setState(() => _priority = v);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Proyek & Estimasi
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: DropdownButtonFormField<String?>(
                      initialValue: _projects.any((p) => p.id == _projectId)
                          ? _projectId
                          : null,
                      decoration: const InputDecoration(labelText: 'Proyek'),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Tanpa proyek'),
                        ),
                        ..._projects.map(
                          (p) => DropdownMenuItem<String?>(
                            value: p.id,
                            child: Text(
                              p.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                      onChanged: (v) => setState(() => _projectId = v),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _estimateCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Estimasi (mnt)',
                        hintText: '45',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Tenggat
              InkWell(
                onTap: _pickDueDate,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 44),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: borderCol),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today_outlined,
                          size: 18, color: textSecondary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _dueAt != null
                              ? (_dueIsDateOnly
                                  ? DateFormat('dd MMM yyyy').format(_dueAt!)
                                  : DateFormat('dd MMM yyyy, HH:mm')
                                      .format(_dueAt!))
                              : 'Atur tenggat waktu (opsional)',
                          style: TextStyle(fontSize: 13.5, color: textPrimary),
                        ),
                      ),
                      if (_dueAt != null)
                        IconButton(
                          tooltip: 'Hapus tenggat',
                          constraints: const BoxConstraints(
                            minWidth: AppTokens.minTouchTarget,
                            minHeight: AppTokens.minTouchTarget,
                          ),
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.close_rounded, size: 17),
                          onPressed: () => setState(() => _dueAt = null),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Pengulangan (Recurrence Rule)
              Text(
                'Pengulangan',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final opt in const [
                    MapEntry('none', 'Tidak ada'),
                    MapEntry('daily', 'Harian'),
                    MapEntry('weekly', 'Mingguan'),
                    MapEntry('monthly', 'Bulanan'),
                  ])
                    ChoiceChip(
                      label: Text(opt.value),
                      selected: _recurrenceFreq == opt.key,
                      onSelected: (_) =>
                          setState(() => _recurrenceFreq = opt.key),
                    ),
                ],
              ),
              if (_recurrenceFreq != 'none') ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      'Interval pengulangan:',
                      style: TextStyle(fontSize: 13, color: textPrimary),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Kurangi interval pengulangan',
                      constraints:
                          const BoxConstraints(minWidth: 44, minHeight: 44),
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: _recurrenceInterval > 1
                          ? () => setState(() => _recurrenceInterval--)
                          : null,
                    ),
                    Text(
                      '$_recurrenceInterval',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Tambah interval pengulangan',
                      constraints:
                          const BoxConstraints(minWidth: 44, minHeight: 44),
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: _recurrenceInterval < 30
                          ? () => setState(() => _recurrenceInterval++)
                          : null,
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),

              if (_templateChecklist.isNotEmpty) ...[
                Text(
                  'Checklist dari Template (${_templateChecklist.length} item)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: _templateChecklist
                      .map((c) => Chip(label: Text(c)))
                      .toList(),
                ),
                const SizedBox(height: 12),
              ],

              // Subtugas awal opsional
              Text(
                'Subtugas Awal (opsional)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _subtaskInputCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Tambah subtugas...',
                        isDense: true,
                      ),
                      onSubmitted: (_) => _addSubtaskLine(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 44,
                    child: OutlinedButton(
                      onPressed: _addSubtaskLine,
                      child: const Text('Tambah'),
                    ),
                  ),
                ],
              ),
              if (_initialSubtasks.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _initialSubtasks
                      .asMap()
                      .entries
                      .map(
                        (e) => InputChip(
                          label: Text(e.value),
                          onDeleted: () => setState(
                              () => _initialSubtasks.removeAt(e.key)),
                        ),
                      )
                      .toList(),
                ),
              ],

              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: FilledButton(
                  onPressed: _saving ? null : _submit,
                  child: Text(_saving ? 'Menyimpan...' : 'Simpan Tugas'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
