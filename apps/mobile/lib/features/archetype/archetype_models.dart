// Archetype test modelleri (docs/04). Kimlik doğrulamalı /v1/archetype uçları.
// Üretilen Dart client (B-3) gelince bu interim modeller değişecek.

class ArchetypeOption {
  const ArchetypeOption({required this.id, required this.label, required this.archetype});

  final String id;
  final String label;
  final String archetype;

  factory ArchetypeOption.fromJson(Map<String, dynamic> json) => ArchetypeOption(
        id: json['id'] as String,
        label: json['label'] as String,
        archetype: json['archetype'] as String,
      );
}

class ArchetypeQuestion {
  const ArchetypeQuestion({required this.id, required this.prompt, required this.options});

  final String id;
  final String prompt;
  final List<ArchetypeOption> options;

  factory ArchetypeQuestion.fromJson(Map<String, dynamic> json) => ArchetypeQuestion(
        id: json['id'] as String,
        prompt: json['prompt'] as String,
        options: (json['options'] as List<dynamic>)
            .map((o) => ArchetypeOption.fromJson(o as Map<String, dynamic>))
            .toList(),
      );
}

class ArchetypeQuestions {
  const ArchetypeQuestions({required this.version, required this.questions});

  final int version;
  final List<ArchetypeQuestion> questions;

  factory ArchetypeQuestions.fromJson(Map<String, dynamic> json) => ArchetypeQuestions(
        version: json['version'] as int,
        questions: (json['questions'] as List<dynamic>)
            .map((q) => ArchetypeQuestion.fromJson(q as Map<String, dynamic>))
            .toList(),
      );
}

class ArchetypeResult {
  const ArchetypeResult({
    required this.userId,
    required this.archetypeSlug,
    required this.scores,
    required this.version,
    required this.createdAt,
  });

  final String userId;
  final String archetypeSlug;
  final Map<String, num> scores;
  final int version;
  final String createdAt;

  factory ArchetypeResult.fromJson(Map<String, dynamic> json) => ArchetypeResult(
        userId: json['userId'] as String,
        archetypeSlug: json['archetypeSlug'] as String,
        scores: (json['scores'] as Map<String, dynamic>).map((k, v) => MapEntry(k, v as num)),
        version: json['version'] as int,
        createdAt: json['createdAt'] as String,
      );
}
