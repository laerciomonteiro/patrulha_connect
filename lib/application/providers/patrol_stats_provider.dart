import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:patrulha_conectada/data/models/patrol_stats.dart';
import 'package:patrulha_conectada/application/providers/location_provider.dart';
import 'package:patrulha_conectada/application/services/patrol_stats_service.dart';
import 'package:patrulha_conectada/data/repositories/vehicle_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provedor para estatísticas de patrulha
final patrolStatsProvider = StateNotifierProvider<PatrolStatsNotifier, PatrolStats>((ref) {
  return PatrolStatsNotifier(ref);
});

class PatrolStatsNotifier extends StateNotifier<PatrolStats> {
  final Ref ref;
  PatrolStatsService? _patrolStatsService;
  bool _isInitialized = false;

  PatrolStatsNotifier(this.ref) : super(PatrolStats.initial()) {
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      // Obter o nome da viatura do armazenamento local
      final vtrName = await LocalStorage.getVTRName();
      if (vtrName != null && vtrName.isNotEmpty) {
        _patrolStatsService = PatrolStatsService(vtrName: vtrName);
        
        // Ouvir atualizações de estatísticas do serviço
        _patrolStatsService!.statsStream.listen((stats) {
          state = stats;
        });
        
        // Ouvir atualizações de localização do provedor de localização para atualizar posição
        ref.listen(locationProvider, (previous, next) {
          if (previous != next && _patrolStatsService != null) {
            // Atualizar estatísticas de patrulha com nova posição
            _patrolStatsService!.updatePosition(next.currentPosition);
          }
        });
        
        _isInitialized = true;
      } else {
        print('PatrolStatsNotifier: Não possível inicializar - Nome da VTR não encontrado');
      }
    } catch (e) {
      print('PatrolStatsNotifier: Erro ao inicializar estatísticas de patrulha: $e');
    }
  }

  @override
  void dispose() {
    _patrolStatsService?.dispose();
    super.dispose();
  }
}