import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:portones_mym/core/constants/hive_boxes.dart';

import 'package:portones_mym/app/providers.dart';
import 'package:portones_mym/features/calendar/presentation/controllers/calendar_controller.dart';
import 'package:portones_mym/features/calendar/presentation/dialogs/job_dialogs.dart';
import 'package:portones_mym/features/calendar/presentation/dialogs/next_visit_flow.dart';
import 'package:portones_mym/features/calendar/presentation/screens/job_detail_screen.dart';
import 'package:portones_mym/features/calendar/presentation/widgets/calendar_month_header.dart';
import 'package:portones_mym/features/calendar/presentation/widgets/calendar_table.dart';
import 'package:portones_mym/features/calendar/presentation/widgets/jobs_day_list.dart';
import 'package:portones_mym/data/models/job_item.dart';
import 'package:portones_mym/features/calendar/presentation/dialogs/year_picker_dialog.dart';

class CalendarHome extends ConsumerStatefulWidget {
  const CalendarHome({super.key});

  @override
  ConsumerState<CalendarHome> createState() => _CalendarHomeState();
}

class _CalendarHomeState extends ConsumerState<CalendarHome> {
  CalendarFormat _format = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();

  @override
  Widget build(BuildContext context) {
    // ✅ Arranca realtime listener (solo se inicia una vez por Provider)

    final cal = ref.watch(calendarControllerProvider);
    final selectedDay = cal.selectedDay;

    return Scaffold(
      appBar: AppBar(title: const Text('Portones M y M')),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await JobDialogs.addJobDialog(context, ref, day: selectedDay);
          if (!mounted) return;
          setState(() {});
        },
        child: const Icon(Icons.add),
      ),

      // ✅ Rebuild automático cuando Hive cambia (por stream Firestore)
      body: ValueListenableBuilder(
        valueListenable: Hive.box(kJobsBox).listenable(),
        builder: (context, _, __) {
          final jobsRepo = ref.watch(jobsRepoProvider);
          final eventsMap = jobsRepo.getAllEvents();

          List<JobItem> eventsLoader(DateTime day) {
            final k = DateTime(day.year, day.month, day.day);
            return eventsMap[k] ?? [];
          }

          return ListView(
            children: [
              CalendarMonthHeader(
                focusedDay: _focusedDay,
                onPrevMonth: () => setState(() => _focusedDay =
                    DateTime(_focusedDay.year, _focusedDay.month - 1, 1)),
                onNextMonth: () => setState(() => _focusedDay =
                    DateTime(_focusedDay.year, _focusedDay.month + 1, 1)),
                onPickYear: () async {
                  final pickedYear = await YearPickerDialog.pick(
                    context,
                    initialYear: _focusedDay.year,
                    minYear: 2020,
                    maxYear: 2035,
                  );

                  if (pickedYear != null && mounted) {
                    setState(() {
                      _focusedDay = DateTime(pickedYear, _focusedDay.month, 1);
                    });
                  }
                },
              ),
              CalendarTable(
                focusedDay: _focusedDay,
                format: _format,
                eventsLoader: eventsLoader,
                onPageChanged: (focused) => setState(() => _focusedDay = focused),
                onFormatChanged: (f) => setState(() => _format = f),
                onDaySelectedSetFocused: (focused) =>
                    setState(() => _focusedDay = focused),
              ),
              const SizedBox(height: 8),
              JobsDayList(
                selectedDay: selectedDay,

                // ✅ sigue igual: refresco inmediato al borrar
                onRefresh: () {
                  if (!mounted) return;
                  setState(() {});
                },

                onToggleDoneWithFlow: ({
                  required context,
                  required day,
                  required job,
                  required done,
                }) async {
                  await NextVisitFlow.run(
                    context: context,
                    ref: ref,
                    day: day,
                    job: job,
                    done: done,
                  );
                  if (!mounted) return;
                  setState(() {});
                },

                onOpenDetail: (ctx, day, job) async {
                  final dayOnly = DateTime(day.year, day.month, day.day);
                  await Navigator.of(ctx).push(
                    MaterialPageRoute(
                      builder: (_) => JobDetailScreen(day: dayOnly, job: job),
                    ),
                  );
                  if (!mounted) return;
                  setState(() {});
                },
              ),
            ],
          );
        },
      ),
    );
  }
}