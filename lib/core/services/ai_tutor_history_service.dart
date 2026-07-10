import '../database/database_helper.dart';
import 'ai_tutor_service.dart';
import 'sync_service.dart';

/// Service de persistance pour stocker et charger l'historique des discussions avec Ngenou via SQLite.
class AiTutorHistoryService {
  /// Sauvegarde le nouveau message de l'historique pour une clé de session donnée.
  /// Efface et réinsère tous les messages, puis déclenche une sync immédiate
  /// de la table tchat_ia_messages pour que les messages soient visibles dans Supabase.
  static Future<void> saveHistory(
    String key,
    List<TutorMessage> messages,
  ) async {
    final db = DatabaseHelper.instance;
    final localDb = await db.database;

    // Soft delete de l'historique existant
    await localDb.update(
      'tchat_ia_messages',
      {
        'is_deleted': 1,
        'is_synced': 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'session_key = ?',
      whereArgs: [key],
    );

    for (final m in messages) {
      await db.insertTchatMessage(
        sessionKey: key,
        role: m.role,
        content: m.content,
        timestamp: m.timestamp.toIso8601String(),
      );
    }

    // Sync immédiate de la table chat — sans attendre le timer de 2 min
    // pour que les messages apparaissent instantanément dans Supabase.
    _triggerChatSync(key);
  }

  /// Déclenche une sync de `tchat_ia_messages` en arrière-plan sans bloquer l'UI.
  static void _triggerChatSync(String key) {
    SyncService.instance.syncChatMessages();
  }

  /// Charge l'historique de messages pour une clé donnée.
  static Future<List<TutorMessage>> loadHistory(String key) async {
    final db = DatabaseHelper.instance;
    final rows = await db.getTchatMessagesBySession(key);

    return rows.map((item) {
      return TutorMessage(
        role: item['role'] ?? 'user',
        content: item['content'] ?? '',
        timestamp: DateTime.parse(
          item['timestamp'] ?? DateTime.now().toIso8601String(),
        ),
      );
    }).toList();
  }

  /// Récupère toutes les conversations sauvegardées pour les lister sur l'écran d'accueil.
  static Future<Map<String, List<TutorMessage>>> getAllHistories() async {
    final db = DatabaseHelper.instance;
    final allRows = await db.getAllTchatHistories();

    final Map<String, List<TutorMessage>> allHistories = {};
    allRows.forEach((sessionKey, rows) {
      allHistories[sessionKey] = rows.map((item) {
        return TutorMessage(
          role: item['role'] ?? 'user',
          content: item['content'] ?? '',
          timestamp: DateTime.parse(
            item['timestamp'] ?? DateTime.now().toIso8601String(),
          ),
        );
      }).toList();
    });
    return allHistories;
  }

  /// Supprime une conversation (soft delete pour la synchronisation).
  static Future<void> deleteHistory(String key) async {
    final db = DatabaseHelper.instance;
    await db.deleteTchatHistory(key);
  }
}
