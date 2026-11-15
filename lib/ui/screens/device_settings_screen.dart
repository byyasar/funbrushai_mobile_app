import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/supabase_constants.dart';
import '../../core/services/device_config_service.dart';
import '../../data/models/toothbrush.dart';
import '../../data/services/supabase_service.dart';
import '../widgets/app_banner.dart';

class DeviceSettingsScreen extends StatefulWidget {
  const DeviceSettingsScreen({super.key});

  @override
  State<DeviceSettingsScreen> createState() => _DeviceSettingsScreenState();
}

class _DeviceSettingsScreenState extends State<DeviceSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _deviceIdController = TextEditingController();
  final _dbUrlController = TextEditingController();
  final _apiKeyController = TextEditingController();

  final SupabaseService _supabaseService = SupabaseService();

  List<Toothbrush> _toothbrushes = [];
  Map<String, bool> _activeStatusMap = {};

  bool _isLoading = true;
  bool _isLoadingBrushes = false;
  bool _isTesting = false;
  bool _isSaving = false;
  bool _obscureApiKey = true;

  Timer? _debounceTimer;

  String? _statusMessage;
  bool? _isStatusSuccess;

  @override
  void initState() {
    super.initState();
    _loadInitialSettings();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _deviceIdController.dispose();
    _dbUrlController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _loadToothbrushesForDevice(String deviceId) async {
    final cleanId = deviceId.trim();
    if (cleanId.isEmpty) {
      if (mounted) {
        setState(() {
          _toothbrushes = [];
          _activeStatusMap = {};
        });
      }
      return;
    }

    if (mounted) {
      setState(() => _isLoadingBrushes = true);
    }

    try {
      final brushes = await _supabaseService.getAllToothbrushes(targetDeviceId: cleanId);
      final inactiveSet = await DeviceConfigService.getInactiveBrushIds(cleanId);
      final statusMap = <String, bool>{};
      for (final b in brushes) {
        statusMap[b.fircaId] = !inactiveSet.contains(b.fircaId);
      }
      if (mounted) {
        setState(() {
          _toothbrushes = brushes;
          _activeStatusMap = statusMap;
        });
      }
    } catch (e) {
      debugPrint('Error loading brushes for device $cleanId: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingBrushes = false);
      }
    }
  }

  void _onDeviceIdChanged(String val) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 600), () {
      _loadToothbrushesForDevice(val);
    });
  }

  Future<void> _loadInitialSettings() async {
    setState(() => _isLoading = true);
    try {
      final deviceId = await DeviceConfigService.getDeviceId();
      final dbUrl = await DeviceConfigService.getDbUrl();
      final apiKey = await DeviceConfigService.getApiKey();

      _deviceIdController.text = deviceId;
      _dbUrlController.text = dbUrl;
      _apiKeyController.text = apiKey;

      await _loadToothbrushesForDevice(deviceId);
    } catch (e) {
      debugPrint('Error loading device settings: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<bool> _testConnectionInternal() async {
    final deviceId = _deviceIdController.text.trim();
    final url = _dbUrlController.text.trim();
    final apiKey = _apiKeyController.text.trim();

    if (url.isEmpty || apiKey.isEmpty) {
      setState(() {
        _isStatusSuccess = false;
        _statusMessage = 'Lütfen veritabanı adresi ve API Key alanlarını doldurun.';
      });
      return false;
    }

    setState(() {
      _isTesting = true;
      _statusMessage = null;
      _isStatusSuccess = null;
    });

    try {
      await _supabaseService.testConnection(
        url: url,
        anonKey: apiKey,
        deviceId: deviceId,
      );
      if (mounted) {
        setState(() {
          _isStatusSuccess = true;
          _statusMessage = 'Bağlantı başarılı! Cihaz ID ve veritabanı doğrulandı.';
        });
      }
      // Bağlantı başarılıysa cihazın fırçalarını da yükle
      if (deviceId.isNotEmpty) {
        _loadToothbrushesForDevice(deviceId);
      }
      return true;
    } catch (e) {
      if (mounted) {
        setState(() {
          _isStatusSuccess = false;
          _statusMessage = 'Bağlantı başarısız: $e';
        });
      }
      return false;
    } finally {
      if (mounted) {
        setState(() => _isTesting = false);
      }
    }
  }

  Future<void> _handleSaveAndConnect() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final deviceId = _deviceIdController.text.trim();
    final url = _dbUrlController.text.trim();
    final apiKey = _apiKeyController.text.trim();

    setState(() => _isSaving = true);

    try {
      // 1. Önce bağlantıyı test edelim
      final isConnected = await _testConnectionInternal();
      if (!isConnected) {
        setState(() => _isSaving = false);
        return;
      }

      // 2. Başarılı ise SharedPreferences'a kalıcı olarak kaydedelim
      await DeviceConfigService.saveConfig(
        deviceId: deviceId,
        dbUrl: url,
        apiKey: apiKey,
      );

      // 3. Supabase servisini bu yeni adres, anahtar ve cihaz ID ile güncelleyelim
      _supabaseService.updateClient(url, apiKey, deviceId: deviceId);

      // 4. Yeni Cihaz ID için veritabanında 5 adet fırça (Firca1..Firca5) kontrol et ve yoksa ekle
      await _supabaseService.ensureDeviceToothbrushesExist(deviceId);

      // 5. Kullanıcıların aktif/pasif durumlarını kaydet
      for (final entry in _activeStatusMap.entries) {
        await DeviceConfigService.setBrushActiveStatus(deviceId, entry.key, entry.value);
      }

      // 6. Kullanıcı ayarlarını en son durumuyla güncelle
      await _loadToothbrushesForDevice(deviceId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Expanded(
                  child: Text('Cihaz ve veritabanı ayarları başarıyla kaydedildi!'),
                ),
              ],
            ),
            backgroundColor: AppColors.greenSuccess,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kayıt sırasında hata oluştu: $e'),
            backgroundColor: AppColors.redMissed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _handleResetDefaults() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Varsayılanlara Sıfırla'),
        content: const Text(
          'Özel bağlantı ayarları silinecek ve uygulamanın varsayılan (.env) ayarlarına dönülecektir. Onaylıyor musunuz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.missedRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sıfırla'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await DeviceConfigService.resetToDefault();
      _supabaseService.resetClient();
      _supabaseService.setDeviceId(DeviceConfigService.defaultDeviceId);

      _deviceIdController.text = DeviceConfigService.defaultDeviceId;
      _dbUrlController.text = SupabaseConstants.url;
      _apiKeyController.text = SupabaseConstants.anonKey;

      await _loadToothbrushesForDevice(DeviceConfigService.defaultDeviceId);

      setState(() {
        _statusMessage = 'Ayarlar varsayılana döndürüldü.';
        _isStatusSuccess = true;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Varsayılan ayarlara dönüldü.'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardTheme.color ??
        (isDark ? AppColors.cardDark : AppColors.cardLight);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const AppBanner(
              title: 'Cihaz Ayarları',
              showBackButton: true,
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(20.0),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Bilgi ve Başlık Kartı
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: isDark
                                      ? [AppColors.primaryDark, AppColors.primaryLightDark]
                                      : [AppColors.primary.withValues(alpha: 0.12), AppColors.primaryLight.withValues(alpha: 0.08)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: AppColors.primary.withValues(alpha: 0.25),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.15),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.settings_input_composite,
                                      color: AppColors.primary,
                                      size: 30,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Cihaz & Veritabanı Entegrasyonu',
                                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Akıllı diş fırçalığınızın ve mobil uygulamanın bağlanacağı ortam parametrelerini buradan yapılandırabilirsiniz.',
                                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                color: isDark
                                                    ? AppColors.secondaryTextDark
                                                    : AppColors.secondaryTextLight,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Cihaz Bilgileri Kartı
                            Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: cardColor,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.04),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.memory, color: AppColors.primary, size: 20),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Cihaz Bilgisi',
                                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  TextFormField(
                                    controller: _deviceIdController,
                                    onChanged: _onDeviceIdChanged,
                                    decoration: InputDecoration(
                                      labelText: 'Cihaz ID (Device ID)',
                                      hintText: 'Örn: Cihaz1',
                                      prefixIcon: const Icon(Icons.tag),
                                      suffixIcon: _isLoadingBrushes
                                          ? const Padding(
                                              padding: EdgeInsets.all(12),
                                              child: SizedBox(
                                                width: 18,
                                                height: 18,
                                                child: CircularProgressIndicator(strokeWidth: 2),
                                              ),
                                            )
                                          : IconButton(
                                              icon: const Icon(Icons.sync, size: 20),
                                              tooltip: 'Kullanıcıları Yenile',
                                              onPressed: () => _loadToothbrushesForDevice(_deviceIdController.text.trim()),
                                            ),
                                      helperText: 'Cihaz ID değiştiğinde kullanıcı ayarları otomatik güncellenir',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    validator: (val) {
                                      if (val == null || val.trim().isEmpty) {
                                        return 'Cihaz ID boş bırakılamaz';
                                      }
                                      return null;
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),

                            // Kullanıcı / Fırça Yönetimi (Aktif / Pasif)
                            Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: cardColor,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.04),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.people_alt_outlined, color: AppColors.primary, size: 20),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Kullanıcı Yönetimi (${_deviceIdController.text.trim().isNotEmpty ? _deviceIdController.text.trim() : "Cihaz"})',
                                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                      ),
                                      if (_isLoadingBrushes)
                                        const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Bu cihaza bağlı kullanıcıları aktif/pasif yapın. 4 kullanıcı aktif olduğunda 2x2 düzeninde listelenir.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  if (_isLoadingBrushes && _toothbrushes.isEmpty)
                                    const Padding(
                                      padding: EdgeInsets.symmetric(vertical: 24),
                                      child: Center(child: CircularProgressIndicator()),
                                    )
                                  else if (_toothbrushes.isEmpty)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      child: Center(
                                        child: Text(
                                          'Bu cihaza ait kullanıcı fırçası henüz yüklenmedi.\n"Kaydet ve Bağlan" ile otomatik oluşturabilirsiniz.',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ),
                                    )
                                  else
                                    ..._toothbrushes.map((brush) {
                                      final isBrushActive = _activeStatusMap[brush.fircaId] ?? true;
                                      final numberStr = brush.fircaId.replaceAll(RegExp(r'[^0-9]'), '');
                                      return Container(
                                        margin: const EdgeInsets.only(bottom: 8),
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: isBrushActive
                                              ? AppColors.primary.withValues(alpha: 0.08)
                                              : (isDark ? Colors.grey[850] : Colors.grey[100]),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: isBrushActive
                                                ? AppColors.primary.withValues(alpha: 0.3)
                                                : Colors.grey.withValues(alpha: 0.2),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            CircleAvatar(
                                              radius: 14,
                                              backgroundColor: isBrushActive
                                                  ? AppColors.primary
                                                  : Colors.grey[400],
                                              child: Text(
                                                numberStr.isNotEmpty ? numberStr : '#',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    brush.userName.isNotEmpty
                                                        ? brush.userName
                                                        : brush.fircaId,
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.w600,
                                                      fontSize: 14,
                                                      color: isBrushActive
                                                          ? null
                                                          : Colors.grey[600],
                                                    ),
                                                  ),
                                                  Text(
                                                    '${brush.fircaId} • ${isBrushActive ? "Aktif" : "Pasif"}',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: isBrushActive
                                                          ? AppColors.primary
                                                          : Colors.grey[500],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Switch.adaptive(
                                              value: isBrushActive,
                                              activeColor: AppColors.primary,
                                              onChanged: (val) async {
                                                setState(() {
                                                  _activeStatusMap[brush.fircaId] = val;
                                                });
                                                final currentDeviceId = _deviceIdController.text.trim();
                                                if (currentDeviceId.isNotEmpty) {
                                                  await DeviceConfigService.setBrushActiveStatus(
                                                    currentDeviceId,
                                                    brush.fircaId,
                                                    val,
                                                  );
                                                }
                                              },
                                            ),
                                          ],
                                        ),
                                      );
                                    }),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),

                            // Veritabanı ve API Key Kartı
                            Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: cardColor,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.04),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.dns, color: AppColors.primary, size: 20),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Veritabanı Bağlantısı',
                                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  TextFormField(
                                    controller: _dbUrlController,
                                    keyboardType: TextInputType.url,
                                    decoration: InputDecoration(
                                      labelText: 'Veritabanı Bağlantı Adresi (URL)',
                                      hintText: 'https://xxxx.supabase.co',
                                      prefixIcon: const Icon(Icons.cloud_outlined),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    validator: (val) {
                                      if (val == null || val.trim().isEmpty) {
                                        return 'Veritabanı adresi boş bırakılamaz';
                                      }
                                      if (!val.trim().startsWith('http://') &&
                                          !val.trim().startsWith('https://')) {
                                        return 'Geçerli bir URL giriniz (https://...)';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: _apiKeyController,
                                    obscureText: _obscureApiKey,
                                    decoration: InputDecoration(
                                      labelText: 'API Key (Anon / Public Key)',
                                      hintText: 'eyJhbGciOi...',
                                      prefixIcon: const Icon(Icons.key_outlined),
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          _obscureApiKey
                                              ? Icons.visibility_outlined
                                              : Icons.visibility_off_outlined,
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            _obscureApiKey = !_obscureApiKey;
                                          });
                                        },
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    validator: (val) {
                                      if (val == null || val.trim().isEmpty) {
                                        return 'API Key boş bırakılamaz';
                                      }
                                      return null;
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Bağlantı Durumu Kartı (Varsa)
                            if (_statusMessage != null) ...[
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: _isStatusSuccess == true
                                      ? AppColors.greenSuccess.withValues(alpha: 0.12)
                                      : AppColors.redMissed.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _isStatusSuccess == true
                                        ? AppColors.greenSuccess
                                        : AppColors.redMissed,
                                    width: 1.2,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      _isStatusSuccess == true
                                          ? Icons.check_circle
                                          : Icons.error_outline,
                                      color: _isStatusSuccess == true
                                          ? AppColors.greenSuccess
                                          : AppColors.redMissed,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        _statusMessage!,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: _isStatusSuccess == true
                                              ? AppColors.greenSuccess
                                              : AppColors.redMissed,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),
                            ],

                            // Butonlar
                            Row(
                              children: [
                                // Bağlantıyı Test Et Butonu
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: (_isTesting || _isSaving)
                                        ? null
                                        : _testConnectionInternal,
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      side: const BorderSide(color: AppColors.primary, width: 1.5),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: _isTesting
                                        ? const SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(Icons.network_check, size: 18),
                                              SizedBox(width: 6),
                                              Text(
                                                'Test Et',
                                                style: TextStyle(fontWeight: FontWeight.bold),
                                              ),
                                            ],
                                          ),
                                  ),
                                ),
                                const SizedBox(width: 12),

                                // Kaydet ve Bağlan Butonu
                                Expanded(
                                  flex: 2,
                                  child: ElevatedButton(
                                    onPressed: (_isTesting || _isSaving)
                                        ? null
                                        : _handleSaveAndConnect,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      elevation: 2,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: _isSaving
                                        ? const SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(Icons.save_outlined, size: 20),
                                              SizedBox(width: 6),
                                              Text(
                                                'Kaydet ve Bağlan',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 15,
                                                ),
                                              ),
                                            ],
                                          ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Varsayılana Dön Butonu
                            Center(
                              child: TextButton.icon(
                                onPressed: (_isTesting || _isSaving)
                                    ? null
                                    : _handleResetDefaults,
                                icon: const Icon(Icons.restore, size: 18, color: Colors.grey),
                                label: const Text(
                                  'Varsayılan Ayarlara Dön (.env)',
                                  style: TextStyle(color: Colors.grey, fontSize: 13),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
