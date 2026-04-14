import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:portones_mym/app/providers.dart';
import 'package:portones_mym/core/utils/date_utils.dart';
import 'package:portones_mym/data/models/job_item.dart';

final calendarControllerProvider =
NotifierProvider<CalendarController, CalendarState>(CalendarController.new);

class CalendarState {
  final String selectedDayKey;

  const CalendarState({
    required this.selectedDayKey,
  });

  /// ✅ Convierte "YYYY-MM-DD" a DateTime SIN parse raro
  DateTime get selectedDay {
    final parts = selectedDayKey.split('-');
    if (parts.length != 3) return DateTime.now();

    final y = int.tryParse(parts[0]) ?? DateTime.now().year;
    final m = int.tryParse(parts[1]) ?? DateTime.now().month;
    final d = int.tryParse(parts[2]) ?? DateTime.now().day;

    return DateTime(y, m, d);
  }

  CalendarState copyWith({
    String? selectedDayKey,
  }) {
    return CalendarState(
      selectedDayKey: selectedDayKey ?? this.selectedDayKey,
    );
  }
}

class CalendarController extends Notifier<CalendarState> {
  @override
  CalendarState build() {
    return CalendarState(selectedDayKey: dayKey(DateTime.now()));
  }

  void setSelectedDay(DateTime day) {
    state = state.copyWith(selectedDayKey: dayKey(day));
  }

  List<JobItem> jobsForSelectedDay() {
    final repo = ref.read(jobsRepoProvider);
    return repo.getForDay(state.selectedDay);
  }

  Future<void> deleteJob({
    required DateTime day,
    required String id,
  }) async {
    final repo = ref.read(jobsRepoProvider);
    await repo.deleteJob(day, id);
  }

  Future<void> moveJob({
    required DateTime fromDay,
    required String id,
    required DateTime toDay,
    int? newTimeMinutes,
  }) async {
    final repo = ref.read(jobsRepoProvider);
    await repo.moveJob(
      fromDay: fromDay,
      id: id,
      toDay: toDay,
      newTimeMinutes: newTimeMinutes,
    );
  }
}