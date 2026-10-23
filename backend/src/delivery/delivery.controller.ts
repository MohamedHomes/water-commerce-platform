import {
    Controller,
    Get,
    Param,
    ParseUUIDPipe,
    UseGuards,
} from '@nestjs/common';
import { CurrentUser } from '../auth/current-user.decorator';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { DeliveryService } from './delivery.service';

@Controller('deliveries')
@UseGuards(JwtAuthGuard)
export class DeliveryController {
    constructor(private readonly deliveryService: DeliveryService) { }

    @Get('orders/:orderId')
    getOrderDelivery(
        @CurrentUser() user: { id: string },
        @Param('orderId', new ParseUUIDPipe()) orderId: string,
    ) {
        return this.deliveryService.getCustomerDelivery(user.id, orderId);
    }
}
