/**
 * Minik PostgreSQL okuyucu — `INSERT` ifadelerindeki VALUES demetlerini çıkarır.
 *
 * ## NEDEN REGEX DEĞİL
 *
 * `db/seed.sql` içindeki tarifler gömülü kütüphanenin (ve dolayısıyla kurulan
 * APK'nın) TEK kaynağı. Regex ile ayrıştırmak burada üç somut yoldan sessizce
 * yanlış üretirdi:
 *
 *   1. **Yorumlar.** Seed dosyası yoğun yorumlu ve yorumların İÇİNDE parantez,
 *      virgül, kesme işareti ve hatta `VALUES` kelimesi geçiyor. Parantez sayan
 *      bir regex, yorum içindeki `(` yüzünden demeti yanlış yerde keser.
 *   2. **Kesme işareti.** Türkçe başlıklar (`'Ocak ve Parazit'`) bugün masum ama
 *      `'Gece'nin Sesi'` gibi bir başlık (SQL'de `''` ile kaçırılır) naif bir
 *      dizgi regex'ini ORTADAN böler.
 *   3. **Sıra bağımlılığı.** `INSERT ... SELECT ... FROM (VALUES ...) AS v (...)`
 *      (presets) ile düz `INSERT ... VALUES` (soundscapes) farklı şekiller;
 *      tek regex ikisini birden doğru okuyamaz.
 *
 * Bu yüzden burada gerçek bir sözcükleyici (lexer) var: yorumları, dizgi
 * kaçışlarını ve dolar-tırnağı DİLİN kurallarıyla ele alır.
 *
 * ## NEDEN "SEED'İ ÇALIŞTIRIP DB'DEN OKUMAK" DEĞİL
 *
 * İlk bakışta en sağlam yol o görünüyor (gerçek Postgres, gerçek ayrıştırma) ama
 * bu üretimin çıktısı bir DRIFT KAPISI besliyor ve kapı iki şey gerektiriyor:
 *
 *   - **Determinizm.** Seed `now()` ve `date_trunc('week', now())` kullanıyor.
 *     DB'den okunan çıktı her hafta (publish_at için her saniye) DEĞİŞİRDİ →
 *     bayt bayt karşılaştıran kapı sürekli kırmızı yanardı.
 *   - **Bağımlılıksızlık.** Kapı CI'da her PR'da koşuyor. Docker + Postgres +
 *     migration + seed zinciri gerektiren bir lint adımı, `check-archetype-drift`
 *     (saf Node, saniyeler) yanında orantısız bir maliyet.
 *
 * Sözcükleyici her ikisini de sağlıyor: saf Node, deterministik.
 *
 * ## KIRILMA FELSEFESİ
 *
 * Anlamadığı her şeyde PATLAR (sessizce atlamaz). `gen-archetype-matrix.mjs`
 * yükleyicisiyle aynı karar: sessizce yanlış üretmektense kırılmak doğrudur.
 * Seed'e bu okuyucunun bilmediği bir ifade girerse CI durur ve buraya destek
 * eklenir — kütüphane sessizce eksilmez.
 */

const KEYWORD = /^[A-Za-z_][A-Za-z0-9_$]*$/;

/**
 * SQL metnini token'lara böler. Yorumlar ATILIR; dizgiler kaçışları çözülmüş
 * hâlde döner.
 */
