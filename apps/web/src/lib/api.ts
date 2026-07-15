// NOCTA public API istemcisi (web viral testi + waitlist). Kimlik gerektirmez.
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

export async function fetchQuestions(): Promise<QuestionMatrix> {
  const res = await fetch(`${API_BASE}/v1/archetype/web/questions`);
  if (!res.ok) throw new Error('questions_failed');
  return res.json() as Promise<QuestionMatrix>;
}

export async function submitAnswers(
  version: number,
  answers: Record<string, string>,
): Promise<WebResult> {
  const res = await fetch(`${API_BASE}/v1/archetype/web`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
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
