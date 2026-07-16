import { Controller, Get } from '@nestjs/common';
import { ApiOkResponse, ApiOperation, ApiTags } from '@nestjs/swagger';
import { ARCHETYPE_INFO } from '../domain/archetype-content';
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
  @ApiOkResponse({ type: [ArchetypeInfoDto] })
  content(): ArchetypeInfoDto[] {
    return ARCHETYPE_INFO.map((a) => ({
      slug: a.slug,
      name: a.name,
      tagline: a.tagline,
      summary: a.summary,
    }));
  }
}
