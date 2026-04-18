import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final supabase = Supabase.instance.client;
  final storage = const FlutterSecureStorage();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _decideNavigation();
  }

  Future<void> _decideNavigation() async {
    await Future.delayed(const Duration(seconds: 2));

    try {
      // Refresh session if exists
      if (supabase.auth.currentSession != null) {
        await supabase.auth.refreshSession();
        print('[DEBUG] Session refreshed.');
      }
    } catch (e) {
      print('[DEBUG] Session refresh failed: $e');
      if (!mounted) return;
      context.go('/role');
      return;
    }

    final user = supabase.auth.currentUser;
    if (user == null) {
      print('[DEBUG] No logged in user. Navigating to /role.');
      if (!mounted) return;
      context.go('/role');
      return;
    }

    final uid = user.id;
    print('[DEBUG] Logged in UID: $uid');

    // ------------------ CHECK ADMIN ------------------
    try {
      final admin = await supabase
          .from('admin')
          .select('aid')
          .eq('aid', uid) // Make sure aid column is UUID/text
          .maybeSingle();

      print('[DEBUG] Admin record: $admin');

      if (admin != null && admin.isNotEmpty) {
        print('[DEBUG] User is Admin. Navigating to /admin/home');
        if (!mounted) return;
        context.go('/admin/home');
        return;
      }
    } catch (e) {
      print('[DEBUG] Admin check failed: $e');
    }

    // ------------------ CHECK INVESTIGATION OFFICER ------------------
    try {
      final officer = await supabase
          .from('investigation_officer')
          .select('iid')
          .eq('iid', uid) // Make sure iid column is UUID/text
          .maybeSingle();

      print('[DEBUG] Officer record: $officer');

      if (officer != null && officer.isNotEmpty) {
        print('[DEBUG] User is Officer. Navigating to /officer/home');
        if (!mounted) return;
        context.go('/officer/home');
        return;
      }
    } catch (e) {
      print('[DEBUG] Officer check failed: $e');
    }

    // ------------------ FALLBACK BASED ON SAVED ROLE ------------------
    try {
      final savedRole = await storage.read(key: 'selected_role');
      print('[DEBUG] Saved Role: $savedRole');

      if (savedRole == 'officer') {
        if (!mounted) return;
        print('[DEBUG] Navigating to /officer/login (saved role)');
        context.go('/officer/login');
        return;
      }

      if (savedRole == 'admin') {
        if (!mounted) return;
        print('[DEBUG] Navigating to /admin/login (saved role)');
        context.go('/admin/login');
        return;
      }
    } catch (e) {
      print('[DEBUG] Saved role check failed: $e');
    }

    // ------------------ DEFAULT FALLBACK ------------------
    print('[DEBUG] Default fallback. Navigating to /role');
    if (!mounted) return;
    context.go('/role');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFF6FC),
      body: Center(
        child: SizedBox(
          height: 300,
          width: 300,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Image(
                image: AssetImage('assets/images/logo.png'),
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 20),
              if (_loading)
                const CircularProgressIndicator(color: Color(0xFF0033A0)),
            ],
          ),
        ),
      ),
    );
  }
}
