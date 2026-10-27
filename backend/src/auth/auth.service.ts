import { BadRequestException, Injectable, UnauthorizedException } from '@nestjs/common';
import { Transform } from 'class-transformer';
import { IsEmail, IsNotEmpty, IsOptional, IsString, Matches, MinLength } from 'class-validator';
import { randomUUID } from 'crypto';
import jwt from 'jsonwebtoken';
import { QueryResultRow } from 'pg';
import { DatabaseService } from '../database/database.service';
import { JWT_EXPIRES_IN, JWT_SECRET, JWT_REFRESH_SECRET, REFRESH_TOKEN_TTL } from './auth.constants';
import { hashPassword, verifyPassword } from './password-hasher';

export type CustomerRole = 'customer' | 'admin';

export interface CustomerRecord {
    id: string;
    email: string;
    passwordHash: string;
    firstName: string;
    lastName: string;
    phone: string;
    role: CustomerRole;
    createdAt: string;
    updatedAt: string;
}

interface CustomerRow extends QueryResultRow {
    id: string;
    email: string;
    password_hash: string;
    first_name: string;
    last_name: string;
    phone: string | null;
    role: CustomerRole;
    created_at: Date | string;
    updated_at: Date | string;
}

export class RegisterCustomerDto {
    @Transform(({ value }) => (typeof value === 'string' ? value.trim().toLowerCase() : value))
    @IsEmail()
    @IsNotEmpty()
    email!: string;

    @IsString()
    @MinLength(8)
    @Matches(/^(?=.*[A-Za-z])(?=.*\d)(?=.*[^A-Za-z\d]).+$/, {
        message: 'Password must include a letter, number, and symbol',
    })
    password!: string;

    @Transform(({ value }) => (typeof value === 'string' ? value.trim() : value))
    @IsString()
    @IsNotEmpty()
    firstName!: string;

    @Transform(({ value }) => (typeof value === 'string' ? value.trim() : value))
    @IsString()
    @IsNotEmpty()
    lastName!: string;

    @Transform(({ value }) => (typeof value === 'string' ? value.trim() : value))
    @IsOptional()
    @IsString()
    phone?: string;
}

export class LoginCustomerDto {
    @Transform(({ value }) => (typeof value === 'string' ? value.trim().toLowerCase() : value))
    @IsEmail()
    @IsNotEmpty()
    email!: string;

    @IsString()
    @IsNotEmpty()
    password!: string;
}

export class RefreshTokenDto {
    @IsString()
    @IsNotEmpty()
    refreshToken!: string;
}

export class UpdateCustomerProfileDto {
    @Transform(({ value }) => (typeof value === 'string' ? value.trim() : value))
    @IsOptional()
    @IsString()
    firstName?: string;

    @Transform(({ value }) => (typeof value === 'string' ? value.trim() : value))
    @IsOptional()
    @IsString()
    lastName?: string;

    @Transform(({ value }) => (typeof value === 'string' ? value.trim() : value))
    @IsOptional()
    @IsString()
    phone?: string;
}

@Injectable()
export class AuthService {
    constructor(private readonly database: DatabaseService) {}

    async register(dto: RegisterCustomerDto) {
        if (!dto.email || !dto.password || !dto.firstName || !dto.lastName) {
            throw new BadRequestException('Email, password, first name, and last name are required');
        }

        const email = dto.email.trim().toLowerCase();
        const now = new Date();
        const passwordHash = await hashPassword(dto.password);
        const id = randomUUID();
        let result;
        try {
            result = await this.database.query<CustomerRow>(
                `
                    INSERT INTO customers (
                        id, email, password_hash, first_name, last_name, phone, created_at, updated_at
                    ) VALUES ($1, $2, $3, $4, $5, $6, $7, $7)
                    RETURNING id, email, password_hash, first_name, last_name, phone, role, created_at, updated_at
                `,
                [id, email, passwordHash, dto.firstName.trim(), dto.lastName.trim(), dto.phone?.trim() ?? '', now],
            );
        } catch (error) {
            if (this.isUniqueViolation(error, 'customers_email_key')) {
                throw new BadRequestException('Customer with this email already exists');
            }
            throw error;
        }

        const customer = this.toCustomer(result.rows[0]);
        return {
            customer: this.serializeCustomer(customer),
            accessToken: this.issueAccessToken(customer),
            refreshToken: this.issueRefreshToken(customer),
        };
    }

