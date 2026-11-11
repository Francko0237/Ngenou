import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/supabase/providers.dart';
import '../features/admin/auth/admin_login_page.dart';
import '../features/admin/dashboard/admin_dashboard_page.dart';
import '../features/admin/release_form/admin_release_form_page.dart';
import '../features/public/confidentialite/confidentialite_page.dart';
import '../features/public/home/home_page.dart';
import '../features/public/nouveautes/nouveautes_page.dart';

/// Provider du routeur GoRouter avec garde d'accès admin
final appRouterProvider = Provider<GoRouter>((ref) {
  final authRepo = ref.watch(authRepositoryProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (BuildContext context, GoRouterState state) async {
      final loc = state.uri.path;
      final isAdminRoute = loc.startsWith('/admin');
      final isLoginPage = loc == '/admin/login';

      if (!isAdminRoute) {
        // Routes publiques : accès libre
        return null;
      }

      final session = authRepo.currentSession;
      final isAuthenticated = session != null;

      if (!isAuthenticated) {
        return isLoginPage ? null : '/admin/login';
      }

      // Vérifier si l'utilisateur est bien admin
      final isAdmin = await authRepo.verifyIsAdmin();

      if (!isAdmin) {
        // Déconnecter et renvoyer sur le login si le rôle n'est pas présent
        await authRepo.signOut();
        return isLoginPage ? null : '/admin/login';
      }

      // Si l'utilisateur est déjà admin et se rend sur la page de login, on le redirige vers le dashboard
      if (isLoginPage) {
        return '/admin';
      }

      return null;
    },
    routes: [
      // Routes publiques
      GoRoute(
        path: '/',
        builder: (context, state) => const HomePage(),
      ),
      GoRoute(
        path: '/nouveautes',
        builder: (context, state) => const NouveautesPage(),
      ),
      GoRoute(
        path: '/confidentialite',
        builder: (context, state) => const ConfidentialitePage(),
      ),

      // Routes d'administration cachées
      GoRoute(
        path: '/admin/login',
        builder: (context, state) => const AdminLoginPage(),
      ),
      GoRoute(
        path: '/admin',
        builder: (context, state) => const AdminDashboardPage(),
      ),
      GoRoute(
        path: '/admin/releases/new',
        builder: (context, state) => const AdminReleaseFormPage(),
      ),
      GoRoute(
        path: '/admin/releases/:id/edit',
        builder: (context, state) {
          final id = state.pathParameters['id'];
          return AdminReleaseFormPage(releaseId: id);
        },
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '404 - Page introuvable',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.go('/'),
              child: const Text('Retour à l\'accueil'),
            ),
          ],
        ),
      ),
    ),
  );
});
