import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/app_release.dart';
import 'auth_repository.dart';
import 'release_repository.dart';

/// Provider du repository des versions
final releaseRepositoryProvider = Provider<ReleaseRepository>((ref) {
  return ReleaseRepository();
});

/// Provider du repository d'authentification
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

/// Provider de la liste des versions publiées (Public)
final publishedReleasesProvider = FutureProvider<List<AppRelease>>((ref) async {
  final repo = ref.watch(releaseRepositoryProvider);
  return repo.getPublishedReleases();
});

/// Provider de la dernière version publiée (Bouton Téléchargement Hero & Navbar)
final latestReleaseProvider = FutureProvider<AppRelease?>((ref) async {
  final repo = ref.watch(releaseRepositoryProvider);
  return repo.getLatestPublishedRelease();
});

/// Provider de toutes les versions pour la console d'administration
final adminReleasesProvider =
    FutureProvider.autoDispose<List<AppRelease>>((ref) async {
  final repo = ref.watch(releaseRepositoryProvider);
  return repo.getAllReleasesAdmin();
});

/// Provider d'écoute de l'état d'authentification Supabase
final authStateProvider = StreamProvider<AuthState>((ref) {
  final authRepo = ref.watch(authRepositoryProvider);
  return authRepo.authStateChanges;
});

/// Provider vérifiant si l'utilisateur actuel a le rôle admin
final isAdminProvider = FutureProvider.autoDispose<bool>((ref) async {
  final authRepo = ref.watch(authRepositoryProvider);
  return authRepo.verifyIsAdmin();
});
