import { createHmac, timingSafeEqual } from 'crypto';
import { Injectable } from '@nestjs/common';

export const PAYMENT_PROVIDER = 'PAYMENT_PROVIDER';

export interface CreateProviderIntent {
    paymentId: string;
    orderId: string;
    customerId: string;
    amount: number;
    currency: string;
    idempotencyKey: string;
}

export interface ProviderIntent {
    providerPaymentId: string;
    checkoutUrl: string | null;
}

export interface VerifiedPaymentEvent {
    eventId: string;
    paymentId: string;
    type: 'payment.succeeded' | 'payment.failed';
    amount: number;
    currency: string;
}

export interface PaymentProvider {
    readonly name: string;
    readonly configured: boolean;
    createIntent(input: CreateProviderIntent): Promise<ProviderIntent>;
    verifyWebhook(rawBody: Buffer, signature: string): VerifiedPaymentEvent;
}

export function signPaymentWebhook(rawBody: Buffer, secret: string): string {
    return createHmac('sha256', secret).update(rawBody).digest('hex');
}

export function safeCompareHexSignatures(expected: string, supplied: string): boolean {
    if (!/^[a-f0-9]{64}$/i.test(supplied) || !/^[a-f0-9]{64}$/i.test(expected)) {
        return false;
    }
    const expectedBytes = Buffer.from(expected, 'hex');
    const suppliedBytes = Buffer.from(supplied, 'hex');
    return expectedBytes.length === suppliedBytes.length
        && timingSafeEqual(expectedBytes, suppliedBytes);
}

@Injectable()
export class UnconfiguredPaymentProvider implements PaymentProvider {
    readonly name = 'unconfigured';
    readonly configured = false;

    async createIntent(): Promise<ProviderIntent> {
        throw new Error('Payment provider is not configured');
    }

    verifyWebhook(): VerifiedPaymentEvent {
        throw new Error('Payment provider webhook verification is not configured');
    }
}

@Injectable()
export class TestPaymentProvider implements PaymentProvider {
    readonly name = 'test';
    readonly configured = true;

    constructor(private readonly webhookSecret = 'test-only-payment-webhook-secret') { }

    async createIntent(input: CreateProviderIntent): Promise<ProviderIntent> {
        return {
            providerPaymentId: `test-${input.paymentId}`,
            checkoutUrl: null,
        };
    }

    verifyWebhook(rawBody: Buffer, signature: string): VerifiedPaymentEvent {
        const expected = signPaymentWebhook(rawBody, this.webhookSecret);
        if (!safeCompareHexSignatures(expected, signature)) {
            throw new Error('Invalid payment webhook signature');
        }

        let payload: unknown;
        try {
            payload = JSON.parse(rawBody.toString('utf8'));
        } catch {
            throw new Error('Invalid payment webhook JSON');
        }
        if (!payload || typeof payload !== 'object') {
            throw new Error('Invalid payment webhook payload');
        }
        const event = payload as Record<string, unknown>;
        if (
            typeof event.eventId !== 'string'
            || typeof event.paymentId !== 'string'
            || (event.type !== 'payment.succeeded' && event.type !== 'payment.failed')
            || typeof event.amount !== 'number'
            || !Number.isFinite(event.amount)
            || event.amount < 0
            || typeof event.currency !== 'string'
        ) {
            throw new Error('Invalid payment webhook event');
        }
        return {
            eventId: event.eventId,
            paymentId: event.paymentId,
            type: event.type,
            amount: event.amount,
            currency: event.currency,
        };
    }
}
