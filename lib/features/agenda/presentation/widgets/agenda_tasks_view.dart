import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/agenda_providers.dart';
import '../../domain/models/agenda_models.dart';

class AgendaTasksView extends ConsumerStatefulWidget {
  const AgendaTasksView({super.key});

  @override
  ConsumerState<AgendaTasksView> createState() => _AgendaTasksViewState();
}

class _AgendaTasksViewState extends ConsumerState<AgendaTasksView> {
  String _selectedFilter = 'active'; // 'all', 'active', 'done'

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    String? statusFilter;
    if (_selectedFilter == 'done') {
      statusFilter = 'done';
    } else if (_selectedFilter == 'active') {
      // Custom filter handled in UI or query
    }

    final tasksAsync = ref.watch(tasksStreamProvider(TaskFilterParams(
      status: statusFilter,
    )));

    return Column(
      children: [
        // Filter Segmented Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'active', label: Text('Tugas Aktif')),
              ButtonSegment(value: 'done', label: Text('Selesai')),
              ButtonSegment(value: 'all', label: Text('Semua')),
            ],
            selected: {_selectedFilter},
            onSelectionChanged: (val) => setState(() => _selectedFilter = val.first),
          ),
        ),
        const Divider(height: 1),

        // List of Tasks
        Expanded(
          child: tasksAsync.when(
            data: (allTasks) {
              final tasks = allTasks.where((item) {
                if (_selectedFilter == 'active') {
                  return item.task.status != 'done';
                }
                if (_selectedFilter == 'done') {
                  return item.task.status == 'done';
                }
                return true;
              }).toList();

              if (tasks.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.checklist_rtl, size: 64, color: theme.colorScheme.outlineVariant),
                      const SizedBox(height: 16),
                      Text(
                        _selectedFilter == 'done'
                            ? 'Belum ada tugas selesai'
                            : 'Tidak ada tugas yang tertunda!',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Semua tugas beres! Kerja bagus! 🎉',
                        style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: tasks.length,
                itemBuilder: (context, index) {
                  final item = tasks[index];
                  return _TaskCard(taskItem: item);
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('Gagal memuat tugas: $err')),
          ),
        ),
      ],
    );
  }
}

class _TaskCard extends ConsumerWidget {
  final TaskWithSubtasks taskItem;

  const _TaskCard({required this.taskItem});

  Color _priorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return Colors.red;
      case 'low':
        return Colors.grey;
      case 'normal':
      default:
        return Colors.blue;
    }
  }

  String _priorityLabel(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return 'Tinggi';
      case 'low':
        return 'Rendah';
      case 'normal':
      default:
        return 'Normal';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final repo = ref.read(agendaRepositoryProvider);
    final isDone = taskItem.task.status == 'done';
    final isOverdue = taskItem.isOverdue;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isOverdue
              ? Colors.red.shade300
              : theme.colorScheme.outlineVariant.withAlpha(100),
          width: isOverdue ? 1.5 : 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row Header: Priority & Overdue & Due Date
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _priorityColor(taskItem.task.priority).withAlpha(25),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _priorityLabel(taskItem.task.priority),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: _priorityColor(taskItem.task.priority),
                    ),
                  ),
                ),
                if (isOverdue) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.red.withAlpha(25),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.warning_amber_rounded, size: 12, color: Colors.red),
                        SizedBox(width: 4),
                        Text(
                          'Terlambat',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.red),
                        ),
                      ],
                    ),
                  ),
                ],
                const Spacer(),
                if (taskItem.task.dueLocalDate != null) ...[
                  Icon(Icons.event, size: 14, color: theme.colorScheme.outline),
                  const SizedBox(width: 4),
                  Text(
                    taskItem.task.dueLocalDate!,
                    style: TextStyle(
                      fontSize: 12,
                      color: isOverdue ? Colors.red : theme.colorScheme.outline,
                      fontWeight: isOverdue ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),

            // Checkbox and Title
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: isDone,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  onChanged: (val) {
                    final newStatus = (val == true) ? 'done' : 'todo';
                    repo.updateTaskStatus(taskItem.task.id, newStatus);
                  },
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        taskItem.task.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          decoration: isDone ? TextDecoration.lineThrough : null,
                          color: isDone ? theme.colorScheme.outline : null,
                        ),
                      ),
                      if (taskItem.task.description != null && taskItem.task.description!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          taskItem.task.description!,
                          style: TextStyle(
                            fontSize: 13,
                            color: theme.colorScheme.onSurfaceVariant,
                            decoration: isDone ? TextDecoration.lineThrough : null,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),

            // Checklist / Subtasks Progress & Items
            if (taskItem.totalChecklistCount > 0) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: taskItem.checklistProgress,
                        backgroundColor: theme.colorScheme.surfaceContainerHighest,
                        minHeight: 6,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${taskItem.completedChecklistCount}/${taskItem.totalChecklistCount}',
                    style: TextStyle(fontSize: 12, color: theme.colorScheme.outline, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...taskItem.checklist.map((sub) {
                return Padding(
                  padding: const EdgeInsets.only(left: 32, top: 2),
                  child: InkWell(
                    onTap: () => repo.toggleChecklistItem(sub.id, !sub.isDone),
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Icon(
                            sub.isDone ? Icons.check_circle : Icons.radio_button_unchecked,
                            size: 16,
                            color: sub.isDone ? Colors.green : theme.colorScheme.outline,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              sub.title,
                              style: TextStyle(
                                fontSize: 13,
                                decoration: sub.isDone ? TextDecoration.lineThrough : null,
                                color: sub.isDone ? theme.colorScheme.outline : null,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}
