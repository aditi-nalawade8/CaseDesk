import 'package:casedesk/IO/IO_home.dart';
import 'package:casedesk/IO/IO_login.dart';
import 'package:casedesk/admin/admin_home.dart';
import 'package:casedesk/admin/admin_login.dart';
import 'package:casedesk/role_selection.dart';
import 'package:casedesk/splashscreen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://qlkqtirpazjbvpvkbzkm.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFsa3F0aXJwYXpqYnZwdmtiemttIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjU2ODc2OTIsImV4cCI6MjA4MTI2MzY5Mn0.8eT6GNXYvRaDFRufE5JA8g6IOgSEiom0uvjHZiKkORw',
  );

  runApp(const ProviderScope(child: CaseDesk()));
}

class CaseDesk extends ConsumerWidget {
  const CaseDesk({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'CaseFlow',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.indigo),
      routerConfig: _router,
    );
  }
}

// ✅ CORRECT ROUTER
final _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (_, __) => const SplashScreen()),

    GoRoute(path: '/role', builder: (_, __) => const RoleSelectionScreen()),

    // 🔐 Admin
    GoRoute(path: '/admin/login', builder: (_, __) => const AdminLoginScreen()),
    GoRoute(path: '/admin/home', builder: (_, __) => const AdminHomeScreen()),

    // 👮 Investigation Officer
    GoRoute(
      path: '/officer/login',
      builder: (_, __) => const OfficerLoginScreen(),
    ),

    // ✅ THIS MUST BE HOME SCREEN — NOT CaseDetailScreen
    GoRoute(
      path: '/officer/home',
      builder: (_, __) => const InvestigationOfficerHome(),
    ),
  ],
);
