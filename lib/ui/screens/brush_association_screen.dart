import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_colors.dart';
import 'home_screen.dart';

class BrushAssociationScreen extends StatefulWidget {
  const BrushAssociationScreen({super.key});

  @override
  State<BrushAssociationScreen> createState() => _BrushAssociationScreenState();
}

class _BrushAssociationScreenState extends State<BrushAssociationScreen> {
  final _brushIdController = TextEditingController();
  final _nameController = TextEditingController();

  Future<void> _saveAndContinue() async {
    if (_brushIdController.text.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('brush_id', _brushIdController.text);
    await prefs.setString('user_name', _nameController.text);

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Welcome to FunBrushAI',
                style: Theme.of(context).textTheme.displayLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Your Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _brushIdController,
                decoration: const InputDecoration(
                  labelText: 'Brush ID',
                  border: OutlineInputBorder(),
                  helperText: 'Enter the ID found on your device',
                ),
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: _saveAndContinue,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                ),
                child: const Text('Start Journaling'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
