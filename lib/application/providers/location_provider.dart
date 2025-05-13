import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:patrulha_conectada/data/data_sources/api_data_source.dart';
import 'package:patrulha_conectada/application/services/location_service.dart';
import 'package:patrulha_conectada/data/models/vehicle_location.dart';
import 'package:patrulha_conectada/data/utils/marker_utils.dart';
import '../../data/repositories/vehicle_repository.dart';
import '../services/background_service.dart';

final locationProvider =
    StateNotifierProvider<LocationNotifier, LocationState>((ref) {
  return LocationNotifier(ref);
});

class LocationState {
  final LatLng currentPosition;
  final Marker currentMarker;
  final Set<Marker> otherVehiclesMarkers;

  LocationState({
    required this.currentPosition,
    required this.currentMarker,
    required this.otherVehiclesMarkers,
  });

  Set<Marker> get allMarkers {
    return {currentMarker, ...otherVehiclesMarkers};
  }

  LocationState copyWith({
    LatLng? currentPosition,
    Marker? currentMarker,
    Set<Marker>? otherVehiclesMarkers,
  }) {
    return LocationState(
      currentPosition: currentPosition ?? this.currentPosition,
      currentMarker: currentMarker ?? this.currentMarker,
      otherVehiclesMarkers: otherVehiclesMarkers ?? this.otherVehiclesMarkers,
    );
  }

  factory LocationState.initial() {
    // Utilizamos uma posição inicial na região de Fortaleza apenas como valor temporário
    // Esta posição será substituída pela posição real do GPS assim que disponível
    const initialPosition = LatLng(-3.71722, -38.54333);
    final defaultMarker = Marker(
      markerId: const MarkerId('current-location'),
      position: initialPosition,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
    );

    return LocationState(
      currentPosition: initialPosition,
      currentMarker: defaultMarker,
      otherVehiclesMarkers: {},
    );
  }
}

class LocationNotifier extends StateNotifier<LocationState> {
  final Ref ref;
  late String userId;
  late ApiDataSource _apiDataSource;
  late LocationService _locationService;
  GoogleMapController? _mapController;
  bool _shouldMoveCameraOnUpdate =
      true; // Flag para controle do movimento da câmera

  LocationNotifier(this.ref) : super(LocationState.initial()) {
    _initializeUserIdAndServices();
  }

  Future<void> _initializeUserIdAndServices() async {
    try {
      final vtrName = await LocalStorage.getVTRName();
      if (vtrName == null || vtrName.isEmpty) {
        print('ERRO: Nome da viatura não definido no LocalStorage.');
        return; // Não inicializa mais nada se não tiver nome da viatura
      }

      userId = vtrName;
      _apiDataSource = ApiDataSource();
      _locationService = LocationService(userId);
      
      try {
        await initializeBackgroundService();
      } catch (e) {
        print('Erro ao inicializar serviço em background: $e');
        // Continua mesmo com erro no serviço background
      }
      
      _initTracking();
    } catch (e) {
      print('Erro na inicialização do provedor de localização: $e');
      // Em caso de erro, ainda mantém o estado inicial
    }
  }

  // Flag para controlar se já recebemos alguma posição real do GPS
  bool _hasReceivedRealPosition = false;

  void _initTracking() {
    _locationService.getLocationUpdates().listen((newPosition) async {
      // Verifica se é uma posição válida (diferente da padrão)
      bool isDefaultPosition = newPosition.latitude == -3.71722 && 
                               newPosition.longitude == -38.54333;
      
      bool isRealPosition = !isDefaultPosition;
      
      // Verifica se essa é a primeira posição real do GPS
      bool isFirstRealPosition = isRealPosition && !_hasReceivedRealPosition;
      
      if (isRealPosition) {
        _hasReceivedRealPosition = true; // Marca que já recebemos pelo menos uma posição real
      }
      
      final customIcon = await createCustomMarker("Você", Colors.red);
      final newMarker = Marker(
        markerId: const MarkerId('current-location'),
        position: newPosition,
        icon: customIcon,
        anchor: const Offset(0.5, 0.5),
      );
      
      state = state.copyWith(
        currentPosition: newPosition,
        currentMarker: newMarker,
      );

      // Move a câmera na primeira atualização real ou quando o GPS é reativado
      if (_mapController != null && (isFirstRealPosition || (_shouldMoveCameraOnUpdate && isRealPosition))) {
        moveCamera(newPosition);
        
        // Desativa movimento automático apenas se não for a primeira posição real
        if (!isFirstRealPosition) {
          _shouldMoveCameraOnUpdate = false;
        }
        
        // Se for a primeira posição real, registra no log
        if (isFirstRealPosition) {
          print('Primeira posição real do GPS obtida: ${newPosition.latitude}, ${newPosition.longitude}');
        }
      }
    });

    _apiDataSource.getLocations().listen((locations) async {
      final markers = await _convertLocationsToMarkers(locations);
      state = state.copyWith(otherVehiclesMarkers: markers);
    });
  }

  void moveCamera(LatLng position) {
    if (_mapController != null) {
      // Verifica se a posição é válida (não é a padrão)
      bool isDefaultPosition = position.latitude == -3.71722 && position.longitude == -38.54333;
      
      if (!isDefaultPosition) {
        print('Movendo câmera para: ${position.latitude}, ${position.longitude}');
        _mapController!.animateCamera(
          CameraUpdate.newLatLng(position),
        );
      } else {
        print('Não é possível mover a câmera para a posição padrão');
        // Tenta obter uma nova posição se estamos com a posição padrão
        _tryGetCurrentPosition();
      }
    }
  }
  
  // Tenta obter a posição atual do GPS de forma forçada
  Future<void> _tryGetCurrentPosition() async {
    print('Tentando obter posição atual do GPS forçadamente...');
    try {
      // Reinicia o serviço de localização
      _locationService.requestCurrentPosition();
    } catch (e) {
      print('Erro ao tentar obter posição atual: $e');
    }
  }

  void setMapController(GoogleMapController controller) {
    _mapController = controller;
    // Move para a posição inicial apenas no primeiro carregamento
    if (_shouldMoveCameraOnUpdate) {
      moveCamera(state.currentPosition);
    }
  }

  Future<Set<Marker>> _convertLocationsToMarkers(
      List<VehicleLocation> vehicleLocations) async {
    final Set<Marker> markers = {};
    for (final vehicle in vehicleLocations) {
      final icon = await createCustomMarker(vehicle.vehicleId, Colors.blue);
      markers.add(
        Marker(
          markerId: MarkerId(vehicle.vehicleId),
          position: vehicle.latLng,
          icon: icon,
          anchor: const Offset(0.5, 0.5),
          consumeTapEvents: true,
        ),
      );
    }
    return markers;
  }

  void startTracking() {}
}
