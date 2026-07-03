import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:refurbnation/theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/onboarding_screen.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => AuthProvider())],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        return MaterialApp(
          title: 'RefurbNation',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: auth.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          initialRoute: '/',
          routes: {
            '/': (context) => const AppSystemDispatcher(),
            '/dashboard': (context) => const DashboardScreen(),
            '/login': (context) => const LoginScreen(),
          },
        );
      },
    );
  }
}

class AppSystemDispatcher extends StatefulWidget {
  const AppSystemDispatcher({super.key});

  @override
  State<AppSystemDispatcher> createState() => _AppSystemDispatcherState();
}

class _AppSystemDispatcherState extends State<AppSystemDispatcher> {
  bool _checkedOnboarding = false;
  bool _hasSeenOnboarding = false;

  @override
  void initState() {
    super.initState();
    _evaluateOnboardingState();
  }

  Future<void> _evaluateOnboardingState() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    String? seen = await auth.storage.read(key: 'has_seen_onboarding');

    if (seen == 'true') {
      await auth.checkAutoLogin();
    }

    if (mounted) {
      setState(() {
        _hasSeenOnboarding = seen == 'true';
        _checkedOnboarding = true;
      });
    }
  }

  Future<void> _completeOnboarding() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    await auth.storage.write(key: 'has_seen_onboarding', value: 'true');
    setState(() {
      _hasSeenOnboarding = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_checkedOnboarding) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
      );
    }

    if (!_hasSeenOnboarding) {
      return OnboardingScreen(onFinish: _completeOnboarding);
    }

    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        if (auth.isAuthenticated) {
          return const DashboardScreen();
        } else {
          return const LoginScreen();
        }
      },
    );
  }
}
