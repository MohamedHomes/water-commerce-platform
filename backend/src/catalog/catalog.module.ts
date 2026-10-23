import { Module } from '@nestjs/common';
import { CatalogController } from './catalog.controller';
import { CatalogService } from './catalog.service';
import { ProductReviewsController } from './product-reviews.controller';
import { ProductReviewsService } from './product-reviews.service';

@Module({
    controllers: [CatalogController, ProductReviewsController],
    providers: [CatalogService, ProductReviewsService],
    exports: [CatalogService, ProductReviewsService],
})
export class CatalogModule { }
