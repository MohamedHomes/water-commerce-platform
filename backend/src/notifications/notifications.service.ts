import { Injectable, NotFoundException } from '@nestjs/common';
import { QueryResultRow } from 'pg';
import { DatabaseService, QueryExecutor } from '../database/database.service';

export interface CreateNotification {
    customerId: string;
    type: string;
    title: string;
    body: string;
    data?: Record<string, unknown>;
    deduplicationKey: string;
}

interface NotificationRow extends QueryResultRow {
    id: string;
    type: string;
    title: string;
    body: string;
    data: Record<string, unknown>;
    read_at: Date | string | null;
    created_at: Date | string;
}

@Injectable()
export class NotificationsService {
    constructor(private readonly database: DatabaseService) { }

    async create(executor: QueryExecutor, notification: CreateNotification) {
        await executor.query(
            `
                INSERT INTO notifications (
                    customer_id, type, title, body, data, deduplication_key
                ) VALUES ($1, $2, $3, $4, $5::jsonb, $6)
                ON CONFLICT (customer_id, deduplication_key) DO NOTHING
            `,
            [
                notification.customerId,
                notification.type,
                notification.title,
                notification.body,
                JSON.stringify(notification.data ?? {}),
                notification.deduplicationKey,
            ],
        );
    }

    async list(customerId: string, limit = 50) {
        const result = await this.database.query<NotificationRow>(
            `
                SELECT id, type, title, body, data, read_at, created_at
                FROM notifications
                WHERE customer_id = $1
                ORDER BY created_at DESC, id DESC
                LIMIT $2
            `,
            [customerId, limit],
        );
        return {
            items: result.rows.map((row) => this.toRecord(row)),
            total: result.rows.length,
        };
    }

    async markRead(customerId: string, notificationId: string) {
        const result = await this.database.query<NotificationRow>(
            `
                UPDATE notifications SET read_at = COALESCE(read_at, NOW())
                WHERE id = $1 AND customer_id = $2
                RETURNING id, type, title, body, data, read_at, created_at
            `,
            [notificationId, customerId],
        );
        if (!result.rows[0]) {
            throw new NotFoundException('Notification not found');
        }
        return this.toRecord(result.rows[0]);
    }

    private toRecord(row: NotificationRow) {
        return {
            id: row.id,
            type: row.type,
            title: row.title,
            body: row.body,
            data: row.data,
            readAt: row.read_at ? new Date(row.read_at).toISOString() : null,
            createdAt: new Date(row.created_at).toISOString(),
        };
    }
}
