import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';
import { ArchetypeContent } from './ArchetypeContent';
import { getArchetype } from '@/content/archetypes';

describe('ArchetypeContent', () => {
  it('archetype içeriğini ve teste CTA linkini gösterir', () => {
    const a = getArchetype('deep-ocean');
    expect(a).toBeDefined();
    render(<ArchetypeContent archetype={a!} />);

    expect(screen.getByRole('heading', { level: 1, name: /deep ocean/i })).toBeInTheDocument();
    expect(screen.getByText(a!.summary)).toBeInTheDocument();
    expect(screen.getByRole('link', { name: /test/i })).toHaveAttribute('href', '/test');
    // preset sesler listelenir
    for (const s of a!.soundsThatHelp) {
      expect(screen.getByText(s)).toBeInTheDocument();
    }
  });
});
