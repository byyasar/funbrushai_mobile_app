import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
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
  final GlobalKey _cropKey = GlobalKey();
  final TransformationController _transformationController = TransformationController();

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

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  Future<void> _loadToothbrushes({String? keepBrushId}) async {
    setState(() => _isLoading = true);
    try {
      final currentSelectedId = keepBrushId ?? _selectedBrush?.id;
      final brushes = await _supabaseService.getAllToothbrushes();
      final activeBrushes = brushes.where((b) => b.isActive).toList();

      setState(() {
        _toothbrushes = activeBrushes;
        if (activeBrushes.isNotEmpty) {
          if (currentSelectedId != null) {
            _selectedBrush = activeBrushes.firstWhere(
              (b) => b.id == currentSelectedId,
              orElse: () => activeBrushes.first,
            );
          } else {
            _selectedBrush = activeBrushes.first;
          }
        } else {
          _selectedBrush = null;
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fırçalar yüklenirken hata oluştu: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 90,
      );

      if (photo != null) {
        setState(() {
          _imageFile = File(photo.path);
          _transformationController.value = Matrix4.identity();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fotoğraf seçilirken hata oluştu: $e')),
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
    final targetBrushId = _selectedBrush!.id;
    final fircaId = _selectedBrush!.fircaId;

    try {
      File fileToUpload = _imageFile!;

      // 1. Kılavuzdaki parmakla hizalanmış görüntüyü kırparak yakala
      try {
        final boundary = _cropKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
        if (boundary != null) {
          final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
          final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
          if (byteData != null) {
            final tempDir = await getTemporaryDirectory();
            final croppedFile = File('${tempDir.path}/cropped_avatar_${DateTime.now().millisecondsSinceEpoch}.png');
            await croppedFile.writeAsBytes(byteData.buffer.asUint8List());
            fileToUpload = croppedFile;
            debugPrint('Cropped image successfully created: ${croppedFile.path}');
          }
        }
      } catch (cropErr) {
        debugPrint('Could not capture cropped boundary, using original file: $cropErr');
      }

      debugPrint('Uploading file to Supabase Storage...');
      final imageUrl = await _supabaseService.uploadBrushAvatar(
        fileToUpload,
        fircaId,
      );
      debugPrint('Upload result URL: $imageUrl');

      if (imageUrl != null) {
        await _supabaseService.updateToothbrushAvatar(
          targetBrushId,
          imageUrl,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Avatar başarıyla kaydedildi!'),
                ],
              ),
              backgroundColor: AppColors.greenSuccess,
            ),
          );
          // Aynı kullanıcı seçili kalacak şekilde yeniden yükle
          await _loadToothbrushes(keepBrushId: targetBrushId);
          setState(() {
            _imageFile = null;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Avatar yüklenirken hata oluştu';
        if (e.toString().contains('StorageApiError')) {
          errorMessage = 'Depolama hatası: "brush_avatars" klasörü kontrol edilmeli.';
        } else {
          errorMessage = 'Hata: $e';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            duration: const Duration(seconds: 4),
            action: SnackBarAction(label: 'Tamam', onPressed: () {}),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  Widget _buildAvatarCropper(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        // Kılavuz Alanı
        Stack(
          alignment: Alignment.center,
          children: [
            // Gölge / Arka plan halkası
            Container(
              width: 210,
              height: 210,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),

            // Parmakla sürüklenebilen ve kırpılan alan
            RepaintBoundary(
              key: _cropKey,
              child: ClipOval(
                child: Container(
                  width: 200,
                  height: 200,
                  color: Colors.black,
                  child: InteractiveViewer(
                    transformationController: _transformationController,
                    clipBehavior: Clip.none,
                    boundaryMargin: const EdgeInsets.all(200),
                    minScale: 0.5,
                    maxScale: 4.0,
                    panEnabled: true,
                    scaleEnabled: true,
                    child: Image.file(
                      _imageFile!,
                      fit: BoxFit.cover,
                      width: 200,
                      height: 200,
                    ),
                  ),
                ),
              ),
            ),

            // Kılavuz Çerçevesi (Border & Kılavuz Çizgileri - Dokunmayı engellemez)
            IgnorePointer(
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.primary,
                    width: 3.5,
                  ),
                ),
                child: Stack(
                  children: [
                    // Hafif artı kılavuzu (merkezleme için)
                    Center(
                      child: Container(
                        width: 16,
                        height: 1.5,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                    Center(
                      child: Container(
                        width: 1.5,
                        height: 16,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Fotoğrafı Değiştirme Butonu (Küçük rozet)
            Positioned(
              bottom: 4,
              right: 4,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _showImageSourceActionSheet(context),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(
                      Icons.refresh,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 14),

        // İpucu Kartı
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[850] : Colors.blue.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.touch_app, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Resmi parmağınızla kaydırıp hizalayın',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.grey[300] : AppColors.primaryDark,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 6),

        // Hizalamayı Sıfırla Butonu
        TextButton.icon(
          onPressed: () {
            _transformationController.value = Matrix4.identity();
          },
          icon: const Icon(Icons.center_focus_strong, size: 16),
          label: const Text('Hizalamayı Sıfırla', style: TextStyle(fontSize: 12)),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const AppBanner(
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
                          const SizedBox(height: 8),
                          Text(
                            'Kullanıcı Avatarını Düzenle',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardTheme.color,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<Toothbrush>(
                                value: _selectedBrush,
                                dropdownColor: Theme.of(context).cardTheme.color,
                                isExpanded: true,
                                hint: const Text('Kullanıcı Seçin'),
                                items: _toothbrushes.map((brush) {
                                  return DropdownMenuItem(
                                    value: brush,
                                    child: Text(
                                      brush.userName.isNotEmpty ? brush.userName : brush.fircaId,
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
                              child: _imageFile != null
                                  ? _buildAvatarCropper(context)
                                  : Stack(
                                      children: [
                                        Container(
                                          width: 160,
                                          height: 160,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: Colors.grey.shade200,
                                            border: Border.all(color: AppColors.primary, width: 3),
                                            image: _selectedBrush!.avatar != null
                                                ? DecorationImage(
                                                    image: NetworkImage(_selectedBrush!.avatar!),
                                                    fit: BoxFit.cover,
                                                  )
                                                : null,
                                          ),
                                          child: _selectedBrush!.avatar == null
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
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black.withValues(alpha: 0.2),
                                                    blurRadius: 6,
                                                    offset: const Offset(0, 2),
                                                  ),
                                                ],
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
                            const SizedBox(height: 32),
                            if (_imageFile != null) ...[
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
                              const SizedBox(height: 10),
                              TextButton(
                                onPressed: _isUploading
                                    ? null
                                    : () {
                                        setState(() {
                                          _imageFile = null;
                                        });
                                      },
                                child: const Text('İptal'),
                              ),
                            ],
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
