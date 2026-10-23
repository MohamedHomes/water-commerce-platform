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
    register(@Body() dto: RegisterCustomerDto) {
        return this.authService.register(dto);
    }

    @Post('login')
    login(@Body() dto: LoginCustomerDto) {
        return this.authService.login(dto);
    }

    @Post('refresh')
    refresh(@Body() dto: RefreshTokenDto) {
        return this.authService.refresh(dto.refreshToken);
    }

    @Post('logout')
    @UseGuards(JwtAuthGuard)
    logout(@CurrentUser() user: { id: string }) {
        return this.authService.logout(user.id);
    }

    @Get('profile')
    @UseGuards(JwtAuthGuard)
    getProfile(@CurrentUser() user: { id: string }) {
        return this.authService.getProfile(user.id);
    }

    @Patch('profile')
    @UseGuards(JwtAuthGuard)
    updateProfile(
        @CurrentUser() user: { id: string },
        @Body() dto: UpdateCustomerProfileDto,
    ) {
        return this.authService.updateProfile(user.id, dto);
    }
}
