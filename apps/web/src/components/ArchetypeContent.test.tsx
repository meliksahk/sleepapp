import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';
import { ArchetypeContent } from './ArchetypeContent';
import { ARCHETYPES, getArchetype } from '@/content/archetypes';

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

  it("diğer sleep identity'lere iç bağlantı verir (kendisi hariç)", () => {
    const a = getArchetype('deep-ocean')!;
    render(<ArchetypeContent archetype={a} />);

    const others = ARCHETYPES.filter((x) => x.slug !== a.slug);
    for (const o of others) {
      const link = screen.getByRole('link', { name: new RegExp(o.name, 'i') });
      expect(link).toHaveAttribute('href', `/a/${o.slug}`);
    }
    // kendi sayfasına link vermez
    expect(screen.queryByRole('link', { name: new RegExp(`${a.name} —`, 'i') })).toBeNull();
  });
});
