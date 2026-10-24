import {
    Body,
    Controller,
    Get,
    Patch,
    Post,
    Req,
    UseGuards,
} from '@nestjs/common';
import { CurrentUser } from './current-user.decorator';
import { JwtAuthGuard } from './jwt-auth.guard';
import { RateLimit, RateLimitGuard } from './rate-limit.guard';
import {
    AuthService,
    LoginCustomerDto,
    RefreshTokenDto,
    RegisterCustomerDto,
    UpdateCustomerProfileDto,
} from './auth.service';

@Controller('auth')
export class AuthController {
    constructor(private readonly authService: AuthService) { }

    @Post('register')
    @RateLimit({ scope: 'auth-register', maxRequests: 20, windowSeconds: 900 })
    @UseGuards(RateLimitGuard)
    register(@Body() dto: RegisterCustomerDto) {
        return this.authService.register(dto);
    }

    @Post('login')
    @RateLimit({ scope: 'auth-login', maxRequests: 10, windowSeconds: 900 })
    @UseGuards(RateLimitGuard)
    login(@Body() dto: LoginCustomerDto) {
        return this.authService.login(dto);
    }

    @Post('refresh')
    @RateLimit({ scope: 'auth-refresh', maxRequests: 30, windowSeconds: 900 })
    @UseGuards(RateLimitGuard)
    refresh(@Body() dto: RefreshTokenDto) {
        return this.authService.refresh(dto.refreshToken);
    }

    @Post('logout')
    @RateLimit({ scope: 'auth-logout', maxRequests: 30, windowSeconds: 900 })
    @UseGuards(JwtAuthGuard, RateLimitGuard)
    logout(@CurrentUser() user: { id: string }) {
        return this.authService.logout(user.id);
    }

    @Get('profile')
    @UseGuards(JwtAuthGuard)
    getProfile(@CurrentUser() user: { id: string }) {
        return this.authService.getProfile(user.id);
    }

    @Patch('profile')
    @RateLimit({ scope: 'auth-profile-update', maxRequests: 10, windowSeconds: 900 })
    @UseGuards(JwtAuthGuard, RateLimitGuard)
    updateProfile(
        @CurrentUser() user: { id: string },
        @Body() dto: UpdateCustomerProfileDto,
    ) {
        return this.authService.updateProfile(user.id, dto);
    }
}
