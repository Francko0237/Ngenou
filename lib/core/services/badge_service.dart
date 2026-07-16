import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/database_helper.dart';
import '../models/badge.dart';
import '../widgets/badge_unlocked_dialog.dart';

class BadgeService {
  static final BadgeService instance = BadgeService._init();
  BadgeService._init();

  final List<AppBadge> defaultBadges = [
    AppBadge(
      id: 'first_defi',
      nom: 'Premier Pas',
      description: 'Vous avez complété votre premier défi quotidien.',
      icone: '🎯',
      category: 'streak',
      conditionDesc: 'Compléter 1 défi quotidien',
    ),
    AppBadge(
      id: 'defi_streak_3',
      nom: 'Régulier',
      description: '3 jours de défis consécutifs ! La régularité paye.',
      icone: '🔥',
      category: 'streak',
      conditionDesc: '3 jours de défis consécutifs',
    ),
    AppBadge(
      id: 'defi_streak_7',
      nom: 'Acharné',
      description: 'Une semaine entière de défis consécutifs ! Impressionnant.',
      icone: '⚡',
      category: 'streak',
      conditionDesc: '7 jours de défis consécutifs',
    ),
    AppBadge(
      id: 'defi_streak_30',
      nom: 'Légende',
      description: '30 jours consécutifs ! Vous êtes entré dans la légende.',
      icone: '👑',
      category: 'streak',
      conditionDesc: '30 jours de défis consécutifs',
    ),
    AppBadge(
      id: 'perfect_defi',
      nom: 'Sans Faute',
      description:
          'Vous avez obtenu 100% de bonnes réponses à un défi quotidien.',
      icone: '⭐',
      category: 'excellence',
      conditionDesc: '100% correct sur un défi quotidien',
    ),
    AppBadge(
      id: 'first_notion',
      nom: 'Premier Chapitre',
      description: 'Vous avez terminé votre première notion de cours.',
      icone: '📖',
      category: 'learning',
      conditionDesc: 'Terminer 1 notion',
    ),
    AppBadge(
      id: 'notions_5',
      nom: 'Studieux',
      description: '5 notions terminées. Vous progressez rapidement !',
      icone: '🎓',
      category: 'learning',
      conditionDesc: 'Terminer 5 notions',
    ),
    AppBadge(
      id: 'notions_20',
      nom: 'Expert',
      description: '20 notions terminées. Plus rien ne vous arrête.',
      icone: '🏆',
      category: 'learning',
      conditionDesc: 'Terminer 20 notions',
    ),
    AppBadge(
      id: 'first_algo',
      nom: 'Hello World',
      description: 'Vous avez résolu votre premier défi d\'algorithmique.',
      icone: '💻',
      category: 'algo',
      conditionDesc: 'Réussir 1 défi algorithmique',
    ),
    AppBadge(
      id: 'algo_5',
      nom: 'Codeur d\'Élite',
      description: '5 défis d\'algorithmique résolus avec succès.',
      icone: '🚀',
      category: 'algo',
      conditionDesc: 'Réussir 5 défis algorithmiques',
    ),
    AppBadge(
      id: 'perfect_score',
      nom: 'Grand Maître',
      description:
          'Vous avez complété une notion avec 100% de réussite aux exercices.',
      icone: '💎',
      category: 'excellence',
      conditionDesc: '100% aux exercices d\'une notion',
    ),
    AppBadge(
      id: 'first_course',
      nom: 'Créateur',
      description: 'Vous avez créé votre premier cours personnalisé.',
      icone: '✨',
      category: 'creative',
      conditionDesc: 'Créer 1 cours personnalisé',
    ),
    AppBadge(
      id: 'first_project',
      nom: 'Organisé',
      description: 'Vous avez créé votre premier projet d\'apprentissage.',
      icone: '📋',
      category: 'creative',
      conditionDesc: 'Créer 1 projet d\'études',
    ),
    AppBadge(
      id: 'early_bird',
      nom: 'Lève-tard ? Non !',
      description:
          'Défi complété avant 8h du matin. L\'avenir appartient à ceux qui se lèvent tôt.',
      icone: '🌅',
      category: 'activity',
      conditionDesc: 'Compléter un défi avant 8h',
    ),
    AppBadge(
      id: 'night_owl',
      nom: 'Oiseau de Nuit',
      description:
          'Défi complété après 22h. L\'inspiration vient avec la nuit.',
      icone: '🦉',
      category: 'activity',
      conditionDesc: 'Compléter un défi après 22h',
    ),
  ];

  /// Récupère la liste de tous les badges avec leur état de verrouillage
  Future<List<AppBadge>> getAllBadgesWithLockState() async {
    final db = DatabaseHelper.instance;
    final unlocked = await db.getUnlockedBadges();

    return defaultBadges.map((badge) {
      final found = unlocked.where((b) => b.id == badge.id).firstOrNull;
      if (found != null) {
        return badge.copyWith(unlockedAt: found.unlockedAt);
      }
      return badge;
    }).toList();
  }

