import { Module } from '@nestjs/common';
import { AuthController } from './auth.controller';
import { AuthService } from './auth.service';
import { RateLimitGuard } from './rate-limit.guard';
import { RateLimitService } from './rate-limit.service';

@Module({
    controllers: [AuthController],
    providers: [AuthService, RateLimitService, RateLimitGuard],
    exports: [AuthService],
})
export class AuthModule { }
