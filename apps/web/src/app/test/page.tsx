import type { Metadata } from 'next';
import { ArchetypeTest } from '@/components/ArchetypeTest';

export const metadata: Metadata = {
  title: 'Sleep Archetype Test — NOCTA',
  description: 'Find your sleep identity in 60 seconds.',
};

export default function TestPage() {
  return (
    <main className="mx-auto max-w-2xl p-5">
      <h1 className="text-display font-display">What&apos;s your sleep identity?</h1>
      <p className="mt-2 mb-6 text-body text-ink-secondary">
        Six quick questions. No account needed.
      </p>
      <ArchetypeTest />
    </main>
  );
}
