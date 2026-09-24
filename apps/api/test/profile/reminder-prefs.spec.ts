import { plainToInstance } from 'class-transformer';
import { validateSync } from 'class-validator';

import { UpdateProfileDto } from '../../src/modules/profile/presentation/dto';
import { defaultProfile } from '../../src/modules/profile/domain/profile.entity';

/**
 * Hatırlatıcı ve sessiz saat tercihleri (F3).
 *
 * **Neden sınır testi:** saat KULLANICININ YEREL saati (0-23). 24 ya da -1
 * kabul edilseydi bildirim zamanlayıcısı hiç çalışmayan bir saate kurulur ve
 * kullanıcı "hatırlatıcı gelmiyor" derken sebebi hiçbir yerde görünmezdi.
 * Sınır DB'de de zorlanıyor (CHECK); bu test uygulama katmanını kanıtlar.
 */
describe('UpdateProfileDto — hatırlatıcı saatleri', () => {
  const errorsFor = (payload: Record<string, unknown>): string[] =>
    validateSync(plainToInstance(UpdateProfileDto, payload)).map((e) => e.property);

  it('0-23 arası saat kabul edilir', () => {
    for (const hour of [0, 7, 23]) {
      expect(errorsFor({ reminderHour: hour })).toEqual([]);
    }
  });

  it('aralık DIŞI saat reddedilir', () => {
    expect(errorsFor({ reminderHour: 24 })).toEqual(['reminderHour']);
    expect(errorsFor({ reminderHour: -1 })).toEqual(['reminderHour']);
    expect(errorsFor({ quietHoursStart: 99 })).toEqual(['quietHoursStart']);
    expect(errorsFor({ quietHoursEnd: 99 })).toEqual(['quietHoursEnd']);
  });

  it('ondalık saat reddedilir (23.5 diye bir saat yok)', () => {
    expect(errorsFor({ reminderHour: 23.5 })).toEqual(['reminderHour']);
  });

  it('varsayılan profil hatırlatıcısız gelir (kimseye habersiz bildirim kurulmaz)', () => {
    const p = defaultProfile('u-1');
    expect(p.reminderHour).toBeNull();
    expect(p.quietHoursStart).toBeNull();
    expect(p.quietHoursEnd).toBeNull();
  });
});
