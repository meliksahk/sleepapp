/**
 * `upload-audio-assets.mjs` saf mantığı — Node'un YERLEŞİK test koşucusu
 * (`node --test`). Yeni bağımlılık YOK; kök workspace'te jest/vitest kurulu değil
 * ve bu script için bir test çatısı eklemek maliyet ilkesine aykırı olurdu.
 *
 * Çalıştır: node --test tooling/
 *
 * ## Neyi kapsıyor, neyi KAPSAMIYOR
 *
 * Kapsıyor: lisans kapısı, meta ayrıştırma, WAV süre okuma, değişiklik tespiti
 * (idempotency KARARININ kendisi — "bu satır güncellenmeli mi").
 *
 * KAPSAMIYOR: gerçek MinIO/Postgres turu. Bu, ayakta bir docker stack'i gerektirir
 * ve CI'da yoktur; script'in uçtan uca idempotency'si ELDE doğrulandı (üç ardışık
 * çalıştırma → tek satır, bkz. rapor). Buradaki testler o davranışın KARAR
 * mantığını kilitler, ağ turunu değil.
 */
import { strict as assert } from 'node:assert';
import { mkdtempSync, writeFileSync, mkdirSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { test } from 'node:test';

import { metaDiffers, readMeta, wavDurationSeconds } from './upload-audio-assets.mjs';

/** Geçici bir inbox girdisi yazar; `readMeta`nın beklediği şekli döndürür. */
function withMeta(meta) {
  const dir = mkdtempSync(join(tmpdir(), 'nocta-assets-'));
  mkdirSync(dir, { recursive: true });
  const metaPath = join(dir, 'sample.json');
  writeFileSync(metaPath, typeof meta === 'string' ? meta : JSON.stringify(meta));
  return { dir, entry: { stem: 'sample', metaPath } };
}

test('LİSANS KAPISI: license boşsa reddedilir', () => {
  const { dir, entry } = withMeta({ title: 'X', genre: 'ambient', license: '  ', source: 'me' });
  assert.throws(() => readMeta(entry), /license/);
  rmSync(dir, { recursive: true, force: true });
});

test('LİSANS KAPISI: license alanı hiç yoksa reddedilir', () => {
  const { dir, entry } = withMeta({ title: 'X', genre: 'ambient', source: 'me' });
  assert.throws(() => readMeta(entry), /license/);
  rmSync(dir, { recursive: true, force: true });
});

test('KAYNAK KAPISI: source boşsa reddedilir', () => {
  const { dir, entry } = withMeta({ title: 'X', genre: 'ambient', license: 'CC0', source: '' });
  assert.throws(() => readMeta(entry), /source/);
  rmSync(dir, { recursive: true, force: true });
});

test('meta dosyası YOKSA reddedilir (lisans bilinmiyor demektir)', () => {
  assert.throws(
    () => readMeta({ stem: 'yok', metaPath: join(tmpdir(), 'kesinlikle-yok-12345.json') }),
    /meta dosyası YOK/,
  );
});

test('bozuk JSON sessizce atlanmaz', () => {
  const { dir, entry } = withMeta('{ bu json değil');
  assert.throws(() => readMeta(entry), /ayrıştırılamadı/);
  rmSync(dir, { recursive: true, force: true });
});

test('geçerli meta normalize edilir (mood küçük harf + tekil, genre küçük harf)', () => {
  const { dir, entry } = withMeta({
    title: '  Pad + Fire  ',
    genre: 'Ambient',
    mood: ['Calm', 'calm', ' SLEEP '],
    license: 'self-produced',
    source: 'NOCTA audio engine',
    durationSeconds: 10.4,
  });
  const meta = readMeta(entry);
  assert.equal(meta.title, 'Pad + Fire');
  assert.equal(meta.genre, 'ambient');
  assert.deepEqual(meta.mood, ['calm', 'sleep']);
  assert.equal(meta.durationSeconds, 10);
  rmSync(dir, { recursive: true, force: true });
});

test('başlık yoksa dosya adına düşer (lisansın aksine güvenli varsayılan)', () => {
  const { dir, entry } = withMeta({ genre: 'ambient', license: 'CC0', source: 'me' });
  assert.equal(readMeta(entry).title, 'sample');
  rmSync(dir, { recursive: true, force: true });
});

test('wavDurationSeconds gerçek bir RIFF başlığından süre okur', () => {
  // 44 baytlık standart başlık + 96000 bayt veri; byteRate 48000*2 = 96000 → 1 sn.
  const header = Buffer.alloc(44);
  header.write('RIFF', 0, 'ascii');
  header.writeUInt32LE(36 + 96000, 4);
  header.write('WAVE', 8, 'ascii');
  header.write('fmt ', 12, 'ascii');
  header.writeUInt32LE(16, 16); // fmt chunk boyutu
  header.writeUInt16LE(1, 20); // PCM
  header.writeUInt16LE(1, 22); // mono
  header.writeUInt32LE(48000, 24); // sampleRate
  header.writeUInt32LE(96000, 28); // byteRate
  header.writeUInt16LE(2, 32); // blockAlign
  header.writeUInt16LE(16, 34); // bitsPerSample
  header.write('data', 36, 'ascii');
  header.writeUInt32LE(96000, 40);

  assert.equal(wavDurationSeconds(Buffer.concat([header, Buffer.alloc(96000)])), 1);
});

test('WAV olmayan bayt dizisinde TAHMİN ÜRETMEZ (null döner)', () => {
  assert.equal(wavDurationSeconds(Buffer.from('bu bir mp3 değil ki')), null);
  assert.equal(wavDurationSeconds(Buffer.alloc(4)), null);
});

test('metaDiffers: hiçbir şey değişmediyse false (→ gereksiz UPDATE yok)', () => {
  const row = {
    title: 'A',
    genre: 'ambient',
    license: 'CC0',
    source: 'me',
    duration_seconds: 10,
    mood: ['calm', 'sleep'],
  };
  assert.equal(metaDiffers(row, { ...row, mood: ['calm', 'sleep'] }), false);
});

test('metaDiffers: mood SIRASI bile değişse fark sayılır', () => {
  const row = {
    title: 'A',
    genre: 'ambient',
    license: 'CC0',
    source: 'me',
    duration_seconds: 10,
    mood: ['calm', 'sleep'],
  };
  assert.equal(metaDiffers(row, { ...row, mood: ['sleep', 'calm'] }), true);
});

test('metaDiffers: lisans değişimi YAKALANIR (denetim izi bozulmasın)', () => {
  const row = {
    title: 'A',
    genre: 'ambient',
    license: 'CC0',
    source: 'me',
    duration_seconds: 10,
    mood: [],
  };
  assert.equal(metaDiffers(row, { ...row, license: 'self-produced' }), true);
});
