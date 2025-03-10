import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:patrulha_conectada/data/repositories/vehicle_repository.dart';
import 'package:patrulha_conectada/presentation/screens/login_screen.dart';

class SignupScreen extends StatefulWidget {
  @override
  _SignupScreenState createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _vtrNameController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>(); // Chave global para o form

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _vtrNameController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _signup() async {
    // Verifica se o FormState está disponível
    final formState = _formKey.currentState;
    if (formState == null) return;

    if (formState.validate()) {
      // Chama validate apenas se formState não é null
      try {
        UserCredential userCredential =
            await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text,
          password: _passwordController.text,
        );

        String userId = userCredential.user!.uid;
        String vtrName = _vtrNameController.text;

        // Salvar informações do usuário e localização
        await FirebaseFirestore.instance.runTransaction((transaction) async {
          // Salva informações do usuário
          await transaction.set(
            FirebaseFirestore.instance.collection('users').doc(userId),
            {
              'vtrName': vtrName,
              'email': _emailController.text,
            },
          );

          // Salva localização inicial
          await transaction.set(
            FirebaseFirestore.instance.collection('locations').doc(vtrName),
            {
              'latitude': 0.0,
              'longitude': 0.0,
              'timestamp': FieldValue.serverTimestamp(),
            },
          );
        });

        // Salva Vehicle Name localmente
        await LocalStorage.saveVTRName(vtrName);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Registro concluído!')),
        );
        Navigator.of(context).pop();
      } on FirebaseAuthException catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'Erro ao cadastrar')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Cadastro'),
      ),
      body: Form(
        key: _formKey,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(labelText: 'E-mail'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, insira seu e-mail';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(labelText: 'Senha'),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, insira uma senha';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _confirmPasswordController,
                decoration: InputDecoration(labelText: 'Confirme a senha'),
                obscureText: true,
                validator: (value) {
                  if (value != _passwordController.text) {
                    return 'Senhas não coincidem';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _vtrNameController,
                decoration: InputDecoration(labelText: 'Identificação da Viatura'),
                textCapitalization: TextCapitalization.characters,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, insira um nome para a viatura';
                  }
                  return null;
                },
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _signup,
                child: Text('Cadastrar'),
              ),
              TextButton(
                onPressed: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => LoginScreen()),
                ),
                child: Text('Já tenho uma conta'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
