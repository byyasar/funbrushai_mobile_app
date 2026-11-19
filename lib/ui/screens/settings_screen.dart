import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
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
    } on PlatformException catch (e) {
      if (mounted) {
        if (e.code == 'camera_access_denied') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Kamera erişim izni verilmedi. Ayarlardan izin verebilirsiniz.'),
              action: SnackBarAction(
                label: 'Ayarlar',
                onPressed: () => openAppSettings(),
              ),
            ),
          );
        } else if (e.code == 'photo_access_denied') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Fotoğraf galerisi izni verilmedi. Ayarlardan izin verebilirsiniz.'),
              action: SnackBarAction(
                label: 'Ayarlar',
                onPressed: () => openAppSettings(),
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Fotoğraf hatası: ${e.message ?? e.code}')),
          );
        }
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

  Widget _buildUserSelector(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_toothbrushes.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
          ),
        ),
        child: const Center(
          child: Text(
            'Kayıtlı aktif fırça/kullanıcı bulunamadı.',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Kullanıcı Seçin',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_toothbrushes.length} Kullanıcı',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 110,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: _toothbrushes.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final brush = _toothbrushes[index];
              final isSelected = _selectedBrush?.id == brush.id;
              final displayName = brush.userName.isNotEmpty ? brush.userName : brush.fircaId;

              return InkWell(
                onTap: () {
                  if (_selectedBrush?.id != brush.id) {
                    setState(() {
                      _selectedBrush = brush;
                      _imageFile = null;
                    });
                  }
                },
                borderRadius: BorderRadius.circular(16),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary.withValues(alpha: isDark ? 0.25 : 0.08)
                        : Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primary
                          : (isDark ? Colors.grey.shade800 : Colors.grey.shade300),
                      width: isSelected ? 2 : 1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Stack(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected ? AppColors.primary : Colors.transparent,
                                width: 2,
                              ),
                              image: brush.avatar != null && brush.avatar!.isNotEmpty
                                  ? DecorationImage(
                                      image: NetworkImage(brush.avatar!),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                              color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                            ),
                            child: (brush.avatar == null || brush.avatar!.isEmpty)
                                ? const Icon(Icons.person, color: Colors.grey, size: 28)
                                : null,
                          ),
                          if (isSelected)
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.check,
                                  size: 12,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        width: 70,
                        child: Text(
                          displayName,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected
                                ? AppColors.primary
                                : (isDark ? Colors.white : Colors.black87),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildUserSelector(context),
                          const SizedBox(height: 24),
                          if (_selectedBrush != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                              decoration: BoxDecoration(
                                color: Theme.of(context).cardColor,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    _selectedBrush!.userName.isNotEmpty
                                        ? _selectedBrush!.userName
                                        : _selectedBrush!.fircaId,
                                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Fırça ID: ${_selectedBrush!.fircaId}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  Center(
                                    child: _imageFile != null
                                        ? _buildAvatarCropper(context)
                                        : Column(
                                            children: [
                                              GestureDetector(
                                                onTap: () => _showImageSourceActionSheet(context),
                                                child: Stack(
                                                  children: [
                                                    Container(
                                                      width: 150,
                                                      height: 150,
                                                      decoration: BoxDecoration(
                                                        shape: BoxShape.circle,
                                                        color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                                                        border: Border.all(color: AppColors.primary, width: 3),
                                                        image: _selectedBrush!.avatar != null && _selectedBrush!.avatar!.isNotEmpty
                                                            ? DecorationImage(
                                                                image: NetworkImage(_selectedBrush!.avatar!),
                                                                fit: BoxFit.cover,
                                                              )
                                                            : null,
                                                      ),
                                                      child: (_selectedBrush!.avatar == null || _selectedBrush!.avatar!.isEmpty)
                                                          ? Icon(Icons.person, size: 75, color: Colors.grey.shade400)
                                                          : null,
                                                    ),
                                                    Positioned(
                                                      bottom: 0,
                                                      right: 0,
                                                      child: Container(
                                                        padding: const EdgeInsets.all(10),
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
                                                          size: 20,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(height: 14),
                                              OutlinedButton.icon(
                                                onPressed: () => _showImageSourceActionSheet(context),
                                                icon: const Icon(Icons.photo_camera, size: 18),
                                                label: const Text('Fotoğrafı Değiştir'),
                                                style: OutlinedButton.styleFrom(
                                                  foregroundColor: AppColors.primary,
                                                  side: const BorderSide(color: AppColors.primary),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(12),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                  ),
                                  if (_imageFile != null) ...[
                                    const SizedBox(height: 24),
                                    ElevatedButton(
                                      onPressed: _isUploading ? null : _uploadAvatar,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                        minimumSize: const Size.fromHeight(50),
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
                                    const SizedBox(height: 8),
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
