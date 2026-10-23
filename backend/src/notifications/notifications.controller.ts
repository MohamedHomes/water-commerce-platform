import {
    Controller,
    Get,
    Param,
    ParseUUIDPipe,
    Patch,
    Query,
    UseGuards,
} from '@nestjs/common';
import { Type } from 'class-transformer';
import { IsInt, IsOptional, Max, Min } from 'class-validator';
import { CurrentUser } from '../auth/current-user.decorator';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { NotificationsService } from './notifications.service';

class ListNotificationsQuery {
    @IsOptional()
    @Type(() => Number)
    @IsInt()
    @Min(1)
    @Max(100)
    limit = 50;
}

@Controller('notifications')
@UseGuards(JwtAuthGuard)
export class NotificationsController {
    constructor(private readonly notificationsService: NotificationsService) { }

    @Get()
    list(
        @CurrentUser() user: { id: string },
        @Query() query: ListNotificationsQuery,
    ) {
        return this.notificationsService.list(user.id, query.limit);
    }

    @Patch(':id/read')
    markRead(
        @CurrentUser() user: { id: string },
        @Param('id', new ParseUUIDPipe()) id: string,
    ) {
        return this.notificationsService.markRead(user.id, id);
    }
}
