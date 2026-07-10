import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../database/database_helper.dart';
import 'auth_service.dart';
import 'schedule_notification_service.dart';

class SyncService extends ChangeNotifier {
  static final SyncService instance = SyncService._();
  SyncService._();

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  final SupabaseClient _client = Supabase.instance.client;
  Timer? _syncTimer;

  /// Démarre une synchronisation périodique automatique toutes les X minutes,
  /// avec une première sync rapide 30s après le démarrage.
  void startPeriodicSync({int intervalMinutes = 2}) {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(Duration(minutes: intervalMinutes), (timer) {
      if (AuthService.isAuthenticated) {
        syncAll();
      }
    });

    // Première sync rapide 30s après le démarrage (sans attendre intervalMinutes)
    Timer(const Duration(seconds: 30), () {
      if (AuthService.isAuthenticated) {
        syncAll();
      }
    });

    debugPrint(
      'Synchronisation périodique démarrée (toutes les $intervalMinutes minutes, 1ère sync dans 30s).',
    );
  }

  /// Synchronise uniquement la table `tchat_ia_messages`.
  /// Appelé après chaque sauvegarde de message pour une sync immédiate
  /// sans attendre le timer périodique de 2 minutes.
  Future<void> syncChatMessages() async {
    if (!AuthService.isAuthenticated) return;
    // Ne pas bloquer si une sync complète est déjà en cours
    if (_isSyncing) return;
    try {
      final userId = AuthService.currentUser!.id;
      await _syncTable('tchat_ia_messages', 'id', userId, useIdDistant: true);
    } catch (e) {
      debugPrint('Erreur syncChatMessages : $e');
    }
  }