  /// Vérifie si de nouveaux badges ont été débloqués et affiche les popups.
  Future<List<AppBadge>> checkAndUnlock(BuildContext context) async {
    final db = DatabaseHelper.instance;
    final List<AppBadge> newlyUnlocked = [];

    // ── Migration silencieuse (premier appel) ────────────────────────────
    // Si des conditions sont déjà satisfaites (activité préexistante),
    // on les marque en base SANS afficher de dialog pour éviter la cascade.
    final prefs = await SharedPreferences.getInstance();
    final migrationDone = prefs.getBool('badge_migration_v1') ?? false;
    if (!migrationDone) {
      await _runSilentMigration(db);
      await prefs.setBool('badge_migration_v1', true);
    }

    // Récupérer les stats globales
    final streak = await db.getDefiStreak();
    final completedNotions = await db.getCompletedNotionsCount();
    final customCourses = await db.getCustomCoursesCount();
    final projects = await db.getProjectsCount();
    final solvedAlgos = await db.countSolvedAlgos();
    final perfectDefi = await db.hasPerfectDefi();
    final perfectScore = await db.hasPerfectMatiereScore();

    final now = DateTime.now();
    final hour = now.hour;

    for (final baseBadge in defaultBadges) {
      final isUnlocked = await db.isBadgeUnlocked(baseBadge.id);
      if (isUnlocked) continue;

      bool conditionMet = false;

      switch (baseBadge.id) {
        case 'first_defi':
          // Streak >= 1 ou au moins une session terminée
          conditionMet = streak >= 1;
          break;
        case 'defi_streak_3':
          conditionMet = streak >= 3;
          break;
        case 'defi_streak_7':
          conditionMet = streak >= 7;
          break;
        case 'defi_streak_30':
          conditionMet = streak >= 30;
          break;
        case 'perfect_defi':
          conditionMet = perfectDefi;
          break;
        case 'first_notion':
          conditionMet = completedNotions >= 1;
          break;
        case 'notions_5':
          conditionMet = completedNotions >= 5;
          break;
        case 'notions_20':
          conditionMet = completedNotions >= 20;
          break;
        case 'first_algo':
          conditionMet = solvedAlgos >= 1;
          break;
        case 'algo_5':
          conditionMet = solvedAlgos >= 5;
          break;
        case 'perfect_score':
          conditionMet = perfectScore;
          break;
        case 'first_course':
          conditionMet = customCourses >= 1;
          break;
        case 'first_project':
          conditionMet = projects >= 1;
          break;
        case 'early_bird':
          // Débloquable si le défi actuel est fait avant 8h
          // Mais on doit s'assurer qu'au moins 1 défi a été fait
          conditionMet = streak >= 1 && hour < 8;
          break;
        case 'night_owl':
          // Débloquable si le défi actuel est fait après 22h
          conditionMet = streak >= 1 && hour >= 22;
          break;
      }

      if (conditionMet) {
        await db.unlockBadge(baseBadge.id, baseBadge);
        final unlockedBadge = baseBadge.copyWith(unlockedAt: now);
        newlyUnlocked.add(unlockedBadge);
      }
    }

    // Afficher les dialogues de déblocage l'un après l'autre
    if (newlyUnlocked.isNotEmpty && context.mounted) {
      for (final badge in newlyUnlocked) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (c) => BadgeUnlockedDialog(badge: badge),
        );
      }
    }

    return newlyUnlocked;
  }

  /// Migration silencieuse — marque en base tous les badges dont la condition
  /// est déjà satisfaite, SANS afficher de dialog.
  /// Appelée une seule fois (clé badge_migration_v1 dans SharedPreferences).
  Future<void> _runSilentMigration(DatabaseHelper db) async {
    final streak = await db.getDefiStreak();
    final completedNotions = await db.getCompletedNotionsCount();
    final customCourses = await db.getCustomCoursesCount();
    final projects = await db.getProjectsCount();
    final solvedAlgos = await db.countSolvedAlgos();
    final perfectDefi = await db.hasPerfectDefi();
    final perfectScore = await db.hasPerfectMatiereScore();
    final now = DateTime.now();
    // Date fictive dans le passé pour les badges "déjà mérités"
    final pastDate = now.subtract(const Duration(days: 1));

    for (final badge in defaultBadges) {
      final isUnlocked = await db.isBadgeUnlocked(badge.id);
      if (isUnlocked) continue;

      bool conditionMet = false;
      switch (badge.id) {
        case 'first_defi':
          conditionMet = streak >= 1;
          break;
        case 'defi_streak_3':
          conditionMet = streak >= 3;
          break;
        case 'defi_streak_7':
          conditionMet = streak >= 7;
          break;
        case 'defi_streak_30':
          conditionMet = streak >= 30;
          break;
        case 'perfect_defi':
          conditionMet = perfectDefi;
          break;
        case 'first_notion':
          conditionMet = completedNotions >= 1;
          break;
        case 'notions_5':
          conditionMet = completedNotions >= 5;
          break;
        case 'notions_20':
          conditionMet = completedNotions >= 20;
          break;
        case 'first_algo':
          conditionMet = solvedAlgos >= 1;
          break;
        case 'algo_5':
          conditionMet = solvedAlgos >= 5;
          break;
        case 'perfect_score':
          conditionMet = perfectScore;
          break;
        case 'first_course':
          conditionMet = customCourses >= 1;
          break;
        case 'first_project':
          conditionMet = projects >= 1;
          break;
        // early_bird / night_owl : basés sur l'heure actuelle, pas de migration
        default:
          conditionMet = false;
      }

      if (conditionMet) {
        // Enregistrer avec une date dans le passé — badge "déjà mérité"
        await db.unlockBadgeSilent(badge.id, badge, pastDate);
      }
    }
  }
}
