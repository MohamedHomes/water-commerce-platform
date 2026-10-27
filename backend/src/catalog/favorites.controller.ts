import { Controller, Delete, Get, Param, Put, UseGuards } from '@nestjs/common';
import { CurrentUser } from '../auth/current-user.decorator';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { FavoritesService } from './favorites.service';

@Controller('catalog/favorites')
@UseGuards(JwtAuthGuard)
export class FavoritesController {
    constructor(private readonly favoritesService: FavoritesService) {}

    @Get()
    list(@CurrentUser() user: { id: string }) {
        return this.favoritesService.list(user.id);
    }

    @Put(':productId')
    add(@CurrentUser() user: { id: string }, @Param('productId') productId: string) {
        return this.favoritesService.add(user.id, productId);
    }

    @Delete(':productId')
    remove(@CurrentUser() user: { id: string }, @Param('productId') productId: string) {
        return this.favoritesService.remove(user.id, productId);
    }
}
