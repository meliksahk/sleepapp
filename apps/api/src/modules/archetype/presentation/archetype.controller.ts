import {
  BadRequestException,
  Body,
  Controller,
  Get,
  Headers,
  HttpCode,
  NotFoundException,
  Post,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiHeader, ApiOkResponse, ApiOperation, ApiTags } from '@nestjs/swagger';
import { resolveLocale } from '../../../shared/locale';
import { AuthGuard, CurrentUser, type AccessTokenClaims } from '../../identity';
import type { QuestionMatrix } from '../domain/archetype';
import { GetQuestionsUseCase } from '../application/get-questions.usecase';
import { SubmitAnswersUseCase } from '../application/submit-answers.usecase';
import { GetLatestResultUseCase } from '../application/get-latest-result.usecase';
import { ListResultsUseCase } from '../application/list-results.usecase';
import { ArchetypeError } from '../domain/errors';
import { ArchetypeResultResponseDto, QuestionsResponseDto, SubmitAnswersDto } from './dto';

@ApiTags('archetype')
@ApiBearerAuth()
@Controller('archetype')
@UseGuards(AuthGuard)
export class ArchetypeController {
  constructor(
    private readonly getQuestions: GetQuestionsUseCase,
    private readonly submitAnswers: SubmitAnswersUseCase,
    private readonly getLatestResult: GetLatestResultUseCase,
    private readonly listResults: ListResultsUseCase,
  ) {}

  @Get('questions')
  @ApiOperation({ summary: 'Geçerli archetype soru matrisi' })
  @ApiHeader({ name: 'Accept-Language', required: false, description: 'en (varsayılan) | tr' })
  @ApiOkResponse({ type: QuestionsResponseDto })
  questions(@Headers('accept-language') acceptLanguage?: string): QuestionMatrix {
    return this.getQuestions.execute(resolveLocale(acceptLanguage));
  }

  @Post('answers')
  @HttpCode(201)
  @ApiOperation({ summary: 'Cevapları gönder → skorla → sonucu kaydet' })
  @ApiOkResponse({ type: ArchetypeResultResponseDto })
  async submit(
    @CurrentUser() user: AccessTokenClaims,
    @Body() dto: SubmitAnswersDto,
  ): Promise<ArchetypeResultResponseDto> {
    try {
      return await this.submitAnswers.execute(user.sub, dto.version, dto.answers);
    } catch (e) {
      if (e instanceof ArchetypeError) {
        throw new BadRequestException({ code: e.code, message: e.message });
      }
      throw e;
    }
  }

  @Get('result')
  @ApiOperation({ summary: 'Kullanıcının en yeni archetype sonucu' })
  @ApiOkResponse({ type: ArchetypeResultResponseDto })
  async result(@CurrentUser() user: AccessTokenClaims): Promise<ArchetypeResultResponseDto> {
    const latest = await this.getLatestResult.execute(user.sub);
    if (!latest) {
      throw new NotFoundException({ code: 'no_result', message: 'Henüz archetype sonucu yok.' });
    }
    return latest;
  }

  @Get('results')
  @ApiOperation({
    summary: 'Kullanıcının archetype sonuç geçmişi (yeniden eskiye; testi tekrar edince büyür)',
  })
  @ApiOkResponse({ type: [ArchetypeResultResponseDto] })
  results(@CurrentUser() user: AccessTokenClaims): Promise<ArchetypeResultResponseDto[]> {
    return this.listResults.execute(user.sub);
  }
}
