import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Representa a localização de uma viatura, incluindo suas coordenadas e identificador único.
class VehicleLocation {
  final LatLng latLng; // Coordenadas da viatura (latitude e longitude)
  final String vehicleId; // Identificador único da viatura (ex: VTR-8362)

  VehicleLocation({
    required this.latLng,
    required this.vehicleId,
  });

  @override
  String toString() {
    return 'VehicleLocation(latLng: $latLng, vehicleId: $vehicleId)';
  }
}