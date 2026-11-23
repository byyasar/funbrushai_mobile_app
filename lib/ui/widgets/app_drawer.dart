import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/providers/theme_provider.dart';
import '../screens/dental_appointments_screen.dart';
import '../screens/family_leaderboard_screen.dart';
import '../screens/device_settings_screen.dart';
import '../screens/music_editor_screen.dart';

class AppDrawer extends StatelessWidget {
  final VoidCallback? onRefreshNeeded;

  const AppDrawer({super.key, this.onRefreshNeeded});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.primaryLight],
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
                  leading: const Icon(Icons.event_note_rounded, color: Color(0xFF0D9488)),
                  title: const Text('Diş Randevularım'),
                  subtitle: const Text('Takvim, hatırlatıcı ve geçmiş', style: TextStyle(fontSize: 11)),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () async {
                    Navigator.pop(context); // Close drawer
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const DentalAppointmentsScreen(),
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
                ListTile(
                  leading: const Icon(Icons.emoji_events, color: Colors.amber),
                  title: const Text('Aile Skor Tablosu'),
                  subtitle: const Text('Haftanın Hijyen Lideri 👑', style: TextStyle(fontSize: 11, color: Colors.amber)),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () async {
                    Navigator.pop(context); // Close drawer
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const FamilyLeaderboardScreen(),
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
          Padding(
            padding: const EdgeInsets.all(16.0),
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
}
