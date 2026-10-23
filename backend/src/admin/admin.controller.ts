import {
    Body,
    Controller,
    Get,
    Param,
    ParseUUIDPipe,
    Patch,
    Post,
    Query,
    UseGuards,
} from '@nestjs/common';
import { CurrentUser } from '../auth/current-user.decorator';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { AdminRoleGuard } from './admin-role.guard';
import {
    AdjustInventoryDto,
    AdminOrdersQuery,
    AdminService,
    CreatePromotionDto,
    DeliveryStatusUpdateDto,
    ModerateReviewDto,
    SetPromotionActiveDto,
    UpdateProductOperationsDto,
} from './admin.service';

@Controller('admin')
@UseGuards(JwtAuthGuard, AdminRoleGuard)
export class AdminController {
    constructor(private readonly adminService: AdminService) { }

    @Get('dashboard')
    getDashboard() {
        return this.adminService.getDashboard();
    }

    @Get('orders')
    getOrders(@Query() query: AdminOrdersQuery) {
        return this.adminService.getOrders(query);
    }

    @Get('promotions')
    getPromotions() {
        return this.adminService.getPromotions();
    }

    @Get('inventory')
    getInventory() {
        return this.adminService.getInventory();
    }

    @Post('inventory/:productId/adjustments')
    adjustInventory(
        @CurrentUser() user: { id: string },
        @Param('productId') productId: string,
        @Body() dto: AdjustInventoryDto,
    ) {
        return this.adminService.adjustInventory(user.id, productId, dto);
    }

    @Get('deliveries')
    getDeliveries() {
        return this.adminService.getDeliveries();
    }

    @Patch('deliveries/:id/status')
    setDeliveryStatus(
        @CurrentUser() user: { id: string },
        @Param('id', ParseUUIDPipe) id: string,
        @Body() dto: DeliveryStatusUpdateDto,
    ) {
        return this.adminService.setDeliveryStatus(user.id, id, dto);
    }

    @Get('reviews')
    getPendingReviews() {
        return this.adminService.getPendingReviews();
    }

    @Patch('reviews/:id/status')
    moderateReview(
        @CurrentUser() user: { id: string },
        @Param('id', ParseUUIDPipe) id: string,
        @Body() dto: ModerateReviewDto,
    ) {
        return this.adminService.moderateReview(user.id, id, dto);
    }

    @Get('products')
    getProducts() {
        return this.adminService.getProducts();
    }

    @Patch('products/:id')
    updateProduct(
        @CurrentUser() user: { id: string },
        @Param('id') id: string,
        @Body() dto: UpdateProductOperationsDto,
    ) {
        return this.adminService.updateProduct(user.id, id, dto);
    }

    @Post('promotions')
    createPromotion(
        @CurrentUser() user: { id: string },
        @Body() dto: CreatePromotionDto,
    ) {
        return this.adminService.createPromotion(user.id, dto);
    }

    @Patch('promotions/:id/active')
    setPromotionActive(
        @CurrentUser() user: { id: string },
        @Param('id', ParseUUIDPipe) id: string,
        @Body() dto: SetPromotionActiveDto,
    ) {
        return this.adminService.setPromotionActive(user.id, id, dto);
    }
}
