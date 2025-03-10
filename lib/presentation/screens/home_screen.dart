import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:patrulha_conectada/application/providers/location_provider.dart';
import '../../data/repositories/vehicle_repository.dart';
import 'package:patrulha_conectada/presentation/screens/login_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (user == null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => LoginScreen()),
        );
      } else {
        _initializeUser(user.uid);
      }
    });
  }

  Future<void> _initializeUser(String userId) async {
    // Tenta obter o documento do usuário com um pequeno timeout
    DocumentSnapshot userDoc;
    try {
      userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get()
          .timeout(const Duration(milliseconds: 500));
    } on TimeoutException {
      // Se o documento não for encontrado no timeout, assume que ainda está sendo criado
      await Future.delayed(const Duration(seconds: 1));
      userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
    }

    if (!userDoc.exists) {
      throw Exception('Usuário não encontrado no Firestore');
    }

    String vtrName = userDoc['vtrName'];
    await LocalStorage.saveVTRName(vtrName);
    setState(() {
      _isLoading = false;
    });
  }

  /*Future<void> _checkVTRName() async {
    final vtrName = await LocalStorage.getVTRName();
    if (vtrName == null || vtrName.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _showVTRNameDialogUntilValid();
      });
    } else {
      final isRegistered = await ApiDataSource().isVehicleNameRegistered(vtrName);
      if (!isRegistered) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Nome "$vtrName" não está registrado no sistema.')),
        );
        await LocalStorage.saveVTRName('');
        setState(() => _isLoading = false);
        return;
      }
      setState(() {
        _isNameSet = true;
        _isLoading = false;
      });
    }
  }*/

  /*Future<void> _showVTRNameDialogUntilValid() async {
    String? newName;
    bool isNameValid = false;
    while (!isNameValid) {
      newName = await showVTRNameDialog(context);
      if (newName == null || newName.isEmpty) return;

      final isRegistered = await ApiDataSource().isVehicleNameRegistered(newName);
      if (isRegistered) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Nome "$newName" já está em uso. Escolha outro.')),
        );
      } else {
        isNameValid = true;
        await LocalStorage.saveVTRName(newName!);
        await ApiDataSource().updateLocation(newName, const LatLng(0, 0));
        setState(() {
          _isNameSet = true;
          _isLoading = false;
        });
        ref.invalidate(locationProvider);
      }
    }
  }*/

  void _onMapCreated(GoogleMapController controller) {
    ref.read(locationProvider.notifier).setMapController(controller);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    /*if (!_isNameSet) {
      return const Scaffold(
        body: Center(child: Text('Nome da viatura não definido.')),
      );
    }*/

    final locationState = ref.watch(locationProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Patrulha Conectada',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor: Colors.blue[800],
        elevation: 4,
      ),
      body: GoogleMap(
        onMapCreated: _onMapCreated,
        initialCameraPosition: CameraPosition(
          target: locationState.currentPosition,
          zoom: 14,
        ),
        markers: locationState.allMarkers,
        myLocationEnabled: true,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => ref
            .read(locationProvider.notifier)
            .moveCamera(locationState.currentPosition),
        child: const Icon(Icons.my_location, size: 32),
        backgroundColor: Colors.white,
        elevation: 5,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        color: Colors.blue[800],
        shape: const CircularNotchedRectangle(),
        notchMargin: 0,
        child: Container(
          height: 56,
          alignment: Alignment.center,
        ),
      ),
    );
  }
}
