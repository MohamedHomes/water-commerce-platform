import {
    CanActivate,
    ExecutionContext,
    Injectable,
    UnauthorizedException,
} from '@nestjs/common';
import jwt from 'jsonwebtoken';
import { DatabaseService } from '../database/database.service';
import { JWT_SECRET } from './auth.constants';

@Injectable()
export class JwtAuthGuard implements CanActivate {
    constructor(private readonly database: DatabaseService) {}

    async canActivate(context: ExecutionContext): Promise<boolean> {
        const request = context.switchToHttp().getRequest();
        const authorization = request.headers.authorization;

        if (!authorization || !authorization.startsWith('Bearer ')) {
            throw new UnauthorizedException('Missing bearer token');
        }

        const token = authorization.replace('Bearer ', '').trim();

        let payload: {
            sub: string;
            email?: string;
            role?: string;
            type?: string;
            authVersion?: number;
        };
        try {
            payload = jwt.verify(token, JWT_SECRET) as typeof payload;

            if (payload.type === 'refresh') {
                throw new UnauthorizedException('Refresh token is not valid for this route');
            }
        } catch {
            throw new UnauthorizedException('Invalid or expired token');
        }

        const result = await this.database.query<{ auth_version: number }>(
            'SELECT auth_version FROM customers WHERE id = $1',
            [payload.sub],
        );
        if (
            !result.rows[0]
            || (payload.authVersion ?? 0) !== result.rows[0].auth_version
        ) {
            throw new UnauthorizedException('Session has been revoked');
        }

        request.user = {
            id: payload.sub,
            email: payload.email,
            role: payload.role ?? 'customer',
        };
        return true;
    }
}
