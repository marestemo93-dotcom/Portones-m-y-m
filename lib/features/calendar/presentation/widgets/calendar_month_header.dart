import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:portones_mym/core/constants/app_constants.dart';

class CalendarMonthHeader extends StatelessWidget {
  const CalendarMonthHeader({
    super.key,
    required this.focusedDay,
    required this.onPrevMonth,
    required this.onNextMonth,
    required this.onPickYear,
  });

  final DateTime focusedDay;
  final VoidCallback onPrevMonth;
  final VoidCallback onNextMonth;
  final Future<void> Function() onPickYear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Mes anterior',
            icon: const Icon(Icons.chevron_left),
            onPressed: onPrevMonth,
          ),
          Expanded(
            child: Center(
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: onPickYear,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                  child: Text(
                    DateFormat('MMMM yyyy', kLocaleEs).format(focusedDay),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Mes siguiente',
            icon: const Icon(Icons.chevron_right),
            onPressed: onNextMonth,
          ),
        ],
      ),
    );
  }
}