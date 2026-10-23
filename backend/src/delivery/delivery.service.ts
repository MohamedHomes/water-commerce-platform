import { Injectable, NotFoundException } from '@nestjs/common';
import { randomBytes } from 'crypto';
import { QueryResultRow } from 'pg';
import { DatabaseService, QueryExecutor } from '../database/database.service';

interface DeliveryRow extends QueryResultRow {
    id: string;
    order_id: string;
    customer_id: string;
    status: string;
    estimated_minutes: number;
    tracking_code: string;
    created_at: Date | string;
    updated_at: Date | string;
    delivered_at: Date | string | null;
}

interface DeliveryEventRow extends QueryResultRow {
    status: string;
    note: string;
    created_at: Date | string;
}

@Injectable()
export class DeliveryService {
    constructor(private readonly database: DatabaseService) { }

    async createForOrder(
        executor: QueryExecutor,
        order: {
            id: string;
            customerId: string;
            estimatedMinutes: number;
        },
    ) {
        const result = await executor.query<DeliveryRow>(
            `
                INSERT INTO deliveries (
                    order_id, customer_id, estimated_minutes, tracking_code
                ) VALUES ($1, $2, $3, $4)
                ON CONFLICT (order_id) DO NOTHING
                RETURNING *
            `,
            [
                order.id,
                order.customerId,
                order.estimatedMinutes,
                randomBytes(12).toString('hex').toUpperCase(),
            ],
        );
        if (!result.rows[0]) {
            return;
        }
        await executor.query(
            `
                INSERT INTO delivery_events (delivery_id, status, note)
                VALUES ($1, 'pending_dispatch', 'Order is ready for delivery dispatch')
            `,
            [result.rows[0].id],
        );
    }

    async cancelForOrder(executor: QueryExecutor, orderId: string) {
        const result = await executor.query<{ id: string }>(
            `
                UPDATE deliveries
                SET status = 'cancelled', updated_at = NOW()
                WHERE order_id = $1 AND status = 'pending_dispatch'
                RETURNING id
            `,
            [orderId],
        );
        if (result.rows[0]) {
            await executor.query(
                `
                    INSERT INTO delivery_events (delivery_id, status, note)
                    VALUES ($1, 'cancelled', 'Order was cancelled before dispatch')
                `,
                [result.rows[0].id],
            );
        }
    }

    async getCustomerDelivery(customerId: string, orderId: string) {
        const result = await this.database.query<DeliveryRow>(
            'SELECT * FROM deliveries WHERE customer_id = $1 AND order_id = $2',
            [customerId, orderId],
        );
        const delivery = result.rows[0];
        if (!delivery) {
            throw new NotFoundException('Delivery is not available for this order');
        }
        const events = await this.database.query<DeliveryEventRow>(
            `
                SELECT status, note, created_at
                FROM delivery_events
                WHERE delivery_id = $1
                ORDER BY created_at, id
            `,
            [delivery.id],
        );
        return {
            id: delivery.id,
            orderId: delivery.order_id,
            status: delivery.status,
            estimatedMinutes: delivery.estimated_minutes,
            trackingCode: delivery.tracking_code,
            createdAt: new Date(delivery.created_at).toISOString(),
            updatedAt: new Date(delivery.updated_at).toISOString(),
            deliveredAt: delivery.delivered_at
                ? new Date(delivery.delivered_at).toISOString()
                : undefined,
            events: events.rows.map((event) => ({
                status: event.status,
                note: event.note,
                createdAt: new Date(event.created_at).toISOString(),
            })),
            trackingAvailable: false,
        };
    }
}
