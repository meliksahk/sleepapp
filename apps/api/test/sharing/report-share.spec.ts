import {
  buildNightReportShare,
  formatDuration,
} from '../../src/modules/sharing/domain/report-share';

const urls = { webBaseUrl: 'https://nocta.app', appScheme: 'nocta' };

describe('formatDuration', () => {
  it('saat + dakika', () => {
    expect(formatDuration(462)).toBe('7h 42m');
  });
  it('tam saat', () => {
    expect(formatDuration(420)).toBe('7h');
  });
  it('yalnızca dakika', () => {
    expect(formatDuration(45)).toBe('45m');
  });
});

describe('buildNightReportShare', () => {
  it('başlık/alt başlık + deep link + web CTA', () => {
    const share = buildNightReportShare(
      { nightDate: '2026-07-15', totalDurationMinutes: 462, calmScore: 85 },
      urls,
    );
    expect(share.title).toBe('My night: 7h 42m');
    expect(share.subtitle).toContain('85/100');
    expect(share.durationText).toBe('7h 42m');
    expect(share.deepLink).toBe('nocta://report/2026-07-15');
    expect(share.webUrl).toBe('https://nocta.app'); // kişisel sayfa yok → indirme CTA
  });

  it('SAĞLIK İDDİASI YOK', () => {
    const blob = JSON.stringify(
      buildNightReportShare(
        { nightDate: '2026-07-15', totalDurationMinutes: 300, calmScore: 70 },
        urls,
      ),
    ).toLowerCase();
    for (const banned of ['cure', 'treat', 'therapy', 'clinically', 'medical', 'disease']) {
      expect(blob).not.toContain(banned);
    }
  });
});
