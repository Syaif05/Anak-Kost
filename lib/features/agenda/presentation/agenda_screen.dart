import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers/agenda_providers.dart';
import 'widgets/add_event_sheet.dart';
import 'widgets/add_task_sheet.dart';
import 'widgets/agenda_calendar_view.dart';
import 'widgets/agenda_tasks_view.dart';

class AgendaScreen extends ConsumerStatefulWidget {
  const AgendaScreen({super.key});

  @override
  ConsumerState<AgendaScreen> createState() => _AgendaScreenState();
}

class _AgendaScreenState extends ConsumerState<AgendaScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {});
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(agendaRepositoryProvider).seedDefaultCalendarsIfEmpty();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _openAddModal() {
    if (_tabController.index == 0) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (_) => AddEventSheet(initialDate: _selectedDate),
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (_) => const AddTaskSheet(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Agenda & Tugas',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.calendar_month), text: 'Agenda Kalender'),
            Tab(icon: Icon(Icons.check_circle_outline), text: 'Daftar Tugas'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddModal,
        icon: const Icon(Icons.add),
        label: Text(_tabController.index == 0 ? 'Tambah Agenda' : 'Tambah Tugas'),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          AgendaCalendarView(
            selectedDate: _selectedDate,
            onDateSelected: (date) => setState(() => _selectedDate = date),
          ),
          const AgendaTasksView(),
        ],
      ),
    );
  }
}
