import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/design_system/design_system.dart';
import '../../../core/share/sharer.dart';
import '../archetype_models.dart';
import '../archetype_providers.dart';

/// Archetype test ekranı (docs/04 M1): soruları yükle → her soruya bir seçenek →
/// gönder → sonuç. Veri katmanı ArchetypeController (401'de otomatik refresh).
/// Not: kullanıcı metinleri l10n'a M1'de taşınacak (M0 hard-coded deseni sürüyor).
class ArchetypeTestScreen extends ConsumerStatefulWidget {
  const ArchetypeTestScreen({super.key});

  @override
  ConsumerState<ArchetypeTestScreen> createState() => _ArchetypeTestScreenState();
}

class _ArchetypeTestScreenState extends ConsumerState<ArchetypeTestScreen> {
  ArchetypeQuestions? _questions;
  final Map<String, String> _answers = {};
  ArchetypeResult? _result;
  bool _loading = true;
  bool _submitting = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final q = await ref.read(archetypeControllerProvider).fetchQuestions();
      if (!mounted) return;
      setState(() {
        _questions = q;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  bool get _allAnswered =>
      _questions != null && _answers.length == _questions!.questions.length;

  Future<void> _submit() async {
    final q = _questions;
    if (q == null || !_allAnswered || _submitting) return;
    setState(() => _submitting = true);
    try {
      final r = await ref.read(archetypeControllerProvider).submitAnswers(q.version, _answers);
      if (!mounted) return;
      setState(() {
        _result = r;
        _submitting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sleep Identity Test')),
      body: SafeArea(child: _body()),
    );
  }

  Widget _body() {
    if (_result != null) return _ResultView(result: _result!);
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: IconButton(
          key: const Key('archetype-retry'),
          icon: const Icon(Icons.refresh),
          iconSize: 40,
          onPressed: _load,
        ),
      );
    }
    final questions = _questions!.questions;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(NoctaSpace.s5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final q in questions) _questionBlock(q),
          const SizedBox(height: NoctaSpace.s5),
          NButton(
            key: const Key('archetype-submit'),
            label: _submitting ? 'Scoring…' : 'See my result',
            onPressed: _allAnswered && !_submitting ? _submit : null,
          ),
        ],
      ),
    );
  }

  Widget _questionBlock(ArchetypeQuestion q) {
    return Padding(
      padding: const EdgeInsets.only(bottom: NoctaSpace.s5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            q.prompt,
            style: TextStyle(fontSize: NoctaFontSize.body, color: NoctaColors.inkPrimary),
          ),
          const SizedBox(height: NoctaSpace.s3),
          for (final o in q.options)
            Padding(
              padding: const EdgeInsets.only(bottom: NoctaSpace.s2),
              child: NButton(
                key: Key('opt-${q.id}-${o.id}'),
                label: o.label,
                variant: _answers[q.id] == o.id
                    ? NButtonVariant.primary
                    : NButtonVariant.ghost,
                onPressed: () => setState(() => _answers[q.id] = o.id),
              ),
            ),
        ],
      ),
    );
  }
}

class _ResultView extends ConsumerStatefulWidget {
  const _ResultView({required this.result});

  final ArchetypeResult result;

  @override
  ConsumerState<_ResultView> createState() => _ResultViewState();
}

class _ResultViewState extends ConsumerState<_ResultView> {
  bool _sharing = false;

  Future<void> _share() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final share = await ref.read(archetypeControllerProvider).fetchShare();
      if (share == null) return;
      await ref
          .read(sharerProvider)
          .share(ShareContent(text: share.title, url: share.webUrl));
      messenger.showSnackBar(const SnackBar(content: Text('Link copied')));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Could not share')));
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // slug → görünen ad ("deep-ocean" → "Deep Ocean").
    final display = widget.result.archetypeSlug
        .split('-')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(NoctaSpace.s5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Your sleep identity',
              style: TextStyle(fontSize: NoctaFontSize.body, color: NoctaColors.inkSecondary),
            ),
            const SizedBox(height: NoctaSpace.s3),
            NCard(
              child: Text(
                display,
                key: const Key('archetype-result'),
                style: TextStyle(fontSize: NoctaFontSize.display, color: NoctaColors.inkPrimary),
              ),
            ),
            const SizedBox(height: NoctaSpace.s5),
            NButton(
              key: const Key('archetype-share'),
              label: _sharing ? 'Sharing…' : 'Share my identity',
              onPressed: _sharing ? null : _share,
            ),
          ],
        ),
      ),
    );
  }
}
