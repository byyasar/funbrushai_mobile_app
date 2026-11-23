import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/providers/theme_provider.dart';
import '../screens/device_settings_screen.dart';
import '../screens/music_editor_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/toothbrush_card_screen.dart';

class AppDrawer extends StatelessWidget {
  final VoidCallback? onRefreshNeeded;

  const AppDrawer({super.key, this.onRefreshNeeded});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Drawer(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [AppColors.primaryDark, AppColors.primaryLightDark]
                    : [AppColors.primary, AppColors.primaryLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: SizedBox(
              width: double.infinity,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      image: const DecorationImage(
                        image: AssetImage('assets/icon/app_icon.jpg'),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'FunBrushBoxApp',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                ListTile(
                  leading: const Icon(Icons.home, color: AppColors.primary),
                  title: const Text('Ana Sayfa'),
                  onTap: () {
                    Navigator.pop(context); // Close drawer
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.cleaning_services_rounded, color: Color(0xFF2563EB)),
                  title: const Text('Diş Fırçalarım'),
                  subtitle: const Text('Fırça durumları ve kullanım ömürleri', style: TextStyle(fontSize: 11)),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () async {
                    Navigator.pop(context); // Close drawer
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ToothbrushCardScreen(),
                      ),
                    );
                    onRefreshNeeded?.call();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.settings_input_composite, color: AppColors.primary),
                  title: const Text('Cihaz Ayarları'),
                  subtitle: const Text('Cihaz ID & Veritabanı', style: TextStyle(fontSize: 11)),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () async {
                    Navigator.pop(context); // Close drawer
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const DeviceSettingsScreen(),
                      ),
                    );
                    onRefreshNeeded?.call();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.account_circle_rounded, color: Color(0xFF059669)),
                  title: const Text('Kullanıcı Avatarını Düzenle'),
                  subtitle: const Text('Profil fotoğrafı ve avatar seçimi', style: TextStyle(fontSize: 11)),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () async {
                    Navigator.pop(context); // Close drawer
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const SettingsScreen(),
                      ),
                    );
                    onRefreshNeeded?.call();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.music_note_rounded, color: Colors.purple),
                  title: const Text('Müzik Düzenleme'),
                  subtitle: const Text('30 sn aralıklı fırçalama müziği', style: TextStyle(fontSize: 11)),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () async {
                    Navigator.pop(context); // Close drawer
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const MusicEditorScreen(),
                      ),
                    );
                    onRefreshNeeded?.call();
                  },
                ),
                // Theme Toggle
                Consumer<ThemeProvider>(
                  builder: (context, themeProvider, child) {
                    return SwitchListTile(
                      title: const Text('Karanlık Mod'),
                      secondary: Icon(
                        themeProvider.isDarkMode ? Icons.dark_mode : Icons.light_mode,
                        color: AppColors.primary,
                      ),
                      value: themeProvider.isDarkMode,
                      onChanged: (bool value) {
                        themeProvider.setThemeMode(
                          value ? ThemeMode.dark : ThemeMode.light,
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.exit_to_app_rounded, color: AppColors.redMissed),
            title: const Text(
              'Uygulamadan Çıkış',
              style: TextStyle(
                color: AppColors.redMissed,
                fontWeight: FontWeight.w600,
              ),
            ),
            onTap: () => _confirmExit(context),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 12.0, top: 4.0),
            child: Text(
              'Versiyon 1.0.0',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.grey,
                  ),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  Future<void> _confirmExit(BuildContext context) async {
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Uygulamadan Çıkış'),
        content: const Text('Uygulamadan çıkmak istediğinize emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.redMissed),
            child: const Text('Çıkış Yap'),
          ),
        ],
      ),
    );

    if (shouldExit == true) {
      if (Platform.isAndroid) {
        await SystemNavigator.pop();
      } else {
        exit(0);
      }
    }
  }
}
