import { Controller, Get, Headers } from '@nestjs/common';
import { ApiHeader, ApiOkResponse, ApiOperation, ApiTags } from '@nestjs/swagger';
import { resolveLocale } from '../../../shared/locale';
import { listArchetypeInfo } from '../domain/archetype-content';
import { ArchetypeInfoDto } from './dto';

/**
 * Archetype tanıtım içeriği — PUBLIC (kimlik gerektirmez; tanıtım verisi).
 * Mobil sonuç ekranı + paylaşım kartı bu tek kaynaktan isim/tagline/özet okur.
 */
@ApiTags('archetype')
@Controller('archetype')
export class ArchetypeContentController {
  @Get('content')
  @ApiOperation({ summary: 'Tüm archetype tanıtım içeriği (isim/tagline/özet)' })
  @ApiHeader({ name: 'Accept-Language', required: false, description: 'en (varsayılan) | tr' })
  @ApiOkResponse({ type: [ArchetypeInfoDto] })
  content(@Headers('accept-language') acceptLanguage?: string): ArchetypeInfoDto[] {
    return listArchetypeInfo(resolveLocale(acceptLanguage)).map((a) => ({
      slug: a.slug,
      name: a.name,
      tagline: a.tagline,
      summary: a.summary,
    }));
  }
}