    async login(dto: LoginCustomerDto) {
        const email = dto.email?.trim().toLowerCase();
        const result = await this.database.query<CustomerRow>(
            `
                SELECT id, email, password_hash, first_name, last_name, phone, role, created_at, updated_at
                FROM customers WHERE email = $1
            `,
            [email],
        );
        const row = result.rows[0];
        if (!row || !(await verifyPassword(dto.password, row.password_hash))) {
            throw new UnauthorizedException('Invalid email or password');
        }

        const customer = this.toCustomer(row);
        return {
            customer: this.serializeCustomer(customer),
            accessToken: this.issueAccessToken(customer),
            refreshToken: this.issueRefreshToken(customer),
        };
    }

    async refresh(refreshToken: string) {
        let payload: { sub: string; type?: string; role?: string };
        try {
            payload = jwt.verify(refreshToken, JWT_REFRESH_SECRET) as typeof payload;
        } catch {
            throw new UnauthorizedException('Invalid or expired refresh token');
        }
        if (payload.type !== 'refresh') {
            throw new UnauthorizedException('Refresh token required');
        }

        const result = await this.database.query<CustomerRow>(
            `
                SELECT id, email, password_hash, first_name, last_name, phone, role, created_at, updated_at
                FROM customers WHERE id = $1
            `,
            [payload.sub],
        );
        if (!result.rows[0]) {
            throw new UnauthorizedException('Customer session not found');
        }

        const customer = this.toCustomer(result.rows[0]);
        return {
            accessToken: this.issueAccessToken(customer),
            refreshToken: this.issueRefreshToken(customer),
        };
    }

    async logout(_userId: string) {
        return {
            success: true,
            message: 'Logged out successfully',
        };
    }

    async getProfile(userId: string) {
        const result = await this.database.query<CustomerRow>(
            `
                SELECT id, email, password_hash, first_name, last_name, phone, role, created_at, updated_at
                FROM customers WHERE id = $1
            `,
            [userId],
        );
        if (!result.rows[0]) {
            throw new UnauthorizedException('Customer not found');
        }
        return this.serializeCustomer(this.toCustomer(result.rows[0]));
    }

    async updateProfile(userId: string, dto: UpdateCustomerProfileDto) {
        const result = await this.database.query<CustomerRow>(
            `
                UPDATE customers
                SET first_name = COALESCE($2, first_name),
                    last_name = COALESCE($3, last_name),
                    phone = COALESCE($4, phone),
                    updated_at = NOW()
                WHERE id = $1
                RETURNING id, email, password_hash, first_name, last_name, phone, role, created_at, updated_at
            `,
            [
                userId,
                dto.firstName ? dto.firstName.trim() : null,
                dto.lastName ? dto.lastName.trim() : null,
                dto.phone === undefined ? null : dto.phone.trim(),
            ],
        );
        if (!result.rows[0]) {
            throw new UnauthorizedException('Customer not found');
        }
        return this.serializeCustomer(this.toCustomer(result.rows[0]));
    }

    private toCustomer(row: CustomerRow): CustomerRecord {
        return {
            id: row.id,
            email: row.email,
            passwordHash: row.password_hash,
            firstName: row.first_name,
            lastName: row.last_name,
            phone: row.phone ?? '',
            role: row.role,
            createdAt: new Date(row.created_at).toISOString(),
            updatedAt: new Date(row.updated_at).toISOString(),
        };
    }

    private isUniqueViolation(error: unknown, constraint: string) {
        return (
            typeof error === 'object' &&
            error !== null &&
            'code' in error &&
            error.code === '23505' &&
            'constraint' in error &&
            error.constraint === constraint
        );
    }

    private issueAccessToken(customer: CustomerRecord) {
        return jwt.sign(
            {
                sub: customer.id,
                email: customer.email,
                role: customer.role,
            },
            JWT_SECRET,
            { expiresIn: JWT_EXPIRES_IN },
        );
    }

    private issueRefreshToken(customer: CustomerRecord) {
        return jwt.sign(
            {
                sub: customer.id,
                type: 'refresh',
                role: customer.role,
            },
            JWT_REFRESH_SECRET,
            { expiresIn: REFRESH_TOKEN_TTL },
        );
    }

    private serializeCustomer(customer: CustomerRecord) {
        return {
            id: customer.id,
            email: customer.email,
            firstName: customer.firstName,
            lastName: customer.lastName,
            phone: customer.phone,
            role: customer.role,
            createdAt: customer.createdAt,
            updatedAt: customer.updatedAt,
        };
    }
}
