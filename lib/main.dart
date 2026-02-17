import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'components/screens/navbar.dart';

void main() {
  // Sistem UI ayarları
  WidgetsFlutterBinding.ensureInitialized();
  
  // Status bar ve navigation bar renklerini ayarla
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF1E2329),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  
  // Sadece portrait mode (dikey)
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  runApp(const BorsaUygulamasi());
}

class BorsaUygulamasi extends StatelessWidget {
  const BorsaUygulamasi({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Crypto Trading Bot',
      debugShowCheckedModeBanner: false,
      
      // Koyu tema konfigürasyonu
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        
        // Ana renkler
        primaryColor: Colors.cyanAccent,
        scaffoldBackgroundColor: const Color(0xFF0B0E11),
        
        // AppBar teması
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E2329),
          elevation: 0,
          centerTitle: true,
          iconTheme: IconThemeData(color: Colors.cyanAccent),
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        
        // Card teması
        cardTheme: const CardTheme(
          color: Color(0xFF1E2329),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
        ),
        
        // Input decoration teması
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF2A2E39),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          hintStyle: const TextStyle(
            color: Colors.white38,
            fontSize: 12,
          ),
        ),
        
        // Icon teması
        iconTheme: const IconThemeData(
          color: Colors.cyanAccent,
        ),
        
        // Text teması
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.white),
          bodyMedium: TextStyle(color: Colors.white70),
          bodySmall: TextStyle(color: Colors.white54),
        ),
        
        // Divider teması
        dividerTheme: const DividerThemeData(
          color: Color(0xFF2A2E39),
          thickness: 1,
        ),
        
        // BottomNavigationBar teması
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF1E2329),
          selectedItemColor: Colors.cyanAccent,
          unselectedItemColor: Colors.white38,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
        ),
        
        // Progress indicator teması
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: Colors.cyanAccent,
        ),
      ),
      
      // Uygulama açıldığında navbar ile başlat
      home: const MainNavBar(),
    );
  }
}