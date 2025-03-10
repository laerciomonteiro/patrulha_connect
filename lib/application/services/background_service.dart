import 'dart:async';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:patrulha_conectada/application/services/location_service.dart';
import 'package:patrulha_conectada/data/data_sources/api_data_source.dart';
import '../../data/models/vehicle_location.dart';
import '../../data/repositories/vehicle_repository.dart';

@pragma('vm:entry-point')
Future<void> initializeBackgroundService() async {
  final service = FlutterBackgroundService();
  final notificationsPlugin = FlutterLocalNotificationsPlugin();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'location_channel',
    'Serviço de Localização',
    description: 'Atualizações de localização em tempo real',
    importance: Importance.max, // Alterado para máxima prioridade
  );

  await notificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: true,
      autoStartOnBoot: true,
      isForegroundMode: true,
      notificationChannelId: 'location_channel',
      initialNotificationTitle: 'Patrulha Conectada',
      initialNotificationContent: 'Coletando localização',
      foregroundServiceNotificationId: 999,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: true,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );
  service.startService();
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  // Configura a notificação primeiro (Android)
  if (service is AndroidServiceInstance) {
    service.setForegroundNotificationInfo(
      title: "Patrulha Conectada",
      content: "Iniciando serviço...",
    );
  }

  // Inicialização do Firebase no isolate de background
  await Firebase.initializeApp();

  final userId = await LocalStorage.getVTRName() ?? '';
  final api = ApiDataSource();
  final locationService = LocationService(userId);

  // Stream para receber atualizações de outras viaturas
  final StreamSubscription<List<VehicleLocation>> vehiclesSub =
      api.getLocations().listen((locations) {
    _processVehicleLocations(locations);
  });

  try {
    locationService.getLocationUpdates().listen((position) async {
      try {
        await FirebaseFirestore.instance
            .collection('locations')
            .doc(userId)
            .set({
          'latitude': position.latitude,
          'longitude': position.longitude,
          'timestamp': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        print('Erro ao atualizar localização: $e');
      }

      if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(
          title: "Viatura: $userId",
          content:
              "Posição: ${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}",
        );
      }
    });
  } catch (e) {
    if (service is AndroidServiceInstance) {
      service.setForegroundNotificationInfo(
        title: "Erro na localização",
        content: "Reiniciando serviço...",
      );
    }
    Timer(const Duration(seconds: 10), initializeBackgroundService);
  }

  service.on('stopService').listen((_) {
    print('Serviço interrompido pelo sistema!');
    initializeBackgroundService();
  });
  // Mantém o serviço ativo mesmo após fechamento
  service.on('detach').listen((_) {
    vehiclesSub.cancel();
    initializeBackgroundService();
  });
}

// Função para processar localizações recebidas
void _processVehicleLocations(List<VehicleLocation> locations) {
  // Implementar futuramente lógica de atualização de interface/mapa aqui
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  return true;
}
