import { BadRequestException, Body, Controller, HttpCode, Post, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiResponse, ApiTags } from '@nestjs/swagger';
import { AuthGuard, CurrentUser, type AccessTokenClaims } from '../../identity';
import { IngestEventsUseCase } from '../application/ingest-events.usecase';
import { AnalyticsError } from '../domain/errors';
import { IngestAcceptedDto, IngestEventsDto } from './dto';

@ApiTags('analytics')
@ApiBearerAuth()
@Controller('analytics')
@UseGuards(AuthGuard)
export class AnalyticsController {
  constructor(private readonly ingest: IngestEventsUseCase) {}

  @Post('events')
  @HttpCode(202)
  @ApiOperation({ summary: 'Ürün analitik olaylarını yut (batch)' })
  @ApiResponse({ status: 202, type: IngestAcceptedDto })
  async events(
    @CurrentUser() user: AccessTokenClaims,
    @Body() dto: IngestEventsDto,
  ): Promise<IngestAcceptedDto> {
    try {
      const accepted = await this.ingest.execute(
        user.sub,
        dto.events.map((e) => ({
          name: e.name,
          occurredAt: new Date(e.occurredAt),
          props: e.props ?? {},
        })),
      );
      return { accepted };
    } catch (e) {
      if (e instanceof AnalyticsError) {
        throw new BadRequestException({ code: e.code, message: e.message });
      }
      throw e;
    }
  }
}
