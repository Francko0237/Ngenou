import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/score.dart';
import '../models/progression.dart';
import '../models/custom_course_package.dart';
import '../models/projet.dart';
import '../models/study_schedule.dart';
import '../models/study_task.dart';
import '../models/task_priority.dart';
import '../models/daily_challenge.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('ngenou.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 11,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE codes_sauvegardes (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          nom TEXT NOT NULL,
          code TEXT NOT NULL,
          date_creation TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE cours_personnalises (
          matiere_id TEXT PRIMARY KEY,
          json_data TEXT NOT NULL,
          date_creation TEXT NOT NULL,
          date_modification TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 4) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS projets (
          id TEXT PRIMARY KEY,
          nom TEXT NOT NULL,
          description TEXT,
          objectif TEXT,
          couleur TEXT NOT NULL,
          icone TEXT NOT NULL,
          matiere_ids TEXT NOT NULL DEFAULT '[]',
          is_system INTEGER NOT NULL DEFAULT 0,
          date_creation TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 5) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS emplois_du_temps (
          id TEXT PRIMARY KEY,
          titre TEXT NOT NULL,
          subjects_json TEXT NOT NULL,
          routine_json TEXT NOT NULL,
          is_active INTEGER NOT NULL DEFAULT 1,
          date_creation TEXT NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS taches_revision (
          id TEXT PRIMARY KEY,
          schedule_id TEXT NOT NULL,
          matiere_id TEXT NOT NULL,
          matiere_nom TEXT NOT NULL,
          projet_id TEXT,
          scheduled_at TEXT NOT NULL,
          duration_minutes INTEGER NOT NULL,
          status TEXT NOT NULL DEFAULT 'pending',
          notification_id INTEGER,
          FOREIGN KEY (schedule_id) REFERENCES emplois_du_temps(id) ON DELETE CASCADE
        )
      ''');
    }
    if (oldVersion < 6) {
      await db.execute(
        'ALTER TABLE emplois_du_temps ADD COLUMN period_weeks INTEGER NOT NULL DEFAULT 2',
      );
    }
    if (oldVersion < 7) {
      await db.execute(
        'ALTER TABLE emplois_du_temps ADD COLUMN period_start TEXT',
      );
      await db.execute(
        'ALTER TABLE emplois_du_temps ADD COLUMN period_end TEXT',
      );
    }
    if (oldVersion < 8) {
      await db.execute('ALTER TABLE taches_revision ADD COLUMN title TEXT');
      await db.execute(
        "ALTER TABLE taches_revision ADD COLUMN priority TEXT NOT NULL DEFAULT 'normal'",
      );
      await _ensureManualSchedule(db);
    }
    if (oldVersion < 9) {
      await db.execute(
        "ALTER TABLE taches_revision ADD COLUMN activity_type TEXT NOT NULL DEFAULT 'study'",
      );
    }
    if (oldVersion < 10) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS defis_quotidiens_sessions (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          date TEXT UNIQUE,
          score INTEGER NOT NULL,
          total INTEGER NOT NULL,
          inclut_algo INTEGER NOT NULL,
          challenges_json TEXT NOT NULL,
          completed INTEGER NOT NULL
        )
      ''');
      if (oldVersion < 11) {
        final tables = [
          'scores',
          'progression',
          'codes_sauvegardes',
          'cours_personnalises',
          'projets',
          'emplois_du_temps',
          'taches_revision',
          'defis_quotidiens_sessions',
        ];
        for (var table in tables) {
          try {
            await db.execute('ALTER TABLE $table ADD COLUMN id_distant TEXT');
            await db.execute('ALTER TABLE $table ADD COLUMN updated_at TEXT');
            await db.execute(
              'ALTER TABLE $table ADD COLUMN is_synced INTEGER NOT NULL DEFAULT 0',
            );
            await db.execute(
              'ALTER TABLE $table ADD COLUMN is_deleted INTEGER NOT NULL DEFAULT 0',
            );
          } catch (e) {
            print("Erreur migration table $table: $e");
          }
        }

        await db.execute('''
        CREATE TABLE IF NOT EXISTS tchat_ia_messages (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          session_key TEXT NOT NULL,
          role TEXT NOT NULL,
          content TEXT NOT NULL,
          timestamp TEXT NOT NULL,
          id_distant TEXT,
          updated_at TEXT,
          is_synced INTEGER NOT NULL DEFAULT 0,
          is_deleted INTEGER NOT NULL DEFAULT 0
        )
      ''');
      }
    }
  }

  Future<void> _ensureManualSchedule(Database db) async {
    final now = DateTime.now().toIso8601String();
    final start = DateTime.now().toIso8601String().substring(0, 10);
    await db.insert('emplois_du_temps', {
      'id': StudyTask.manualScheduleId,
      'titre': 'Tâches manuelles',
      'subjects_json': '[]',
      'routine_json': '{}',
      'period_start': start,
      'period_end': start,
      'period_weeks': 1,
      'is_active': 0,
      'date_creation': now,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE scores (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        matiere_id TEXT NOT NULL,
        notion_id TEXT NOT NULL,
        exercice_id TEXT NOT NULL,
        score INTEGER NOT NULL,
        total INTEGER NOT NULL,
        pourcentage REAL NOT NULL,
        date_tentative TEXT NOT NULL,
        tentative_num INTEGER NOT NULL,
        id_distant TEXT,
        updated_at TEXT,
        is_synced INTEGER NOT NULL DEFAULT 0,
        is_deleted INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE progression (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        matiere_id TEXT NOT NULL,
        notion_id TEXT NOT NULL,
        statut TEXT NOT NULL,
        nb_exercices_reussis INTEGER DEFAULT 0,
        nb_exercices_total INTEGER DEFAULT 0,
        derniere_activite TEXT,
        id_distant TEXT,
        updated_at TEXT,
        is_synced INTEGER NOT NULL DEFAULT 0,
        is_deleted INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE terminal_historique (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        code TEXT NOT NULL,
        output TEXT,
        date_execution TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE codes_sauvegardes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nom TEXT NOT NULL,
        code TEXT NOT NULL,
        date_creation TEXT NOT NULL,
        id_distant TEXT,
        updated_at TEXT,
        is_synced INTEGER NOT NULL DEFAULT 0,
        is_deleted INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE cours_personnalises (
        matiere_id TEXT PRIMARY KEY,
        json_data TEXT NOT NULL,
        date_creation TEXT NOT NULL,
        date_modification TEXT NOT NULL,
        id_distant TEXT,
        updated_at TEXT,
        is_synced INTEGER NOT NULL DEFAULT 0,
        is_deleted INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE projets (
        id TEXT PRIMARY KEY,
        nom TEXT NOT NULL,
        description TEXT,
        objectif TEXT,
        couleur TEXT NOT NULL,
        icone TEXT NOT NULL,
        matiere_ids TEXT NOT NULL DEFAULT '[]',
        is_system INTEGER NOT NULL DEFAULT 0,
        date_creation TEXT NOT NULL,
        id_distant TEXT,
        updated_at TEXT,
        is_synced INTEGER NOT NULL DEFAULT 0,
        is_deleted INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
        CREATE TABLE emplois_du_temps (
          id TEXT PRIMARY KEY,
          titre TEXT NOT NULL,
          subjects_json TEXT NOT NULL,
          routine_json TEXT NOT NULL,
          period_weeks INTEGER NOT NULL DEFAULT 2,
          period_start TEXT,
          period_end TEXT,
          is_active INTEGER NOT NULL DEFAULT 1,
          date_creation TEXT NOT NULL,
          id_distant TEXT,
          updated_at TEXT,
          is_synced INTEGER NOT NULL DEFAULT 0,
          is_deleted INTEGER NOT NULL DEFAULT 0
        )
    ''');

    await db.execute('''
      CREATE TABLE taches_revision (
        id TEXT PRIMARY KEY,
        schedule_id TEXT NOT NULL,
        matiere_id TEXT NOT NULL,
        matiere_nom TEXT NOT NULL,
        title TEXT,
        projet_id TEXT,
        scheduled_at TEXT NOT NULL,
        duration_minutes INTEGER NOT NULL,
        status TEXT NOT NULL DEFAULT 'pending',
        priority TEXT NOT NULL DEFAULT 'normal',
        activity_type TEXT NOT NULL DEFAULT 'study',
        notification_id INTEGER,
        id_distant TEXT,
        updated_at TEXT,
        is_synced INTEGER NOT NULL DEFAULT 0,
        is_deleted INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (schedule_id) REFERENCES emplois_du_temps(id) ON DELETE CASCADE
      )
    ''');

    await _ensureManualSchedule(db);

    await db.execute('''
      CREATE TABLE IF NOT EXISTS defis_quotidiens_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT UNIQUE,
        score INTEGER NOT NULL,
        total INTEGER NOT NULL,
        inclut_algo INTEGER NOT NULL,
        challenges_json TEXT NOT NULL,
        completed INTEGER NOT NULL,
        id_distant TEXT,
        updated_at TEXT,
        is_synced INTEGER NOT NULL DEFAULT 0,
        is_deleted INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS tchat_ia_messages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_key TEXT NOT NULL,
        role TEXT NOT NULL,
        content TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        id_distant TEXT,
        updated_at TEXT,
        is_synced INTEGER NOT NULL DEFAULT 0,
        is_deleted INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  Future<void> ensureManualScheduleExists() async {
    final db = await database;
    await _ensureManualSchedule(db);
  }

  Future<void> insertScore(Score score) async {
    final db = await instance.database;
    final map = Map<String, dynamic>.from(score.toMap());
    map['updated_at'] = DateTime.now().toIso8601String();
    map['is_synced'] = 0;
    map['is_deleted'] = 0;
    await db.insert(
      'scores',
      map,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Score>> getScoresByNotion(String notionId) async {
    final db = await instance.database;
    final result = await db.query(
      'scores',
      where: 'notion_id = ? AND is_deleted = 0',
      whereArgs: [notionId],
      orderBy: 'date_tentative DESC',
    );
    return result.map((json) => Score.fromMap(json)).toList();
  }

  Future<double> getMoyenneByNotion(String notionId) async {
    final db = await instance.database;
    final result = await db.rawQuery(
      'SELECT AVG(pourcentage) as moyenne FROM scores WHERE notion_id = ? AND is_deleted = 0',
      [notionId],
    );
    if (result.isNotEmpty && result.first['moyenne'] != null) {
      return result.first['moyenne'] as double;
    }
    return 0.0;
  }

  Future<void> upsertProgression(Progression p) async {
    final db = await instance.database;
    final existing = await db.query(
      'progression',
      where: 'matiere_id = ? AND notion_id = ?',
      whereArgs: [p.matiereId, p.notionId],
    );

    final map = Map<String, dynamic>.from(p.toMap());
    map['updated_at'] = DateTime.now().toIso8601String();
    map['is_synced'] = 0;
    map['is_deleted'] = 0;

    if (existing.isNotEmpty) {
      await db.update(
        'progression',
        map,
        where: 'id = ?',
        whereArgs: [existing.first['id']],
      );
    } else {
      await db.insert('progression', map);
    }
  }

  Future<List<Progression>> getProgressionsByMatiere(String matiereId) async {
    final db = await instance.database;
    final result = await db.query(
      'progression',
      where: 'matiere_id = ? AND is_deleted = 0',
      whereArgs: [matiereId],
    );
    return result.map((json) => Progression.fromMap(json)).toList();
  }

  Future<double> getProgressionGlobale(String matiereId) async {
    final db = await instance.database;
    final result = await db.rawQuery(
      'SELECT SUM(nb_exercices_reussis) as reussis, SUM(nb_exercices_total) as total FROM progression WHERE matiere_id = ? AND is_deleted = 0',
      [matiereId],
    );
    if (result.isNotEmpty &&
        result.first['total'] != null &&
        (result.first['total'] as int) > 0) {
      int reussis = result.first['reussis'] as int;
      int total = result.first['total'] as int;
      if (total == 0) return 0.0;
      return (reussis / total) * 100.0;
    }
    return 0.0;
  }

  Future<void> insertHistoriqueTerminal(String code, String output) async {
    final db = await instance.database;
    await db.insert('terminal_historique', {
      'code': code,
      'output': output,
      'date_execution': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getHistoriqueTerminal() async {
    final db = await instance.database;
    return await db.query(
      'terminal_historique',
      orderBy: 'date_execution DESC',
      limit: 50,
    );
  }

  Future<void> insertCodeSauvegarde(String nom, String code) async {
    final db = await instance.database;
    await db.insert('codes_sauvegardes', {
      'nom': nom,
      'code': code,
      'date_creation': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
      'is_synced': 0,
      'is_deleted': 0,
    });
  }

  Future<List<Map<String, dynamic>>> getCodesSauvegardes() async {
    final db = await instance.database;
    return await db.query(
      'codes_sauvegardes',
      where: 'is_deleted = 0',
      orderBy: 'date_creation DESC',
    );
  }

  Future<void> deleteCodeSauvegarde(int id) async {
    final db = await instance.database;
    await db.update(
      'codes_sauvegardes',
      {
        'is_deleted': 1,
        'is_synced': 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> resetProgression() async {
    final db = await instance.database;
    await db.delete('progression');
    await db.delete('scores');
    await db.delete('terminal_historique');
  }

  Future<void> insertCustomCourse(CustomCoursePackage package) async {
    final db = await instance.database;
    final now = DateTime.now().toIso8601String();
    await db.insert('cours_personnalises', {
      'matiere_id': package.matiere.id,
      'json_data': jsonEncode(package.toJson()),
      'date_creation': now,
      'date_modification': now,
      'updated_at': now,
      'is_synced': 0,
      'is_deleted': 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<CustomCoursePackage>> getAllCustomCourses() async {
    final db = await instance.database;
    final rows = await db.query('cours_personnalises', where: 'is_deleted = 0');
    return rows.map((row) {
      final map =
          jsonDecode(row['json_data'] as String) as Map<String, dynamic>;
      return CustomCoursePackage.fromJson(map);
    }).toList();
  }

  Future<void> deleteCustomCourse(String matiereId) async {
    final db = await instance.database;
    final now = DateTime.now().toIso8601String();
    await db.update(
      'cours_personnalises',
      {'is_deleted': 1, 'is_synced': 0, 'updated_at': now},
      where: 'matiere_id = ?',
      whereArgs: [matiereId],
    );
    await db.update(
      'progression',
      {'is_deleted': 1, 'is_synced': 0, 'updated_at': now},
      where: 'matiere_id = ?',
      whereArgs: [matiereId],
    );
    await db.update(
      'scores',
      {'is_deleted': 1, 'is_synced': 0, 'updated_at': now},
      where: 'matiere_id = ?',
      whereArgs: [matiereId],
    );
  }

  Future<void> updateCustomCourseMeta(
    String matiereId,
    String nom,
    String description,
  ) async {
    final db = await instance.database;
    final rows = await db.query(
      'cours_personnalises',
      where: 'matiere_id = ?',
      whereArgs: [matiereId],
    );
    if (rows.isEmpty) return;

    final map =
        jsonDecode(rows.first['json_data'] as String) as Map<String, dynamic>;
    (map['matiere'] as Map<String, dynamic>)['nom'] = nom;
    (map['matiere'] as Map<String, dynamic>)['description'] = description;

    final now = DateTime.now().toIso8601String();
    await db.update(
      'cours_personnalises',
      {
        'json_data': jsonEncode(map),
        'date_modification': now,
        'updated_at': now,
        'is_synced': 0,
      },
      where: 'matiere_id = ?',
      whereArgs: [matiereId],
    );
  }

  // ─── Projets CRUD ─────────────────────────────────────────────────────────

  Future<void> insertProjet(Projet projet) async {
    final db = await instance.database;
    final map = Map<String, dynamic>.from(projet.toMap());
    final now = DateTime.now().toIso8601String();
    map['updated_at'] = now;
    map['is_synced'] = 0;
    map['is_deleted'] = 0;
    await db.insert(
      'projets',
      map,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Projet>> getAllProjets() async {
    final db = await instance.database;
    final rows = await db.query(
      'projets',
      where: 'is_deleted = 0',
      orderBy: 'is_system DESC, date_creation ASC',
    );
    return rows.map((r) => Projet.fromMap(r)).toList();
  }

  Future<void> updateProjet(Projet projet) async {
    final db = await instance.database;
    final map = Map<String, dynamic>.from(projet.toMap());
    final now = DateTime.now().toIso8601String();
    map['updated_at'] = now;
    map['is_synced'] = 0;
    await db.update('projets', map, where: 'id = ?', whereArgs: [projet.id]);
  }

  Future<void> deleteProjet(String projetId) async {
    final db = await instance.database;
    final now = DateTime.now().toIso8601String();
    await db.update(
      'projets',
      {'is_deleted': 1, 'is_synced': 0, 'updated_at': now},
      where: 'id = ?',
      whereArgs: [projetId],
    );
  }

  /// Ajoute un cours (matiereId) à un projet.
  Future<void> addMatiereToProjet(String projetId, String matiereId) async {
    final db = await instance.database;
    final rows = await db.query(
      'projets',
      where: 'id = ?',
      whereArgs: [projetId],
    );
    if (rows.isEmpty) return;
    final projet = Projet.fromMap(rows.first);
    if (projet.matiereIds.contains(matiereId)) return;
    final updated = projet.copyWith(
      matiereIds: [...projet.matiereIds, matiereId],
    );
    final map = Map<String, dynamic>.from(updated.toMap());
    final now = DateTime.now().toIso8601String();
    map['updated_at'] = now;
    map['is_synced'] = 0;
    await db.update('projets', map, where: 'id = ?', whereArgs: [projetId]);
  }

  /// Retire un cours (matiereId) d'un projet.
  Future<void> removeMatiereFromProjet(
    String projetId,
    String matiereId,
  ) async {
    final db = await instance.database;
    final rows = await db.query(
      'projets',
      where: 'id = ?',
      whereArgs: [projetId],
    );
    if (rows.isEmpty) return;
    final projet = Projet.fromMap(rows.first);
    final updated = projet.copyWith(
      matiereIds: projet.matiereIds.where((id) => id != matiereId).toList(),
    );
    final map = Map<String, dynamic>.from(updated.toMap());
    final now = DateTime.now().toIso8601String();
    map['updated_at'] = now;
    map['is_synced'] = 0;
    await db.update('projets', map, where: 'id = ?', whereArgs: [projetId]);
  }

  /// Retourne tous les matiereIds présents dans au moins un projet.
  Future<Set<String>> getAllProjectMatiereIds() async {
    final projets = await getAllProjets();
    return projets.expand((p) => p.matiereIds).toSet();
  }

  // ─── Emplois du temps ─────────────────────────────────────────────────────

  Future<void> insertSchedule(StudySchedule schedule) async {
    final db = await database;
    final map = Map<String, dynamic>.from(schedule.toMap());
    final now = DateTime.now().toIso8601String();
    map['updated_at'] = now;
    map['is_synced'] = 0;
    map['is_deleted'] = 0;
    await db.insert(
      'emplois_du_temps',
      map,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateSchedule(StudySchedule schedule) async {
    final db = await database;
    final map = Map<String, dynamic>.from(schedule.toMap());
    final now = DateTime.now().toIso8601String();
    map['updated_at'] = now;
    map['is_synced'] = 0;
    await db.update(
      'emplois_du_temps',
      map,
      where: 'id = ?',
      whereArgs: [schedule.id],
    );
  }

  Future<void> deleteTask(String taskId) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    await db.update(
      'taches_revision',
      {'is_deleted': 1, 'is_synced': 0, 'updated_at': now},
      where: 'id = ?',
      whereArgs: [taskId],
    );
  }

  Future<List<StudyTask>> getTasksForDate(DateTime day) async {
    final db = await database;
    final datePrefix =
        '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
    final rows = await db.query(
      'taches_revision',
      where: 'scheduled_at LIKE ? AND is_deleted = 0',
      whereArgs: ['$datePrefix%'],
      orderBy: 'scheduled_at ASC',
    );
    return rows.map((r) => StudyTask.fromMap(r)).toList();
  }

  Future<List<StudyTask>> getTaskHistory({
    TaskHistoryFilter filter = TaskHistoryFilter.all,
    String? search,
    DateTime? beforeDate,
  }) async {
    final db = await database;
    final where = <String>['is_deleted = 0'];
    final args = <Object?>[];

    switch (filter) {
      case TaskHistoryFilter.all:
        break;
      case TaskHistoryFilter.completed:
        where.add("status = 'completed'");
      case TaskHistoryFilter.cancelled:
        where.add("status = 'cancelled'");
    }

    if (beforeDate != null) {
      where.add('scheduled_at < ?');
      args.add(beforeDate.toIso8601String());
    }

    if (search != null && search.trim().isNotEmpty) {
      where.add('(matiere_nom LIKE ? OR title LIKE ?)');
      final q = '%${search.trim()}%';
      args.addAll([q, q]);
    }

    final rows = await db.query(
      'taches_revision',
      where: where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'scheduled_at DESC',
      limit: 200,
    );
    return rows.map((r) => StudyTask.fromMap(r)).toList();
  }

  Future<List<StudySchedule>> getAllSchedules({
    bool includeSystem = false,
  }) async {
    final db = await database;
    final rows = await db.query(
      'emplois_du_temps',
      where: 'is_deleted = 0',
      orderBy: 'date_creation DESC',
    );
    final schedules = rows.map((r) => StudySchedule.fromMap(r)).toList();
    if (includeSystem) return schedules;
    return schedules.where((s) => s.id != StudyTask.manualScheduleId).toList();
  }

  Future<void> deleteSchedule(String scheduleId) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    await db.update(
      'taches_revision',
      {'is_deleted': 1, 'is_synced': 0, 'updated_at': now},
      where: 'schedule_id = ?',
      whereArgs: [scheduleId],
    );
    await db.update(
      'emplois_du_temps',
      {'is_deleted': 1, 'is_synced': 0, 'updated_at': now},
      where: 'id = ?',
      whereArgs: [scheduleId],
    );
  }

  Future<void> updateScheduleActive(String scheduleId, bool active) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    await db.update(
      'emplois_du_temps',
      {'is_active': active ? 1 : 0, 'updated_at': now, 'is_synced': 0},
      where: 'id = ?',
      whereArgs: [scheduleId],
    );
  }

  Future<void> insertTask(StudyTask task) async {
    final db = await database;
    final map = Map<String, dynamic>.from(task.toMap());
    final now = DateTime.now().toIso8601String();
    map['updated_at'] = now;
    map['is_synced'] = 0;
    map['is_deleted'] = 0;
    await db.insert(
      'taches_revision',
      map,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> insertTasks(List<StudyTask> tasks) async {
    final db = await database;
    final batch = db.batch();
    final now = DateTime.now().toIso8601String();
    for (final t in tasks) {
      final map = Map<String, dynamic>.from(t.toMap());
      map['updated_at'] = now;
      map['is_synced'] = 0;
      map['is_deleted'] = 0;
      batch.insert(
        'taches_revision',
        map,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<StudyTask>> getTasksBySchedule(String scheduleId) async {
    final db = await database;
    final rows = await db.query(
      'taches_revision',
      where: 'schedule_id = ? AND is_deleted = 0',
      whereArgs: [scheduleId],
      orderBy: 'scheduled_at ASC',
    );
    return rows.map((r) => StudyTask.fromMap(r)).toList();
  }

  Future<List<StudyTask>> getAllPendingTasks() async {
    final db = await database;
    final rows = await db.query(
      'taches_revision',
      where: "status IN ('pending', 'snoozed') AND is_deleted = 0",
      orderBy: 'scheduled_at ASC',
    );
    return rows.map((r) => StudyTask.fromMap(r)).toList();
  }

  Future<List<StudyTask>> getUpcomingTasks({int limit = 50}) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    final rows = await db.query(
      'taches_revision',
      where:
          "scheduled_at >= ? AND status IN ('pending', 'snoozed') AND is_deleted = 0",
      whereArgs: [now],
      orderBy: 'scheduled_at ASC',
      limit: limit,
    );
    return rows.map((r) => StudyTask.fromMap(r)).toList();
  }

  Future<StudyTask?> getTaskById(String taskId) async {
    final db = await database;
    final rows = await db.query(
      'taches_revision',
      where: 'id = ? AND is_deleted = 0',
      whereArgs: [taskId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return StudyTask.fromMap(rows.first);
  }

  Future<void> updateTask(StudyTask task) async {
    final db = await database;
    final map = Map<String, dynamic>.from(task.toMap());
    final now = DateTime.now().toIso8601String();
    map['updated_at'] = now;
    map['is_synced'] = 0;
    await db.update(
      'taches_revision',
      map,
      where: 'id = ?',
      whereArgs: [task.id],
    );
  }

  Future<void> deleteTasksBySchedule(String scheduleId) async {
    final db = await database;
    await db.delete(
      'taches_revision',
      where: 'schedule_id = ?',
      whereArgs: [scheduleId],
    );
  }

  // ─── Défis Quotidiens CRUD ───────────────────────────────────────────────

  Future<void> insertDailyChallengeSession(
    DailyChallengeSession session,
  ) async {
    final db = await database;
    final map = Map<String, dynamic>.from(session.toMap());
    final now = DateTime.now().toIso8601String();
    map['updated_at'] = now;
    map['is_synced'] = 0;
    map['is_deleted'] = 0;
    await db.insert(
      'defis_quotidiens_sessions',
      map,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<DailyChallengeSession?> getDailyChallengeSessionForDate(
    String date,
  ) async {
    final db = await database;
    final rows = await db.query(
      'defis_quotidiens_sessions',
      where: 'date = ? AND is_deleted = 0',
      whereArgs: [date],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return DailyChallengeSession.fromMap(rows.first);
  }

  Future<List<DailyChallengeSession>> getAllDailyChallengeSessions() async {
    final db = await database;
    final rows = await db.query(
      'defis_quotidiens_sessions',
      where: 'is_deleted = 0',
      orderBy: 'date DESC',
    );
    return rows.map((r) => DailyChallengeSession.fromMap(r)).toList();
  }

  Future<void> updateDailyChallengeSession(
    DailyChallengeSession session,
  ) async {
    final db = await database;
    final map = Map<String, dynamic>.from(session.toMap());
    final now = DateTime.now().toIso8601String();
    map['updated_at'] = now;
    map['is_synced'] = 0;
    await db.update(
      'defis_quotidiens_sessions',
      map,
      where: 'date = ?',
      whereArgs: [session.date],
    );
  }

  /// Retourne un résumé ultra-compact des statistiques de défis pour le LLM.
  Future<String> getDailyChallengesStatsSummary() async {
    final db = await database;
    final rows = await db.query(
      'defis_quotidiens_sessions',
      where: 'is_deleted = 0',
    );
    if (rows.isEmpty) return 'Aucun défi quotidien relevé pour le moment.';

    int totalSessions = rows.length;
    int completedSessions = 0;
    int totalQuestions = 0;
    int totalCorrect = 0;
    final lastScores = <int>[];

    // Trier par date pour avoir les plus récents
    final sortedRows = List<Map<String, dynamic>>.from(rows)
      ..sort((a, b) => (b['date'] as String).compareTo(a['date'] as String));

    for (final row in sortedRows) {
      if ((row['completed'] as int) == 1) {
        completedSessions++;
      }
      totalQuestions += row['total'] as int;
      totalCorrect += row['score'] as int;
      if (lastScores.length < 5) {
        lastScores.add(row['score'] as int);
      }
    }

    final successRate = totalQuestions > 0
        ? (totalCorrect / totalQuestions * 100).toStringAsFixed(0)
        : '0';
    final scoresStr = lastScores.reversed.join('/');

    return 'Défis: $completedSessions/$totalSessions complétés. Taux réussite: $successRate%. Derniers scores: [$scoresStr/5].';
  }

  // ─── Tchat IA Messages CRUD ──────────────────────────────────────────────
  Future<void> insertTchatMessage({
    required String sessionKey,
    required String role,
    required String content,
    required String timestamp,
  }) async {
    final db = await database;
    await db.insert('tchat_ia_messages', {
      'session_key': sessionKey,
      'role': role,
      'content': content,
      'timestamp': timestamp,
      'updated_at': DateTime.now().toIso8601String(),
      'is_synced': 0,
      'is_deleted': 0,
    });
  }

  Future<List<Map<String, dynamic>>> getTchatMessagesBySession(
    String sessionKey,
  ) async {
    final db = await database;
    return await db.query(
      'tchat_ia_messages',
      where: 'session_key = ? AND is_deleted = 0',
      whereArgs: [sessionKey],
      orderBy: 'timestamp ASC',
    );
  }

  Future<void> deleteTchatHistory(String sessionKey) async {
    final db = await database;
    await db.update(
      'tchat_ia_messages',
      {
        'is_deleted': 1,
        'is_synced': 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'session_key = ?',
      whereArgs: [sessionKey],
    );
  }

  Future<Map<String, List<Map<String, dynamic>>>> getAllTchatHistories() async {
    final db = await database;
    final rows = await db.query(
      'tchat_ia_messages',
      where: 'is_deleted = 0',
      orderBy: 'timestamp ASC',
    );

    final Map<String, List<Map<String, dynamic>>> histories = {};
    for (final row in rows) {
      final key = row['session_key'] as String;
      if (!histories.containsKey(key)) {
        histories[key] = [];
      }
      histories[key]!.add(row);
    }
    return histories;
  }

  // Purge complète de la base de données locale (lors de la déconnexion)
  Future<void> clearLocalData() async {
    final db = await database;
    final tables = [
      'scores',
      'progression',
      'terminal_historique',
      'codes_sauvegardes',
      'cours_personnalises',
      'projets',
      'emplois_du_temps',
      'taches_revision',
      'defis_quotidiens_sessions',
      'tchat_ia_messages',
    ];
    for (final table in tables) {
      await db.delete(table);
    }
    await _ensureManualSchedule(db);
  }
}
