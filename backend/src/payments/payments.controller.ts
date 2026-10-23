import {
    Body,
    Controller,
    Get,
    Headers,
    HttpCode,
    HttpStatus,
    Param,
    ParseUUIDPipe,
    Post,
    Req,
    UseGuards,
} from '@nestjs/common';
import { RawBodyRequest } from '@nestjs/common';
import { Request } from 'express';
import { CurrentUser } from '../auth/current-user.decorator';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CreatePaymentIntentDto, PaymentsService } from './payments.service';

type RequestWithRawBody = RawBodyRequest<Request>;

@Controller('payments')
export class PaymentsController {
    constructor(private readonly paymentsService: PaymentsService) { }

    @Post('intents')
    @UseGuards(JwtAuthGuard)
    @HttpCode(HttpStatus.CREATED)
    createIntent(
        @CurrentUser() user: { id: string },
        @Body() dto: CreatePaymentIntentDto,
    ) {
        return this.paymentsService.createIntent(user.id, dto);
    }

    @Get('orders/:orderId')
    @UseGuards(JwtAuthGuard)
    getPayments(
        @CurrentUser() user: { id: string },
        @Param('orderId', new ParseUUIDPipe()) orderId: string,
    ) {
        return this.paymentsService.getPayments(user.id, orderId);
    }

    @Post('webhook')
    @HttpCode(HttpStatus.OK)
    processWebhook(
        @Req() request: RequestWithRawBody,
        @Headers('x-payment-signature') signature?: string,
    ) {
        return this.paymentsService.processWebhook(request.rawBody, signature);
    }
}
