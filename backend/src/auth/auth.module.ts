import { Global, Module } from '@nestjs/common';
import { AuthController } from './auth.controller';
import { AuthService } from './auth.service';
import { JwtAuthGuard } from './jwt-auth.guard';
import { RateLimitGuard } from './rate-limit.guard';
import { RateLimitService } from './rate-limit.service';
import { MailService } from './mail.service';

@Global()
@Module({
    controllers: [AuthController],
    providers: [AuthService, JwtAuthGuard, RateLimitService, RateLimitGuard, MailService],
    exports: [AuthService, JwtAuthGuard],
})
export class AuthModule {}