export function tokenize(sql) {
  const tokens = [];
  let i = 0;

  const lineOf = (pos) => sql.slice(0, pos).split('\n').length;

  while (i < sql.length) {
    const c = sql[i];

    // Boşluk.
    if (c === ' ' || c === '\t' || c === '\r' || c === '\n') {
      i++;
      continue;
    }

    // `-- satır yorumu`
    if (c === '-' && sql[i + 1] === '-') {
      while (i < sql.length && sql[i] !== '\n') i++;
      continue;
    }

    // `/* blok yorumu */` (iç içe geçebilir — Postgres kuralı)
    if (c === '/' && sql[i + 1] === '*') {
      let depth = 1;
      i += 2;
      while (i < sql.length && depth > 0) {
        if (sql[i] === '/' && sql[i + 1] === '*') {
          depth++;
          i += 2;
        } else if (sql[i] === '*' && sql[i + 1] === '/') {
          depth--;
          i += 2;
        } else {
          i++;
        }
      }
      if (depth > 0) throw new Error(`[sql] kapanmamış blok yorumu (satır ${lineOf(i)})`);
      continue;
    }

    // Dolar-tırnaklı dizgi: $$...$$ ya da $tag$...$tag$
    if (c === '$') {
      const m = /^\$([A-Za-z_][A-Za-z0-9_]*)?\$/.exec(sql.slice(i));
      if (m) {
        const tag = m[0];
        const end = sql.indexOf(tag, i + tag.length);
        if (end < 0) throw new Error(`[sql] kapanmamış ${tag} dizgisi (satır ${lineOf(i)})`);
        tokens.push({ kind: 'string', value: sql.slice(i + tag.length, end), line: lineOf(i) });
        i = end + tag.length;
        continue;
      }
    }

    // Tek tırnaklı dizgi — `''` içeride tek tırnak demektir.
    if (c === "'") {
      let j = i + 1;
      let out = '';
      let closed = false;
      while (j < sql.length) {
        if (sql[j] === "'") {
          if (sql[j + 1] === "'") {
            out += "'";
            j += 2;
            continue;
          }
          closed = true;
          break;
        }
        out += sql[j];
        j++;
      }
      if (!closed) throw new Error(`[sql] kapanmamış dizgi (satır ${lineOf(i)})`);
      tokens.push({ kind: 'string', value: out, line: lineOf(i) });
      i = j + 1;
      continue;
    }

    // Çift tırnaklı tanımlayıcı.
    if (c === '"') {
      const end = sql.indexOf('"', i + 1);
      if (end < 0) throw new Error(`[sql] kapanmamış tanımlayıcı (satır ${lineOf(i)})`);
      tokens.push({ kind: 'ident', value: sql.slice(i + 1, end), line: lineOf(i) });
      i = end + 1;
      continue;
    }

    // Tip dönüşümü.
    if (c === ':' && sql[i + 1] === ':') {
      tokens.push({ kind: 'punct', value: '::', line: lineOf(i) });
      i += 2;
      continue;
    }

    // Sayı (işaret AYRI token — tekli eksi ifade değerlendiricisinde ele alınır).
    if (/[0-9]/.test(c) || (c === '.' && /[0-9]/.test(sql[i + 1] ?? ''))) {
      const m = /^[0-9]*\.?[0-9]+(?:[eE][+-]?[0-9]+)?/.exec(sql.slice(i));
      tokens.push({ kind: 'number', value: m[0], line: lineOf(i) });
      i += m[0].length;
      continue;
    }

    // Tanımlayıcı / anahtar kelime.
    if (/[A-Za-z_]/.test(c)) {
      const m = /^[A-Za-z_][A-Za-z0-9_$]*/.exec(sql.slice(i));
      tokens.push({ kind: 'ident', value: m[0], line: lineOf(i) });
      i += m[0].length;
      continue;
    }

    tokens.push({ kind: 'punct', value: c, line: lineOf(i) });
    i++;
  }

  return tokens;
}

/** Token bir anahtar kelime mi (büyük/küçük harf duyarsız)? */
function isKeyword(token, word) {
  return token !== undefined && token.kind === 'ident' && token.value.toUpperCase() === word;
}

function isPunct(token, ch) {
  return token !== undefined && token.kind === 'punct' && token.value === ch;
}

/** `;` ile (parantez derinliği 0'da) ifadelere böler. */
export function splitStatements(tokens) {
  const statements = [];
  let current = [];
  let depth = 0;
  for (const t of tokens) {
    if (isPunct(t, '(') || isPunct(t, '[')) depth++;
    if (isPunct(t, ')') || isPunct(t, ']')) depth--;
    if (isPunct(t, ';') && depth === 0) {
      if (current.length > 0) statements.push(current);
      current = [];
      continue;
    }
    current.push(t);
  }
  if (current.length > 0) statements.push(current);
  return statements;
}

