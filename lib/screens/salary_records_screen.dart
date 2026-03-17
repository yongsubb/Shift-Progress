import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../database/database_helper.dart';
import '../models/salary_record.dart';
import '../models/shift.dart';
import '../theme/app_theme.dart';

class SalaryRecordsScreen extends StatefulWidget {
  const SalaryRecordsScreen({super.key});

  @override
  State<SalaryRecordsScreen> createState() => _SalaryRecordsScreenState();
}

class _SalaryRecordsScreenState extends State<SalaryRecordsScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final Set<int> _expandedRecordIds = <int>{};

  List<SalaryRecord> _records = [];

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    final records = await _dbHelper.getAllSalaryRecords();
    if (!mounted) return;
    setState(() {
      _records = records;
    });
  }

  double get _totalEarnings {
    return _records.fold(0, (sum, record) => sum + record.totalSalary);
  }

  double get _totalHours {
    return _records.fold(0, (sum, record) => sum + record.totalHours);
  }

  int get _totalShifts {
    return _records.fold(0, (sum, record) => sum + record.shiftCount);
  }

  String _formatHours(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(1);
  }

  String _formatCutoffWindow(SalaryRecord record) {
    if (record.periodStart.year == record.periodEnd.year &&
        record.periodStart.month == record.periodEnd.month) {
      final monthName = DateFormat('MMM').format(record.periodStart);
      return '$monthName ${record.periodStart.day}-${record.periodEnd.day}, ${record.periodStart.year}';
    }

    return '${DateFormat('MMM dd, yyyy').format(record.periodStart)} - ${DateFormat('MMM dd, yyyy').format(record.periodEnd)}';
  }

  String _cutoffTypeLabel(String periodType) {
    return periodType == '1-15' ? 'Days 1-15' : 'Days 16-end';
  }

  Widget _buildPill(
    BuildContext context, {
    required IconData icon,
    required String label,
    Color iconColor = const Color(0xFFC8D2E3),
    Color textColor = const Color(0xFFC8D2E3),
    bool compact = false,
  }) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 9 : 10,
        vertical: compact ? 6 : 7,
      ),
      decoration: BoxDecoration(
        color: const Color(0x26394A68),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x33566C96)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 13 : 14, color: iconColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: (compact ? textTheme.labelSmall : textTheme.labelMedium)
                ?.copyWith(color: textColor, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewCard(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return _GlassPanel(
      borderRadius: 20,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [AppColors.accentPurple, AppColors.accentPink],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(color: Colors.white, width: 2.5),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accentPurple.withValues(alpha: 0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet_outlined,
                    color: Colors.white,
                    size: 19,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Estimated earnings',
                        style: textTheme.titleMedium?.copyWith(
                          color: const Color(0xFFE5E7EB),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Salary records from completed cutoffs.',
                        style: textTheme.bodySmall?.copyWith(
                          color: const Color(0xFFC8D2E3),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: _buildPill(
                    context,
                    icon: Icons.history_rounded,
                    label: '${_records.length} cutoffs',
                    iconColor: AppColors.accentPurple,
                    textColor: const Color(0xFFE5E7EB),
                    compact: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.accentYellow,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x44F4C542),
                    blurRadius: 12,
                    offset: Offset(0, 7),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total estimated earnings',
                          style: textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF151A22),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Across all saved cutoff records',
                          style: textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF2A3140),
                            height: 1.25,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '₱${_totalEarnings.toStringAsFixed(2)}',
                        style: textTheme.titleMedium?.copyWith(
                          color: const Color(0xFF151A22),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 5,
              runSpacing: 5,
              children: [
                _buildPill(
                  context,
                  icon: Icons.receipt_long_rounded,
                  label: '${_records.length} records',
                  compact: true,
                ),
                _buildPill(
                  context,
                  icon: Icons.task_alt_rounded,
                  label: '$_totalShifts shifts',
                  compact: true,
                ),
                _buildPill(
                  context,
                  icon: Icons.schedule_rounded,
                  label: '${_formatHours(_totalHours)} hrs',
                  compact: true,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionIntro(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cutoff history',
            style: textTheme.titleMedium?.copyWith(
              color: const Color(0xFFE5E7EB),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Open a record to inspect the shifts archived in that pay period.',
            style: textTheme.bodySmall?.copyWith(
              color: const Color(0xFFC8D2E3),
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: _GlassPanel(
        borderRadius: 20,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF24324A),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.receipt_long_rounded,
                  color: Color(0xFFC8D2E3),
                  size: 22,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'No cutoff records yet',
                style: textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Completed shifts will appear here after a cutoff is saved.',
                textAlign: TextAlign.center,
                style: textTheme.bodySmall?.copyWith(
                  color: const Color(0xFFC8D2E3),
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    BuildContext context, {
    required String label,
    required String value,
  }) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: textTheme.bodySmall?.copyWith(
                color: const Color(0xFFC8D2E3),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: textTheme.bodySmall?.copyWith(
                color: const Color(0xFFE5E7EB),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShiftCard(
    BuildContext context,
    Shift shift, {
    required double ratePerHour,
  }) {
    final textTheme = Theme.of(context).textTheme;
    final shiftName = shift.shiftType.replaceAll(' Shift', '');

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0x26394A68),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x33566C96)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('EEE, MMM dd yyyy').format(shift.date),
                      style: textTheme.labelMedium?.copyWith(
                        color: const Color(0xFFE5E7EB),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      shiftName,
                      style: textTheme.bodyLarge?.copyWith(
                        color: const Color(0xFFE5E7EB),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '₱${shift.calculateSalary(ratePerHour).toStringAsFixed(2)}',
                style: textTheme.bodyLarge?.copyWith(
                  color: AppColors.accentYellow,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildPill(
                context,
                icon: Icons.schedule_rounded,
                label: '${shift.hoursWorked.toStringAsFixed(1)} hrs',
                compact: true,
              ),
              if (shift.overtimeHours > 0)
                _buildPill(
                  context,
                  icon: Icons.flash_on_rounded,
                  label: 'OT ${shift.overtimeHours.toStringAsFixed(1)}h',
                  compact: true,
                ),
              if (shift.isHoliday)
                _buildPill(
                  context,
                  icon: Icons.celebration_rounded,
                  label: 'Holiday',
                  compact: true,
                ),
              if (shift.specialPayMultiplier > 1.0)
                _buildPill(
                  context,
                  icon: Icons.local_fire_department_rounded,
                  label: shift.specialPayMultiplier == 2.0 ? '2x pay' : '+30%',
                  compact: true,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildShiftSection(BuildContext context, SalaryRecord record) {
    final textTheme = Theme.of(context).textTheme;

    return FutureBuilder<List<Shift>>(
      future: record.id == null
          ? Future.value(const <Shift>[])
          : _dbHelper.getArchivedShifts(record.id!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'No shifts found for this cutoff.',
              style: textTheme.bodyMedium?.copyWith(
                color: const Color(0xFFC8D2E3),
              ),
            ),
          );
        }

        final shifts = snapshot.data!;
        return Column(
          children: shifts
              .map(
                (shift) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _buildShiftCard(
                    context,
                    shift,
                    ratePerHour: record.ratePerHour,
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _buildRecordCard(BuildContext context, SalaryRecord record) {
    final textTheme = Theme.of(context).textTheme;
    final recordId = record.id;
    final isExpanded =
        recordId != null && _expandedRecordIds.contains(recordId);

    return _GlassPanel(
      borderRadius: 20,
      borderColor: isExpanded
          ? const Color(0x55F4C542)
          : const Color(0x33566C96),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: PageStorageKey(
            'salary-record-${record.id ?? _formatCutoffWindow(record)}',
          ),
          onExpansionChanged: (expanded) {
            if (recordId == null) return;
            setState(() {
              if (expanded) {
                _expandedRecordIds.add(recordId);
              } else {
                _expandedRecordIds.remove(recordId);
              }
            });
          },
          tilePadding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          collapsedIconColor: const Color(0xFFC8D2E3),
          iconColor: AppColors.accentYellow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          collapsedShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          leading: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0x26394A68),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.calendar_month_rounded,
              size: 16,
              color: Color(0xFFC8D2E3),
            ),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  _formatCutoffWindow(record),
                  style: textTheme.titleSmall?.copyWith(
                    color: const Color(0xFFE5E7EB),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '₱${record.totalSalary.toStringAsFixed(2)}',
                style: textTheme.titleSmall?.copyWith(
                  color: AppColors.accentYellow,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _buildPill(
                  context,
                  icon: Icons.event_repeat_rounded,
                  label: _cutoffTypeLabel(record.periodType),
                  compact: true,
                ),
                _buildPill(
                  context,
                  icon: Icons.task_alt_rounded,
                  label: '${record.shiftCount} shifts',
                  compact: true,
                ),
                _buildPill(
                  context,
                  icon: Icons.schedule_rounded,
                  label: '${_formatHours(record.totalHours)} hrs',
                  compact: true,
                ),
              ],
            ),
          ),
          children: [
            const Divider(color: Color(0x2EFFFFFF), height: 14),
            Container(
              decoration: BoxDecoration(
                color: const Color(0x1AFFFFFF),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0x33566C96)),
              ),
              child: Column(
                children: [
                  _buildDetailRow(
                    context,
                    label: 'Cutoff window',
                    value: _formatCutoffWindow(record),
                  ),
                  const Divider(color: Color(0x2EFFFFFF), height: 1),
                  _buildDetailRow(
                    context,
                    label: 'Rate per hour',
                    value: '₱${record.ratePerHour.toStringAsFixed(2)}',
                  ),
                  const Divider(color: Color(0x2EFFFFFF), height: 1),
                  _buildDetailRow(
                    context,
                    label: 'Avg hours / shift',
                    value:
                        '${(record.totalHours / record.shiftCount).toStringAsFixed(2)} hrs',
                  ),
                  const Divider(color: Color(0x2EFFFFFF), height: 1),
                  _buildDetailRow(
                    context,
                    label: 'Avg earnings / shift',
                    value:
                        '₱${(record.totalSalary / record.shiftCount).toStringAsFixed(2)}',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Archived shifts',
              style: textTheme.labelLarge?.copyWith(
                color: const Color(0xFFE5E7EB),
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            _buildShiftSection(context, record),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: const Text('Salary Records')),
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
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildOverviewCard(context),
                  const SizedBox(height: 14),
                  _buildSectionIntro(context),
                  const SizedBox(height: 10),
                  Expanded(
                    child: _records.isEmpty
                        ? _buildEmptyState(context)
                        : ListView.separated(
                            padding: const EdgeInsets.only(bottom: 112),
                            itemCount: _records.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              return _buildRecordCard(context, _records[index]);
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({
    required this.child,
    this.borderRadius = 24,
    this.borderColor = const Color(0x33566C96),
  });

  final Widget child;
  final double borderRadius;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0x26344766),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: borderColor),
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
