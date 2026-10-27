import { Module } from '@nestjs/common';
import { CatalogController } from './catalog.controller';
import { CatalogService } from './catalog.service';
import { ProductReviewsController } from './product-reviews.controller';
import { ProductReviewsService } from './product-reviews.service';
import { FavoritesController } from './favorites.controller';
import { FavoritesService } from './favorites.service';

@Module({
    controllers: [CatalogController, ProductReviewsController, FavoritesController],
    providers: [CatalogService, ProductReviewsService, FavoritesService],
    exports: [CatalogService, ProductReviewsService],
})
export class CatalogModule {}
