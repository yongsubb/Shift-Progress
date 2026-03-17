import 'dart:io';
import 'dart:ui';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'models/shift.dart';
import 'models/salary_record.dart';
import 'database/database_helper.dart';
import 'screens/about_screen.dart';
import 'screens/salary_records_screen.dart';
import 'screens/schedule_history_screen.dart';
import 'screens/welcome_onboarding_screen.dart';
import 'theme/app_theme.dart';

void main() {
  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWeb;
  }

  // Initialize FFI for Windows/Linux/MacOS
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Shift Progress',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.dark,
      home: const AppLaunchGate(),
    );
  }
}

class AppLaunchGate extends StatefulWidget {
  const AppLaunchGate({super.key});

  @override
  State<AppLaunchGate> createState() => _AppLaunchGateState();
}

class _AppLaunchGateState extends State<AppLaunchGate> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  bool _isLoading = true;
  bool _showOnboarding = false;
  String? _nickname;

  @override
  void initState() {
    super.initState();
    _loadLaunchState();
  }

  Future<void> _loadLaunchState() async {
    String? onboardingSeen;
    String? savedNickname;

    try {
      onboardingSeen = await _dbHelper
          .getSettingValue('onboardingSeen')
          .timeout(const Duration(seconds: 4));
      savedNickname = await _dbHelper
          .getSettingValue('nickname')
          .timeout(const Duration(seconds: 4));
    } catch (_) {
      // Fall back to onboarding instead of keeping the splash forever.
      onboardingSeen = null;
      savedNickname = null;
    }

    final normalizedNickname = (savedNickname ?? '').trim();

    if (!mounted) return;
    setState(() {
      _showOnboarding = onboardingSeen != '1';
      _nickname = normalizedNickname.isEmpty ? null : normalizedNickname;
      _isLoading = false;
    });
  }

  Future<void> _completeOnboarding(String? nickname) async {
    final trimmedNickname = (nickname ?? '').trim();
    try {
      await _dbHelper
          .setSettingValue('onboardingSeen', '1')
          .timeout(const Duration(seconds: 4));
      await _dbHelper
          .setSettingValue('nickname', trimmedNickname)
          .timeout(const Duration(seconds: 4));
    } catch (_) {
      // Allow app entry even if persistence fails on this device/browser.
    }

    if (!mounted) return;
    setState(() {
      _nickname = trimmedNickname.isEmpty ? null : trimmedNickname;
      _showOnboarding = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const _LaunchLoadingScreen();
    }

    if (_showOnboarding) {
      return WelcomeOnboardingScreen(
        initialNickname: _nickname,
        onContinue: _completeOnboarding,
      );
    }

    return MainNavigationShell(nickname: _nickname);
  }
}

