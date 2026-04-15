import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  // Notifier to trigger UI updates when database changes
  final ValueNotifier<int> artifactUpdateNotifier = ValueNotifier(0);

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('library.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 11,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const integerType = 'INTEGER NOT NULL';

    // Ek alanlar: type (pdf veya text), filePath (PDF'in kaydedildiği yer)
    await db.execute('''
CREATE TABLE artifacts (
  id $idType,
  originalText $textType,
  aiExplanation $textType,
  date $textType,
  pdfName $textType,
  type TEXT DEFAULT 'text',
  filePath TEXT,
  folderId INTEGER
  )
''');
    await db.execute('''
CREATE TABLE folders (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  createdAt TEXT NOT NULL,
  category TEXT DEFAULT 'notes'
)
''');
    await db.execute('''
CREATE TABLE pdf_sessions (
  id $idType,
  pdfName $textType,
  elapsedSeconds $integerType,
  totalSeconds INTEGER DEFAULT 0,
  date $textType
  )
''');
    await db.execute('''
CREATE TABLE artifact_history (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  artifactId INTEGER NOT NULL,
  pdfName TEXT NOT NULL,
  pageNumber INTEGER NOT NULL,
  date TEXT NOT NULL,
  FOREIGN KEY (artifactId) REFERENCES artifacts (id) ON DELETE CASCADE
)
''');
    await db.execute('''
CREATE TABLE quiz_history (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  date TEXT NOT NULL,
  artifactId INTEGER NOT NULL,
  isCorrect INTEGER NOT NULL,
  UNIQUE(date, artifactId) ON CONFLICT REPLACE,
  FOREIGN KEY (artifactId) REFERENCES artifacts (id) ON DELETE CASCADE
)
''');
    await db.execute('''
CREATE TABLE quotes (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  quotedText TEXT NOT NULL,
  pdfName TEXT NOT NULL,
  pageNumber INTEGER NOT NULL,
  date TEXT NOT NULL,
  folderId INTEGER
)
''');
    await db.execute('''
CREATE TABLE drawing_strokes (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  pdfPath TEXT NOT NULL,
  strokesJson TEXT NOT NULL,
  updatedAt TEXT NOT NULL
)
''');
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
      const textType = 'TEXT NOT NULL';
      const integerType = 'INTEGER NOT NULL';
      await db.execute('''
CREATE TABLE pdf_sessions (
  id $idType,
  pdfName $textType,
  elapsedSeconds $integerType,
  date $textType
  )
''');
    }
    if (oldVersion < 3) {
      await db
          .execute('ALTER TABLE artifacts ADD COLUMN type TEXT DEFAULT "text"');
      await db.execute('ALTER TABLE artifacts ADD COLUMN filePath TEXT');
    }
    if (oldVersion < 4) {
      await db.execute('''
CREATE TABLE artifact_history (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  artifactId INTEGER NOT NULL,
  pdfName TEXT NOT NULL,
  pageNumber INTEGER NOT NULL,
  date TEXT NOT NULL,
  FOREIGN KEY (artifactId) REFERENCES artifacts (id) ON DELETE CASCADE
)
''');
      // Create initial history records for existing text artifacts
      final artifacts =
          await db.query('artifacts', where: "type = 'text' OR type IS NULL");
      for (final a in artifacts) {
        final Map<String, dynamic> historyRow = {
          'artifactId': a['id'],
          'pdfName': a['pdfName'] ?? 'Bilinmiyor',
          'pageNumber': 1,
          'date': a['date'] ?? DateTime.now().toIso8601String(),
        };
        // wait db.insert() without await inside map is bad, do it in loop
        await db.insert('artifact_history', historyRow);
      }
    }
    if (oldVersion < 5) {
      await db.execute('''
CREATE TABLE quiz_history (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  date TEXT NOT NULL,
  artifactId INTEGER NOT NULL,
  isCorrect INTEGER NOT NULL,
  UNIQUE(date, artifactId) ON CONFLICT REPLACE,
)
''');
    }
    if (oldVersion < 6) {
      await db.execute(
          'ALTER TABLE pdf_sessions ADD COLUMN totalSeconds INTEGER DEFAULT 0');
    }
    if (oldVersion < 8) {
      await db.execute('''
CREATE TABLE quotes (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  quotedText TEXT NOT NULL,
  pdfName TEXT NOT NULL,
  pageNumber INTEGER NOT NULL,
  date TEXT NOT NULL
)
''');
    }
    if (oldVersion < 9) {
      await db.execute('''
CREATE TABLE IF NOT EXISTS drawing_strokes (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  pdfPath TEXT NOT NULL,
  strokesJson TEXT NOT NULL,
  updatedAt TEXT NOT NULL
)
''');
    }
    if (oldVersion < 10) {
      await db.execute('''
CREATE TABLE IF NOT EXISTS folders (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  createdAt TEXT NOT NULL
)
''');
      await db.execute('ALTER TABLE artifacts ADD COLUMN folderId INTEGER');
    }
    if (oldVersion < 11) {
      await db.execute('ALTER TABLE folders ADD COLUMN category TEXT DEFAULT "notes"');
      await db.execute('ALTER TABLE quotes ADD COLUMN folderId INTEGER');
    }
  }

  Future<int> insertArtifact(Map<String, dynamic> row) async {
    final db = await instance.database;
    final int? pageNumber = row['pageNumber'] as int?;
    final String pdfName = row['pdfName'] as String? ?? 'Bilinmiyor';
    final String date =
        row['date'] as String? ?? DateTime.now().toIso8601String();

    if (row['type'] == null || row['type'] == 'text') {
      final originalText = row['originalText'] as String?;
      if (originalText != null && originalText.trim().isNotEmpty) {
        final existing = await db.query('artifacts',
            where:
                "LOWER(TRIM(originalText)) = LOWER(TRIM(?)) AND (type = 'text' OR type IS NULL)",
            whereArgs: [originalText]);

        if (existing.isNotEmpty) {
          final artifactId = existing.first['id'] as int;
          final existingHistory = await db.query('artifact_history',
              where: 'artifactId = ? AND pdfName = ? AND pageNumber = ?',
              whereArgs: [artifactId, pdfName, pageNumber ?? 1]);

          if (existingHistory.isEmpty) {
            await db.insert('artifact_history', {
              'artifactId': artifactId,
              'pdfName': pdfName,
              'pageNumber': pageNumber ?? 1,
              'date': date,
            });
          }
          artifactUpdateNotifier.value++;
          return artifactId;
        }
      }
    }

    final insertRow = Map<String, dynamic>.from(row);
    insertRow.remove('pageNumber');

    final id = await db.insert('artifacts', insertRow);

    if (insertRow['type'] == null || insertRow['type'] == 'text') {
      await db.insert('artifact_history', {
        'artifactId': id,
        'pdfName': pdfName,
        'pageNumber': pageNumber ?? 1,
        'date': date,
      });
    }

    artifactUpdateNotifier.value++;
    return id;
  }

  Future<List<Map<String, dynamic>>> fetchAllArtifacts() async {
    final db = await instance.database;
    return await db.query('artifacts', orderBy: 'date DESC');
  }

  Future<int> insertFolder(String name, [String category = 'notes']) async {
    final db = await instance.database;
    final id = await db.insert('folders', {
      'name': name.trim(),
      'createdAt': DateTime.now().toIso8601String(),
      'category': category,
    });
    artifactUpdateNotifier.value++;
    return id;
  }

  Future<List<Map<String, dynamic>>> fetchAllFolders() async {
    final db = await instance.database;
    return await db.query('folders', orderBy: 'createdAt DESC');
  }

  Future<int> deleteFolder(int id) async {
    final db = await instance.database;
    await db.update('artifacts', {'folderId': null}, where: 'folderId = ?', whereArgs: [id]);
    final result = await db.delete('folders', where: 'id = ?', whereArgs: [id]);
    artifactUpdateNotifier.value++;
    return result;
  }

  Future<int> deleteArtifact(int id) async {
    final db = await instance.database;
    await db
        .delete('artifact_history', where: 'artifactId = ?', whereArgs: [id]);
    final result =
        await db.delete('artifacts', where: 'id = ?', whereArgs: [id]);
    artifactUpdateNotifier.value++;
    return result;
  }

  Future<int> insertQuote(Map<String, dynamic> row) async {
    final db = await instance.database;
    final int id = await db.insert('quotes', row);
    artifactUpdateNotifier.value++;
    return id;
  }

  Future<List<Map<String, dynamic>>> fetchAllQuotes() async {
    final db = await instance.database;
    return await db.query('quotes', orderBy: 'date DESC');
  }

  Future<int> deleteQuote(int id) async {
    final db = await instance.database;
    final result = await db.delete('quotes', where: 'id = ?', whereArgs: [id]);
    artifactUpdateNotifier.value++;
    return result;
  }

  Future<List<Map<String, dynamic>>> getArtifactHistory(int artifactId) async {
    final db = await instance.database;
    return await db.query('artifact_history',
        where: 'artifactId = ?', whereArgs: [artifactId], orderBy: 'date DESC');
  }

  Future<void> recordQuizResult(int artifactId, bool isCorrect) async {
    final db = await instance.database;
    final String today = DateTime.now().toIso8601String().split('T')[0];

    await db.insert(
      'quiz_history',
      {
        'date': today,
        'artifactId': artifactId,
        'isCorrect': isCorrect ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>> getDailyStats() async {
    final db = await instance.database;
    final String today = DateTime.now().toIso8601String().split('T')[0];

    final result = await db.rawQuery('''
      SELECT 
        COUNT(*) as total, 
        SUM(isCorrect) as correct
      FROM quiz_history
      WHERE date = ?
    ''', [today]);

    final data = result.first;
    final int total = (data['total'] as num?)?.toInt() ?? 0;
    final int correct = (data['correct'] as num?)?.toInt() ?? 0;
    final int incorrect = total - correct;
    final double percentage = total > 0 ? (correct / total) * 100 : 0;

    return {
      'total': total,
      'correct': correct,
      'incorrect': incorrect,
      'percentage': percentage.toStringAsFixed(1),
    };
  }

  Future<void> savePdfSession(
      String pdfName, int elapsedSeconds, int totalSecondsInc) async {
    final db = await instance.database;
    final normalizedName = pdfName.trim().toLowerCase();

    // Check if exists
    final List<Map<String, dynamic>> existing = await db.query('pdf_sessions',
        where: 'pdfName = ?', whereArgs: [normalizedName]);

    if (existing.isNotEmpty) {
      final int currentSeconds = existing.first['elapsedSeconds'] as int;
      final int currentTotalSeconds =
          (existing.first['totalSeconds'] as int?) ?? 0;
      await db.update(
          'pdf_sessions',
          {
            'elapsedSeconds': currentSeconds + elapsedSeconds,
            'totalSeconds': currentTotalSeconds + totalSecondsInc,
            'date': DateTime.now().toIso8601String()
          },
          where: 'pdfName = ?',
          whereArgs: [normalizedName]);
    } else {
      await db.insert('pdf_sessions', {
        'pdfName': normalizedName,
        'elapsedSeconds': elapsedSeconds,
        'totalSeconds': totalSecondsInc,
        'date': DateTime.now().toIso8601String()
      });
    }
    artifactUpdateNotifier.value++;
  }

  Future<List<Map<String, dynamic>>> getPdfStatistics() async {
    final db = await instance.database;
    return await db.rawQuery('''
      SELECT pdfName, SUM(elapsedSeconds) as activeSeconds, SUM(totalSeconds) as backgroundSeconds
      FROM pdf_sessions
      GROUP BY pdfName
      ORDER BY backgroundSeconds DESC, activeSeconds DESC
    ''');
  }

  Future<Map<String, int>> getTotalTime() async {
    final db = await instance.database;
    final result = await db.rawQuery(
        'SELECT SUM(elapsedSeconds) as activeTotal, SUM(totalSeconds) as backgroundTotal FROM pdf_sessions');
    if (result.isNotEmpty) {
      return {
        'activeTotal': (result.first['activeTotal'] as num?)?.toInt() ?? 0,
        'backgroundTotal':
            (result.first['backgroundTotal'] as num?)?.toInt() ?? 0,
      };
    }
    return {'activeTotal': 0, 'backgroundTotal': 0};
  }

  Future<void> clearStatistics() async {
    final db = await instance.database;
    await db.delete('pdf_sessions');
    artifactUpdateNotifier.value++;
  }

  /// Çizim verilerini PDF yoluna göre kaydet
  Future<void> saveDrawingStrokes(String pdfPath, String strokesJson) async {
    final db = await instance.database;
    final normalized = pdfPath.trim();
    final existing = await db.query('drawing_strokes',
        where: 'pdfPath = ?', whereArgs: [normalized]);

    if (existing.isNotEmpty) {
      await db.update(
        'drawing_strokes',
        {
          'strokesJson': strokesJson,
          'updatedAt': DateTime.now().toIso8601String(),
        },
        where: 'pdfPath = ?',
        whereArgs: [normalized],
      );
    } else {
      await db.insert('drawing_strokes', {
        'pdfPath': normalized,
        'strokesJson': strokesJson,
        'updatedAt': DateTime.now().toIso8601String(),
      });
    }
  }

  /// PDF yoluna göre kaydedilmiş çizim verilerini getir
  Future<String?> loadDrawingStrokes(String pdfPath) async {
    final db = await instance.database;
    final result = await db.query('drawing_strokes',
        where: 'pdfPath = ?', whereArgs: [pdfPath.trim()]);
    if (result.isNotEmpty) {
      return result.first['strokesJson'] as String?;
    }
    return null;
  }

  /// PDF yoluna göre çizim verilerini sil
  Future<void> deleteDrawingStrokes(String pdfPath) async {
    final db = await instance.database;
    await db.delete('drawing_strokes',
        where: 'pdfPath = ?', whereArgs: [pdfPath.trim()]);
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }

  Future<int> updateArtifactFolder(int id, int? folderId) async {
    final db = await instance.database;
    int count = await db.update(
      'artifacts',
      {'folderId': folderId},
      where: 'id = ?',
      whereArgs: [id],
    );
    artifactUpdateNotifier.value++;
    return count;
  }

  Future<int> updateQuoteFolder(int id, int? folderId) async {
    final db = await instance.database;
    int count = await db.update(
      'quotes',
      {'folderId': folderId},
      where: 'id = ?',
      whereArgs: [id],
    );
    artifactUpdateNotifier.value++;
    return count;
  }
}
