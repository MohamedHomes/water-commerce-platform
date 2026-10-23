import { Global, Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Pool } from 'pg';
import { DatabaseService } from './database.service';
import { DATABASE_POOL, DatabasePool } from './database.types';
import { MigrationRunnerService } from './migration-runner.service';

@Global()
@Module({
    providers: [
        DatabaseService,
        MigrationRunnerService,
        {
            provide: DATABASE_POOL,
            inject: [ConfigService],
            useFactory: (config: ConfigService): DatabasePool => {
                const connectionString = config.get<string>('DATABASE_URL');
                if (!connectionString) {
                    throw new Error(
                        'DATABASE_URL is not configured. Set DATABASE_URL (postgres://user:password@host:port/database) before starting the backend.',
                    );
                }
                return new Pool({
                    connectionString,
                    max: 10,
                    connectionTimeoutMillis: 10_000,
                }) as unknown as DatabasePool;
            },
        },
    ],
    exports: [DatabaseService, DATABASE_POOL],
})
export class DatabaseModule { }
