import {
    BadRequestException,
    Injectable,
    NotFoundException,
} from '@nestjs/common';
import { Transform } from 'class-transformer';
import {
    IsBoolean,
    IsNotEmpty,
    IsNumber,
    Max,
    Min,
    IsOptional,
    IsString,
    Matches,
} from 'class-validator';
import { QueryResultRow } from 'pg';
import { DatabaseService, QueryExecutor } from '../database/database.service';

export interface AddressRecord {
    id: string;
    customerId: string;
    label: string;
    recipientName: string;
    phone: string;
    city: string;
    district: string;
    street: string;
    building: string;
    apartment?: string;
    floor?: string;
    latitude?: number;
    longitude?: number;
    notes?: string;
    isDefault: boolean;
    createdAt: string;
    updatedAt: string;
}

export interface CityRecord {
    id: string;
    name: string;
    countryCode: string;
    region: string;
}

export interface DeliveryZoneRecord {
    id: string;
    city: string;
    name: string;
    baseFee: number;
    expressFee?: number;
    estimatedMinutes: number;
    isActive: boolean;
}

interface AddressRow extends QueryResultRow {
    id: string;
    customer_id: string;
    label: string;
    recipient_name: string;
    phone: string;
    city: string;
    district: string;
    street: string;
    building: string;
    apartment: string | null;
    floor: string | null;
    latitude: string | number | null;
    longitude: string | number | null;
    notes: string | null;
    is_default: boolean;
    created_at: Date | string;
    updated_at: Date | string;
}

interface CityRow extends QueryResultRow {
    id: string;
    name: string;
    country_code: string;
    region: string;
}

interface DeliveryZoneRow extends QueryResultRow {
    id: string;
    city: string;
    name: string;
    base_fee: string | number;
    express_fee: string | number;
    estimated_minutes: number;
    is_active: boolean;
}

export class CreateAddressDto {
    @Transform(({ value }) => (typeof value === 'string' ? value.trim() : value))
    @IsString()
    @IsNotEmpty()
    label!: string;

    @Transform(({ value }) => (typeof value === 'string' ? value.trim() : value))
    @IsString()
    @IsNotEmpty()
    recipientName!: string;

    @Transform(({ value }) => (typeof value === 'string' ? value.trim() : value))
    @IsString()
    @IsNotEmpty()
    @Matches(/^[+0-9\s-]{7,20}$/)
    phone!: string;

    @Transform(({ value }) => (typeof value === 'string' ? value.trim() : value))
    @IsString()
    @IsNotEmpty()
    city!: string;

    @Transform(({ value }) => (typeof value === 'string' ? value.trim() : value))
    @IsString()
    @IsNotEmpty()
    district!: string;

    @Transform(({ value }) => (typeof value === 'string' ? value.trim() : value))
    @IsString()
    @IsNotEmpty()
    street!: string;

    @Transform(({ value }) => (typeof value === 'string' ? value.trim() : value))
    @IsString()
    @IsNotEmpty()
    building!: string;

    @Transform(({ value }) => (typeof value === 'string' ? value.trim() : value))
    @IsOptional()
    @IsString()
    apartment?: string;

    @Transform(({ value }) => (typeof value === 'string' ? value.trim() : value))
    @IsOptional()
    @IsString()
    floor?: string;

    @IsOptional()
    @IsNumber()
    @Min(-90)
    @Max(90)
    latitude?: number;

    @IsOptional()
    @IsNumber()
    @Min(-180)
    @Max(180)
    longitude?: number;

    @Transform(({ value }) => (typeof value === 'string' ? value.trim() : value))
    @IsOptional()
    @IsString()
    notes?: string;

    @IsOptional()
    @IsBoolean()
    isDefault?: boolean;
}

export class UpdateAddressDto {
    @Transform(({ value }) => (typeof value === 'string' ? value.trim() : value))
    @IsOptional()
    @IsString()
    @IsNotEmpty()
    label?: string;

    @Transform(({ value }) => (typeof value === 'string' ? value.trim() : value))
    @IsOptional()
    @IsString()
    @IsNotEmpty()
    recipientName?: string;

