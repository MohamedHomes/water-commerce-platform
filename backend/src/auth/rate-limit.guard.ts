import {
    CanActivate,
    ExecutionContext,
    HttpException,
    HttpStatus,
    Injectable,
    Logger,
    SetMetadata,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { RateLimitPolicy, RateLimitService } from './rate-limit.service';

const RATE_LIMIT_POLICY = 'rate-limit-policy';

export const RateLimit = (policy: RateLimitPolicy) => SetMetadata(RATE_LIMIT_POLICY, policy);

interface RateLimitRequest {
    ip?: string;
    socket?: { remoteAddress?: string };
    body?: Record<string, unknown>;
}

interface RateLimitResponse {
    setHeader(name: string, value: string): void;
}

@Injectable()
export class RateLimitGuard implements CanActivate {
    private readonly logger = new Logger(RateLimitGuard.name);

    constructor(
        private readonly reflector: Reflector,
        private readonly rateLimitService: RateLimitService,
    ) {}

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
            this.reject(responseFor(context), policy.scope, decision.retryAfterSeconds);
        }

        if (policy.identityField) {
            const identity = request.body?.[policy.identityField];
            if (typeof identity === 'string' && identity.trim().length > 0) {
                const identityDecision = await this.rateLimitService.consume(
                    {
                        scope: `${policy.scope}-identity`,
                        maxRequests: policy.identityMaxRequests ?? policy.maxRequests,
                        windowSeconds: policy.windowSeconds,
                    },
                    `${clientAddress}\0${identity.trim().toLowerCase()}`,
                );
                if (!identityDecision.allowed) {
                    this.reject(responseFor(context), `${policy.scope}-identity`, identityDecision.retryAfterSeconds);
                }
            }
        }
        return true;
    }

    private reject(response: RateLimitResponse, scope: string, retryAfterSeconds: number): never {
        this.logger.warn(`Rate limit exceeded for ${scope}; retry after ${retryAfterSeconds}s`);
        response.setHeader('Retry-After', String(retryAfterSeconds));
        throw new HttpException('Too many requests', HttpStatus.TOO_MANY_REQUESTS);
    }
}

function responseFor(context: ExecutionContext): RateLimitResponse {
    return context.switchToHttp().getResponse<RateLimitResponse>();
}
