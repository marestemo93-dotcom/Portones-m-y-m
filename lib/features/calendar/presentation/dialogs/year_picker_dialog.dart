import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class YearPickerDialog {
  static Future<int?> pick(
      BuildContext context, {
        required int initialYear,
        int minYear = 2020,
        int maxYear = 2035,
      }) async {
    int tempYear = initialYear.clamp(minYear, maxYear);

    final years = List<int>.generate(maxYear - minYear + 1, (i) => minYear + i);
    final initialIndex = years.indexOf(tempYear);

    final result = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          height: 300,
          color: Colors.black,
          child: Column(
            children: [
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, null),
                    child: const Text('Cancelar'),
                  ),
                  const Text('Seleccionar año', style: TextStyle(fontWeight: FontWeight.bold)),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, tempYear),
                    child: const Text('Aceptar'),
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: CupertinoTheme(
                  data: const CupertinoThemeData(brightness: Brightness.dark),
                  child: CupertinoPicker(
                    scrollController: FixedExtentScrollController(
                      initialItem: initialIndex < 0 ? 0 : initialIndex,
                    ),
                    itemExtent: 40,
                    onSelectedItemChanged: (index) => tempYear = years[index],
                    children: [
                      for (final y in years)
                        Center(
                          child: Text(y.toString(), style: const TextStyle(fontSize: 20)),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    return result;
  }
}