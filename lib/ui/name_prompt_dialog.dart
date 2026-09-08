import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'view_icons.dart';

/// Prompt for a name (and, for Views, an icon from the curated set). Pass
/// [initialName]/[initialIcon] to prefill for a rename — the confirm button
/// then reads "Save" instead of "Create". Returns `(name, iconSlug)` or null
/// on cancel/empty.
Future<(String, String)?> promptName(
  BuildContext context,
  String title, {
  bool withIcon = false,
  String? initialName,
  String initialIcon = 'home',
}) async {
  final result = await showDialog<(String, String)>(
    context: context,
    builder: (_) => NamePromptDialog(
      title: title,
      withIcon: withIcon,
      initialName: initialName,
      initialIcon: initialIcon,
    ),
  );
  return (result != null && result.$1.isNotEmpty) ? result : null;
}

/// Owns its [TextEditingController] so it is disposed with the dialog's own
/// lifecycle — disposing right after `showDialog` resolves races the pop
/// transition, which may still be painting the field.
class NamePromptDialog extends StatefulWidget {
  const NamePromptDialog({
    super.key,
    required this.title,
    this.withIcon = false,
    this.initialName,
    this.initialIcon = 'home',
  });

  final String title;
  final bool withIcon;

  /// Prefill for renames; null = a fresh create.
  final String? initialName;
  final String initialIcon;

  @override
  State<NamePromptDialog> createState() => _NamePromptDialogState();
}

class _NamePromptDialogState extends State<NamePromptDialog> {
  late final _controller = TextEditingController(text: widget.initialName);
  late String _icon = widget.initialIcon;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.of(context).pop((_controller.text.trim(), _icon));

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(hintText: l10n.nameLabel),
            onSubmitted: (_) => _submit(),
          ),
          if (widget.withIcon) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                for (final e in viewIcons.entries)
                  IconButton(
                    tooltip: e.key,
                    isSelected: _icon == e.key,
                    onPressed: () => setState(() => _icon = e.key),
                    icon: Icon(e.value),
                    selectedIcon: Icon(e.value, color: scheme.primary),
                    style: IconButton.styleFrom(
                      backgroundColor: _icon == e.key
                          ? scheme.primaryContainer
                          : null,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(widget.initialName == null ? l10n.create : l10n.save),
        ),
      ],
    );
  }
}
