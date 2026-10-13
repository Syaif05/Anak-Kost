import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme.dart';
import '../../../../app/widgets/app_ui_components.dart';
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
        // Filter Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              AppPillFilterChip(
                label: 'Tugas Aktif',
                isSelected: _selectedFilter == 'active',
                onTap: () => setState(() => _selectedFilter = 'active'),
              ),
              const SizedBox(width: 8),
              AppPillFilterChip(
                label: 'Selesai',
                isSelected: _selectedFilter == 'done',
                onTap: () => setState(() => _selectedFilter = 'done'),
              ),
              const SizedBox(width: 8),
              AppPillFilterChip(
                label: 'Semua',
                isSelected: _selectedFilter == 'all',
                onTap: () => setState(() => _selectedFilter = 'all'),
              ),
            ],
          ),
        ),

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
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceSecondary,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppTheme.borderColor),
                          ),
                          child: const Icon(
                            Icons.checklist_rtl_rounded,
                            size: 28,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _selectedFilter == 'done'
                              ? 'Belum ada tugas selesai'
                              : 'Tidak ada tugas yang tertunda!',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Semua tugas beres! Kerja bagus! 🎉',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
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

  Widget _buildPriorityBadge(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return AppStatusBadge.error('Tinggi');
      case 'low':
        return AppStatusBadge.neutral('Rendah');
      case 'normal':
      default:
        return AppStatusBadge(
          label: 'Normal',
          backgroundColor: AppTheme.primaryTealContainer,
          textColor: AppTheme.primaryTeal,
        );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(agendaRepositoryProvider);
    final isDone = taskItem.task.status == 'done';
    final isOverdue = taskItem.isOverdue;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isOverdue ? AppTheme.error.withAlpha(120) : AppTheme.borderColor,
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
                _buildPriorityBadge(taskItem.task.priority),
                if (isOverdue) ...[
                  const SizedBox(width: 6),
                  AppStatusBadge.error('Terlambat', icon: Icons.warning_amber_rounded),
                ],
                const Spacer(),
                if (taskItem.task.dueLocalDate != null) ...[
                  const Icon(Icons.event_outlined, size: 14, color: AppTheme.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    taskItem.task.dueLocalDate!,
                    style: TextStyle(
                      fontSize: 12,
                      color: isOverdue ? AppTheme.error : AppTheme.textSecondary,
                      fontWeight: isOverdue ? FontWeight.w700 : FontWeight.w500,
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
                Transform.scale(
                  scale: 1.05,
                  child: Checkbox(
                    value: isDone,
                    activeColor: AppTheme.primaryTeal,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    onChanged: (val) {
                      final newStatus = (val == true) ? 'done' : 'todo';
                      repo.updateTaskStatus(taskItem.task.id, newStatus);
                    },
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        taskItem.task.title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          decoration: isDone ? TextDecoration.lineThrough : null,
                          color: isDone ? AppTheme.textSecondary : AppTheme.textPrimary,
                        ),
                      ),
                      if (taskItem.task.description != null && taskItem.task.description!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          taskItem.task.description!,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
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
                        backgroundColor: AppTheme.surfaceSecondary,
                        valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryTeal),
                        minHeight: 6,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${taskItem.completedChecklistCount}/${taskItem.totalChecklistCount}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
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
                            sub.isDone ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                            size: 16,
                            color: sub.isDone ? AppTheme.success : AppTheme.textSecondary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              sub.title,
                              style: TextStyle(
                                fontSize: 13,
                                decoration: sub.isDone ? TextDecoration.lineThrough : null,
                                color: sub.isDone ? AppTheme.textSecondary : AppTheme.textPrimary,
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
