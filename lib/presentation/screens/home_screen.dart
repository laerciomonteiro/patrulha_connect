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
    try {
      DocumentSnapshot userDoc;
      try {
        userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get()
            .timeout(const Duration(milliseconds: 500)); // Reduced timeout
      } on TimeoutException {
        // If the document is not found in the initial timeout, try again with a longer delay
        await Future.delayed(const Duration(seconds: 2)); // Increased delay for retry
        userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get();
      }

      if (!userDoc.exists) {
        print('Error: User document not found in Firestore for user ID: $userId');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Erro ao carregar dados do usuário. Tente novamente.')),
          );
          setState(() {
            _isLoading = false;
          });
        }
        return;
      }

      final userData = userDoc.data() as Map<String, dynamic>?;
      if (userData == null || !userData.containsKey('vtrName')) {
        print('Error: vtrName not found in user document for user ID: $userId');
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Nome da VTR não configurado para este usuário.')),
          );
          setState(() {
            _isLoading = false;
          });
        }
        return;
      }

      String vtrName = userData['vtrName'];
      await LocalStorage.saveVTRName(vtrName);
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      print('Error in _initializeUser: $e');
      print('Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ocorreu um erro inesperado: ${e.toString()}')),
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
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

    // Acessa o estado de localização do provider
    final locationState = ref.watch(locationProvider);
    
    // Verifica se o Google Maps está renderizando corretamente
    // Se não tivermos marcadores e estivermos na posição inicial, pode indicar um problema
    bool mapHasIssue = locationState.allMarkers.length <= 1 && 
                       locationState.currentPosition.latitude == -3.71722 && 
                       locationState.currentPosition.longitude == -38.54333;
    
    if (mapHasIssue) {
      // Oferece opção de recuperação para o usuário
      return Scaffold(
        appBar: AppBar(
          title: const Text('Patrulha Conectada'),
          backgroundColor: Colors.blue[800],
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Não foi possível carregar o mapa corretamente.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  // Solicitar que o usuário informe o nome da viatura novamente
                  final user = FirebaseAuth.instance.currentUser;
                  if (user != null) {
                    final TextEditingController controller = TextEditingController();
                    final result = await showDialog<String>(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) => AlertDialog(
                        title: const Text('Identificação da Viatura'),
                        content: TextField(
                          controller: controller,
                          decoration: const InputDecoration(
                            hintText: 'Ex: POG-4444',
                            labelText: 'Nome da Viatura',
                          ),
                          textCapitalization: TextCapitalization.characters,
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancelar'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, controller.text),
                            child: const Text('Confirmar'),
                          ),
                        ],
                      ),
                    );
                    
                    if (result != null && result.isNotEmpty) {
                      try {
                        // Atualiza o documento do usuário com o novo nome de viatura
                        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
                          'vtrName': result,
                          'email': user.email,
                        });
                        
                        // Cria localização inicial
                        await FirebaseFirestore.instance.collection('locations').doc(result).set({
                          'latitude': 0.0,
                          'longitude': 0.0,
                          'timestamp': FieldValue.serverTimestamp(),
                        });
                        
                        // Salva localmente
                        await LocalStorage.saveVTRName(result);
                        
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Viatura configurada com sucesso!')),
                        );
                        
                        // Recarrega a tela
                        if (mounted) {
                          Navigator.pushReplacement(
                            context, 
                            MaterialPageRoute(builder: (context) => HomeScreen())
                          );
                        }
                      } catch (e) {
                        print('Erro ao configurar viatura: $e');
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Erro ao configurar viatura: ${e.toString()}')),
                        );
                      }
                    }
                  }
                },
                child: const Text('Configurar Viatura'),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () {
                  // Logout e retorno para tela de login
                  FirebaseAuth.instance.signOut();
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => LoginScreen()),
                  );
                },
                child: const Text('Voltar para Login'),
              ),
            ],
          ),
        ),
      );
    }

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
