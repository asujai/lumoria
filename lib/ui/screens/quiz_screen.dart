import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../core/database/database_helper.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  List<Map<String, dynamic>> _artifacts = [];
  int _currentIndex = 0;
  bool _showAnswer = false;
  Map<String, dynamic> _stats = {
    'total': 0,
    'correct': 0,
    'incorrect': 0,
    'percentage': '0.0',
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final allArtifacts = await _dbHelper.fetchAllArtifacts();
    // Copy the list to prevent modifying unmodifiable collections from sqflite
    final List<Map<String, dynamic>> modifiableList = List.from(allArtifacts);
    modifiableList.shuffle();

    final stats = await _dbHelper.getDailyStats();
    if (mounted) {
      setState(() {
        _artifacts = modifiableList;
        _stats = stats;
      });
    }
  }

  Future<void> _handleAnswer(bool isCorrect) async {
    if (_showAnswer || _artifacts.isEmpty) return;

    final currentArtifact = _artifacts[_currentIndex];
    await _dbHelper.recordQuizResult(currentArtifact['id'] as int, isCorrect);

    final updatedStats = await _dbHelper.getDailyStats();

    setState(() {
      _showAnswer = true;
      _stats = updatedStats;
    });

    // Automatically move to the next word
    await Future.delayed(const Duration(milliseconds: 1500));

    if (mounted) {
      if (_currentIndex < _artifacts.length - 1) {
        setState(() {
          _currentIndex++;
          _showAnswer = false;
        });
      } else {
        // Stop at the last word
        setState(() {
          // Keep showing the answer of the last word, and maybe change index to length if we want completion screen
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCompleted = _artifacts.isNotEmpty &&
        _currentIndex >= _artifacts.length - 1 &&
        _showAnswer;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'quiz_mode_title'.tr(),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: _artifacts.isEmpty
          ? Center(
              child: Text(
                'Kütüphanenizde henüz kelime yok.',
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),
            )
          : SafeArea(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  children: [
                    // Daily Stats Banner
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: theme.colorScheme.primary
                                .withValues(alpha: 0.1)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatColumn(
                              'quiz_solved'.tr(),
                              _stats['total'].toString(),
                              theme.colorScheme.primary),
                          _buildStatColumn('quiz_correct_count'.tr(),
                              _stats['correct'].toString(), Colors.green),
                          _buildStatColumn('quiz_wrong_count'.tr(),
                              _stats['incorrect'].toString(), Colors.redAccent),
                          _buildStatColumn(
                              'quiz_accuracy'.tr(),
                              '%${_stats['percentage']}',
                              theme.colorScheme.tertiary),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Word Card
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(32),
                          boxShadow: [
                            BoxShadow(
                              color: theme.colorScheme.shadow
                                  .withValues(alpha: 0.05),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                            BoxShadow(
                              color: theme.colorScheme.primary
                                  .withValues(alpha: 0.05),
                              blurRadius: 30,
                              spreadRadius: 5,
                            ),
                          ],
                          border: Border.all(
                              color: theme.colorScheme.surfaceContainerHighest),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _artifacts[_currentIndex]['originalText']
                                  as String,
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            if (_showAnswer) ...[
                              const SizedBox(height: 24),
                              Container(
                                width: 40,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary
                                      .withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                _artifacts[_currentIndex]['aiExplanation']
                                    as String,
                                style: TextStyle(
                                  fontSize: 16,
                                  height: 1.5,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              if (!isCompleted) ...[
                                const SizedBox(height: 16),
                                Text(
                                  'quiz_next_word'.tr(),
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: theme.colorScheme.primary
                                          .withValues(alpha: 0.6)),
                                )
                              ] else ...[
                                const SizedBox(height: 16),
                                Text(
                                  'quiz_completed'.tr(),
                                  style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.green,
                                      fontWeight: FontWeight.bold),
                                )
                              ]
                            ],
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed:
                                _showAnswer ? null : () => _handleAnswer(false),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              foregroundColor: Colors.redAccent,
                              side: BorderSide(
                                  color: _showAnswer
                                      ? Colors.grey.withValues(alpha: 0.3)
                                      : Colors.redAccent
                                          .withValues(alpha: 0.5)),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.close,
                                    color: _showAnswer
                                        ? Colors.grey
                                        : Colors.redAccent),
                                const SizedBox(width: 8),
                                Text('quiz_wrong'.tr(),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed:
                                _showAnswer ? null : () => _handleAnswer(true),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.check, color: Colors.white),
                                const SizedBox(width: 8),
                                Text('quiz_correct'.tr(),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatColumn(String label, String value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
