import {
    CanActivate,
    ExecutionContext,
    HttpException,
    HttpStatus,
    Injectable,
    SetMetadata,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { RateLimitPolicy, RateLimitService } from './rate-limit.service';

const RATE_LIMIT_POLICY = 'rate-limit-policy';

export const RateLimit = (policy: RateLimitPolicy) => SetMetadata(RATE_LIMIT_POLICY, policy);

interface RateLimitRequest {
    ip?: string;
    socket?: { remoteAddress?: string };
}

interface RateLimitResponse {
    setHeader(name: string, value: string): void;
}

@Injectable()
export class RateLimitGuard implements CanActivate {
    constructor(
        private readonly reflector: Reflector,
        private readonly rateLimitService: RateLimitService,
    ) { }

    async canActivate(context: ExecutionContext): Promise<boolean> {
        const policy = this.reflector.getAllAndOverride<RateLimitPolicy>(RATE_LIMIT_POLICY, [
            context.getHandler(),
            context.getClass(),
        ]);
        if (!policy) return true;

        const request = context.switchToHttp().getRequest<RateLimitRequest>();
        const clientAddress = request.ip ?? request.socket?.remoteAddress ?? 'unknown';
        const decision = await this.rateLimitService.consume(policy, clientAddress);
        if (!decision.allowed) {
            const response = context.switchToHttp().getResponse<RateLimitResponse>();
            response.setHeader('Retry-After', String(decision.retryAfterSeconds));
            throw new HttpException('Too many requests', HttpStatus.TOO_MANY_REQUESTS);
        }
        return true;
    }
}
