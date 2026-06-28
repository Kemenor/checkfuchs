import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers.dart';

/// Vacation periods (design-concept §6) — schedule time away in advance.
/// Pauses recurring generation while active; hard deadlines still pass.
class VacationScreen extends ConsumerWidget {
  const VacationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vacations = ref.watch(vacationsProvider);
    final fmt = DateFormat.MMMd();

    return Scaffold(
      appBar: AppBar(title: const Text('Vacation')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Vacation pauses your recurring tasks for the dates you pick — no '
              'missed-habit pile-up while you\'re away. Real deadlines still pass.',
              style: TextStyle(color: Theme.of(context).colorScheme.outline),
            ),
          ),
          Expanded(
            child: vacations.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('$e')),
              data: (list) => list.isEmpty
                  ? Center(
                      child: Text('No vacations scheduled',
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.outline)))
                  : ListView(
                      children: [
                        for (final v in list)
                          ListTile(
                            leading: const Icon(Icons.beach_access_outlined),
                            title: Text('${fmt.format(v.start)} – ${fmt.format(v.end)}'),
                            trailing: IconButton(
                              icon: Icon(Icons.delete_outline,
                                  color: Theme.of(context).colorScheme.error),
                              onPressed: () async {
                                await ref
                                    .read(taskRepositoryProvider)
                                    .deleteVacation(v.id);
                                await ref.read(taskRepositoryProvider).reconcileAll(
                                    ref.read(clockProvider).now());
                              },
                            ),
                          ),
                      ],
                    ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'addVacation',
        onPressed: () => _add(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
    );
  }

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final now = ref.read(clockProvider).now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 3),
    );
    if (range == null) return;
    final repo = ref.read(taskRepositoryProvider);
    await repo.addVacation(
      DateTime(range.start.year, range.start.month, range.start.day),
      DateTime(range.end.year, range.end.month, range.end.day, 23, 59),
    );
    await repo.reconcileAll(ref.read(clockProvider).now());
  }
}
