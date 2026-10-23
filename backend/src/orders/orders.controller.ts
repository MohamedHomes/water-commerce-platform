import {
    Body,
    Controller,
    Get,
    HttpCode,
    HttpStatus,
    Param,
    ParseUUIDPipe,
    Post,
    Query,
    UseGuards,
} from '@nestjs/common';
import { CurrentUser } from '../auth/current-user.decorator';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { ListOrdersQuery, OrdersService, PlaceOrderDto } from './orders.service';

@Controller('orders')
@UseGuards(JwtAuthGuard)
export class OrdersController {
    constructor(private readonly ordersService: OrdersService) { }

    @Post()
    @HttpCode(HttpStatus.CREATED)
    placeOrder(
        @CurrentUser() user: { id: string },
        @Body() dto: PlaceOrderDto,
    ) {
        return this.ordersService.placeOrder(user.id, dto);
    }

    @Get()
    getOrders(
        @CurrentUser() user: { id: string },
        @Query() query: ListOrdersQuery,
    ) {
        return this.ordersService.getOrders(user.id, query);
    }

    @Get(':id')
    getOrder(
        @CurrentUser() user: { id: string },
        @Param('id', new ParseUUIDPipe()) id: string,
    ) {
        return this.ordersService.getOrder(user.id, id);
    }

    @Post(':id/cancel')
    @HttpCode(HttpStatus.OK)
    cancelOrder(
        @CurrentUser() user: { id: string },
        @Param('id', new ParseUUIDPipe()) id: string,
    ) {
        return this.ordersService.cancelOrder(user.id, id);
    }

    @Post(':id/reorder')
    @HttpCode(HttpStatus.OK)
    reorder(
        @CurrentUser() user: { id: string },
        @Param('id', new ParseUUIDPipe()) id: string,
    ) {
        return this.ordersService.reorder(user.id, id);
    }
}