  /// Arrête la synchronisation périodique.
  void stopPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
    debugPrint('Synchronisation périodique arrêtée.');
  }

  /// Déclenche la synchronisation complète de toutes les tables si connecté.
  Future<void> syncAll() async {
    if (_isSyncing) return;
    if (!AuthService.isAuthenticated) {
      debugPrint('Synchronisation impossible : utilisateur non authentifié.');
      return;
    }

    _isSyncing = true;
    notifyListeners();
    debugPrint('Début de la synchronisation Supabase...');

    try {
      final userId = AuthService.currentUser!.id;

      // Synchronisation séquentielle — SQLite ne supporte pas les accès
      // concurrents en écriture, donc on garde le séquentiel pour fiabilité.
      await _syncTable('scores', 'id', userId, useIdDistant: true);
      await _syncTable('progression', 'id', userId, useIdDistant: true);
      await _syncTable('codes_sauvegardes', 'id', userId, useIdDistant: true);
      await _syncTable('cours_personnalises', 'matiere_id', userId);
      await _syncTable('projets', 'id', userId);
      await _syncTable('emplois_du_temps', 'id', userId);
      await _syncTable('taches_revision', 'id', userId);
      await _syncTable(
        'defis_quotidiens_sessions',
        'id',
        userId,
        useIdDistant: true,
      );
      await _syncTable('tchat_ia_messages', 'id', userId, useIdDistant: true);

      // Replanifier toutes les alarmes après la sync des tâches.
      try {
        final pending = await DatabaseHelper.instance.getAllPendingTasks();
        await ScheduleNotificationService.rescheduleAll(pending);
      } catch (e) {
        debugPrint('Erreur reschedule après sync : $e');
      }

      debugPrint('Synchronisation réussie !');
    } catch (e) {
      debugPrint('Erreur lors de la synchronisation : $e');
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────────────────

  /// Parse un timestamp ISO-8601 en ignorant les problèmes de timezone.
  /// Retourne toujours un DateTime UTC comparable.
  DateTime _parseTs(String? raw) {
    if (raw == null || raw.isEmpty)
      return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    final dt = DateTime.tryParse(raw);
    if (dt == null) return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    // S'assurer qu'on compare toujours en UTC
    return dt.isUtc ? dt : dt.toUtc();
  }

  /// Retourne le timestamp UTC actuel en ISO-8601 (avec Z).
  String _nowUtc() => DateTime.now().toUtc().toIso8601String();

  /// Convertit les champs booléens SQLite (0/1) en bool pour Supabase/PostgreSQL.
  void _toSupabaseBooleans(Map<String, dynamic> map) {
    for (final key in [
      'is_deleted',
      'is_system',
      'completed',
      'is_active',
      'inclut_algo',
    ]) {
      if (map.containsKey(key) && map[key] is int) {
        map[key] = map[key] == 1;
      }
    }
  }

  /// Convertit les champs booléens PostgreSQL en entiers (0/1) pour SQLite.
  void _toSqliteBooleans(Map<String, dynamic> map) {
    for (final key in [
      'is_deleted',
      'is_system',
      'completed',
      'is_active',
      'inclut_algo',
    ]) {
      if (map.containsKey(key) && map[key] is bool) {
        map[key] = (map[key] as bool) ? 1 : 0;
      }
    }
  }

  /// Convertit scheduled_at en UTC pour Supabase.
  void _toUtcScheduledAt(Map<String, dynamic> map, String tableName) {
    if (tableName != 'taches_revision') return;
    final raw = map['scheduled_at'];
    if (raw == null) return;
    final dt = DateTime.tryParse(raw.toString());
    if (dt != null) map['scheduled_at'] = dt.toUtc().toIso8601String();
  }

  /// Convertit scheduled_at UTC → heure locale pour SQLite.
  void _toLocalScheduledAt(Map<String, dynamic> map, String tableName) {
    if (tableName != 'taches_revision') return;
    final raw = map['scheduled_at'];
    if (raw == null) return;
    final dt = DateTime.tryParse(raw.toString());
    if (dt != null) map['scheduled_at'] = dt.toLocal().toIso8601String();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // _syncTable : PUSH → PULL → PURGE
  // ─────────────────────────────────────────────────────────────────────────

  /// Règle fondamentale : un enregistrement local avec is_synced=0 contient des
  /// modifications non encore envoyées. Le PULL ne doit JAMAIS l'écraser,
  /// quelle que soit la comparaison de timestamps.
  Future<void> _syncTable(
    String tableName,
    String primaryKey,
    String userId, {
    bool useIdDistant = false,
  }) async {
    final db = await DatabaseHelper.instance.database;

    // ── 1. PUSH : envoyer les modifications locales non synchronisées ──────

    final unsyncedRows = await db.query(tableName, where: 'is_synced = 0');
    for (final row in unsyncedRows) {
      final map = Map<String, dynamic>.from(row);
      map['user_id'] = userId;
      map.remove('is_synced');

      // Normaliser updated_at en UTC avant d'envoyer à Supabase
      if (map['updated_at'] == null || (map['updated_at'] as String).isEmpty) {
        map['updated_at'] = _nowUtc();
      } else {
        final ts = DateTime.tryParse(map['updated_at'].toString());
        if (ts != null) map['updated_at'] = ts.toUtc().toIso8601String();
      }

      _toSupabaseBooleans(map);
      _toUtcScheduledAt(map, tableName);

      if (useIdDistant) {
        final localId = row[primaryKey];
        final idDistant = row['id_distant'];
        map.remove(primaryKey);
        map.remove('id_distant');

        try {
          if (idDistant == null || idDistant.toString().isEmpty) {
            final List<dynamic> inserted = await _client
                .from(tableName)
                .insert(map)
                .select();

            if (inserted.isNotEmpty) {
              final remoteId = inserted.first['id'];
              final remoteUpdatedAt = inserted.first['updated_at']?.toString();
              await db.update(
                tableName,
                {
                  'id_distant': remoteId.toString(),
                  'is_synced': 1,
                  if (remoteUpdatedAt != null) 'updated_at': remoteUpdatedAt,
                },
                where: '$primaryKey = ?',
                whereArgs: [localId],
              );
            }
          } else {
            map['id'] = int.tryParse(idDistant.toString()) ?? idDistant;
            final List<dynamic> upserted = await _client
                .from(tableName)
                .upsert(map)
                .select();
            final remoteUpdatedAt = upserted.isNotEmpty
                ? upserted.first['updated_at']?.toString()
                : null;
            await db.update(
              tableName,
              {
                'is_synced': 1,
                if (remoteUpdatedAt != null) 'updated_at': remoteUpdatedAt,
              },
              where: '$primaryKey = ?',
              whereArgs: [localId],
            );
          }
        } catch (e) {
          debugPrint(
            'Erreur push (id_distant) table $tableName clé $localId : $e',
          );
        }
      } else {
        map.remove('id_distant');
        try {
          final List<dynamic> upserted = await _client
              .from(tableName)
              .upsert(map)
              .select();
          final remoteUpdatedAt = upserted.isNotEmpty
              ? upserted.first['updated_at']?.toString()
              : null;
          await db.update(
            tableName,
            {
              'is_synced': 1,
              if (remoteUpdatedAt != null) 'updated_at': remoteUpdatedAt,
            },
            where: '$primaryKey = ?',
            whereArgs: [row[primaryKey]],
          );
        } catch (e) {
          debugPrint(
            'Erreur push table $tableName clé ${row[primaryKey]} : $e',
          );
        }
      }
    }

    // ── 2. PULL : récupérer les données distantes ──────────────────────────

    try {
      final List<dynamic> remoteRows = await _client
          .from(tableName)
          .select()
          .eq('user_id', userId);

      for (final remote in remoteRows) {
        if (useIdDistant) {
          final remoteIdVal = remote['id'].toString();
          final localRows = await db.query(
            tableName,
            where: 'id_distant = ?',
            whereArgs: [remoteIdVal],
          );

          if (localRows.isEmpty) {
            final isDeleted = remote['is_deleted'];
            final deleted = isDeleted == true || isDeleted == 1;
            if (!deleted) {
              final toInsert = Map<String, dynamic>.from(remote);
              toInsert['id_distant'] = remoteIdVal;
              toInsert['is_synced'] = 1;
              toInsert.remove('id');
              toInsert.remove('user_id');
              _toSqliteBooleans(toInsert);
              _toLocalScheduledAt(toInsert, tableName);
              try {
                await db.insert(tableName, toInsert);
              } catch (e) {
                debugPrint('Erreur insert pull $tableName : $e');
              }
            }
          } else {
            final local = localRows.first;
            if (local['is_synced'] == 0) continue;

            final localUpdated = _parseTs(local['updated_at']?.toString());
            final remoteUpdated = _parseTs(remote['updated_at']?.toString());

            if (remoteUpdated.isAfter(localUpdated)) {
              final toUpdate = Map<String, dynamic>.from(remote);
              toUpdate['id_distant'] = remoteIdVal;
              toUpdate['is_synced'] = 1;
              toUpdate.remove('id');
              toUpdate.remove('user_id');
              _toSqliteBooleans(toUpdate);
              _toLocalScheduledAt(toUpdate, tableName);
              try {
                await db.update(
                  tableName,
                  toUpdate,
                  where: 'id_distant = ?',
                  whereArgs: [remoteIdVal],
                );
              } catch (e) {
                debugPrint('Erreur update pull $tableName : $e');
              }
            }
          }
        } else {
          final keyVal = remote[primaryKey];
          final localRows = await db.query(
            tableName,
            where: '$primaryKey = ?',
            whereArgs: [keyVal],
          );

          if (localRows.isEmpty) {
            final isDeleted = remote['is_deleted'];
            final deleted = isDeleted == true || isDeleted == 1;
            if (!deleted) {
              final toInsert = Map<String, dynamic>.from(remote);
              toInsert['is_synced'] = 1;
              toInsert.remove('id_distant');
              toInsert.remove('user_id');
              _toSqliteBooleans(toInsert);
              _toLocalScheduledAt(toInsert, tableName);
              try {
                await db.insert(tableName, toInsert);
              } catch (e) {
                debugPrint('Erreur insert pull $tableName : $e');
              }
            }
          } else {
            final local = localRows.first;
            if (local['is_synced'] == 0) continue;

            final localUpdated = _parseTs(local['updated_at']?.toString());
            final remoteUpdated = _parseTs(remote['updated_at']?.toString());

            if (remoteUpdated.isAfter(localUpdated)) {
              final toUpdate = Map<String, dynamic>.from(remote);
              toUpdate['is_synced'] = 1;
              toUpdate.remove('id_distant');
              toUpdate.remove('user_id');
              _toSqliteBooleans(toUpdate);
              _toLocalScheduledAt(toUpdate, tableName);
              try {
                await db.update(
                  tableName,
                  toUpdate,
                  where: '$primaryKey = ?',
                  whereArgs: [keyVal],
                );
              } catch (e) {
                debugPrint('Erreur update pull $tableName : $e');
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Erreur pull table $tableName : $e');
    }

    // ── 3. PURGE ────────────────────────────────────────────────────────────
    // Purge locale : supprimer les lignes soft-deleted déjà synchronisées
    try {
      await db.delete(tableName, where: 'is_deleted = 1 AND is_synced = 1');
    } catch (e) {
      debugPrint('Erreur purge locale table $tableName : $e');
    }

    // Purge distante : supprimer les lignes soft-deleted dans Supabase
    // pour éviter l'accumulation de doublons au fil du temps.
    try {
      await _client
          .from(tableName)
          .delete()
          .eq('user_id', userId)
          .eq('is_deleted', true);
    } catch (e) {
      debugPrint('Erreur purge distante table $tableName : $e');
    }
  }
}