/** `(` konumundan başlayıp eşleşen `)` indeksini döndürür. */
function matchParen(tokens, open) {
  let depth = 0;
  for (let i = open; i < tokens.length; i++) {
    if (isPunct(tokens[i], '(')) depth++;
    else if (isPunct(tokens[i], ')')) {
      depth--;
      if (depth === 0) return i;
    }
  }
  throw new Error(`[sql] eşleşmeyen parantez (satır ${tokens[open]?.line ?? '?'})`);
}

/** Parantez içindeki virgülle ayrık öğeleri token dilimleri olarak döndürür. */
function splitByComma(tokens, from, to) {
  const parts = [];
  let depth = 0;
  let start = from;
  for (let i = from; i < to; i++) {
    const t = tokens[i];
    if (isPunct(t, '(') || isPunct(t, '[')) depth++;
    else if (isPunct(t, ')') || isPunct(t, ']')) depth--;
    else if (isPunct(t, ',') && depth === 0) {
      parts.push(tokens.slice(start, i));
      start = i + 1;
    }
  }
  parts.push(tokens.slice(start, to));
  return parts.filter((p) => p.length > 0);
}

/** Sütun adı listesi: `(a, b, c)` → ['a','b','c'] (küçük harfe indirgenmiş). */
function readIdentList(tokens, open) {
  const close = matchParen(tokens, open);
  const names = splitByComma(tokens, open + 1, close).map((part) => {
    if (part.length !== 1 || part[0].kind !== 'ident') {
      throw new Error(`[sql] sütun adı beklendi (satır ${part[0]?.line ?? '?'})`);
    }
    return part[0].value.toLowerCase();
  });
  return { names, close };
}

/**
 * Bir ifadeyi (token dilimi) JS değerine çevirir.
 *
 * Desteklenen: dizgi (opsiyonel `::tip` dönüşümüyle), sayı, NULL, TRUE/FALSE,
 * `ARRAY[...]`, ve fonksiyon çağrısı. Fonksiyon çağrısı DEĞERLENDİRİLMEZ —
 * `{ expr: 'now()' }` gibi bir işaretçi döner; çağıran onu tanır ya da patlar.
 * Bilinmeyen her şeyde hata: sessizce `null` üretmek, kütüphaneden sessizce
 * içerik düşürürdü.
 */
export function evaluate(tokens) {
  if (tokens.length === 0) throw new Error('[sql] boş ifade');

  // Sondaki `::tip` dönüşümlerini soy (üst üste gelebilir: `x::text::jsonb`).
  let body = tokens;
  const casts = [];
  for (;;) {
    // En sondaki `::` yi (derinlik 0'da) bul.
    let castAt = -1;
    let depth = 0;
    for (let i = 0; i < body.length; i++) {
      if (isPunct(body[i], '(') || isPunct(body[i], '[')) depth++;
      else if (isPunct(body[i], ')') || isPunct(body[i], ']')) depth--;
      else if (isPunct(body[i], '::') && depth === 0) castAt = i;
    }
    if (castAt === -1) break;
    const typeTokens = body.slice(castAt + 1);
    if (typeTokens.length === 0 || typeTokens[0].kind !== 'ident') {
      throw new Error(`[sql] '::' sonrası tip adı beklendi (satır ${body[castAt].line})`);
    }
    casts.unshift(typeTokens[0].value.toLowerCase());
    body = body.slice(0, castAt);
  }

  const value = evaluateBase(body);
  return applyCasts(value, casts, body[0]?.line);
}

