import {
    Body,
    Controller,
    Delete,
    Get,
    HttpCode,
    HttpStatus,
    Param,
    Patch,
    Post,
    UseGuards,
} from '@nestjs/common';
import { CurrentUser } from '../auth/current-user.decorator';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { AddCartItemDto, CartService, UpdateCartItemDto } from './cart.service';

@Controller('cart')
@UseGuards(JwtAuthGuard)
export class CartController {
    constructor(private readonly cartService: CartService) { }

    @Get()
    getCart(@CurrentUser() user: { id: string }) {
        return this.cartService.getCart(user.id);
    }

    @Post('items')
    addItem(
        @CurrentUser() user: { id: string },
        @Body() dto: AddCartItemDto,
    ) {
        return this.cartService.addItem(user.id, dto);
    }

    @Patch('items/:productId')
    updateItem(
        @CurrentUser() user: { id: string },
        @Param('productId') productId: string,
        @Body() dto: UpdateCartItemDto,
    ) {
        return this.cartService.updateItem(user.id, productId, dto);
    }

    @Delete('items/:productId')
    removeItem(
        @CurrentUser() user: { id: string },
        @Param('productId') productId: string,
    ) {
        return this.cartService.removeItem(user.id, productId);
    }

    @Delete()
    clearCart(@CurrentUser() user: { id: string }) {
        return this.cartService.clearCart(user.id);
    }

    @Post('validate')
    @HttpCode(HttpStatus.OK)
    validateCart(@CurrentUser() user: { id: string }) {
        return this.cartService.validateCart(user.id);
    }
}
