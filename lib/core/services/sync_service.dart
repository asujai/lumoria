import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter/foundation.dart';
import '../database/database_helper.dart';
import 'feature_access_service.dart';

class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  final _supabase = Supabase.instance.client;
  final _dbHelper = DatabaseHelper.instance;

  bool _isSyncing = false;

  void init() {
    _dbHelper.artifactUpdateNotifier.addListener(() {
      if (!_isSyncing) {
        _performBackgroundSync();
      }
    });
  }

  void _performBackgroundSync() async {
    return; // Maliyetleri önlemek için geçici olarak kapatıldı
  }

  void performSync() async {
    return; // Maliyetleri önlemek için geçici olarak kapatıldı
  }

  Future<void> syncLocalToServer() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    final db = await _dbHelper.database;

    // Kelimeleri eşitle (sadece tip: text olanlar)
    final artifacts =
        await db.query('artifacts', where: "type = 'text' OR type IS NULL");
    for (var artifact in artifacts) {
      try {
        await _supabase.from('synced_artifacts').upsert({
          'user_id': user.id,
          'original_text': artifact['originalText'],
          'ai_explanation': artifact['aiExplanation'],
          'date': artifact['date'],
          'pdf_name': artifact['pdfName'],
          'type': artifact['type'] ?? 'text',
          'file_path': artifact['filePath'],
        }, onConflict: 'user_id, original_text');
      } catch (e) {
        debugPrint('Kelime senkronizasyon hatası: $e');
      }
    }

    // Kelime geçmişini (nerede tıklandığı vs) eşitle
    final histories = await db.query('artifact_history');
    for (var history in histories) {
      final artifactMatches =
          artifacts.where((a) => a['id'] == history['artifactId']);
      if (artifactMatches.isNotEmpty) {
        final artifact = artifactMatches.first;
        if (artifact['originalText'] != null) {
          try {
            await _supabase.from('synced_artifact_history').upsert({
              'user_id': user.id,
              'original_text': artifact['originalText'],
              'pdf_name': history['pdfName'],
              'page_number': history['pageNumber'],
              'date': history['date'],
            }, onConflict: 'user_id, original_text, pdf_name, page_number');
          } catch (e) {
            debugPrint('Geçmiş senkronizasyon hatası: $e');
          }
        }
      }
    }

    // Quiz geçmişini eşitle
    final quizzes = await db.query('quiz_history');
    for (var quiz in quizzes) {
      final artifactMatches =
          artifacts.where((a) => a['id'] == quiz['artifactId']);
      if (artifactMatches.isNotEmpty) {
        final artifact = artifactMatches.first;
        if (artifact['originalText'] != null) {
          try {
            await _supabase.from('synced_quiz_history').upsert({
              'user_id': user.id,
              'date': quiz['date'],
              'original_text': artifact['originalText'],
              'is_correct': quiz['isCorrect'],
            }, onConflict: 'user_id, date, original_text');
          } catch (e) {
            debugPrint('Quiz senkronizasyon hatası: $e');
          }
        }
      }
    }
  }

  Future<void> syncServerToLocal() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    final db = await _dbHelper.database;

    // Sunucudaki kelimeleri çek
    final serverArtifacts = await _supabase.from('synced_artifacts').select();

    for (var serverArtifact in serverArtifacts) {
      // Veritabanına yaz (insertArtifact metodu kendi içinde var olma kontrolünü text string bazlı yapıyor)
      await _dbHelper.insertArtifact({
        'originalText': serverArtifact['original_text'],
        'aiExplanation': serverArtifact['ai_explanation'],
        'date': serverArtifact['date'],
        'pdfName': serverArtifact['pdf_name'],
        'type': serverArtifact['type'] ?? 'text',
        'filePath': serverArtifact['file_path'],
      });
    }

    // Id'ler lokal veritabanında farklı olacağı için artifact tablosundan ID eşleştirmesi yapmamız gerek
    final localArtifacts =
        await db.query('artifacts', where: "type = 'text' OR type IS NULL");

    // Geçmiş verilerini eşitle
    final serverHistories =
        await _supabase.from('synced_artifact_history').select();
    for (var serverHistory in serverHistories) {
      try {
        final localMatches = localArtifacts.where((a) =>
            (a['originalText'] as String).trim().toLowerCase() ==
            (serverHistory['original_text'] as String).trim().toLowerCase());

        if (localMatches.isNotEmpty) {
          final localArtifact = localMatches.first;
          final artifactId = localArtifact['id'];

          // Aynı kayıt var mı kontrol et
          final exists = await db.query('artifact_history',
              where: 'artifactId = ? AND pdfName = ? AND pageNumber = ?',
              whereArgs: [
                artifactId,
                serverHistory['pdf_name'],
                serverHistory['page_number']
              ]);

          if (exists.isEmpty) {
            await db.insert('artifact_history', {
              'artifactId': artifactId,
              'pdfName': serverHistory['pdf_name'],
              'pageNumber': serverHistory['page_number'],
              'date': serverHistory['date'] ?? DateTime.now().toIso8601String(),
            });
          }
        }
      } catch (e) {
        debugPrint('Geçmiş DB senkronizasyon hatası: $e');
      }
    }

    // Quiz verilerini eşitle
    final serverQuizzes = await _supabase.from('synced_quiz_history').select();
    for (var serverQuiz in serverQuizzes) {
      try {
        final localMatches = localArtifacts.where((a) =>
            (a['originalText'] as String).trim().toLowerCase() ==
            (serverQuiz['original_text'] as String).trim().toLowerCase());

        if (localMatches.isNotEmpty) {
          final localArtifact = localMatches.first;
          final artifactId = localArtifact['id'];

          await db.insert(
              'quiz_history',
              {
                'date': serverQuiz['date'],
                'artifactId': artifactId,
                'isCorrect': serverQuiz['is_correct'],
              },
              conflictAlgorithm: ConflictAlgorithm.replace);
        }
      } catch (e) {
        debugPrint('Quiz DB senkronizasyon hatası: $e');
      }
    }

    // Uygulama genelinde senkronize edilen verilerin sayfada görünmesi için bildirimi tetikle
    _dbHelper.artifactUpdateNotifier.value++;
  }
}
