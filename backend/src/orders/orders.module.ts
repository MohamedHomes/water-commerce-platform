import { Module } from '@nestjs/common';
import { AddressModule } from '../address/address.module';
import { CartModule } from '../cart/cart.module';
import { DeliveryModule } from '../delivery/delivery.module';
import { NotificationsModule } from '../notifications/notifications.module';
import { OrdersController } from './orders.controller';
import { OrdersService } from './orders.service';

@Module({
    imports: [AddressModule, CartModule, DeliveryModule, NotificationsModule],
    controllers: [OrdersController],
    providers: [OrdersService],
})
export class OrdersModule { }
