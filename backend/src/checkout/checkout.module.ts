import { Module } from '@nestjs/common';
import { AddressModule } from '../address/address.module';
import { CartModule } from '../cart/cart.module';
import { CheckoutController } from './checkout.controller';
import { CheckoutService } from './checkout.service';

@Module({
    imports: [CartModule, AddressModule],
    controllers: [CheckoutController],
    providers: [CheckoutService],
})
export class CheckoutModule { }
