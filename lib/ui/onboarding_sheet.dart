import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/notification.dart';
import '../domain/recurrence.dart';
import '../domain/template.dart';
import '../l10n/app_localizations.dart';
import '../providers.dart';
import 'reminder_editor.dart';
import 'window_choice.dart';
import 'window_editor.dart';

/// First-run onboarding (PLAN Phase 8): its only job is to seed the **carrier**
/// — the one unavoidable daily habit that gets the app opened every day. No
/// tour, no permissions pitch; the sheet is freely dismissible (swipe away and
/// just use the app) and is offered exactly once — never re-nagged.
Future<void> showOnboardingSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _OnboardingSheet(),
  );
}

class _OnboardingSheet extends ConsumerStatefulWidget {
  const _OnboardingSheet();

  @override
  ConsumerState<_OnboardingSheet> createState() => _OnboardingSheetState();
}

class _OnboardingSheetState extends ConsumerState<_OnboardingSheet> {
  final _controller = TextEditingController();
  WindowSelection _window = WindowSelection.anytime;
  List<TaskNotification> _reminders = const [];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Creates the daily Template (the carrier) and reconciles, so the first
  /// instance is on the surface the moment the sheet closes.
  Future<void> _start() async {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    final repo = ref.read(taskRepositoryProvider);
    final now = ref.read(clockProvider).now();

    await repo.createTemplate(
      Template(
        name: name,
        recurrence: Recurrence.daily(DateTime(now.year, now.month, now.day)),
        windowRule: _window.toRule(),
        createdAt: now,
        notifications: _reminders,
      ),
    );
    await repo.reconcileAll(now);
    if (_reminders.isNotEmpty) await ensureNotificationPermission(ref);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 4, 16, viewInsets + 16),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '🦊',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 44),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.onboardingTitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                l10n.onboardingBody,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _controller,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: l10n.nameLabel,
                  hintText: l10n.onboardingNameHint,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 20),
              _SectionLabel(l10n.activeWindowSection),
              const SizedBox(height: 8),
              WindowEditor(
                value: _window,
                onChanged: (w) => setState(() => _window = w),
              ),
              const SizedBox(height: 20),
              _SectionLabel(l10n.remindersSection),
              const SizedBox(height: 8),
              ReminderEditor(
                value: _reminders,
                onChanged: (n) => setState(() => _reminders = n),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _controller.text.trim().isEmpty ? null : _start,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(l10n.onboardingStart),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: Theme.of(context).colorScheme.outline,
        fontWeight: FontWeight.w700,
        letterSpacing: .6,
      ),
    );
  }
}
