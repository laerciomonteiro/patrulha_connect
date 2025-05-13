import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:patrulha_conectada/data/models/patrol_stats.dart';
import 'package:patrulha_conectada/data/models/vehicle_location.dart';
import 'package:patrulha_conectada/data/repositories/vehicle_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Serviço responsável por calcular e acompanhar estatísticas de patrulha
class PatrolStatsService {
  final String vtrName;
  DateTime? _patrolStartTime;
  List<LatLng> _locationHistory = [];
  double _totalDistance = 0.0;
  double _currentSpeed = 0.0;
  List<double> _speedReadings = [];
  Timer? _updateTimer;
  final _statsStreamController = StreamController<PatrolStats>.broadcast();
  PatrolStats _currentStats = PatrolStats.initial();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final int _nearbyRadiusMeters = 5000; // Raio de 5km para considerar unidades "próximas"

  Stream<PatrolStats> get statsStream => _statsStreamController.stream;
  
  PatrolStatsService({required this.vtrName}) {
    _initService();
  }

  void _initService() async {
    // Tente carregar estatísticas salvas primeiro
    final loadedStats = await _loadSavedStats();
    if (loadedStats != null) {
      // Temos estatísticas salvas, use-as
      _patrolStartTime = loadedStats.patrolStartTime ?? DateTime.now();
      _totalDistance = loadedStats.distanceTraveled;
      // Adicione uma leitura inicial de velocidade para evitar erros NaN
      _speedReadings = [loadedStats.averageSpeed];
      _currentStats = loadedStats;
      _statsStreamController.add(_currentStats);
      print('Estatísticas de patrulha carregadas: ${_patrolStartTime}, distância: $_totalDistance');
    } else {
      // Nenhuma estatística salva, comece do zero
      _patrolStartTime = DateTime.now();
      await _savePatrolStartTime(_patrolStartTime!);
      print('Nova patrulha iniciada em: $_patrolStartTime');
    }
    
    _startPeriodicUpdates();
  }
  
  /// Carregar estatísticas de patrulha salvas do SharedPreferences
  Future<PatrolStats?> _loadSavedStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final statsJson = prefs.getString('patrol_stats_$vtrName');
      final patrolStartTimeMs = prefs.getInt('patrol_start_$vtrName');
      
