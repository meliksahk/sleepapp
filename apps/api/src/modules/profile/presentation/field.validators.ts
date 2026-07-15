import { registerDecorator, type ValidationOptions } from 'class-validator';

/**
 * Geçerli IANA saat dilimi mi? (ör. 'Europe/Istanbul'). "Gece" gruplaması
 * (kullanıcı yerel günü, 06:00 sınırı — CLAUDE.md §4) geçerli tz'ye bağlıdır.
 */
export function isIanaTimeZone(value: unknown): boolean {
  if (typeof value !== 'string' || value.length === 0) return false;
  try {
    // Geçersiz tz'de Intl RangeError fırlatır.
    new Intl.DateTimeFormat('en-US', { timeZone: value });
    return true;
  } catch {
    return false;
  }
}

/** Biçimsel olarak geçerli BCP-47 dil etiketi mi? (ör. 'en', 'tr', 'en-US'). */
export function isBcp47Locale(value: unknown): boolean {
  if (typeof value !== 'string' || value.length === 0) return false;
  try {
    Intl.getCanonicalLocales(value);
    return true;
  } catch {
    return false;
  }
}

export function IsIanaTimeZone(options?: ValidationOptions) {
  return function (object: object, propertyName: string): void {
    registerDecorator({
      name: 'isIanaTimeZone',
      target: object.constructor,
      propertyName,
      options,
      validator: {
        validate: (value: unknown) => isIanaTimeZone(value),
        defaultMessage: () => 'timezone geçerli bir IANA saat dilimi olmalı (ör. Europe/Istanbul)',
      },
    });
  };
}

export function IsBcp47Locale(options?: ValidationOptions) {
  return function (object: object, propertyName: string): void {
    registerDecorator({
      name: 'isBcp47Locale',
      target: object.constructor,
      propertyName,
      options,
      validator: {
        validate: (value: unknown) => isBcp47Locale(value),
        defaultMessage: () => 'locale geçerli bir dil etiketi olmalı (ör. en, tr, en-US)',
      },
    });
  };
}
