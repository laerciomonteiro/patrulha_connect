import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:patrulha_conectada/data/data_sources/api_data_source.dart';
import 'dart:async';

class LocationService {
  final ApiDataSource _apiDataSource;
  final String userId;
  LatLng? _lastSentPosition;
  final StreamController<LatLng> _locationStreamController = StreamController();
  bool _isUpdating = false;

  LocationService(this.userId) : _apiDataSource = ApiDataSource();

  Stream<LatLng> getLocationUpdates() {
    if (!_isUpdating) {
      _isUpdating = true;
      _startLocationUpdates();
    }
    return _locationStreamController.stream;
  }

  void _startLocationUpdates() async {
    while (_isUpdating) {
      await Future.delayed(const Duration(seconds: 3));

      try {
        LocationPermission permission = await Geolocator.checkPermission();

        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
          if (permission != LocationPermission.whileInUse &&
              permission != LocationPermission.always) {
            throw Exception("Permissão de localização negada.");
          }
        }

        if (permission == LocationPermission.deniedForever) {
          throw Exception(
              "Permissão permanentemente negada. Ative nas configurações.");
        }

        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );

        LatLng newLocation = LatLng(position.latitude, position.longitude);

        if (_shouldUpdateLocation(newLocation)) {
          await _apiDataSource.updateLocation(userId, newLocation);
          _lastSentPosition = newLocation;
          _locationStreamController.add(newLocation);
        }
      } catch (e) {
        print("Erro ao obter localização: $e");
        if (e.toString().contains("permanently")) {
          await Geolocator.openAppSettings();
        }
        // Reinicia após 10 segundos com backoff exponencial
        await Future.delayed(Duration(seconds: 10));
        _startLocationUpdates();
      }
    }
  }

  bool _shouldUpdateLocation(LatLng newLocation) {
    if (_lastSentPosition == null) return true;

    // 0.000045 graus ≈ 5 metros (cálculo aproximado para latitude)
    const double minChange = 0.000045;
    final latDiff = (newLocation.latitude - _lastSentPosition!.latitude).abs();
    final lngDiff =
        (newLocation.longitude - _lastSentPosition!.longitude).abs();

    return latDiff > minChange || lngDiff > minChange;
  }

  void dispose() {
    _isUpdating = false;
    _locationStreamController.close();
    print('Serviço de localização finalizado');
  }
}
