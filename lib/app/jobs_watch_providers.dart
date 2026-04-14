import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:portones_mym/app/providers.dart';
import 'package:portones_mym/core/constants/hive_boxes.dart';
import 'package:portones_mym/core/utils/date_utils.dart';
import 'package:portones_mym/data/models/job_item.dart';

/// Convierte el selectedDayProvider (yyyy-MM-dd) a DateTime
final selectedDayDateProvider = Provider<DateTime>((ref) {
  final key = ref.watch(selectedDayProvider);
  // key viene como yyyy-MM-dd
  final d = DateTime.parse('${key}T00:00:00');
  return DateTime(d.year, d.month, d.day);
});

/// ✅ Stream que emite cada vez que cambie la lista de jobs del día en Hive
final jobsForSelectedDayStreamProvider = StreamProvider<List<JobItem>>((ref) async* {
  final repo = ref.watch(jobsRepoProvider);
  final day = ref.watch(selectedDayDateProvider);
  final key = dayKey(day);

  final box = Hive.box(kJobsBox);

  // 1) Emitir estado inicial
  yield repo.getForDay(day);

  // 2) Emitir cada vez que ese key cambie
  await for (final _ in box.watch(key: key)) {
    yield repo.getForDay(day);
  }
});