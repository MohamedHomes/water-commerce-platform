import {
    CanActivate,
    ExecutionContext,
    Injectable,
    UnauthorizedException,
} from '@nestjs/common';
import jwt from 'jsonwebtoken';
import { JWT_SECRET } from './auth.constants';

@Injectable()
export class JwtAuthGuard implements CanActivate {
    async canActivate(context: ExecutionContext): Promise<boolean> {
        const request = context.switchToHttp().getRequest();
        const authorization = request.headers.authorization;

        if (!authorization || !authorization.startsWith('Bearer ')) {
            throw new UnauthorizedException('Missing bearer token');
        }

        const token = authorization.replace('Bearer ', '').trim();

        try {
            const payload = jwt.verify(token, JWT_SECRET) as {
                sub: string;
                email?: string;
                role?: string;
                type?: string;
            };

            if (payload.type === 'refresh') {
                throw new UnauthorizedException('Refresh token is not valid for this route');
            }

            request.user = {
                id: payload.sub,
                email: payload.email,
                role: payload.role ?? 'customer',
            };

            return true;
        } catch {
            throw new UnauthorizedException('Invalid or expired token');
        }
    }
}
