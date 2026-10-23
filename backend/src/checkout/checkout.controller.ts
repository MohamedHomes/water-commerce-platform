import {
    Body,
    Controller,
    HttpCode,
    HttpStatus,
    Get,
    Param,
    Post,
    UseGuards,
} from '@nestjs/common';
import { CurrentUser } from '../auth/current-user.decorator';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { PrepareCheckoutDto, CheckoutService } from './checkout.service';

@Controller('checkout')
@UseGuards(JwtAuthGuard)
export class CheckoutController {
    constructor(private readonly checkoutService: CheckoutService) { }

    @Post('prepare')
    @HttpCode(HttpStatus.CREATED)
    prepareCheckout(
        @CurrentUser() user: { id: string },
        @Body() dto: PrepareCheckoutDto,
    ) {
        return this.checkoutService.prepareCheckout(user.id, dto);
    }

    @Get(':checkoutId')
    getCheckoutSession(
        @CurrentUser() user: { id: string },
        @Param('checkoutId') checkoutId: string,
    ) {
        return this.checkoutService.getCheckoutSession(user.id, checkoutId);
    }
}
