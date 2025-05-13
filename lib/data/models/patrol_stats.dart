/// Classe modelo para estatísticas de patrulha exibidas no widget PatrolStatsCard
class PatrolStats {
  /// Tempo total gasto patrulhando na sessão atual
  final Duration patrolDuration;
  
  /// Distância total percorrida em quilômetros desde o início da patrulha
  final double distanceTraveled;
  
  /// Velocidade média em quilômetros por hora
  final double averageSpeed;
  
  /// Número de outras unidades de patrulha nas proximidades
  final int nearbyUnits;
  
  /// Indica se o veículo de patrulha está atualmente em movimento
  final bool isMoving;
  
  /// O horário em que a patrulha foi iniciada (para persistência de dados)
  final DateTime? patrolStartTime;
  
  // Métricas adicionais opcionais que podem ser incluídas:
  // final double fuelEfficiency;
  // final int stationaryTime; // Tempo parado (em minutos)
  // final double areaCircumference; // Km cobertos em circunferência
  // final double patrolAreaCoverage; // Percentual da área atribuída coberta

  const PatrolStats({
    required this.patrolDuration,
    required this.distanceTraveled,
    required this.averageSpeed,
    required this.nearbyUnits,
    this.isMoving = false,
    this.patrolStartTime,
  });
  
  /// Converter para formato JSON para armazenamento persistente
  Map<String, dynamic> toJson() {
    return {
      'patrolDurationMs': patrolDuration.inMilliseconds,
      'distanceTraveled': distanceTraveled,
      'averageSpeed': averageSpeed,
      'nearbyUnits': nearbyUnits,
      'isMoving': isMoving,
      'patrolStartTime': patrolStartTime?.millisecondsSinceEpoch,
    };
  }
  
  /// Criar a partir de dados JSON (armazenamento persistente)
  factory PatrolStats.fromJson(Map<String, dynamic> json) {
    return PatrolStats(
      patrolDuration: Duration(milliseconds: json['patrolDurationMs'] ?? 0),
      distanceTraveled: json['distanceTraveled'] ?? 0.0,
      averageSpeed: json['averageSpeed'] ?? 0.0,
      nearbyUnits: json['nearbyUnits'] ?? 0,
      isMoving: json['isMoving'] ?? false,
      patrolStartTime: json['patrolStartTime'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(json['patrolStartTime']) 
          : null,
    );
  }

  /// Criar uma cópia deste PatrolStats com os campos especificados substituídos pelos novos valores
  PatrolStats copyWith({
    Duration? patrolDuration,
    double? distanceTraveled,
    double? averageSpeed,
    int? nearbyUnits,
    bool? isMoving,
  }) {
    return PatrolStats(
      patrolDuration: patrolDuration ?? this.patrolDuration,
      distanceTraveled: distanceTraveled ?? this.distanceTraveled,
      averageSpeed: averageSpeed ?? this.averageSpeed,
      nearbyUnits: nearbyUnits ?? this.nearbyUnits,
      isMoving: isMoving ?? this.isMoving,
    );
  }

  /// Estatísticas iniciais com valores zero
  factory PatrolStats.initial() {
    return const PatrolStats(
      patrolDuration: Duration.zero,
      distanceTraveled: 0.0,
      averageSpeed: 0.0,
      nearbyUnits: 0,
      isMoving: false,
    );
  }
}