    @Transform(({ value }) => (typeof value === 'string' ? value.trim() : value))
    @IsOptional()
    @IsString()
    @Matches(/^[+0-9\s-]{7,20}$/)
    phone?: string;

    @Transform(({ value }) => (typeof value === 'string' ? value.trim() : value))
    @IsOptional()
    @IsString()
    @IsNotEmpty()
    city?: string;

    @Transform(({ value }) => (typeof value === 'string' ? value.trim() : value))
    @IsOptional()
    @IsString()
    @IsNotEmpty()
    district?: string;

    @Transform(({ value }) => (typeof value === 'string' ? value.trim() : value))
    @IsOptional()
    @IsString()
    @IsNotEmpty()
    street?: string;

    @Transform(({ value }) => (typeof value === 'string' ? value.trim() : value))
    @IsOptional()
    @IsString()
    @IsNotEmpty()
    building?: string;

    @Transform(({ value }) => (typeof value === 'string' ? value.trim() : value))
    @IsOptional()
    @IsString()
    apartment?: string;

    @Transform(({ value }) => (typeof value === 'string' ? value.trim() : value))
    @IsOptional()
    @IsString()
    floor?: string;

    @IsOptional()
    @IsNumber()
    @Min(-90)
    @Max(90)
    latitude?: number;

    @IsOptional()
    @IsNumber()
    @Min(-180)
    @Max(180)
    longitude?: number;

    @Transform(({ value }) => (typeof value === 'string' ? value.trim() : value))
    @IsOptional()
    @IsString()
    notes?: string;

    @IsOptional()
    @IsBoolean()
    isDefault?: boolean;
}

@Injectable()
export class AddressService {
    constructor(private readonly database: DatabaseService) { }

    async getCities() {
        const result = await this.database.query<CityRow>(
            `
                SELECT id, name, country_code, region
                FROM cities
                WHERE is_active = TRUE
                ORDER BY CASE id WHEN 'city-riyadh' THEN 1 WHEN 'city-jeddah' THEN 2 ELSE 3 END, name
            `,
        );
        return {
            items: result.rows.map((row) => this.toCity(row)),
            total: result.rowCount ?? result.rows.length,
        };
    }

    async getDeliveryZones(city?: string) {
        const result = await this.database.query<DeliveryZoneRow>(
            `
                SELECT z.id, c.name AS city, z.name, z.base_fee, z.express_fee,
                    z.estimated_minutes, z.is_active
                FROM delivery_zones z
                JOIN cities c ON c.id = z.city_id
                WHERE z.is_active = TRUE AND c.is_active = TRUE
                  AND ($1::text IS NULL OR LOWER(c.name) = LOWER($1))
                ORDER BY CASE c.id WHEN 'city-riyadh' THEN 1 WHEN 'city-jeddah' THEN 2 ELSE 3 END,
                    z.name, z.id
            `,
            [city?.trim() || null],
        );
        return {
            items: result.rows.map((row) => this.toDeliveryZone(row)),
            total: result.rowCount ?? result.rows.length,
        };
    }

    async getAddresses(userId: string) {
        const result = await this.database.query<AddressRow>(
            `
                SELECT id, customer_id, label, recipient_name, phone, city, district,
                    street, building, apartment, floor, latitude, longitude, notes,
                    is_default, created_at, updated_at
                FROM customer_addresses
                WHERE customer_id = $1
                ORDER BY is_default DESC, created_at, id
            `,
            [userId],
        );
        return {
            items: result.rows.map((row) => this.toAddress(row)),
            total: result.rows.length,
        };
    }

    async getAddressById(userId: string, addressId: string, executor: QueryExecutor = this.database) {
        const result = await executor.query<AddressRow>(
            `
                SELECT id, customer_id, label, recipient_name, phone, city, district,
                    street, building, apartment, floor, latitude, longitude, notes,
                    is_default, created_at, updated_at
                FROM customer_addresses
                WHERE customer_id = $1 AND id = $2
            `,
            [userId, addressId],
        );
        if (!result.rows[0]) {
            throw new NotFoundException('Address not found');
        }
        return this.toAddress(result.rows[0]);
    }

