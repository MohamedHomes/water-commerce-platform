import { Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { DatabaseModule } from '../database/database.module';
import { DeliveryModule } from '../delivery/delivery.module';
import { NotificationsModule } from '../notifications/notifications.module';
import {
    PAYMENT_PROVIDER,
    TestPaymentProvider,
    UnconfiguredPaymentProvider,
} from './payment-provider';
import { PaymentsController } from './payments.controller';
import { PaymentsService } from './payments.service';

@Module({
    imports: [DatabaseModule, DeliveryModule, NotificationsModule],
    controllers: [PaymentsController],
    providers: [
        PaymentsService,
        {
            provide: PAYMENT_PROVIDER,
            inject: [ConfigService],
            useFactory: (config: ConfigService) => config.get('NODE_ENV') === 'test'
                ? new TestPaymentProvider()
                : new UnconfiguredPaymentProvider(),
        },
    ],
})
export class PaymentsModule { }