      if (statsJson != null) {
        final Map<String, dynamic> statsMap = jsonDecode(statsJson);
        
        // Se tivermos uma hora de início salva, use-a para atualizar a duração
        if (patrolStartTimeMs != null) {
          final startTime = DateTime.fromMillisecondsSinceEpoch(patrolStartTimeMs);
          final now = DateTime.now();
          final currentDuration = now.difference(startTime);
          
          // Atualize a duração carregada com o tempo realmente decorrido
          statsMap['patrolDurationMs'] = currentDuration.inMilliseconds;
          statsMap['patrolStartTime'] = patrolStartTimeMs;
        }
        
        return PatrolStats.fromJson(statsMap);
      }
      return null;
    } catch (e) {
      print('Erro ao carregar estatísticas de patrulha salvas: $e');
      return null;
    }
  }
  
  /// Salvar hora de início da patrulha separadamente para cálculos mais precisos de duração
  Future<void> _savePatrolStartTime(DateTime startTime) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('patrol_start_$vtrName', startTime.millisecondsSinceEpoch);
    } catch (e) {
      print('Erro ao salvar hora de início da patrulha: $e');
    }
  }

  void _startPeriodicUpdates() {
    _updateTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _updateStats();
    });
  }

  /// Atualizar posição e calcular novas estatísticas
  Future<void> updatePosition(LatLng newPosition) async {
    final now = DateTime.now();
    
    // Verifica se a posição recebida é a posição padrão inicial (-3.71722, -38.54333)
    bool isDefaultPosition = newPosition.latitude == -3.71722 && newPosition.longitude == -38.54333;
    
    // Se for a posição padrão e não tivermos histórico ainda, ignoramos
    if (isDefaultPosition && _locationHistory.isEmpty) {
      print('Ignorando posição inicial padrão para cálculo de distância');
      return;
    }
    
    // Adicionar à história de localização
    if (_locationHistory.isNotEmpty) {
      final lastPosition = _locationHistory.last;
      final distanceInMeters = Geolocator.distanceBetween(
        lastPosition.latitude, 
        lastPosition.longitude, 
        newPosition.latitude, 
        newPosition.longitude
      );
      
      // Calcular tempo desde a última atualização de posição (em horas)
      final timeSinceLastUpdateMs = _locationHistory.length > 1 ? 
          now.difference(now.subtract(const Duration(seconds: 5))).inMilliseconds : 0;
      final timeSinceLastUpdateHours = timeSinceLastUpdateMs / (1000 * 60 * 60);
      
      // Contabilizar apenas se tivermos nos movido mais de 5 metros (reduzir ruído do GPS)
      if (distanceInMeters > 5) {
        _totalDistance += distanceInMeters / 1000; // Converter para quilômetros
        
        // Atualizar velocidade atual (km/h) usando apenas o movimento recente
        if (timeSinceLastUpdateHours > 0) {
          _currentSpeed = (distanceInMeters / 1000) / timeSinceLastUpdateHours;
          
          // Adicionar apenas leituras de velocidade razoáveis (menos de 200 km/h)
          if (_currentSpeed < 200) {
            _speedReadings.add(_currentSpeed);
          }
        }
        
        _locationHistory.add(newPosition);
      } else {
        // Se não estiver se movendo significativamente, definir velocidade próxima de zero
        _currentSpeed = 0.1; // Valor não zero pequeno
        if (_speedReadings.length > 10) {
          // Substituir a leitura mais antiga por zero para reduzir média gradualmente
          _speedReadings[_speedReadings.length % 10] = 0.0;
        } else {
          _speedReadings.add(0.0);
        }
      }
    } else {
      // Primeira posição (real, não a padrão)
      _locationHistory.add(newPosition);
      print('Adicionada primeira posição real ao histórico: ${newPosition.latitude}, ${newPosition.longitude}');
    }
    
    await _updateStats();
  }

  Future<void> _updateStats() async {
    final now = DateTime.now();
    final patrolDuration = _patrolStartTime != null ? now.difference(_patrolStartTime!) : Duration.zero;
    
    // Calcular velocidade média
    double avgSpeed = 0.0;
    if (_speedReadings.isNotEmpty) {
      // Usar as 10 leituras mais recentes para uma "média móvel"
      final recentReadings = _speedReadings.length > 10 
        ? _speedReadings.sublist(_speedReadings.length - 10) 
        : _speedReadings;
      
      avgSpeed = recentReadings.reduce((a, b) => a + b) / recentReadings.length;
    }
    
    // Limitar velocidade média a algo razoável (máximo de 150 km/h)
    avgSpeed = math.min(avgSpeed, 150.0);
    
    // Determinar se está se movendo com base nas leituras de velocidade recentes (mais preciso)
    bool isMoving = false;
    if (_speedReadings.isNotEmpty) {
      // Verificar as últimas 3 leituras para evitar piscamento
      final checkCount = math.min(3, _speedReadings.length);
      final recentSpeedSum = _speedReadings
          .sublist(_speedReadings.length - checkCount)
          .reduce((a, b) => a + b);
      
      // Considerar em movimento apenas se a média das últimas 3 leituras for > 3 km/h
      isMoving = recentSpeedSum / checkCount > 3.0;
    }
    
    // Obter número de unidades próximas
    int nearbyUnits = await _countNearbyUnits();
    
    _currentStats = PatrolStats(
      patrolDuration: patrolDuration,
      distanceTraveled: _totalDistance,
      averageSpeed: avgSpeed,
      nearbyUnits: nearbyUnits,
      isMoving: isMoving,
      patrolStartTime: _patrolStartTime,
    );
    
    // Salvar estatísticas atualizadas no SharedPreferences
    await _saveStats(_currentStats);
    
    // Transmitir estatísticas atualizadas
    _statsStreamController.add(_currentStats);
  }
  
  /// Salvar estatísticas de patrulha no SharedPreferences
  Future<void> _saveStats(PatrolStats stats) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final statsJson = jsonEncode(stats.toJson());
      await prefs.setString('patrol_stats_$vtrName', statsJson);
    } catch (e) {
      print('Erro ao salvar estatísticas de patrulha: $e');
    }
  }
  
  Future<int> _countNearbyUnits() async {
    if (_locationHistory.isEmpty) return 0;
    
    try {
      // Obter posição atual
      final myPosition = _locationHistory.last;
      
      // Consultar todas as localizações de veículos
      final locationsSnapshot = await _firestore.collection('locations').get();
      
      int count = 0;
      for (var doc in locationsSnapshot.docs) {
        // Ignorar próprio veículo
        if (doc.id == vtrName) continue;
        
        final data = doc.data();
        if (data.containsKey('latitude') && data.containsKey('longitude')) {
          final otherLat = data['latitude'] as double;
          final otherLng = data['longitude'] as double;
          
          final distanceInMeters = Geolocator.distanceBetween(
            myPosition.latitude, myPosition.longitude, otherLat, otherLng
          );
          
          if (distanceInMeters <= _nearbyRadiusMeters) {
            count++;
          }
        }
      }
      
      return count;
    } catch (e) {
      print('Erro ao contar unidades próximas: $e');
      return 0;
    }
  }
  
  void dispose() {
    _updateTimer?.cancel();
    _statsStreamController.close();
  }
}