    async createAddress(userId: string, dto: CreateAddressDto) {
        const phone = dto.phone?.trim();
        if (!phone || !/^[+0-9\s-]{7,20}$/.test(phone)) {
            throw new BadRequestException('A valid phone number is required');
        }
        if ((dto.latitude === undefined) !== (dto.longitude === undefined)) {
            throw new BadRequestException('Latitude and longitude must be provided together');
        }

        return this.database.withTransaction(async (client) => {
            await client.query('SELECT id FROM customers WHERE id = $1 FOR UPDATE', [userId]);
            const city = await this.findCity(dto.city, client);
            const count = await client.query<{ count: string }>(
                'SELECT COUNT(*)::text AS count FROM customer_addresses WHERE customer_id = $1',
                [userId],
            );
            const isDefault = dto.isDefault ?? Number(count.rows[0].count) === 0;
            if (isDefault) {
                await client.query(
                    'UPDATE customer_addresses SET is_default = FALSE WHERE customer_id = $1',
                    [userId],
                );
            }

            const result = await client.query<AddressRow>(
                `
                    INSERT INTO customer_addresses (
                        customer_id, city_id, label, recipient_name, phone, city,
                        district, street, building, apartment, floor, latitude,
                        longitude, notes, is_default
                    ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15)
                    RETURNING id, customer_id, label, recipient_name, phone, city, district,
                        street, building, apartment, floor, latitude, longitude, notes,
                        is_default, created_at, updated_at
                `,
                [
                    userId, city.id, dto.label.trim(), dto.recipientName.trim(), phone,
                    city.name, dto.district.trim(), dto.street.trim(), dto.building.trim(),
                    dto.apartment?.trim() ?? null, dto.floor?.trim() ?? null,
                    dto.latitude ?? null, dto.longitude ?? null, dto.notes?.trim() ?? null,
                    isDefault,
                ],
            );
            return this.toAddress(result.rows[0]);
        });
    }

    async updateAddress(userId: string, addressId: string, dto: UpdateAddressDto) {
        return this.database.withTransaction(async (client) => {
            await client.query('SELECT id FROM customers WHERE id = $1 FOR UPDATE', [userId]);
            const current = await this.getAddressById(userId, addressId, client);
            const phone = dto.phone?.trim() ?? current.phone;
            if (!/^[+0-9\s-]{7,20}$/.test(phone)) {
                throw new BadRequestException('A valid phone number is required');
            }
            const cityName = dto.city?.trim() ?? current.city;
            const city = await this.findCity(cityName, client);
            const latitude = dto.latitude ?? current.latitude;
            const longitude = dto.longitude ?? current.longitude;
            if ((latitude === undefined) !== (longitude === undefined)) {
                throw new BadRequestException('Latitude and longitude must be provided together');
            }
            if (dto.isDefault === true) {
                await client.query(
                    'UPDATE customer_addresses SET is_default = FALSE WHERE customer_id = $1',
                    [userId],
                );
            }

            const result = await client.query<AddressRow>(
                `
                    UPDATE customer_addresses
                    SET city_id = $3, label = $4, recipient_name = $5, phone = $6,
                        city = $7, district = $8, street = $9, building = $10,
                        apartment = $11, floor = $12, latitude = $13, longitude = $14,
                        notes = $15, is_default = CASE WHEN $16 THEN TRUE ELSE is_default END,
                        updated_at = NOW()
                    WHERE customer_id = $1 AND id = $2
                    RETURNING id, customer_id, label, recipient_name, phone, city, district,
                        street, building, apartment, floor, latitude, longitude, notes,
                        is_default, created_at, updated_at
                `,
                [
                    userId, addressId, city.id, dto.label?.trim() ?? current.label,
                    dto.recipientName?.trim() ?? current.recipientName, phone, city.name,
                    dto.district?.trim() ?? current.district, dto.street?.trim() ?? current.street,
                    dto.building?.trim() ?? current.building, dto.apartment?.trim() ?? current.apartment ?? null,
                    dto.floor?.trim() ?? current.floor ?? null, latitude ?? null, longitude ?? null,
                    dto.notes?.trim() ?? current.notes ?? null, dto.isDefault === true,
                ],
            );
            return this.toAddress(result.rows[0]);
        });
    }

