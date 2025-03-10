import 'package:google_maps_flutter/google_maps_flutter.dart';

class VehicleMarker {
  final String id;
  final LatLng position;

  VehicleMarker({required this.id, required this.position});

  Marker toMarker() {
    return Marker(
      markerId: MarkerId(id),
      position: position,
      infoWindow: InfoWindow(title: 'Viatura $id'),
    );
  }
}