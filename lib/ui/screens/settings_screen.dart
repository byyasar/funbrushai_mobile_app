import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/app_colors.dart';
import '../../data/models/toothbrush.dart';
import '../../data/services/supabase_service.dart';
import '../widgets/app_banner.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  final ImagePicker _picker = ImagePicker();
  
  List<Toothbrush> _toothbrushes = [];
  Toothbrush? _selectedBrush;
  File? _imageFile;
  bool _isLoading = false;
  bool _isUploading = false;

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

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: source,
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

  void _showImageSourceActionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Galeri'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Kamera'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImage(ImageSource.camera);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _uploadAvatar() async {
    debugPrint('Starting avatar upload...');
    if (_selectedBrush == null) {
      debugPrint('Upload failed: No brush selected');
      return;
    }
    if (_imageFile == null) {
      debugPrint('Upload failed: No image file selected');
      return;
    }

    setState(() => _isUploading = true);
    try {
      debugPrint('Uploading file to Supabase Storage...');
      final imageUrl = await _supabaseService.uploadBrushAvatar(
        _imageFile!,
        _selectedBrush!.fircaId,
      );
      debugPrint('Upload result URL: $imageUrl');

      if (imageUrl != null) {
        await _supabaseService.updateToothbrushAvatar(
          _selectedBrush!.id,
          imageUrl,
        );
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Görsel başarıyla güncellendi!')),
          );
          await _loadToothbrushes(); // Reload to show new avatar
          setState(() {
            _imageFile = null;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        // Show more detailed error message
        String errorMessage = 'Error uploading avatar';
        if (e.toString().contains('StorageApiError')) {
           errorMessage = 'Storage Error: Check if "brush_avatars" bucket exists and is public.';
        } else {
           errorMessage = 'Error: $e';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(label: 'OK', onPressed: () {}),
          ),
        );
      }
    } finally {
      setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        child: Column(
          children: [
            AppBanner(
              title: 'Kullanıcı Avatarını Düzenle',
              showBackButton: true,
            ),
            Expanded(
              child: _isLoading && _toothbrushes.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                         /*Text(
                            'Kullanıcı Avatarını Düzenle',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textDark,
                                ),
                          ),*/
                          const SizedBox(height: 24),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<Toothbrush>(
                                value: _selectedBrush,
                                isExpanded: true,
                                hint: const Text('Kullanıcı Seçin'),
                                items: _toothbrushes.map((brush) {
                                  return DropdownMenuItem(
                                    value: brush,
                                    child: Text(
                                      brush.userName,
                                      style: const TextStyle(fontWeight: FontWeight.w500),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  setState(() {
                                    _selectedBrush = val;
                                    _imageFile = null;
                                  });
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),
                          if (_selectedBrush != null) ...[
                            Center(
                              child: Stack(
                                children: [
                                  Container(
                                    width: 150,
                                    height: 150,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.grey.shade200,
                                      border: Border.all(color: AppColors.primary, width: 3),
                                      image: _imageFile != null
                                          ? DecorationImage(
                                              image: FileImage(_imageFile!),
                                              fit: BoxFit.cover,
                                            )
                                          : _selectedBrush!.avatar != null
                                              ? DecorationImage(
                                                  image: NetworkImage(_selectedBrush!.avatar!),
                                                  fit: BoxFit.cover,
                                                )
                                              : null,
                                    ),
                                    child: (_imageFile == null && _selectedBrush!.avatar == null)
                                        ? Icon(Icons.person, size: 80, color: Colors.grey.shade400)
                                        : null,
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: GestureDetector(
                                      onTap: () => _showImageSourceActionSheet(context),
                                      child: Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary,
                                          shape: BoxShape.circle,
                                          border: Border.all(color: Colors.white, width: 3),
                                        ),
                                        child: const Icon(
                                          Icons.camera_alt,
                                          color: Colors.white,
                                          size: 24,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 40),
                            if (_imageFile != null)
                              ElevatedButton(
                                onPressed: _isUploading ? null : _uploadAvatar,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: _isUploading
                                    ? const SizedBox(
                                        height: 24,
                                        width: 24,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text(
                                        'Avatarı Kaydet',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                              ),
                          ],
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