function applyCasts(value, casts, line) {
  let out = value;
  for (const cast of casts) {
    if (cast === 'jsonb' || cast === 'json') {
      if (typeof out !== 'string') {
        throw new Error(`[sql] ::${cast} yalnızca dizgiye uygulanabilir (satır ${line})`);
      }
      try {
        out = JSON.parse(out);
      } catch (err) {
        throw new Error(`[sql] geçersiz JSON (satır ${line}): ${err.message}`);
      }
    }
    // uuid/text/date/int gibi dönüşümler değeri DEĞİŞTİRMEZ — okuma yolunda
    // dizgi olarak taşınırlar (JSON'da zaten dizgi olacaklar).
  }
  return out;
}

function evaluateBase(tokens) {
  const first = tokens[0];

  // Tekli eksi.
  if (isPunct(first, '-')) {
    const inner = evaluateBase(tokens.slice(1));
    if (typeof inner !== 'number') throw new Error(`[sql] '-' sayı bekler (satır ${first.line})`);
    return -inner;
  }

  // Tek parantezle sarılı ifade.
  if (isPunct(first, '(') && matchParen(tokens, 0) === tokens.length - 1) {
    return evaluate(tokens.slice(1, -1));
  }

  if (tokens.length === 1) {
    if (first.kind === 'string') return first.value;
    if (first.kind === 'number') return Number(first.value);
    if (first.kind === 'ident') {
      const upper = first.value.toUpperCase();
      if (upper === 'NULL') return null;
      if (upper === 'TRUE') return true;
      if (upper === 'FALSE') return false;
    }
    throw new Error(`[sql] anlaşılmayan ifade: "${first.value}" (satır ${first.line})`);
  }

  // ARRAY[...]
  if (isKeyword(first, 'ARRAY') && isPunct(tokens[1], '[')) {
    const close = tokens.length - 1;
    if (!isPunct(tokens[close], ']')) {
      throw new Error(`[sql] ARRAY[...] kapanmıyor (satır ${first.line})`);
    }
    return splitByComma(tokens, 2, close).map((part) => evaluate(part));
  }

  // Fonksiyon çağrısı → değerlendirilmez, işaretçi döner.
  if (first.kind === 'ident' && isPunct(tokens[1], '(') && matchParen(tokens, 1) === tokens.length - 1) {
    const args = splitByComma(tokens, 2, tokens.length - 1);
    return {
      expr: first.value.toLowerCase(),
      args: args.map((part) => {
        try {
          return evaluate(part);
        } catch {
          // İç içe fonksiyon (`date_trunc('week', now())`) — argümanı ham
          // metniyle taşımak yeter; çağıran bütün ifadeye bakarak karar verir.
          return { raw: part.map((t) => t.value).join(' ') };
        }
      }),
    };
  }

  throw new Error(
    `[sql] anlaşılmayan ifade: "${tokens.map((t) => t.value).join(' ')}" (satır ${first.line})`,
  );
}

/**
 * Postgres text[] literali → dizi. `'{a,b}'` → ['a','b'], `'{}'` → [].
 *
 * Tırnaklı öğeler (`'{"a,b"}'`) de desteklenir — bugün seed'de yok ama bir slug'a
 * virgül girdiği gün sessizce ikiye bölünmesin.
 */
export function parsePgTextArray(literal, context) {
  if (typeof literal !== 'string') {
    throw new Error(`[sql] ${context}: text[] literali dizgi olmalı`);
  }
  const trimmed = literal.trim();
  if (!trimmed.startsWith('{') || !trimmed.endsWith('}')) {
    throw new Error(`[sql] ${context}: geçersiz text[] literali: ${literal}`);
  }
  const inner = trimmed.slice(1, -1).trim();
  if (inner === '') return [];

  const out = [];
  let i = 0;
  while (i < inner.length) {
    if (inner[i] === '"') {
      let j = i + 1;
      let value = '';
      while (j < inner.length && inner[j] !== '"') {
        if (inner[j] === '\\') j++;
        value += inner[j];
        j++;
      }
      out.push(value);
      i = j + 1;
      while (i < inner.length && inner[i] !== ',') i++;
      i++;
    } else {
      const comma = inner.indexOf(',', i);
      const end = comma === -1 ? inner.length : comma;
      out.push(inner.slice(i, end).trim());
      i = end + 1;
    }
  }
  return out;
}

