import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/supabase_constants.dart';

class DeviceConfigService {
  static const String _keyDeviceId = 'device_id';
  static const String _keyDbUrl = 'custom_supabase_url';
  static const String _keyApiKey = 'custom_supabase_anon_key';

  /// Varsayılan Cihaz ID değeri
  static String get defaultDeviceId => dotenv.env['DEVICE_ID'] ?? 'Cihaz1';

  /// Kayıtlı Cihaz ID'sini döndürür. Yoksa varsayılan olarak 'Cihaz1' döner.
  static Future<String> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_keyDeviceId);
    if (saved != null && saved.trim().isNotEmpty) {
      return saved.trim();
    }
    return defaultDeviceId;
  }

  /// Kayıtlı veritabanı URL'sini döndürür. Yoksa .env'deki varsayılanı döner.
  static Future<String> getDbUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_keyDbUrl);
    if (saved != null && saved.trim().isNotEmpty) {
      return saved.trim();
    }
    return SupabaseConstants.url;
  }

  /// Kayıtlı API Key'i döndürür. Yoksa .env'deki varsayılanı döner.
  static Future<String> getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_keyApiKey);
    if (saved != null && saved.trim().isNotEmpty) {
      return saved.trim();
    }
    return SupabaseConstants.anonKey;
  }

  /// Cihaz ID, URL ve API Key'i SharedPreferences'a kaydeder.
  static Future<void> saveConfig({
    required String deviceId,
    required String dbUrl,
    required String apiKey,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyDeviceId, deviceId.trim());
    await prefs.setString(_keyDbUrl, dbUrl.trim());
    await prefs.setString(_keyApiKey, apiKey.trim());
  }

  /// Özel ayarları temizleyip .env varsayılanlarına döner.
  static Future<void> resetToDefault() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyDeviceId);
    await prefs.remove(_keyDbUrl);
    await prefs.remove(_keyApiKey);
  }

  /// Özel bir konfigürasyon girilip girilmediğini kontrol eder.
  static Future<bool> hasCustomConfig() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_keyDbUrl) || prefs.containsKey(_keyDeviceId);
  }

  static String _keyInactiveBrushes(String deviceId) => 'inactive_brushes_${deviceId.trim()}';

  /// Belirtilen cihaz için pasif yapılan fırça ID'lerini döndürür
  static Future<Set<String>> getInactiveBrushIds(String deviceId) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_keyInactiveBrushes(deviceId)) ?? [];
    return list.toSet();
  }

  /// Belirtilen cihaz için fırçanın aktif/pasif durumunu kaydeder
  static Future<void> setBrushActiveStatus(String deviceId, String fircaId, bool isActive) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _keyInactiveBrushes(deviceId);
    final current = (prefs.getStringList(key) ?? []).toSet();
    if (isActive) {
      current.remove(fircaId.trim());
    } else {
      current.add(fircaId.trim());
    }
    await prefs.setStringList(key, current.toList());
  }

  /// Tüm fırçaların aktif/pasif durum haritasını döndürür
  static Future<Map<String, bool>> getBrushesActiveMap(String deviceId, List<String> fircaIds) async {
    final inactive = await getInactiveBrushIds(deviceId);
    final result = <String, bool>{};
    for (final id in fircaIds) {
      result[id] = !inactive.contains(id);
    }
    return result;
  }
}
