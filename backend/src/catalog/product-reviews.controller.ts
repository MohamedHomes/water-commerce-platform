import {
    Body,
    Controller,
    Get,
    Param,
    Post,
    UseGuards,
} from '@nestjs/common';
import { CurrentUser } from '../auth/current-user.decorator';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CreateProductReviewDto, ProductReviewsService } from './product-reviews.service';

@Controller('catalog/products/:productId/reviews')
export class ProductReviewsController {
    constructor(private readonly reviewsService: ProductReviewsService) { }

    @Get()
    getProductReviews(@Param('productId') productId: string) {
        return this.reviewsService.getProductReviews(productId);
    }

    @Post()
    @UseGuards(JwtAuthGuard)
    createReview(
        @CurrentUser() user: { id: string },
        @Param('productId') productId: string,
        @Body() dto: CreateProductReviewDto,
    ) {
        return this.reviewsService.createReview(user.id, productId, dto);
    }
}