/**
 * Bir `INSERT` ifadesinden `{ table, columns, rows }` çıkarır.
 * `rows`, sütun adı → değer haritalarıdır. INSERT değilse null.
 *
 * İki şekil desteklenir:
 *   1. `INSERT INTO t (cols) VALUES (...), (...)`
 *   2. `INSERT INTO t (cols) SELECT ... FROM (VALUES (...), (...)) AS v (cols)`
 *
 * (2)'de takma ad sütun listesi INSERT sütun listesiyle KARŞILAŞTIRILIR: SELECT
 * sırası değiştiği gün sessizce yanlış eşleşme yerine hata alınsın.
 */
export function parseInsert(statement) {
  if (!isKeyword(statement[0], 'INSERT') || !isKeyword(statement[1], 'INTO')) return null;
  const tableToken = statement[2];
  if (tableToken?.kind !== 'ident') {
    throw new Error(`[sql] INSERT INTO sonrası tablo adı beklendi (satır ${tableToken?.line ?? '?'})`);
  }
  const table = tableToken.value.toLowerCase();

  if (!isPunct(statement[3], '(')) {
    throw new Error(`[sql] ${table}: sütun listesi zorunlu (satır ${statement[3]?.line ?? '?'})`);
  }
  const { names: columns, close } = readIdentList(statement, 3);

  let valuesAt = -1;
  const selectForm = isKeyword(statement[close + 1], 'SELECT');
  for (let i = close + 1; i < statement.length; i++) {
    if (isKeyword(statement[i], 'VALUES')) {
      valuesAt = i;
      break;
    }
  }
  if (valuesAt === -1) throw new Error(`[sql] ${table}: VALUES bulunamadı`);

  // Demet listesi.
  const tuples = [];
  let i = valuesAt + 1;
  for (;;) {
    if (!isPunct(statement[i], '(')) break;
    const end = matchParen(statement, i);
    tuples.push(splitByComma(statement, i + 1, end));
    i = end + 1;
    if (isPunct(statement[i], ',')) {
      i++;
      continue;
    }
    break;
  }
  if (tuples.length === 0) throw new Error(`[sql] ${table}: VALUES sonrası demet yok`);

  if (selectForm) {
    // `) AS v (a, b, c)` — takma ad sütunları INSERT sütunlarıyla aynı sırada mı?
    let j = i;
    while (j < statement.length && !isKeyword(statement[j], 'AS')) j++;
    if (j >= statement.length || statement[j + 1]?.kind !== 'ident' || !isPunct(statement[j + 2], '(')) {
      throw new Error(
        `[sql] ${table}: SELECT ... FROM (VALUES ...) biçiminde 'AS ad (sütunlar)' zorunlu — ` +
          'sütun eşleşmesi doğrulanamıyor.',
      );
    }
    const { names: aliasColumns } = readIdentList(statement, j + 2);
    if (aliasColumns.join(',') !== columns.join(',')) {
      throw new Error(
        `[sql] ${table}: INSERT sütunları (${columns.join(', ')}) ile ` +
          `takma ad sütunları (${aliasColumns.join(', ')}) AYNI SIRADA değil. ` +
          'Bu okuyucu eşleşmeyi sıraya göre yapıyor; sessizce yanlış veri üretmemek için duruyor.',
      );
    }
  }

  const rows = tuples.map((tuple, index) => {
    if (tuple.length !== columns.length) {
      throw new Error(
        `[sql] ${table}: ${index + 1}. demette ${tuple.length} değer var, ${columns.length} sütun bekleniyor.`,
      );
    }
    const row = {};
    columns.forEach((name, k) => {
      row[name] = evaluate(tuple[k]);
    });
    return row;
  });

  return { table, columns, rows };
}
