import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class WelcomeOnboardingScreen extends StatefulWidget {
  const WelcomeOnboardingScreen({
    super.key,
    required this.onContinue,
    this.initialNickname,
  });

  final String? initialNickname;
  final Future<void> Function(String? nickname) onContinue;

  @override
  State<WelcomeOnboardingScreen> createState() =>
      _WelcomeOnboardingScreenState();
}

class _WelcomeOnboardingScreenState extends State<WelcomeOnboardingScreen> {
  late final TextEditingController _nicknameController;
  bool _hasShownInitialPrompt = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nicknameController = TextEditingController(
      text: widget.initialNickname ?? '',
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _hasShownInitialPrompt) return;
      _hasShownInitialPrompt = true;
      _showNicknamePrompt();
    });
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _showNicknamePrompt() async {
    final dialogController = TextEditingController(
      text: _nicknameController.text,
    );

    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Add a nickname?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This is optional. If you add one, the app can greet you a little more personally.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 14),
              TextField(
                controller: dialogController,
                autofocus: true,
                maxLength: 18,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Nickname',
                  hintText: 'Example: Alex',
                ),
                onSubmitted: (value) {
                  Navigator.pop(dialogContext, value.trim());
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, ''),
              child: const Text('Skip'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext, dialogController.text.trim());
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    dialogController.dispose();

    if (!mounted || result == null) return;
    setState(() {
      _nicknameController.text = result.trim();
    });
  }

  Future<void> _continueToApp() async {
    if (_isSaving) return;

    setState(() {
      _isSaving = true;
    });

    try {
      await widget.onContinue(_nicknameController.text.trim());
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final nickname = _nicknameController.text.trim();

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
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 84,
                          height: 84,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [
                                AppColors.accentPurple,
                                AppColors.accentPink,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.accentPurple.withValues(
                                  alpha: 0.32,
                                ),
                                blurRadius: 22,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.calendar_month_rounded,
                            size: 38,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Welcome to Shift Tracker',
                        textAlign: TextAlign.center,
                        style: textTheme.headlineMedium?.copyWith(
                          color: const Color(0xFFE5E7EB),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Track your shifts, keep an eye on completed hours, and save cutoff salary records in one place.',
                        textAlign: TextAlign.center,
                        style: textTheme.bodyLarge?.copyWith(
                          color: const Color(0xFFC8D2E3),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 22),
                      _WelcomeCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'What you can do here',
                              style: textTheme.titleMedium?.copyWith(
                                color: const Color(0xFFE5E7EB),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 14),
                            const _WelcomeFeatureRow(
                              icon: Icons.schedule_rounded,
                              title: 'Track daily shifts',
                              subtitle:
                                  'Organize opening, mid, closing, and graveyard schedules.',
                            ),
                            const SizedBox(height: 12),
                            const _WelcomeFeatureRow(
                              icon: Icons.task_alt_rounded,
                              title: 'Log completed work',
                              subtitle:
                                  'Keep completed shifts and total hours up to date.',
                            ),
                            const SizedBox(height: 12),
                            const _WelcomeFeatureRow(
                              icon: Icons.receipt_long_rounded,
                              title: 'Save salary cutoffs',
                              subtitle:
                                  'Archive completed pay periods into salary records.',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      _WelcomeCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Nickname',
                                  style: textTheme.titleSmall?.copyWith(
                                    color: const Color(0xFFE5E7EB),
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0x26394A68),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: const Color(0x33566C96),
                                    ),
                                  ),
                                  child: Text(
                                    'Optional',
                                    style: textTheme.labelMedium?.copyWith(
                                      color: const Color(0xFFC8D2E3),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              nickname.isEmpty
                                  ? 'You can keep it blank for now, or add one for a more personal greeting in the app.'
                                  : 'Nice to meet you, $nickname. We will use it in your welcome greeting.',
                              style: textTheme.bodyMedium?.copyWith(
                                color: const Color(0xFFC8D2E3),
                                height: 1.45,
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextButton.icon(
                              onPressed: _showNicknamePrompt,
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              label: Text(
                                nickname.isEmpty
                                    ? 'Add nickname'
                                    : 'Edit nickname',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      FilledButton.icon(
                        onPressed: _isSaving ? null : _continueToApp,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.arrow_forward_rounded),
                        label: Text(
                          _isSaving ? 'Opening app...' : 'Start tracking',
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'This welcome step shows only on your first launch.',
                        textAlign: TextAlign.center,
                        style: textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF97A6BE),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0x26344766),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0x33566C96)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x44000000),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _WelcomeFeatureRow extends StatelessWidget {
  const _WelcomeFeatureRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: const Color(0x26394A68),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, size: 18, color: AppColors.accentYellow),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: textTheme.titleSmall?.copyWith(
                  color: const Color(0xFFE5E7EB),
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: textTheme.bodySmall?.copyWith(
                  color: const Color(0xFFC8D2E3),
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
