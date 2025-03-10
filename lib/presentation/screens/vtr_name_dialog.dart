import 'package:flutter/material.dart';

class VTRNameScreen extends StatelessWidget {
  final String userId;

  VTRNameScreen({required this.userId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Define Vehicle Name')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          child: Column(
            children: [
              TextFormField(
                decoration: InputDecoration(labelText: 'Vehicle Name'),
                textCapitalization: TextCapitalization.characters,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a vehicle name';
                  }
                  return null;
                },
              ),
              ElevatedButton(
                onPressed: () {
                  // Salvar o vehicle name e voltar para a HomeScreen
                },
                child: Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
