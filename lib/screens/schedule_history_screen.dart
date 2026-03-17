import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../database/database_helper.dart';
import '../models/salary_record.dart';
import '../models/shift.dart';
import '../theme/app_theme.dart';

class ScheduleHistoryScreen extends StatefulWidget {
  const ScheduleHistoryScreen({super.key});

  @override
  State<ScheduleHistoryScreen> createState() => _ScheduleHistoryScreenState();
}

class _ScheduleHistoryScreenState extends State<ScheduleHistoryScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  List<Shift> _completedThisPeriod = const [];
  List<_ArchivedCutoffGroup> _archivedGroups = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final completed = await _dbHelper.getCompletedShifts();
    final records = await _dbHelper.getAllSalaryRecords();
    final archivedGroups = await Future.wait(
      records.where((record) => record.id != null).map((record) async {
        final shifts = await _dbHelper.getArchivedShifts(record.id!);
        return _ArchivedCutoffGroup(record: record, shifts: shifts);
      }),
    );

    if (!mounted) return;
    setState(() {
      _completedThisPeriod = completed;
      _archivedGroups = archivedGroups
          .where((group) => group.shifts.isNotEmpty)
          .toList();
      _loading = false;
    });
  }

  String _titleForShift(Shift shift) {
    return shift.shiftType.replaceAll(' Shift', '');
  }

  String _subtitleForShift(Shift shift) {
    return DateFormat('EEEE: MMMM dd yyyy').format(shift.date);
  }

  String _formatTime(DateTime dateTime) {
    final formatted = DateFormat('h:mma').format(dateTime).toLowerCase();
    return formatted.replaceAll(':00', '');
  }

  (DateTime start, double baseHours)? _shiftStartAndBaseHours(Shift shift) {
    final date = shift.date;

    if (shift.startMinutes != null && shift.endMinutes != null) {
      final startMinutes = shift.startMinutes!;
      final endMinutes = shift.endMinutes!;
      var delta = endMinutes - startMinutes;
      if (delta <= 0) delta += 24 * 60;
      return (
        DateTime(
          date.year,
          date.month,
          date.day,
        ).add(Duration(minutes: startMinutes)),
        delta / 60.0,
      );
    }

    final shiftType = shift.shiftType.toLowerCase();

    if (shiftType.contains('opening')) {
      return (DateTime(date.year, date.month, date.day, 6), 6.0);
    }
    if (shiftType.contains('mid')) {
      return (DateTime(date.year, date.month, date.day, 12), 6.0);
    }
    if (shiftType.contains('closing')) {
      return (DateTime(date.year, date.month, date.day, 18), 6.0);
    }
    if (shiftType.contains('graveyard')) {
      return (DateTime(date.year, date.month, date.day, 0), 6.0);
    }
    return null;
  }

  String _timeRangeForShift(Shift shift) {
    final startAndBase = _shiftStartAndBaseHours(shift);
    if (startAndBase == null) {
      return '${shift.hoursWorked.toStringAsFixed(1)}h shift';
    }

    final start = startAndBase.$1;
    final baseHours = startAndBase.$2;

    final baseMinutes = (baseHours * 60).round();
    final baseEnd = start.add(Duration(minutes: baseMinutes));
    final extraHours = shift.hoursWorked - baseHours;

    final baseText = '${_formatTime(start)} to ${_formatTime(baseEnd)}';
    if (extraHours <= 0) return baseText;

    String formatExtra(double value) {
      final fixed = value == value.roundToDouble()
          ? value.toStringAsFixed(0)
          : value.toStringAsFixed(1);
      return fixed;
    }

    return '$baseText (+${formatExtra(extraHours)} hrs)';
  }

  String _formatHours(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(1);
  }

  String _cutoffLabel(SalaryRecord record) {
    if (record.periodStart.year == record.periodEnd.year &&
        record.periodStart.month == record.periodEnd.month) {
      final monthName = DateFormat('MMMM').format(record.periodStart);
      return '$monthName ${record.periodStart.day}-${record.periodEnd.day}, ${record.periodStart.year} cutoff';
    }

    return '${DateFormat('MMM dd, yyyy').format(record.periodStart)} - ${DateFormat('MMM dd, yyyy').format(record.periodEnd)} cutoff';
  }

  String _cutoffSummary(SalaryRecord record) {
    return '${record.shiftCount} schedules | ${_formatHours(record.totalHours)} hrs | ₱${record.totalSalary.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    final hasContent =
        _completedThisPeriod.isNotEmpty || _archivedGroups.isNotEmpty;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: const Text('Schedule History')),
      body: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(gradient: AppGradients.baseBackground),
            ),
          ),
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(gradient: AppGradients.topGlow),
            ),
          ),
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(gradient: AppGradients.midGlow),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : !hasContent
                  ? Center(
                      child: Text(
                        'No completed shifts yet.\nTap the check on a finished shift to move it here.',
                        textAlign: TextAlign.center,
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.only(bottom: 12),
                      children: [
                        if (_completedThisPeriod.isNotEmpty) ...[
                          Text(
                            'Completed (This period)',
                            style: textTheme.labelLarge?.copyWith(
                              color: const Color(0xFFC8D2E3),
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.4,
                            ),
                          ),
                          const SizedBox(height: 10),
                          ..._completedThisPeriod.map(
                            (shift) => Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: _HistoryShiftCard(
                                icon: Icons.task_alt_rounded,
                                title: _titleForShift(shift),
                                subtitle: _subtitleForShift(shift),
                                timeText: _timeRangeForShift(shift),
                                isCompleted: true,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                        ],
                        if (_archivedGroups.isNotEmpty) ...[
                          Text(
                            'Archived (Previous periods)',
                            style: textTheme.labelLarge?.copyWith(
                              color: const Color(0xFFC8D2E3),
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.4,
                            ),
                          ),
                          const SizedBox(height: 10),
                          ..._archivedGroups.map(
                            (group) => Padding(
                              padding: const EdgeInsets.only(bottom: 18),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0x1EFFFFFF),
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(
                                        color: const Color(0x33566C96),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _cutoffLabel(group.record),
                                          style: textTheme.titleSmall?.copyWith(
                                            color: const Color(0xFFF6F8FC),
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _cutoffSummary(group.record),
                                          style: textTheme.bodySmall?.copyWith(
                                            color: const Color(0xFFC8D2E3),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  ...group.shifts.map(
                                    (shift) => Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 14,
                                      ),
                                      child: _HistoryShiftCard(
                                        icon: Icons.history_rounded,
                                        title: _titleForShift(shift),
                                        subtitle: _subtitleForShift(shift),
                                        timeText: _timeRangeForShift(shift),
                                        isCompleted: true,
                                        tagText: _cutoffLabel(group.record),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryShiftCard extends StatelessWidget {
  const _HistoryShiftCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.timeText,
    required this.isCompleted,
    this.tagText,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String timeText;
  final bool isCompleted;
  final String? tagText;

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
      color: const Color(0xFFE5E7EB),
      fontWeight: FontWeight.w800,
    );
    final subtitleStyle = Theme.of(context).textTheme.titleSmall?.copyWith(
      color: const Color(0xFFE5E7EB),
      fontWeight: FontWeight.w600,
    );

    return _GlassCard(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0x26394A68),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(icon, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: titleStyle),
                      if (tagText != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0x1AF7C94C),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: const Color(0x33F7C94C)),
                          ),
                          child: Text(
                            tagText!,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: const Color(0xFFFFE082),
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Text(subtitle, style: subtitleStyle),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 10, top: 2),
                  child: _StatusCircle(isCompleted: isCompleted),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(color: Color(0x2EFFFFFF), height: 1.0),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(
                  Icons.alarm_outlined,
                  size: 17,
                  color: Color(0xFFAEB8CA),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    timeText,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: const Color(0xFFDCE3EF),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ArchivedCutoffGroup {
  const _ArchivedCutoffGroup({required this.record, required this.shifts});

  final SalaryRecord record;
  final List<Shift> shifts;
}

class _StatusCircle extends StatelessWidget {
  const _StatusCircle({required this.isCompleted});

  final bool isCompleted;

  @override
  Widget build(BuildContext context) {
    if (isCompleted) {
      return Container(
        width: 28,
        height: 28,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check, color: Color(0xFF131A25), size: 16),
      );
    }

    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.textMutedOnDark, width: 1.5),
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0x26344766),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0x33566C96)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x55000000),
                blurRadius: 18,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
