import {
    CanActivate,
    ExecutionContext,
    ForbiddenException,
    Injectable,
} from '@nestjs/common';
import { DatabaseService } from '../database/database.service';

@Injectable()
export class AdminRoleGuard implements CanActivate {
    constructor(private readonly database: DatabaseService) { }

    async canActivate(context: ExecutionContext): Promise<boolean> {
        const request = context.switchToHttp().getRequest<{ user?: { id?: string } }>();
        const customerId = request.user?.id;
        if (!customerId) {
            throw new ForbiddenException('Administrator access required');
        }
        const result = await this.database.query<{ role: string }>(
            'SELECT role FROM customers WHERE id = $1',
            [customerId],
        );
        if (result.rows[0]?.role !== 'admin') {
            throw new ForbiddenException('Administrator access required');
        }
        return true;
    }
}
