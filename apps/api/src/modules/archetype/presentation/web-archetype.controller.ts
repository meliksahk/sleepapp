import {
  BadRequestException,
  Body,
  Controller,
  Get,
  Headers,
  HttpCode,
  NotFoundException,
  Param,
  Post,
  UseGuards,
} from '@nestjs/common';
import { ApiHeader, ApiOkResponse, ApiOperation, ApiTags } from '@nestjs/swagger';
import { resolveLocale } from '../../../shared/locale';
import { Throttle, ThrottlerGuard } from '@nestjs/throttler';
import { ScoreWebUseCase } from '../application/score-web.usecase';
import { GetWebResultUseCase } from '../application/get-web-result.usecase';
import { GetQuestionsUseCase } from '../application/get-questions.usecase';
import { ArchetypeError } from '../domain/errors';
import type { QuestionMatrix } from '../domain/archetype';
import { QuestionsResponseDto, SubmitAnswersDto, WebResultResponseDto } from './dto';

/**
 * Public web archetype testi (docs/05 W0) — kimlik GEREKMEZ. IP rate-limit
 * (throttler, in-memory; Redis tabanlı dağıtık limit B4). Yalnızca bu controller
 * throttle'lı — diğer uçlar etkilenmez.
 */
@ApiTags('archetype-web')
@Controller('archetype/web')
@UseGuards(ThrottlerGuard)
@Throttle({ default: { limit: 30, ttl: 60_000 } })
export class WebArchetypeController {
  constructor(
    private readonly scoreWeb: ScoreWebUseCase,
    private readonly getWebResult: GetWebResultUseCase,
    private readonly getQuestions: GetQuestionsUseCase,
  ) {}

  @Get('questions')
  @ApiOperation({ summary: 'Public archetype soru matrisi (web testi render eder)' })
  @ApiHeader({ name: 'Accept-Language', required: false, description: 'en (varsayilan) | tr' })
  @ApiOkResponse({ type: QuestionsResponseDto })
  questions(@Headers('accept-language') acceptLanguage?: string): QuestionMatrix {
    return this.getQuestions.execute(resolveLocale(acceptLanguage));
  }

  @Post()
  @HttpCode(201)
  @ApiOperation({ summary: 'Anonim web testi — skorla + paylaşım slug üret' })
  @ApiOkResponse({ type: WebResultResponseDto })
  async score(@Body() dto: SubmitAnswersDto): Promise<WebResultResponseDto> {
    try {
      return await this.scoreWeb.execute(dto.version, dto.answers);
    } catch (e) {
      if (e instanceof ArchetypeError) {
        throw new BadRequestException({ code: e.code, message: e.message });
      }
      throw e;
    }
  }

  @Get(':slug')
  @ApiOperation({ summary: 'Paylaşım slug ile anonim sonuç (OG / /a sayfası)' })
  @ApiOkResponse({ type: WebResultResponseDto })
  async result(@Param('slug') slug: string): Promise<WebResultResponseDto> {
    const found = await this.getWebResult.execute(slug);
    if (!found) {
      throw new NotFoundException({ code: 'not_found', message: 'Sonuç bulunamadı.' });
    }
    return found;
  }
}
