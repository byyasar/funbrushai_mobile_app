import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/providers/theme_provider.dart';
import 'core/providers/mascot_provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/constants/supabase_constants.dart';
import 'core/services/device_config_service.dart';
import 'core/theme/app_theme.dart';
import 'ui/screens/home_screen.dart';

import 'dart:io';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Ekran yönünü sadece dikey (portrait) olarak kilitle
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  await dotenv.load(fileName: ".env");
  
  // Bypass SSL certificate verification for development
  HttpOverrides.global = MyHttpOverrides();

  await initializeDateFormatting('tr', null);

  // Load custom database connection if configured by the user
  final dbUrl = await DeviceConfigService.getDbUrl();
  final apiKey = await DeviceConfigService.getApiKey();

  await Supabase.initialize(
    url: dbUrl.isNotEmpty ? dbUrl : SupabaseConstants.url,
    anonKey: apiKey.isNotEmpty ? apiKey : SupabaseConstants.anonKey,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => MascotProvider()),
      ],
      child: const FunBrushAiApp(),
    ),
  );
}

class FunBrushAiApp extends StatelessWidget {
  const FunBrushAiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FunBrushBoxApp',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: Provider.of<ThemeProvider>(context).themeMode,
      home: const HomeScreen(),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('tr', 'TR'),
      ],
    );
  }
}

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  }
}
