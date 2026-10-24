import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { resolve } from 'path';
import { Inject } from '@nestjs/common';
import { DATABASE_POOL, DatabasePool } from './database.types';
import { runMigrations } from './migration-runner';

@Injectable()
export class MigrationRunnerService implements OnModuleInit {
    private readonly logger = new Logger(MigrationRunnerService.name);
    private readonly migrationDirectory = resolve(__dirname, '..', '..', 'migrations');

    constructor(@Inject(DATABASE_POOL) private readonly database: DatabasePool) { }

    async onModuleInit() {
        await this.runMigrations();
    }

    async runMigrations() {
        const result = await runMigrations(this.database, this.migrationDirectory);
        for (const name of result.applied) {
            this.logger.log(`Applied migration ${name}`);
        }
    }
}
