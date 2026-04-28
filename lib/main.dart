import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/screen.dart';
import 'services/auth_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Game Tracker',
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      // AuthGate decide qué pantalla mostrar primero
      home: const AuthGate(),
      // Rutas nombradas — igual que Tweeter
      routes: {
        '/home': (context) => const GameListScreen(),
        '/login': (context) => const LoginScreen(),
      },
    );
  }
}

/// Decide si ir al HomeScreen o al LoginScreen
/// comprobando si hay token persistido en SharedPreferences.
/// Mismo patrón que en Tweeter.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late Future<bool> _sessionFuture;

  @override
  void initState() {
    super.initState();
    _sessionFuture = _checkSession();
  }

  Future<bool> _checkSession() async {
    await AuthService().init();
    return AuthService().isAuthenticated();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _sessionFuture,
      builder: (context, snapshot) {
        // Spinner mientras se leen las SharedPreferences
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final isAuthenticated = snapshot.data ?? false;
        return isAuthenticated ? const GameListScreen() : const LoginScreen();
      },
    );
  }
}