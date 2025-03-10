import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:patrulha_conectada/data/models/vehicle_location.dart';

class ApiDataSource {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> updateLocation(String userId, LatLng position) async {
    try {
      await _firestore.collection('locations').doc(userId).set({
        'latitude': position.latitude,
        'longitude': position.longitude,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Erro ao atualizar localização: $e');
    }
  }

  Future<void> initializeFirebaseInBackground() async {
    await Firebase.initializeApp(); // Necessário no isolate de background
  }

  Stream<List<VehicleLocation>> getLocations() {
    return _firestore.collection('locations').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return VehicleLocation(
          latLng: LatLng(data['latitude'], data['longitude']),
          vehicleId: doc.id, // ID do documento = nome da viatura
        );
      }).toList();
    });
  }

  Future<bool> isVehicleNameRegistered(String vehicleName) async {
    final doc = await _firestore.collection('locations').doc(vehicleName).get();
    return doc.exists; // Retorna true se o documento já existir
  }
}
