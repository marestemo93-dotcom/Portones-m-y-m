import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:portones_mym/core/constants/app_constants.dart';
import 'package:portones_mym/core/services/notif_service.dart';
import 'package:portones_mym/data/models/job_item.dart';

class JobTile extends StatelessWidget {
  const JobTile({
    super.key,
    required this.job,
    required this.selectedDay,
    required this.onToggleDone,
    required this.onOpenDetail,
    required this.onDelete,
  });

  final JobItem job;
  final DateTime selectedDay;
  final Future<void> Function(bool done) onToggleDone;
  final Future<void> Function() onOpenDetail;
  final Future<void> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    final timeStr = job.timeOfDay == null ? '' : ' • ${NotifService.formatAmPm(job.timeOfDay!)}';

    return Card(
      child: ListTile(
        leading: Checkbox(
          value: job.isDone,
          activeColor: Colors.green,
          onChanged: (v) => onToggleDone(v ?? false),
        ),
        title: Text(
          job.titulo,
          style: TextStyle(
            decoration: job.isDone ? TextDecoration.lineThrough : TextDecoration.none,
            color: job.isDone ? Colors.white70 : Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text('${DateFormat.yMMMd(kLocaleEs).format(job.fecha)}$timeStr'),
        onTap: onOpenDetail,
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: onDelete,
        ),
      ),
    );
  }
}