    async setDefaultAddress(userId: string, addressId: string) {
        return this.database.withTransaction(async (client) => {
            await client.query('SELECT id FROM customers WHERE id = $1 FOR UPDATE', [userId]);
            await this.getAddressById(userId, addressId, client);
            const result = await client.query<AddressRow>(
                `
                    UPDATE customer_addresses
                    SET is_default = (id = $2), updated_at = NOW()
                    WHERE customer_id = $1
                    RETURNING id, customer_id, label, recipient_name, phone, city, district,
                        street, building, apartment, floor, latitude, longitude, notes,
                        is_default, created_at, updated_at
                `,
                [userId, addressId],
            );
            const updated = result.rows.find((row) => row.id === addressId);
            if (!updated) {
                throw new NotFoundException('Address not found');
            }
            return this.toAddress(updated);
        });
    }

    async deleteAddress(userId: string, addressId: string) {
        return this.database.withTransaction(async (client) => {
            await client.query('SELECT id FROM customers WHERE id = $1 FOR UPDATE', [userId]);
            const address = await this.getAddressById(userId, addressId, client);
            await client.query(
                'DELETE FROM customer_addresses WHERE customer_id = $1 AND id = $2',
                [userId, addressId],
            );
            if (address.isDefault) {
                await client.query(
                    `
                        UPDATE customer_addresses
                        SET is_default = TRUE, updated_at = NOW()
                        WHERE id = (
                            SELECT id FROM customer_addresses
                            WHERE customer_id = $1
                            ORDER BY created_at, id LIMIT 1
                        )
                    `,
                    [userId],
                );
            }
            return { success: true, deletedId: addressId };
        });
    }

    async resolveDeliveryZone(city: string, zoneId?: string, executor: QueryExecutor = this.database) {
        const result = await executor.query<DeliveryZoneRow>(
            `
                SELECT z.id, c.name AS city, z.name, z.base_fee, z.express_fee,
                    z.estimated_minutes, z.is_active
                FROM delivery_zones z
                JOIN cities c ON c.id = z.city_id
                WHERE LOWER(c.name) = LOWER($1)
                  AND c.is_active = TRUE AND z.is_active = TRUE
                  AND ($2::text IS NULL OR z.id = $2)
                ORDER BY z.name, z.id
                LIMIT 1
            `,
            [city.trim(), zoneId ?? null],
        );
        if (!result.rows[0]) {
            throw new BadRequestException(`No active delivery zone is available for ${city}`);
        }
        return this.toDeliveryZone(result.rows[0]);
    }

    private async findCity(cityName: string, executor: QueryExecutor) {
        const result = await executor.query<CityRow>(
            `
                SELECT id, name, country_code, region
                FROM cities
                WHERE LOWER(name) = LOWER($1) AND is_active = TRUE
                LIMIT 1
            `,
            [cityName.trim()],
        );
        if (!result.rows[0]) {
            throw new BadRequestException('City is not configured for delivery');
        }
        return this.toCity(result.rows[0]);
    }

    private toCity(row: CityRow): CityRecord {
        return {
            id: row.id,
            name: row.name,
            countryCode: row.country_code,
            region: row.region,
        };
    }

    private toDeliveryZone(row: DeliveryZoneRow): DeliveryZoneRecord {
        return {
            id: row.id,
            city: row.city,
            name: row.name,
            baseFee: Number(row.base_fee),
            expressFee: Number(row.express_fee),
            estimatedMinutes: row.estimated_minutes,
            isActive: row.is_active,
        };
    }

    private toAddress(row: AddressRow): AddressRecord {
        return {
            id: row.id,
            customerId: row.customer_id,
            label: row.label,
            recipientName: row.recipient_name,
            phone: row.phone,
            city: row.city,
            district: row.district,
            street: row.street,
            building: row.building,
            apartment: row.apartment ?? undefined,
            floor: row.floor ?? undefined,
            latitude: row.latitude === null ? undefined : Number(row.latitude),
            longitude: row.longitude === null ? undefined : Number(row.longitude),
            notes: row.notes ?? undefined,
            isDefault: row.is_default,
            createdAt: new Date(row.created_at).toISOString(),
            updatedAt: new Date(row.updated_at).toISOString(),
        };
    }
}
