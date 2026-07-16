/**
 * API tabanı. SUNUCU tarafında okunur (route handler + middleware) — bilerek
 * NEXT_PUBLIC_ DEĞİL: panelin tarayıcı tarafı API'ye doğrudan gitmez, kendi
 * route handler'ına gider. Böylece token'lar httpOnly çerezde kalır ve JS'e
 * hiç değmez (bkz. session/route.ts).
 */
export const API_BASE = process.env.API_URL ?? 'http://localhost:3001';
