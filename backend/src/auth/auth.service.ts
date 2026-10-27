import { BadRequestException, Injectable, ServiceUnavailableException, UnauthorizedException } from '@nestjs/common';
import { Transform } from 'class-transformer';
import { IsEmail, IsNotEmpty, IsOptional, IsString, Matches, MinLength } from 'class-validator';
import { createHash, randomBytes, randomUUID } from 'crypto';
import jwt from 'jsonwebtoken';
import { QueryResultRow } from 'pg';
import { DatabaseService } from '../database/database.service';
import { JWT_EXPIRES_IN, JWT_SECRET, JWT_REFRESH_SECRET, REFRESH_TOKEN_TTL } from './auth.constants';
import { hashPassword, verifyPassword } from './password-hasher';
import { MailService } from './mail.service';

export type CustomerRole = 'customer' | 'admin';

export interface CustomerRecord {
    id: string;
    email: string;
    passwordHash: string;
    firstName: string;
    lastName: string;
    phone: string;
    role: CustomerRole;
    authVersion: number;
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
    auth_version: number;
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

export class ChangeCustomerPasswordDto {
    @IsString()
    @IsNotEmpty()
    currentPassword!: string;

    @IsString()
    @MinLength(8)
    @Matches(/^(?=.*[A-Za-z])(?=.*\d)(?=.*[^A-Za-z\d]).+$/, {
        message: 'Password must include a letter, number, and symbol',
    })
    newPassword!: string;
}

export class RequestPasswordResetDto {
    @Transform(({ value }) => (typeof value === 'string' ? value.trim().toLowerCase() : value))
    @IsEmail()
    email!: string;
}

export class ConfirmPasswordResetDto {
    @IsString()
    @Matches(/^[a-f0-9]{64}$/i)
    token!: string;

    @IsString()
    @MinLength(8)
    @Matches(/^(?=.*[A-Za-z])(?=.*\d)(?=.*[^A-Za-z\d]).+$/, {
        message: 'Password must include a letter, number, and symbol',
    })
    newPassword!: string;
}

@Injectable()
export class AuthService {
    constructor(
        private readonly database: DatabaseService,
        private readonly mailService: MailService,
    ) {}

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
                    RETURNING id, email, password_hash, first_name, last_name, phone, role,
                        auth_version, created_at, updated_at
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
                SELECT id, email, password_hash, first_name, last_name, phone, role,
                    auth_version, created_at, updated_at
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
        let payload: { sub: string; type?: string; role?: string; authVersion?: number };
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
                SELECT id, email, password_hash, first_name, last_name, phone, role,
                    auth_version, created_at, updated_at
                FROM customers WHERE id = $1
            `,
            [payload.sub],
        );
        if (!result.rows[0]) {
            throw new UnauthorizedException('Customer session not found');
        }
        if ((payload.authVersion ?? 0) !== result.rows[0].auth_version) {
            throw new UnauthorizedException('Refresh token has been revoked');
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
                SELECT id, email, password_hash, first_name, last_name, phone, role,
                    auth_version, created_at, updated_at
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
                RETURNING id, email, password_hash, first_name, last_name, phone, role,
                    auth_version, created_at, updated_at
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

    async changePassword(userId: string, dto: ChangeCustomerPasswordDto) {
        const row = await this.database.withTransaction(async (client) => {
            const result = await client.query<CustomerRow>(
                `
                    SELECT id, email, password_hash, first_name, last_name, phone, role,
                        auth_version, created_at, updated_at
                    FROM customers WHERE id = $1 FOR UPDATE
                `,
                [userId],
            );
            const current = result.rows[0];
            if (!current) {
                throw new UnauthorizedException('Customer not found');
            }
            if (!(await verifyPassword(dto.currentPassword, current.password_hash))) {
                throw new UnauthorizedException('Current password is incorrect');
            }
            if (await verifyPassword(dto.newPassword, current.password_hash)) {
                throw new BadRequestException('New password must differ from the current password');
            }
            const passwordHash = await hashPassword(dto.newPassword);
            const updated = await client.query<CustomerRow>(
                `
                    UPDATE customers
                    SET password_hash = $2, auth_version = auth_version + 1, updated_at = NOW()
                    WHERE id = $1
                    RETURNING id, email, password_hash, first_name, last_name, phone, role,
                        auth_version, created_at, updated_at
                `,
                [userId, passwordHash],
            );
            return updated.rows[0];
        });
        const customer = this.toCustomer(row);
        return {
            success: true,
            accessToken: this.issueAccessToken(customer),
            refreshToken: this.issueRefreshToken(customer),
        };
    }

    async requestPasswordReset(email: string) {
        if (!this.mailService.isConfigured) {
            throw new ServiceUnavailableException('Password recovery email is not configured');
        }
        const normalizedEmail = email.trim().toLowerCase();
        const result = await this.database.query<{ id: string; email: string }>(
            'SELECT id, email FROM customers WHERE email = $1',
            [normalizedEmail],
        );
        if (!result.rows[0]) {
            return {
                message:
                    'If an account matches this email, recovery instructions will be sent if delivery is available.',
            };
        }

        const token = randomBytes(32).toString('hex');
        const tokenHash = createHash('sha256').update(token).digest('hex');
        await this.database.query(
            `
                INSERT INTO password_reset_tokens (token_hash, customer_id, expires_at)
                VALUES ($1, $2, NOW() + INTERVAL '15 minutes')
            `,
            [tokenHash, result.rows[0].id],
        );
        const delivered = await this.mailService.sendPasswordResetCode(result.rows[0].email, token);
        if (!delivered) {
            await this.database.query('DELETE FROM password_reset_tokens WHERE token_hash = $1', [tokenHash]);
        }
        return {
            message: 'If an account matches this email, recovery instructions will be sent if delivery is available.',
        };
    }

    async confirmPasswordReset(dto: ConfirmPasswordResetDto) {
        const tokenHash = createHash('sha256').update(dto.token).digest('hex');
        await this.database.withTransaction(async (client) => {
            const result = await client.query<{
                customer_id: string;
                token_hash: string;
                expires_at: Date | string;
                used_at: Date | string | null;
            }>(
                `
                    SELECT token_hash, customer_id, expires_at, used_at
                    FROM password_reset_tokens
                    WHERE token_hash = $1
                    FOR UPDATE
                `,
                [tokenHash],
            );
            const reset = result.rows[0];
            if (
                !reset ||
                reset.token_hash !== tokenHash ||
                reset.used_at !== null ||
                new Date(reset.expires_at).getTime() <= Date.now()
            ) {
                throw new BadRequestException('Recovery code is invalid or expired');
            }
            const passwordHash = await hashPassword(dto.newPassword);
            await client.query(
                `UPDATE customers
                SET password_hash = $2, auth_version = auth_version + 1, updated_at = NOW()
                WHERE id = $1`,
                [reset.customer_id, passwordHash],
            );
            await client.query(
                'UPDATE password_reset_tokens SET used_at = NOW() WHERE customer_id = $1 AND used_at IS NULL',
                [reset.customer_id],
            );
        });
        return { success: true };
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
            authVersion: row.auth_version,
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
                authVersion: customer.authVersion,
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
                authVersion: customer.authVersion,
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
