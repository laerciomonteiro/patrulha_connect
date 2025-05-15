import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:patrulha_conectada/application/providers/location_provider.dart';
import 'package:patrulha_conectada/application/providers/patrol_stats_provider.dart';
import '../../data/repositories/vehicle_repository.dart';
import 'package:patrulha_conectada/presentation/screens/login_screen.dart';
import 'package:patrulha_conectada/presentation/widgets/metric_card.dart';

class HomeScreen extends ConsumerStatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _isLoading = true;
  bool _isMapInitializing = true;
  Timer? _mapInitTimer;

  @override
  void initState() {
    super.initState();
    // Monitora alterações no estado de autenticação do usuário
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

  @override
  void dispose() {
    _mapInitTimer?.cancel(); // Cancela o temporizador se existir
    super.dispose();
  }

  // Inicia um temporizador para lidar com casos em que o mapa não inicializa corretamente
  void _startMapInitializationTimeout() {
    if (_mapInitTimer != null) return; // Define o temporizador apenas uma vez

    _mapInitTimer = Timer(const Duration(seconds: 8), () {
      if (mounted) {
        setState(() {
          // Se ainda estamos na posição inicial após 8 segundos,
          // provavelmente temos um problema com permissões de localização ou carregamento do mapa
          if (_isMapInitializing) {
            _isMapInitializing = false;

            // Exibe uma mensagem para o usuário
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    'Não foi possível obter sua localização. Verifique as permissões do app.'),
                duration: Duration(seconds: 5),
              ),
            );

            // Força uma recarga do provedor de localização
            ref.invalidate(locationProvider);
          }
        });
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
            .timeout(
                const Duration(milliseconds: 500)); // Temporizador reduzido
      } on TimeoutException {
        // Se o documento não for encontrado no temporizador inicial, tenta novamente com um atraso maior
        await Future.delayed(
            const Duration(seconds: 2)); // Atraso aumentado para nova tentativa
        userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get();
      }

      if (!userDoc.exists) {
        print(
            'Erro: Documento de usuário não encontrado no Firestore para ID: $userId');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    'Erro ao carregar dados do usuário. Tente novamente.')),
          );
          setState(() {
            _isLoading = false;
          });
        }
        return;
      }

      final userData = userDoc.data() as Map<String, dynamic>?;
      if (userData == null || !userData.containsKey('vtrName')) {
        print(
            'Erro: vtrName não encontrado no documento de usuário para ID: $userId');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content:
                    Text('Nome da VTR não configurado para este usuário.')),
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
      print('Erro em _initializeUser: $e');
      print('Rastreamento de pilha: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Ocorreu um erro inesperado: ${e.toString()}')),
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    ref.read(locationProvider.notifier).setMapController(controller);
  }

  // Função para mover a câmera para a posição atual
  void _moveCameraToCurrentPosition(LatLng position) {
    ref.read(locationProvider.notifier).moveCamera(position);

    // Feedback visual para o usuário
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Centralizando na posição atual'),
      duration: Duration(seconds: 1),
    ));
  }

  Widget _buildMetricCards() {
    final stats = ref.watch(patrolStatsProvider);

    return Container(
      height: 120,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 16),
        children: [
          MetricCard(
            icon: Icons.groups,
            color: Colors.green,
            title: 'Próximas',
            value: '${stats.nearbyUnits}',
            subtitle: 'Viaturas próximas',
            onTap: () {},
          ),
          MetricCard(
            icon: Icons.directions_car,
            color: Colors.orange,
            title: 'Distância',
            value: '${stats.distanceTraveled.toStringAsFixed(1)} km',
            subtitle: '${(stats.distanceTraveled / 0.2).round()} min',
            onTap: () {},
          ),
          MetricCard(
            icon: Icons.timer,
            color: Colors.purple.shade400,
            title: 'Patrulha',
            value: _formatDuration(stats.patrolDuration),
            subtitle: stats.isMoving ? 'Em movimento' : 'Parado',
            onTap: () {},
          ),
          MetricCard(
            icon: Icons.speed,
            color: Colors.pink,
            title: 'Velocidade',
            value: '${stats.averageSpeed.toStringAsFixed(1)}',
            subtitle: 'km/h média',
            onTap: () {},
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitHours = twoDigits(duration.inHours);
    return '$twoDigitHours:$twoDigitMinutes hrs';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Acessa o estado de localização do provedor
    final locationState = ref.watch(locationProvider);

    // Verifica se o Google Maps está renderizando corretamente
    // Consideramos problema apenas se não houver marcadores após um tempo razoável
    bool mapHasIssue = false;

    // Verificamos se ainda estamos na posição inicial após alguns segundos de carregamento
    if (_isMapInitializing) {
      // Verifica se a posição é a padrão inicial
      bool isDefaultPosition =
          locationState.currentPosition.latitude == -3.71722 &&
              locationState.currentPosition.longitude == -38.54333;

      if (isDefaultPosition) {
        // Posição inicial padrão indica que não recebemos atualização de localização ainda
        _startMapInitializationTimeout();
      } else {
        // Recebemos uma posição válida do GPS, então o mapa está funcionando
        _isMapInitializing = false;
        print('Mapa inicializado com posição real do GPS');
      }
    }

    if (mapHasIssue) {
      // Fornece opção de recuperação para o usuário
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
                    final TextEditingController controller =
                        TextEditingController();
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
                            onPressed: () =>
                                Navigator.pop(context, controller.text),
                            child: const Text('Confirmar'),
                          ),
                        ],
                      ),
                    );

                    if (result != null && result.isNotEmpty) {
                      try {
                        // Atualiza o documento do usuário com o novo nome de viatura
                        await FirebaseFirestore.instance
                            .collection('users')
                            .doc(user.uid)
                            .set({
                          'vtrName': result,
                          'email': user.email,
                        });

                        // Cria localização inicial
                        await FirebaseFirestore.instance
                            .collection('locations')
                            .doc(result)
                            .set({
                          'latitude': 0.0,
                          'longitude': 0.0,
                          'timestamp': FieldValue.serverTimestamp(),
                        });

                        // Salva localmente
                        await LocalStorage.saveVTRName(result);

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content:
                                  Text('Viatura configurada com sucesso!')),
                        );

                        // Recarrega a tela
                        if (mounted) {
                          Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => HomeScreen()));
                        }
                      } catch (e) {
                        print('Erro ao configurar viatura: $e');
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text(
                                  'Erro ao configurar viatura: ${e.toString()}')),
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
      body: Stack(
        children: [
          // Google Map como camada base
          GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: CameraPosition(
              target: locationState.currentPosition,
              zoom: 14,
            ),
            markers: locationState.allMarkers,
            myLocationEnabled: true,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
          ),

          // Cartões de métricas
          Positioned(
            top: 20,
            left: 0,
            right: 0,
            child: _buildMetricCards(),
          ),

          // Botão para centralizar na posição atual
          Positioned(
            bottom: 40,
            right: 0,
            left: 0,
            child: Center(
              child: Material(
                elevation: 6,
                borderRadius: BorderRadius.circular(30),
                color: Colors.blue[800],
                child: InkWell(
                  onTap: () => _moveCameraToCurrentPosition(
                      locationState.currentPosition),
                  borderRadius: BorderRadius.circular(30),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.my_location,
                          color: Colors.white,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'CENTRALIZAR',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
