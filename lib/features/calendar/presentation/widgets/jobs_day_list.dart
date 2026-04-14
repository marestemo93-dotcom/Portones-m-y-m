// lib/features/calendar/presentation/widgets/jobs_day_list.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:portones_mym/app/providers.dart';
import 'package:portones_mym/core/constants/hive_boxes.dart';
import 'package:portones_mym/data/models/job_item.dart';
import 'package:portones_mym/features/calendar/presentation/widgets/job_tile.dart';

/// ✅ A prueba de todo: se dispara con CUALQUIER cambio en el box.
/// (No depende del key del día, así evitamos el caso donde el job cae en otro key)
final jobsBoxTickProvider = StreamProvider<void>((ref) {
  final box = Hive.box(kJobsBox);
  return box.watch().map((_) => null);
});

class JobsDayList extends ConsumerWidget {
  const JobsDayList({
    super.key,
    required this.selectedDay,
    required this.onToggleDoneWithFlow,
    required this.onOpenDetail,
    required this.onRefresh,
  });

  final DateTime selectedDay;

  final Future<void> Function({
  required BuildContext context,
  required DateTime day,
  required JobItem job,
  required bool done,
  }) onToggleDoneWithFlow;

  final Future<void> Function(BuildContext context, DateTime day, JobItem job)
  onOpenDetail;

  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobsRepo = ref.watch(jobsRepoProvider);

    // ✅ con solo mirar este provider, la UI se reconstruye cuando cambie Hive
    ref.watch(jobsBoxTickProvider);

    final dayOnly = DateTime(selectedDay.year, selectedDay.month, selectedDay.day);
    final todaysJobs = jobsRepo.getForDay(dayOnly);

    if (todaysJobs.isEmpty) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(12, 10, 12, 18),
        child: Center(child: Text('No hay trabajos este día')),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: todaysJobs.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (context, i) {
        final job = todaysJobs[i];

        return JobTile(
          job: job,
          selectedDay: dayOnly,
          onToggleDone: (done) => onToggleDoneWithFlow(
            context: context,
            day: dayOnly,
            job: job,
            done: done,
          ),
          onOpenDetail: () => onOpenDetail(context, dayOnly, job),
          onDelete: () async {
            await jobsRepo.deleteJob(dayOnly, job.id);
            onRefresh(); // ya no es necesario, pero lo dejamos
          },
        );
      },
    );
  }
}