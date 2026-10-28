import '../database/database_helper.dart';
import 'ai_tutor_service.dart';
import 'sync_service.dart';

/// Service de persistance pour stocker et charger l'historique des discussions avec Ngenou via SQLite.
class AiTutorHistoryService {
  /// Sauvegarde les messages d'une discussion de façon incrémentale.
  /// Seuls les NOUVEAUX messages non encore présents en base sont insérés.
  /// Les messages existants et leurs identifiants de synchronisation sont conservés intacts.
  static Future<void> saveHistory(
    String key,
    List<TutorMessage> messages,
  ) async {
    final db = DatabaseHelper.instance;
    final localDb = await db.database;

    // Récupérer les messages existants non supprimés pour cette session
    final existingRows = await localDb.query(
      'tchat_ia_messages',
      where: 'session_key = ? AND is_deleted = 0',
      whereArgs: [key],
      orderBy: 'id ASC',
    );

    // Signatures des messages existants : role_content_timestamp
    final existingSet = <String>{};
    for (final row in existingRows) {
      final role = (row['role'] ?? '').toString();
      final content = (row['content'] ?? '').toString().trim();
      final ts = (row['timestamp'] ?? '').toString();
      existingSet.add('${role}_${content}_$ts');
    }

    bool hasNew = false;
    for (final m in messages) {
      final role = m.role;
      final content = m.content.trim();
      final ts = m.timestamp.toIso8601String();
      final sig = '${role}_${content}_$ts';

      if (!existingSet.contains(sig)) {
        await db.insertTchatMessage(
          sessionKey: key,
          role: m.role,
          content: m.content,
          timestamp: ts,
        );
        existingSet.add(sig);
        hasNew = true;
      }
    }

    // Sync immédiate de la table chat uniquement s'il y a de nouveaux messages
    if (hasNew) {
      _triggerChatSync(key);
    }
  }

  /// Déclenche une sync de `tchat_ia_messages` en arrière-plan sans bloquer l'UI.
  static void _triggerChatSync(String key) {
    SyncService.instance.syncChatMessages();
  }

  /// Charge l'historique de messages pour une clé donnée avec dédoublonnage strict.
  static Future<List<TutorMessage>> loadHistory(String key) async {
    final db = DatabaseHelper.instance;
    final rows = await db.getTchatMessagesBySession(key);

    final List<TutorMessage> list = [];
    final Set<String> seen = {};

    for (final item in rows) {
      final role = (item['role'] ?? 'user').toString();
      final content = (item['content'] ?? '').toString();
      final tsStr = item['timestamp']?.toString() ?? DateTime.now().toIso8601String();

      // Signature anti-doublon (role + contenu normalisé + timestamp)
      final sig = '${role}_${content.trim()}_$tsStr';
      if (!seen.add(sig)) continue;

      list.add(TutorMessage(
        role: role,
        content: content,
        timestamp: DateTime.tryParse(tsStr) ?? DateTime.now(),
      ));
    }

    return list;
  }

  /// Récupère toutes les conversations sauvegardées pour les lister sur l'écran d'accueil.
  static Future<Map<String, List<TutorMessage>>> getAllHistories() async {
    final db = DatabaseHelper.instance;
    final allRows = await db.getAllTchatHistories();

    final Map<String, List<TutorMessage>> allHistories = {};
    allRows.forEach((sessionKey, rows) {
      final List<TutorMessage> list = [];
      final Set<String> seen = {};

      for (final item in rows) {
        final role = (item['role'] ?? 'user').toString();
        final content = (item['content'] ?? '').toString();
        final tsStr = item['timestamp']?.toString() ?? DateTime.now().toIso8601String();

        final sig = '${role}_${content.trim()}_$tsStr';
        if (!seen.add(sig)) continue;

        list.add(TutorMessage(
          role: role,
          content: content,
          timestamp: DateTime.tryParse(tsStr) ?? DateTime.now(),
        ));
      }
      allHistories[sessionKey] = list;
    });
    return allHistories;
  }

  /// Supprime une conversation (soft delete pour la synchronisation).
  static Future<void> deleteHistory(String key) async {
    final db = DatabaseHelper.instance;
    await db.deleteTchatHistory(key);
    _triggerChatSync(key);
  }
}
