import { Module } from '@nestjs/common';
import { AdminController } from './admin.controller';
import { AdminRoleGuard } from './admin-role.guard';
import { AdminService } from './admin.service';

@Module({
    controllers: [AdminController],
    providers: [AdminRoleGuard, AdminService],
})
export class AdminModule { }
