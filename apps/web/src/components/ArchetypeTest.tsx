'use client';

import { useEffect, useState } from 'react';
import { fetchQuestions, submitAnswers, type QuestionMatrix, type WebResult } from '@/lib/api';
import { getArchetype } from '@/content/archetypes';
import { ShareCard } from '@/components/ShareCard';

export function ArchetypeTest() {
  const [matrix, setMatrix] = useState<QuestionMatrix | null>(null);
  const [answers, setAnswers] = useState<Record<string, string>>({});
  const [result, setResult] = useState<WebResult | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);

  useEffect(() => {
    fetchQuestions()
      .then(setMatrix)
      .catch(() => setError('Sorular yüklenemedi.'));
  }, []);

  if (error) {
    return (
      <p role="alert" className="text-danger">
        {error}
      </p>
    );
  }

  if (result) {
    const data = getArchetype(result.archetypeSlug);
    // Viral döngü (docs/05): sonucu görme anı = paylaşma anı. Kartı BURADA göster —
    // /a/[slug]'a ekstra tıklama beklemeden. Bilinmeyen slug'da kart atlanır (çökmez).
    return (
      <div className="rounded-card bg-bg-raised p-5">
        <p className="text-ink-secondary text-caption">Your sleep identity</p>
        <h2 className="text-h1 font-display capitalize">
          {data?.name ?? result.archetypeSlug.replace(/-/g, ' ')}
        </h2>
        {data && <p className="mt-2 text-body text-ink-secondary">{data.tagline}</p>}

        {data && (
          <div className="mt-5">
            <ShareCard
              slug={data.slug}
              name={data.name}
              tagline={data.tagline}
              sounds={data.soundsThatHelp}
            />
          </div>
        )}

        <a
          className="mt-5 inline-block rounded-button bg-accent-aurora px-5 py-3 text-bg-base"
          href={`/a/${result.archetypeSlug}`}
        >
          Read about your archetype
        </a>
      </div>
    );
  }

  if (!matrix) {
    return <p className="text-ink-secondary">Yükleniyor…</p>;
  }

  const allAnswered = matrix.questions.every((q) => answers[q.id]);

  const onSubmit = async () => {
    setSubmitting(true);
    try {
      setResult(await submitAnswers(matrix.version, answers));
    } catch {
      setError('Sonuç hesaplanamadı.');
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <div className="flex flex-col gap-6">
      {matrix.questions.map((q) => (
        <fieldset key={q.id} className="rounded-card bg-bg-raised p-4">
          <legend className="text-body font-display">{q.prompt}</legend>
          <div className="mt-2 flex flex-col gap-2">
            {q.options.map((o) => (
              <label key={o.id} className="flex items-center gap-2 text-ink-secondary">
                <input
                  type="radio"
                  name={q.id}
                  value={o.id}
                  checked={answers[q.id] === o.id}
                  onChange={() => setAnswers((a) => ({ ...a, [q.id]: o.id }))}
                />
                {o.label}
              </label>
            ))}
          </div>
        </fieldset>
      ))}
      <button
        type="button"
        disabled={!allAnswered || submitting}
        onClick={onSubmit}
        className="rounded-button bg-accent-aurora px-5 py-3 text-bg-base disabled:opacity-50"
      >
        {submitting ? 'Hesaplanıyor…' : 'Sonucu gör'}
      </button>
    </div>
  );
}
