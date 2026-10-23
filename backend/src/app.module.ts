import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { DatabaseModule } from './database/database.module';
import { DeliveryModule } from './delivery/delivery.module';
import { AddressModule } from './address/address.module';
import { AppController } from './app.controller';
import { AppService } from './app.service';
import { AuthModule } from './auth/auth.module';
import { CartModule } from './cart/cart.module';
import { CatalogModule } from './catalog/catalog.module';
import { CheckoutModule } from './checkout/checkout.module';
import { HealthController } from './health.controller';
import { OrdersModule } from './orders/orders.module';
import { PaymentsModule } from './payments/payments.module';
import { NotificationsModule } from './notifications/notifications.module';
import { SearchModule } from './search/search.module';
import { AdminModule } from './admin/admin.module';

@Module({
    imports: [ConfigModule.forRoot({ isGlobal: true }), DatabaseModule, AuthModule, CatalogModule, SearchModule, CartModule, AddressModule, CheckoutModule, OrdersModule, PaymentsModule, DeliveryModule, NotificationsModule, AdminModule],
    controllers: [AppController, HealthController],
    providers: [AppService],
})
export class AppModule { }
