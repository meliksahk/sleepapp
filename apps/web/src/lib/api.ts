// NOCTA public API istemcisi (web viral testi + waitlist). Kimlik gerektirmez.
import type { Locale } from '@/lib/i18n';
export interface QuestionOption {
  id: string;
  label: string;
  archetype: string;
}
export interface Question {
  id: string;
  prompt: string;
  options: QuestionOption[];
}
export interface QuestionMatrix {
  version: number;
  questions: Question[];
}
export interface WebResult {
  shareSlug: string;
  archetypeSlug: string;
  scores: Record<string, number>;
  version: number;
}

const API_BASE = process.env.NEXT_PUBLIC_API_URL ?? 'http://localhost:3001';

/**
 * Dil BAŞLIKLA taşınır, query parametresiyle DEĞİL.
 *
 * API'nin kontratı bunu şart koşuyor (apps/api/src/shared/locale.ts): dil bir sunum
 * tercihidir, kaynak kimliğinin parçası değil. Query parametresi olsaydı aynı içeriğin
 * iki ayrı URL'i olur, cache ve paylaşım linkleri bölünürdü. Tanımadığı dilde API
 * sessizce EN'e düşer.
 */
function localeHeaders(locale: Locale): Record<string, string> {
  return { 'Accept-Language': locale };
}

export async function fetchQuestions(locale: Locale = 'en'): Promise<QuestionMatrix> {
  const res = await fetch(`${API_BASE}/v1/archetype/web/questions`, {
    headers: localeHeaders(locale),
  });
  if (!res.ok) throw new Error('questions_failed');
  return res.json() as Promise<QuestionMatrix>;
}

export async function submitAnswers(
  version: number,
  answers: Record<string, string>,
  locale: Locale = 'en',
): Promise<WebResult> {
  const res = await fetch(`${API_BASE}/v1/archetype/web`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', ...localeHeaders(locale) },
    body: JSON.stringify({ version, answers }),
  });
  if (!res.ok) throw new Error('submit_failed');
  return res.json() as Promise<WebResult>;
}

export async function joinWaitlist(email: string, source?: string): Promise<void> {
  const res = await fetch(`${API_BASE}/v1/waitlist`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, source }),
  });
  if (!res.ok) throw new Error('waitlist_failed');
}