class _LaunchLoadingScreen extends StatelessWidget {
  const _LaunchLoadingScreen();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
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
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 74,
                  height: 74,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [AppColors.accentPurple, AppColors.accentPink],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accentPurple.withValues(alpha: 0.30),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.calendar_month_rounded,
                    color: Colors.white,
                    size: 34,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Shift Tracker',
                  style: textTheme.headlineSmall?.copyWith(
                    color: const Color(0xFFE5E7EB),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Preparing your workspace...',
                  style: textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFFC8D2E3),
                  ),
                ),
                const SizedBox(height: 18),
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key, this.nickname});

  final String? nickname;

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  final GlobalKey<_ShiftTrackerHomeState> _scheduleKey =
      GlobalKey<_ShiftTrackerHomeState>();
  int _selectedIndex = 0;
  double _scheduleFabOpacity = 1.0;

  void _handleScheduleScrollOffset(double offset) {
    final clampedOffset = offset.clamp(0.0, 180.0).toDouble();
    final nextOpacity = (1.0 - (clampedOffset / 180.0) * 0.45)
        .clamp(0.55, 1.0)
        .toDouble();

    if ((_scheduleFabOpacity - nextOpacity).abs() < 0.02) {
      return;
    }

    setState(() {
      _scheduleFabOpacity = nextOpacity;
    });
  }

  void _openAddShiftFromCenterButton() {
    if (_selectedIndex != 0) {
      setState(() {
        _selectedIndex = 0;
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduleKey.currentState?._showAddShiftDialog();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1B2433),
      extendBody: true,
      body: SizedBox.expand(
        child: IndexedStack(
          index: _selectedIndex,
          children: [
            ShiftTrackerHome(
              key: _scheduleKey,
              showSalaryShortcut: false,
              nickname: widget.nickname,
              onScrollOffsetChanged: _handleScheduleScrollOffset,
            ),
            const SalaryRecordsScreen(),
            const AboutScreen(),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: Transform.translate(
        offset: const Offset(0, -18),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          opacity: _selectedIndex == 0 ? _scheduleFabOpacity : 1.0,
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF243B77).withValues(alpha: 0.28),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: FloatingActionButton(
              elevation: 0,
              backgroundColor: const Color(0xFF243B77),
              shape: const CircleBorder(),
              onPressed: _openAddShiftFromCenterButton,
              child: const Icon(Icons.add, size: 34, color: Colors.white),
            ),
          ),
        ),
      ),
      bottomNavigationBar: SizedBox(
        width: double.infinity,
        child: Container(
          width: double.infinity,
          color: const Color(0xFF1B2433),
          child: SafeArea(
            top: false,
            child: Container(
              width: double.infinity,
              height: 84,
              decoration: const BoxDecoration(
                color: Color(0xFF1B2433),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(22),
                  topRight: Radius.circular(22),
                ),
                border: Border(top: BorderSide(color: Color(0x33566C96))),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: _BottomNavItem(
                          icon: Icons.calendar_today_rounded,
                          label: 'Schedule',
                          selected: _selectedIndex == 0,
                          onTap: () {
                            setState(() {
                              _selectedIndex = 0;
                            });
                          },
                        ),
                      ),
                    ),
                    Expanded(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: _BottomNavItem(
                          icon: Icons.receipt_long_rounded,
                          label: 'Salary',
                          selected: _selectedIndex == 1,
                          onTap: () {
                            setState(() {
                              _selectedIndex = 1;
                            });
                          },
                        ),
                      ),
                    ),
                    Expanded(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: _BottomNavItem(
                          icon: Icons.info_outline_rounded,
                          label: 'About',
                          selected: _selectedIndex == 2,
                          onTap: () {
                            setState(() {
                              _selectedIndex = 2;
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final activeColor = const Color(0xFF6D5DD3);
    final inactiveColor = const Color(0xFFC8D2E3);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 170),
          curve: Curves.easeOut,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? const Color(0x26394A68) : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: selected
                ? Border.all(color: const Color(0x33566C96))
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 20,
                color: selected ? activeColor : inactiveColor,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  height: 1.0,
                  fontWeight: FontWeight.w600,
                  color: selected ? activeColor : inactiveColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PayPeriodRange {
  const _PayPeriodRange({
    required this.start,
    required this.end,
    required this.type,
  });

  final DateTime start;
  final DateTime end;
  final String type;
}

class ShiftTrackerHome extends StatefulWidget {
  const ShiftTrackerHome({
    super.key,
    this.showSalaryShortcut = true,
    this.nickname,
    this.onScrollOffsetChanged,
  });

  final bool showSalaryShortcut;
  final String? nickname;
  final ValueChanged<double>? onScrollOffsetChanged;

  @override
  State<ShiftTrackerHome> createState() => _ShiftTrackerHomeState();
}

class _ShiftTrackerHomeState extends State<ShiftTrackerHome>
    with WidgetsBindingObserver {
  final _overtimeController = TextEditingController();
  final _rateController = TextEditingController();
  final _startTimeController = TextEditingController();
  final _endTimeController = TextEditingController();
  Timer? _greetingTimer;
  Timer? _persistentAlarmTimer;
  DateTime _selectedDate = DateTime.now();
  String _selectedShiftType = 'Opening Shift';
  String _specialPay = 'Normal';
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  String _alarmMethod = 'Sound + Notification';
  String _alarmRingtone = 'Classic Bell';
  int _alarmLeadMinutes = 30;
  List<Shift> _shifts = [];
  int _completedShiftCount = 0;
  double _completedShiftHours = 0.0;
  double _completedShiftSalary = 0.0;
  double _ratePerHour = 15.0;
  double _overtimeMultiplier = 1.5;
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final Set<String> _triggeredAlarmKeys = <String>{};
  bool _isCheckingDueAlarms = false;

  final List<String> _shiftTypes = [
    'Opening Shift',
    'Mid Shift',
    'Closing Shift',
    'Graveyard Shift',
  ];

  final List<String> _specialPayOptions = ['Normal', 'Double Pay', '+30%'];
  final List<String> _alarmMethods = const [
    'Notification only',
    'Sound + Notification',
    'Vibration + Sound',
    'Persistent alarm',
  ];
  final List<String> _ringtones = const [
    'Classic Bell',
    'Digital Beep',
    'Soft Chime',
    'Loud Siren',
  ];
  final List<int> _leadMinuteOptions = const [5, 10, 15, 30, 60, 120];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _applyDefaultShiftTimes(_selectedShiftType);
    _startGreetingTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onScrollOffsetChanged?.call(0);
    });
    _loadData();
  }

  void _startGreetingTimer() {
    _greetingTimer?.cancel();
    _greetingTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted) return;
      setState(() {});
      _checkDueShiftAlarms();
    });
  }

  Future<void> _loadData() async {
    await _loadRate();
    await _loadOvertimeMultiplier();
    await _loadAlarmSettings();
    await _checkAndResetPayPeriod();
    await _loadShifts();
    await _checkDueShiftAlarms();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkDueShiftAlarms();
    }
  }

  Future<void> _loadAlarmSettings() async {
    final method = await _dbHelper.getSettingValue('alarmMethod');
    final ringtone = await _dbHelper.getSettingValue('alarmRingtone');
    final leadMinutes = await _dbHelper.getSettingValue('alarmLeadMinutes');
    final parsedLead = int.tryParse(leadMinutes ?? '');

    if (!mounted) return;
    setState(() {
      if (method != null && _alarmMethods.contains(method)) {
        _alarmMethod = method;
      }
      if (ringtone != null && _ringtones.contains(ringtone)) {
        _alarmRingtone = ringtone;
      }
      if (parsedLead != null && _leadMinuteOptions.contains(parsedLead)) {
        _alarmLeadMinutes = parsedLead;
      }
    });
  }

  DateTime _shiftStartDateTime(Shift shift) {
    final date = shift.date;
    final startMinutes = shift.startMinutes;
    if (startMinutes != null) {
      return DateTime(
        date.year,
        date.month,
        date.day,
      ).add(Duration(minutes: startMinutes));
    }

    final defaults = _defaultTimesForShiftType(shift.shiftType);
    return DateTime(
      date.year,
      date.month,
      date.day,
      defaults.$1.hour,
      defaults.$1.minute,
    );
  }

  String _alarmKeyForShift(Shift shift) {
    final start = _shiftStartDateTime(shift);
    final reminderAt = start.subtract(Duration(minutes: _alarmLeadMinutes));
    final shiftKey =
        shift.id?.toString() ??
        '${shift.date.toIso8601String()}-${shift.shiftType}-${shift.startMinutes ?? 'default'}';
    return '$shiftKey|${reminderAt.toIso8601String()}';
  }

  SystemSoundType _soundTypeForRingtone(String ringtone) {
    return ringtone == 'Soft Chime'
        ? SystemSoundType.click
        : SystemSoundType.alert;
  }

  List<Duration> _ringtoneIntervals(String ringtone) {
    switch (ringtone) {
      case 'Digital Beep':
        return const [
          Duration.zero,
          Duration(milliseconds: 180),
          Duration(milliseconds: 180),
        ];
      case 'Soft Chime':
        return const [Duration.zero];
      case 'Loud Siren':
        return const [
          Duration.zero,
          Duration(milliseconds: 240),
          Duration(milliseconds: 240),
          Duration(milliseconds: 240),
        ];
      case 'Classic Bell':
      default:
        return const [Duration.zero, Duration(milliseconds: 280)];
    }
  }

  Future<void> _playRingtone(String ringtone) async {
    final soundType = _soundTypeForRingtone(ringtone);
    final intervals = _ringtoneIntervals(ringtone);

    for (var index = 0; index < intervals.length; index++) {
      if (index > 0) {
        await Future<void>.delayed(intervals[index]);
      }
      await SystemSound.play(soundType);
    }
  }

  Future<void> _playAlarmEffects({
    required String method,
    required String ringtone,
  }) async {
    if (method == 'Notification only') return;

    await _playRingtone(ringtone);

    if (method == 'Vibration + Sound' || method == 'Persistent alarm') {
      await HapticFeedback.mediumImpact();
      await HapticFeedback.vibrate();
    }
  }

  void _stopPersistentAlarm() {
    _persistentAlarmTimer?.cancel();
    _persistentAlarmTimer = null;
  }

  void _startPersistentAlarm({
    required String ringtone,
    bool includeVibration = true,
  }) {
    _stopPersistentAlarm();
    _persistentAlarmTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      _playRingtone(ringtone);
      if (includeVibration) {
        HapticFeedback.vibrate();
      }
    });
  }

  String _shiftAlarmTitle(Shift shift) {
    final shiftLabel = shift.shiftType.replaceAll(' Shift', '');
    return '$shiftLabel shift reminder';
  }

  String _shiftAlarmMessage(Shift shift) {
    final start = _shiftStartDateTime(shift);
    final formattedStart = DateFormat('EEE, MMM d - h:mm a').format(start);
    return 'Your ${shift.shiftType.replaceAll(' Shift', '')} shift starts at $formattedStart.';
  }

  void _showNotificationOnlyReminder(Shift shift) {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(_shiftAlarmMessage(shift)),
          duration: const Duration(seconds: 6),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Future<void> _showInteractiveAlarmDialog({
    required String title,
    required String message,
    required String method,
    required String ringtone,
    String dismissLabel = 'Dismiss',
  }) async {
    final isPersistent = method == 'Persistent alarm';
    await _playAlarmEffects(method: method, ringtone: ringtone);
    if (isPersistent) {
      _startPersistentAlarm(ringtone: ringtone);
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: !isPersistent,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0x1AFFFFFF),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0x33FFFFFF)),
                ),
                child: Text(
                  'Method: $method\nRingtone: $ringtone',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFFC8D2E3),
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(dismissLabel),
            ),
          ],
        );
      },
    );

    _stopPersistentAlarm();
  }

  Future<void> _triggerReminderForShift(Shift shift) async {
    if (!mounted) return;

    if (_alarmMethod == 'Notification only') {
      _showNotificationOnlyReminder(shift);
      return;
    }

    await _showInteractiveAlarmDialog(
      title: _shiftAlarmTitle(shift),
      message: _shiftAlarmMessage(shift),
      method: _alarmMethod,
      ringtone: _alarmRingtone,
    );
  }

  Future<void> _previewAlarmMethod({
    required String method,
    required String ringtone,
    required int leadMinutes,
  }) async {
    if (!mounted) return;

    if (method == 'Notification only') {
      final messenger = ScaffoldMessenger.of(context);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'Preview: you will get a quiet reminder banner $leadMinutes minutes before your shift.',
            ),
            duration: const Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
          ),
        );
      return;
    }

    await _showInteractiveAlarmDialog(
      title: 'Alarm preview',
      message:
          'This is how "$method" will alert you $leadMinutes minutes before a shift.',
      method: method,
      ringtone: ringtone,
      dismissLabel: method == 'Persistent alarm' ? 'Stop preview' : 'Close',
    );
  }

  Future<void> _checkDueShiftAlarms() async {
    if (!mounted || _isCheckingDueAlarms || _shifts.isEmpty) return;

    _isCheckingDueAlarms = true;
    try {
      final now = DateTime.now();
      final dueShifts =
          _shifts.where((shift) {
            if (shift.isCompleted) return false;

            final start = _shiftStartDateTime(shift);
            final reminderAt = start.subtract(
              Duration(minutes: _alarmLeadMinutes),
            );
            if (now.isBefore(reminderAt) || !now.isBefore(start)) {
              return false;
            }

            return !_triggeredAlarmKeys.contains(_alarmKeyForShift(shift));
          }).toList()..sort(
            (a, b) => _shiftStartDateTime(a).compareTo(_shiftStartDateTime(b)),
          );

      for (final shift in dueShifts) {
        _triggeredAlarmKeys.add(_alarmKeyForShift(shift));
        await _triggerReminderForShift(shift);
      }
    } finally {
      _isCheckingDueAlarms = false;
    }
  }

  Future<void> _showAlarmSettingsDialog() async {
    String selectedMethod = _alarmMethod;
    String selectedRingtone = _alarmRingtone;
    int selectedLeadMinutes = _alarmLeadMinutes;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Alarm Settings'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: selectedRingtone,
                      decoration: const InputDecoration(
                        labelText: 'Ringtone',
                        border: OutlineInputBorder(),
                      ),
                      items: _ringtones
                          .map(
                            (ringtone) => DropdownMenuItem(
                              value: ringtone,
                              child: Text(ringtone),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() {
                          selectedRingtone = value;
                        });
                      },
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<int>(
                      initialValue: selectedLeadMinutes,
                      decoration: const InputDecoration(
                        labelText: 'Remind me before shift',
                        border: OutlineInputBorder(),
                      ),
                      items: _leadMinuteOptions
                          .map(
                            (minutes) => DropdownMenuItem(
                              value: minutes,
                              child: Text('$minutes minutes'),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() {
                          selectedLeadMinutes = value;
                        });
                      },
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Alarm method',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    ..._alarmMethods.map(
                      (method) => RadioListTile<String>(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: Text(method),
                        value: method,
                        groupValue: selectedMethod,
                        onChanged: (value) {
                          if (value == null) return;
                          setDialogState(() {
                            selectedMethod = value;
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0x1AFFFFFF),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0x33FFFFFF)),
                      ),
                      child: const Text(
                        'Typical alarm methods:\n'
                        '- Notification only: quiet reminder banner.\n'
                        '- Sound + Notification: standard phone alarm style.\n'
                        '- Vibration + Sound: better when phone is in pocket.\n'
                        '- Persistent alarm: repeats until dismissed.\n\n'
                        'Reminders trigger while the app is open.',
                        style: TextStyle(fontSize: 12.5),
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () => _previewAlarmMethod(
                        method: selectedMethod,
                        ringtone: selectedRingtone,
                        leadMinutes: selectedLeadMinutes,
                      ),
                      icon: const Icon(Icons.play_circle_outline_rounded),
                      label: const Text('Test current alarm'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    await _dbHelper.setSettingValue(
                      'alarmMethod',
                      selectedMethod,
                    );
                    await _dbHelper.setSettingValue(
                      'alarmRingtone',
                      selectedRingtone,
                    );
                    await _dbHelper.setSettingValue(
                      'alarmLeadMinutes',
                      selectedLeadMinutes.toString(),
                    );

                    if (!mounted) return;
                    setState(() {
                      _alarmMethod = selectedMethod;
                      _alarmRingtone = selectedRingtone;
                      _alarmLeadMinutes = selectedLeadMinutes;
                    });
                    Navigator.pop(dialogContext);
                    await _checkDueShiftAlarms();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Alarm saved: $_alarmMethod, $_alarmRingtone, $_alarmLeadMinutes min before shift.',
                        ),
                      ),
                    );
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _loadRate() async {
    final rate = await _dbHelper.getRatePerHour();
    setState(() {
      _ratePerHour = rate;
    });
  }

  Future<void> _loadOvertimeMultiplier() async {
    final multiplier = await _dbHelper.getOvertimeMultiplier();
    setState(() {
      _overtimeMultiplier = multiplier;
    });
  }

  Future<void> _checkAndResetPayPeriod() async {
    final now = DateTime.now();
    final currentPeriod = _payPeriodForDate(now);
    final completedShifts = await _dbHelper.getCompletedShifts();
    final shiftsToArchive = completedShifts
        .where((shift) => shift.date.isBefore(currentPeriod.start))
        .toList();

    if (shiftsToArchive.isEmpty) {
      await _dbHelper.updateLastPeriodCheck(now);
      return;
    }

    final groupedPeriods = <String, _PayPeriodRange>{};
    final groupedShifts = <String, List<Shift>>{};

    for (final shift in shiftsToArchive) {
      final period = _payPeriodForDate(shift.date);
      final key =
          '${period.start.toIso8601String()}|${period.end.toIso8601String()}';

      groupedPeriods[key] = period;
      groupedShifts.putIfAbsent(key, () => []).add(shift);
    }

    final sortedKeys = groupedPeriods.keys.toList()
      ..sort(
        (a, b) => groupedPeriods[a]!.start.compareTo(groupedPeriods[b]!.start),
      );

    int archivedPeriodCount = 0;
    String? latestArchivedLabel;
    double latestArchivedTotal = 0.0;

    for (final key in sortedKeys) {
      final period = groupedPeriods[key]!;
      final periodShifts = groupedShifts[key]!
        ..sort((a, b) => a.date.compareTo(b.date));

      final totalHours = periodShifts.fold(
        0.0,
        (sum, shift) => sum + shift.hoursWorked,
      );
      final totalSalary = periodShifts.fold(
        0.0,
        (sum, shift) =>
            sum + shift.calculateSalary(_ratePerHour, _overtimeMultiplier),
      );

      final record = SalaryRecord(
        periodStart: period.start,
        periodEnd: period.end,
        totalHours: totalHours,
        ratePerHour: _ratePerHour,
        totalSalary: totalSalary,
        shiftCount: periodShifts.length,
        periodType: period.type,
      );

      final recordId = await _dbHelper.insertSalaryRecord(record);

      for (final shift in periodShifts) {
        await _dbHelper.insertArchivedShift(recordId, shift);
        if (shift.id != null) {
          await _dbHelper.deleteShift(shift.id!);
        }
      }

      archivedPeriodCount++;
      latestArchivedLabel = _formatPayPeriodLabel(period);
      latestArchivedTotal = totalSalary;
    }

    await _dbHelper.updateLastPeriodCheck(now);

    if (mounted && latestArchivedLabel != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            archivedPeriodCount == 1
                ? 'Cutoff saved for $latestArchivedLabel. Estimated salary: ₱${latestArchivedTotal.toStringAsFixed(2)}'
                : 'Saved $archivedPeriodCount cutoff records. Latest period: $latestArchivedLabel',
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _greetingTimer?.cancel();
    _stopPersistentAlarm();
    _overtimeController.dispose();
    _rateController.dispose();
    _startTimeController.dispose();
    _endTimeController.dispose();
    super.dispose();
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour12 = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute;
    final suffix = time.period == DayPeriod.am ? 'am' : 'pm';
    if (minute == 0) return '$hour12$suffix';
    final mm = minute.toString().padLeft(2, '0');
    return '$hour12:$mm$suffix';
  }

  String _timeGreeting(DateTime dateTime) {
    final hour = dateTime.hour;
    if (hour >= 18) return 'Good evening';
    if (hour >= 12) return 'Good afternoon';
    return 'Good morning';
  }

  IconData _timeGreetingIcon(DateTime dateTime) {
    final hour = dateTime.hour;
    if (hour >= 18) return Icons.nights_stay_rounded;
    if (hour >= 12) return Icons.light_mode_rounded;
    return Icons.wb_sunny_rounded;
  }

  int _minutesFromTimeOfDay(TimeOfDay time) => time.hour * 60 + time.minute;

  (TimeOfDay start, TimeOfDay end) _defaultTimesForShiftType(String shiftType) {
    final normalized = shiftType.toLowerCase();
    if (normalized.contains('opening')) {
      return (
        const TimeOfDay(hour: 6, minute: 0),
        const TimeOfDay(hour: 12, minute: 0),
      );
    }
    if (normalized.contains('mid')) {
      return (
        const TimeOfDay(hour: 12, minute: 0),
        const TimeOfDay(hour: 18, minute: 0),
      );
    }
    if (normalized.contains('closing')) {
      return (
        const TimeOfDay(hour: 18, minute: 0),
        const TimeOfDay(hour: 0, minute: 0),
      );
    }
    if (normalized.contains('graveyard')) {
      return (
        const TimeOfDay(hour: 0, minute: 0),
        const TimeOfDay(hour: 6, minute: 0),
      );
    }
    return (
      const TimeOfDay(hour: 9, minute: 0),
      const TimeOfDay(hour: 15, minute: 0),
    );
  }

  void _applyDefaultShiftTimes(String shiftType) {
    final defaults = _defaultTimesForShiftType(shiftType);
    _startTime = defaults.$1;
    _endTime = defaults.$2;
    _startTimeController.text = _formatTimeOfDay(_startTime!);
    _endTimeController.text = _formatTimeOfDay(_endTime!);
  }

  double _baseHoursFromTimes(TimeOfDay start, TimeOfDay end) {
    final startMinutes = _minutesFromTimeOfDay(start);
    final endMinutes = _minutesFromTimeOfDay(end);
    var delta = endMinutes - startMinutes;
    if (delta <= 0) delta += 24 * 60;
    return delta / 60.0;
  }

  Future<void> _loadShifts() async {
    final shifts = await _dbHelper.getActiveShifts();
    final completedShifts = await _dbHelper.getCompletedShifts();
    final completedCount = completedShifts.length;
    final completedHours = completedShifts.fold(
      0.0,
      (sum, shift) => sum + shift.hoursWorked,
    );
    final completedSalary = completedShifts.fold(
      0.0,
      (sum, shift) =>
          sum + shift.calculateSalary(_ratePerHour, _overtimeMultiplier),
    );
    if (!mounted) return;
    setState(() {
      _shifts = shifts;
      _completedShiftCount = completedCount;
      _completedShiftHours = completedHours;
      _completedShiftSalary = completedSalary;
    });
    await _checkDueShiftAlarms();
  }

  String _formatHours(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(1);
  }

  String _formatCurrencyCompact(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(2);
  }

  _PayPeriodRange _payPeriodForDate(DateTime date) {
    if (date.day <= 15) {
      return _PayPeriodRange(
        start: DateTime(date.year, date.month, 1),
        end: DateTime(date.year, date.month, 15, 23, 59, 59),
        type: '1-15',
      );
    }

    final lastDay = DateTime(date.year, date.month + 1, 0).day;
    return _PayPeriodRange(
      start: DateTime(date.year, date.month, 16),
      end: DateTime(date.year, date.month, lastDay, 23, 59, 59),
      type: '16-end',
    );
  }

  String _formatPayPeriodLabel(_PayPeriodRange period) {
    if (period.start.month == period.end.month &&
        period.start.year == period.end.year) {
      final monthName = DateFormat('MMM').format(period.start);
      return '$monthName ${period.start.day}-${period.end.day}, ${period.start.year}';
    }

    return '${DateFormat('MMM dd, yyyy').format(period.start)} - ${DateFormat('MMM dd, yyyy').format(period.end)}';
  }

  DateTime _shiftEndDateTime(Shift shift) {
    final date = shift.date;
    final normalized = shift.shiftType.toLowerCase();

    if (normalized.contains('opening')) {
      return DateTime(date.year, date.month, date.day, 12);
    }
    if (normalized.contains('mid')) {
      return DateTime(date.year, date.month, date.day, 18);
    }
    if (normalized.contains('closing')) {
      return DateTime(
        date.year,
        date.month,
        date.day,
      ).add(const Duration(days: 1));
    }
    if (normalized.contains('graveyard')) {
      return DateTime(date.year, date.month, date.day, 6);
    }

    return DateTime(
      date.year,
      date.month,
      date.day,
    ).add(Duration(hours: shift.hoursWorked.round()));
  }

  bool _canCompleteShift(Shift shift) {
    if (shift.id == null) return false;
    return DateTime.now().isAfter(_shiftEndDateTime(shift));
  }

  Future<double?> _promptExtraWorkedHours() async {
    final controller = TextEditingController();
    String? errorText;

    final value = await showDialog<double>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Added work hours'),
              content: TextFormField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'How many hours were added?',
                  hintText: 'e.g. 0.5',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.timer_outlined),
                  errorText: errorText,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final parsed = double.tryParse(controller.text.trim());
                    if (parsed == null || parsed <= 0) {
                      setDialogState(() {
                        errorText = 'Enter a number greater than 0';
                      });
                      return;
                    }
                    Navigator.pop(dialogContext, parsed);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    controller.dispose();
    return value;
  }

  Future<void> _completeShift(Shift shift) async {
    if (shift.id == null) return;

    final hasAddedHours = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Complete shift'),
        content: const Text('Has anything been added to its workings?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (hasAddedHours == null) return;

    double extraHours = 0;
    if (hasAddedHours) {
      final entered = await _promptExtraWorkedHours();
      if (!mounted) return;
      if (entered == null) return;
      extraHours = entered;
    }

    final completedAt = DateTime.now();
    final newHoursWorked = shift.hoursWorked + extraHours;
    final newOvertimeHours = shift.overtimeHours + extraHours;

    await _dbHelper.markShiftCompletedWithHours(
      shift.id!,
      completedAt: completedAt,
      hoursWorked: newHoursWorked,
      overtimeHours: newOvertimeHours,
    );
    await _loadShifts();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Shift moved to history.')));
  }

  double _defaultRegularHours(String shiftType) {
    final normalized = shiftType.toLowerCase();
    if (normalized.contains('opening')) return 6.0;
    if (normalized.contains('mid')) return 6.0;
    if (normalized.contains('closing')) return 6.0;
    if (normalized.contains('graveyard')) return 6.0;
    return 6.0;
  }

  Future<void> _addShift() async {
    final start = _startTime;
    final end = _endTime;
    final baseHours = (start != null && end != null)
        ? _baseHoursFromTimes(start, end)
        : _defaultRegularHours(_selectedShiftType);

    final extraHours = _overtimeController.text.isEmpty
        ? 0.0
        : (double.tryParse(_overtimeController.text) ?? 0.0);
    final totalHours = baseHours + extraHours;

    final regularHours = totalHours <= 8 ? totalHours : 8.0;
    final overtimeHours = totalHours > 8 ? totalHours - 8.0 : 0.0;

    double specialPayMultiplier = 1.0;
    if (_specialPay == 'Double Pay') {
      specialPayMultiplier = 2.0;
    } else if (_specialPay == '+30%') {
      specialPayMultiplier = 1.3;
    }

    final shift = Shift(
      date: _selectedDate,
      startMinutes: start == null ? null : _minutesFromTimeOfDay(start),
      endMinutes: end == null ? null : _minutesFromTimeOfDay(end),
      hoursWorked: totalHours,
      shiftType: _selectedShiftType,
      regularHours: regularHours,
      overtimeHours: overtimeHours,
      isHoliday: false,
      specialPayMultiplier: specialPayMultiplier,
    );

    await _dbHelper.insertShift(shift);
    _overtimeController.clear();
    setState(() {
      _selectedDate = DateTime.now();
      _selectedShiftType = 'Opening Shift';
      _specialPay = 'Normal';
      _applyDefaultShiftTimes(_selectedShiftType);
    });
    await _loadShifts();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Shift added successfully!')),
      );
    }
  }

  Future<void> _deleteShift(int id) async {
    await _dbHelper.deleteShift(id);
    await _loadShifts();
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Shift deleted')));
    }
  }

  Future<void> _confirmDeleteShift(int id) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete shift?'),
        content: const Text('This action can\'t be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (shouldDelete != true) return;
    await _deleteShift(id);
  }

  double get _totalSalary {
    return _shifts.fold(
      0,
      (sum, shift) =>
          sum + shift.calculateSalary(_ratePerHour, _overtimeMultiplier),
    );
  }

  double get _averageSalary {
    if (_shifts.isEmpty) return 0;
    return _totalSalary / _shifts.length;
  }

  Future<void> _showEditRateDialog() async {
    _rateController.text = _ratePerHour.toStringAsFixed(2);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Rate Per Hour'),
        content: TextFormField(
          controller: _rateController,
          decoration: InputDecoration(
            labelText: 'Rate Per Hour',
            border: const OutlineInputBorder(),
            prefixIcon: Padding(
              padding: const EdgeInsets.all(12),
              child: Image.asset(
                'asset/peso.png',
                width: 20,
                height: 20,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const Text(
                  '₱',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newRate = double.tryParse(_rateController.text);
              if (newRate != null && newRate > 0) {
                await _dbHelper.updateRatePerHour(newRate);
                await _loadRate();
                await _loadShifts();
                if (!context.mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Rate updated successfully!')),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  String _getCurrentPeriodText() {
    final now = DateTime.now();
    final monthName = DateFormat('MMM').format(now);
    final year = now.year;

    if (now.day <= 15) {
      return 'Current Period: $monthName 1-15';
    } else {
      final lastDay = DateTime(year, now.month + 1, 0).day;
      return 'Current Period: $monthName 16-$lastDay';
    }
  }

  String _getCurrentPeriodShortText() {
    final now = DateTime.now();
    final monthName = DateFormat('MMM').format(now);
    final year = now.year;

    if (now.day <= 15) {
      return '$monthName 1-15, $year';
    } else {
      final lastDay = DateTime(year, now.month + 1, 0).day;
      return '$monthName 16-$lastDay, $year';
    }
  }

  bool _isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _shiftBadgeText(String shiftType) {
    final normalized = shiftType.toLowerCase();
    if (normalized.contains('opening')) return 'OP';
    if (normalized.contains('mid')) return 'M';
    if (normalized.contains('closing')) return 'C';
    if (normalized.contains('graveyard')) return 'GY';
    return 'S';
  }

  List<_SupplementItemData> _supplementItems() {
    if (_shifts.isEmpty) return [];

    final sortedShifts = [..._shifts]..sort((a, b) => a.date.compareTo(b.date));

    return sortedShifts.asMap().entries.map((entry) {
      final index = entry.key;
      final shift = entry.value;
      final shiftLabel = shift.shiftType.replaceAll(' Shift', '');
      final canComplete = _canCompleteShift(shift);
      return _SupplementItemData(
        id: shift.id,
        scheduleDate: shift.date,
        title: shiftLabel,
        subtitle: DateFormat('EEEE: MMMM dd yyyy').format(shift.date),
        timeText: _timeRangeForShift(shift),
        badgeText: _shiftBadgeText(shift.shiftType),
        isCompleted: shift.isCompleted,
        isAlert: !shift.isCompleted,
        canComplete: canComplete,
        onComplete: canComplete && shift.id != null
            ? () => _completeShift(shift)
            : null,
      );
    }).toList();
  }

  String _timeRangeForShift(Shift shift) {
    String formatTime(DateTime dateTime) {
      final formatted = DateFormat('h:mma').format(dateTime).toLowerCase();
      return formatted.replaceAll(':00', '');
    }

    (DateTime start, double baseHours)? startAndBaseHours() {
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

    final startAndBase = startAndBaseHours();
    if (startAndBase == null) {
      return '${shift.hoursWorked.toStringAsFixed(1)}h shift';
    }

    final start = startAndBase.$1;
    final baseHours = startAndBase.$2;

    final baseMinutes = (baseHours * 60).round();
    final baseEnd = start.add(Duration(minutes: baseMinutes));
    final extraHours = shift.hoursWorked - baseHours;

    final baseText = '${formatTime(start)} to ${formatTime(baseEnd)}';
    if (extraHours <= 0) return baseText;

    final formattedExtra = extraHours == extraHours.roundToDouble()
        ? extraHours.toStringAsFixed(0)
        : extraHours.toStringAsFixed(1);

    return '$baseText (+$formattedExtra hrs)';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final items = _supplementItems();
    final progressText = '$_completedShiftCount/15 shifts completed';
    final completedHoursText =
        '${_formatHours(_completedShiftHours)} hrs (₱${_formatCurrencyCompact(_completedShiftSalary)})';
    final now = DateTime.now();
    final greetingText = _timeGreeting(now);
    final greetingIcon = _timeGreetingIcon(now);
    final nickname = widget.nickname?.trim();
    final displayGreeting = nickname == null || nickname.isEmpty
        ? greetingText
        : '$greetingText, $nickname';
    final todayStart = DateTime(now.year, now.month, now.day);

    final todaysItems = items
        .where((item) => _isSameDate(item.scheduleDate, now))
        .toList();
    final nextItems = items
        .where((item) => item.scheduleDate.isAfter(todayStart))
        .toList();
    final previousItems = items
        .where((item) => item.scheduleDate.isBefore(todayStart))
        .toList();

    final nowSectionItems = todaysItems.isNotEmpty
        ? todaysItems
        : (previousItems.isNotEmpty
              ? [previousItems.last]
              : (items.isNotEmpty ? [items.first] : <_SupplementItemData>[]));
    final nextSectionItems = nextItems
        .where((item) => !nowSectionItems.contains(item))
        .toList();
    final notificationTitle = DateFormat('EEEE: MMMM dd yyyy').format(now);
    final notificationSubtitle = nowSectionItems.isEmpty
        ? 'No schedule today yet. Add one and set your reminder.'
        : nowSectionItems.length == 1
        ? 'You have 1 schedule today. Tap bell to set reminder.'
        : 'You have ${nowSectionItems.length} schedules today. Tap bell to set reminder.';

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Schedule'),
        actions: [
          IconButton(
            icon: const Icon(Icons.playlist_add_check_rounded),
            tooltip: 'Schedule History',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ScheduleHistoryScreen(),
                ),
              );
            },
          ),

          IconButton(
            icon: Image.asset(
              'asset/peso.png',
              width: 25,
              height: 25,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const Text(
                '₱',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFE5E7EB),
                ),
              ),
            ),
            tooltip: 'Edit Rate',
            onPressed: _showEditRateDialog,
          ),
          if (widget.showSalaryShortcut)
            IconButton(
              icon: const Icon(Icons.history),
              tooltip: 'Salary Records',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SalaryRecordsScreen(),
                  ),
                );
              },
            ),
        ],
      ),
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
            bottom: false,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    if (notification.metrics.axis == Axis.vertical) {
                      widget.onScrollOffsetChanged?.call(
                        notification.metrics.pixels
                            .clamp(0.0, double.infinity)
                            .toDouble(),
                      );
                    }
                    return false;
                  },
                  child: SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 128),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ScoreHeader(
                              icon: Icons.calendar_month_rounded,
                              title: 'Shift Progress',
                              subtitle: '$progressText\n$completedHoursText',
                            ),
                            const SizedBox(height: 24),
                            ActionNotificationCard(
                              title: notificationTitle,
                              subtitle: notificationSubtitle,
                              icon: Icons.notifications_rounded,
                              onTap: _showAlarmSettingsDialog,
                            ),
                            const SizedBox(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  greetingIcon,
                                  color: AppColors.accentYellow,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    displayGreeting,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          color: const Color(0xFFE5E7EB),
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            if (items.isEmpty)
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E2A3D),
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: const Color(0x33566C96),
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Container(
                                      width: 64,
                                      height: 64,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF24324A),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: const Icon(
                                        Icons.calendar_month_rounded,
                                        color: Color(0xFFC8D2E3),
                                        size: 30,
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    Text(
                                      'No schedules yet',
                                      style: textTheme.titleMedium?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Tap the + button below to add your first shift.',
                                      textAlign: TextAlign.center,
                                      style: textTheme.bodyMedium?.copyWith(
                                        color: const Color(0xFFC8D2E3),
                                        height: 1.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (nowSectionItems.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Text(
                                  'Your Schedule Now',
                                  style: textTheme.labelLarge?.copyWith(
                                    color: const Color(0xFFC8D2E3),
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ),
                            ...nowSectionItems.map(
                              (item) => Padding(
                                padding: const EdgeInsets.only(bottom: 14),
                                child: SupplementCard(
                                  badgeText: item.badgeText,
                                  title: item.title,
                                  subtitle: item.subtitle,
                                  timeText: item.timeText,
                                  isCompleted: item.isCompleted,
                                  isAlert: item.isAlert,
                                  canComplete: item.canComplete,
                                  onComplete: item.onComplete,
                                  onLongPress: item.id == null
                                      ? null
                                      : () => _confirmDeleteShift(item.id!),
                                ),
                              ),
                            ),
                            if (nextSectionItems.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(
                                  bottom: 10,
                                  top: 2,
                                ),
                                child: Text(
                                  'Next Schedule',
                                  style: textTheme.labelLarge?.copyWith(
                                    color: const Color(0xFFC8D2E3),
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ),
                            ...nextSectionItems.map(
                              (item) => Padding(
                                padding: const EdgeInsets.only(bottom: 14),
                                child: SupplementCard(
                                  badgeText: item.badgeText,
                                  title: item.title,
                                  subtitle: item.subtitle,
                                  timeText: item.timeText,
                                  isCompleted: item.isCompleted,
                                  isAlert: item.isAlert,
                                  canComplete: item.canComplete,
                                  onComplete: item.onComplete,
                                  onLongPress: item.id == null
                                      ? null
                                      : () => _confirmDeleteShift(item.id!),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showAddShiftDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Shift'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: const Text('Date'),
                  subtitle: Text(
                    DateFormat('MMM dd, yyyy').format(_selectedDate),
                  ),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () => _selectDate(context),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _selectedShiftType,
                  decoration: const InputDecoration(
                    labelText: 'Shift Type',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.work),
                  ),
                  items: _shiftTypes.map((String type) {
                    return DropdownMenuItem<String>(
                      value: type,
                      child: Text(type),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedShiftType = newValue!;
                      _applyDefaultShiftTimes(_selectedShiftType);
                    });
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _startTimeController,
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: 'Start shift',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.access_time),
                        ),
                        onTap: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime:
                                _startTime ??
                                const TimeOfDay(hour: 6, minute: 0),
                          );
                          if (picked == null) return;
                          if (!mounted) return;
                          setState(() {
                            _startTime = picked;
                            _startTimeController.text = _formatTimeOfDay(
                              picked,
                            );
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _endTimeController,
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: 'End shift',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.access_time_filled),
                        ),
                        onTap: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime:
                                _endTime ??
                                const TimeOfDay(hour: 12, minute: 0),
                          );
                          if (picked == null) return;
                          if (!mounted) return;
                          setState(() {
                            _endTime = picked;
                            _endTimeController.text = _formatTimeOfDay(picked);
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Set your start and end shift time to calculate manual hours.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _specialPay,
                  decoration: const InputDecoration(
                    labelText: 'Special Pay',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.monetization_on),
                  ),
                  items: _specialPayOptions.map((String option) {
                    return DropdownMenuItem<String>(
                      value: option,
                      child: Text(option),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _specialPay = newValue!;
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                _addShift();
                Navigator.pop(context);
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }
}

class _SupplementItemData {
  const _SupplementItemData({
    this.id,
    required this.scheduleDate,
    required this.title,
    required this.subtitle,
    required this.timeText,
    required this.badgeText,
    required this.isCompleted,
    required this.isAlert,
    this.canComplete = false,
    this.onComplete,
  });

  final int? id;
  final DateTime scheduleDate;
  final String title;
  final String subtitle;
  final String timeText;
  final String badgeText;
  final bool isCompleted;
  final bool isAlert;
  final bool canComplete;
  final VoidCallback? onComplete;
}

class ScoreHeader extends StatelessWidget {
  const ScoreHeader({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [AppColors.accentPurple, AppColors.accentPink],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: AppColors.accentPurple.withValues(alpha: 0.35),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 30),
        ),
        const SizedBox(height: 14),
        Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: const Color(0xFFE5E7EB),
            fontWeight: FontWeight.w800,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: const Color(0xFFE5E7EB)),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class ActionNotificationCard extends StatelessWidget {
  const ActionNotificationCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.accentYellow,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: const Color(0xFF151A22),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF2A3140),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  color: Color(0xFF1B2230),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SupplementCard extends StatelessWidget {
  const SupplementCard({
    super.key,
    required this.badgeText,
    required this.title,
    required this.subtitle,
    required this.timeText,
    required this.isCompleted,
    required this.isAlert,
    this.canComplete = false,
    this.onComplete,
    this.onLongPress,
  });

  final String badgeText;
  final String title;
  final String subtitle;
  final String timeText;
  final bool isCompleted;
  final bool isAlert;
  final bool canComplete;
  final VoidCallback? onComplete;
  final VoidCallback? onLongPress;

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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onLongPress: onLongPress,
          onSecondaryTap: onLongPress,
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
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            badgeText,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: badgeText.length > 1 ? 0.6 : 0,
                                ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: titleStyle),
                          const SizedBox(height: 6),
                          Text(subtitle, style: subtitleStyle),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 10, top: 2),
                      child: _StatusCircle(
                        isCompleted: isCompleted,
                        enabled:
                            canComplete && !isCompleted && onComplete != null,
                        onTap: onComplete,
                        onLongPress: onLongPress,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(color: Color(0x2EFFFFFF), height: 1.0),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.alarm_outlined,
                      size: 17,
                      color: const Color(0xFFAEB8CA),
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
        ),
      ),
    );
  }
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.text,
    required this.icon,
    required this.onTap,
  });

  final String text;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.accentYellow,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                text,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: const Color(0xFF151A22),
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 30,
                height: 30,
                decoration: const BoxDecoration(
                  color: Color(0xFF1B2230),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: AppColors.accentYellow, size: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusCircle extends StatelessWidget {
  const _StatusCircle({
    required this.isCompleted,
    this.enabled = false,
    this.onTap,
    this.onLongPress,
  });

  final bool isCompleted;
  final bool enabled;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

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

    final foregroundColor = enabled
        ? AppColors.accentYellow
        : AppColors.textMutedOnDark;

    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: foregroundColor, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check, size: 16, color: foregroundColor),
          const SizedBox(width: 6),
          Text(
            'Complete',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: foregroundColor,
              fontWeight: FontWeight.w700,
              height: 1.0,
            ),
          ),
        ],
      ),
    );

    if (!enabled || onTap == null) {
      return chip;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        onSecondaryTap: onLongPress,
        borderRadius: BorderRadius.circular(999),
        child: chip,
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
