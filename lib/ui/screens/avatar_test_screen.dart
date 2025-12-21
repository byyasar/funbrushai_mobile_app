import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../data/models/toothbrush.dart';
import '../../data/services/supabase_service.dart';

class AvatarTestScreen extends StatefulWidget {
  const AvatarTestScreen({super.key});

  @override
  State<AvatarTestScreen> createState() => _AvatarTestScreenState();
}

class _AvatarTestScreenState extends State<AvatarTestScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  final ImagePicker _picker = ImagePicker();
  
  List<Toothbrush> _toothbrushes = [];
  Toothbrush? _selectedBrush;
  File? _imageFile;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadToothbrushes();
  }

  Future<void> _loadToothbrushes() async {
    setState(() => _isLoading = true);
    try {
      final brushes = await _supabaseService.getAllToothbrushes();
      setState(() {
        _toothbrushes = brushes;
        if (brushes.isNotEmpty) {
          _selectedBrush = brushes.first;
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading brushes: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (photo != null) {
        setState(() {
          _imageFile = File(photo.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  Future<void> _uploadAvatar() async {
    if (_selectedBrush == null || _imageFile == null) return;

    setState(() => _isLoading = true);
    try {
      final imageUrl = await _supabaseService.uploadBrushAvatar(
        _imageFile!,
        _selectedBrush!.fircaId,
      );

      if (imageUrl != null) {
        await _supabaseService.updateToothbrushAvatar(
          _selectedBrush!.id,
          imageUrl,
        );
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Resim başarıyla yüklendi!')),
          );
          _loadToothbrushes(); // Reload to show new avatar
          setState(() {
            _imageFile = null;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Bir hata oluştu: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Avatar Upload Test')),
      body: _isLoading && _toothbrushes.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButton<Toothbrush>(
                    value: _selectedBrush,
                    isExpanded: true,
                    hint: const Text('Select Toothbrush'),
                    items: _toothbrushes.map((brush) {
                      return DropdownMenuItem(
                        value: brush,
                        child: Text('${brush.name} (${brush.fircaId})'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedBrush = val;
                        _imageFile = null;
                      });
                    },
                  ),
                  const SizedBox(height: 20),
                  if (_selectedBrush != null) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            const Text('Current Avatar:', style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 10),
                            if (_selectedBrush!.avatar != null)
                              Image.network(
                                _selectedBrush!.avatar!,
                                height: 150,
                                errorBuilder: (_, __, ___) => const Icon(Icons.error),
                              )
                            else
                              const Text('No avatar set'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Take Photo'),
                    ),
                    const SizedBox(height: 20),
                    if (_imageFile != null) ...[
                      Image.file(_imageFile!, height: 200),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _uploadAvatar,
                        child: _isLoading 
                            ? const CircularProgressIndicator() 
                            : const Text('Upload & Save'),
                      ),
                    ],
                  ],
                ],
              ),
            ),
    );
  }
}
