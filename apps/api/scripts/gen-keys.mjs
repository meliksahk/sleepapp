// RS256 anahtar çifti üretir (identity access JWT). Çıktı stdout'a; .env veya
// GitHub Environments'a ELLE konur — repoya ASLA yazılmaz (CLAUDE.md §6).
import { generateKeyPair, exportPKCS8, exportSPKI } from 'jose';

const { privateKey, publicKey } = await generateKeyPair('RS256', { extractable: true });
const priv = await exportPKCS8(privateKey);
const pub = await exportSPKI(publicKey);

const oneLine = (pem) => pem.replace(/\n/g, '\\n').trim();
console.log('# .env için (satır sonları \\n olarak kaçışlı):');
console.log(`JWT_PRIVATE_KEY="${oneLine(priv)}"`);
console.log(`JWT_PUBLIC_KEY="${oneLine(pub)}"`);
