import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:portones_mym/core/constants/app_constants.dart';
import 'package:portones_mym/core/utils/location_colors.dart';
import 'package:portones_mym/data/models/job_item.dart';
import 'package:portones_mym/features/calendar/presentation/controllers/calendar_controller.dart';



class CalendarTable extends ConsumerWidget {
  const CalendarTable({
    super.key,
    required this.focusedDay,
    required this.format,
    required this.eventsLoader,
    required this.onPageChanged,
    required this.onFormatChanged,
    required this.onDaySelectedSetFocused,
  });


  final DateTime focusedDay;
  final CalendarFormat format;

  /// TableCalendar necesita esto para los puntitos
  final List<JobItem> Function(DateTime day) eventsLoader;

  /// Cuando cambian de mes (swipe)
  final void Function(DateTime focused) onPageChanged;

  /// Si algún día querés habilitar formatos
  final void Function(CalendarFormat f) onFormatChanged;

  /// Para que CalendarHome actualice su _focusedDay en setState
  final void Function(DateTime focused) onDaySelectedSetFocused;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(calendarControllerProvider);
    final selectedDay = st.selectedDay;

    return TableCalendar<JobItem>(
      headerVisible: false,
      locale: kLocaleEs,
      firstDay: DateTime.utc(2020, 1, 1),
      lastDay: DateTime.utc(2035, 12, 31),
      focusedDay: focusedDay,
      selectedDayPredicate: (day) => isSameDay(day, selectedDay),
      calendarBuilders: CalendarBuilders(
        markerBuilder: (context, date, events) {
          if (events.isEmpty) return const SizedBox.shrink();

          final jobs = events.cast<JobItem>();
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: jobs.take(4).map((job) {
              return Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.symmetric(horizontal: 1),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colorForLocation(job.locationSnapshot),
                ),
              );
            }).toList(),
          );
        },
      ),
      calendarFormat: format,
      availableCalendarFormats: const {CalendarFormat.month: 'Mes'},
      startingDayOfWeek: StartingDayOfWeek.monday,
      calendarStyle: const CalendarStyle(
        outsideDaysVisible: true,
        markersAlignment: Alignment.bottomCenter,
        markerMargin: EdgeInsets.symmetric(horizontal: 1.2),
        markersMaxCount: 4,
      ),
      sixWeekMonthsEnforced: true,
      eventLoader: eventsLoader,

      onDaySelected: (selected, focused) {
        ref.read(calendarControllerProvider.notifier).setSelectedDay(selected);
        onDaySelectedSetFocused(focused);
      },

      onPageChanged: (focused) => onPageChanged(focused),
      onFormatChanged: (format) => onFormatChanged(format),
    );
  }
}