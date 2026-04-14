import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:portones_mym/data/repositories/jobs_repository.dart';
import 'package:portones_mym/data/repositories/clients_repository.dart';
import 'package:portones_mym/data/repositories/garantias_repository.dart';
import 'package:portones_mym/core/utils/date_utils.dart';

final homeTabIndexProvider = StateProvider<int>((ref) => 0);

// calendario seleccionado (yyyy-MM-dd)
final selectedDayProvider =
StateProvider<String>((ref) => dayKey(DateTime.now()));

// para abrir/scroll a garantía
final garantiaTargetJobIdProvider = StateProvider<String?>((ref) => null);

final jobsRepoProvider = Provider<JobsRepository>((ref) => JobsRepository());
final clientsRepoProvider = Provider<ClientsRepository>((ref) => ClientsRepository());
final garantiasRepoProvider = Provider<GarantiasRepository>((ref) => GarantiasRepository());


