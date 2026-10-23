import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { resolve } from 'path';
import { DatabaseService } from './database.service';
import { runMigrations } from './migration-runner';

@Injectable()
export class MigrationRunnerService implements OnModuleInit {
    private readonly logger = new Logger(MigrationRunnerService.name);
    private readonly migrationDirectory = resolve(__dirname, '..', '..', 'migrations');

    constructor(private readonly database: DatabaseService) { }

    async onModuleInit() {
        await this.runMigrations();
    }

    async runMigrations() {
        const result = await this.database.withTransaction((client) =>
            runMigrations(client, this.migrationDirectory),
        );
        for (const name of result.applied) {
            this.logger.log(`Applied migration ${name}`);
        }
    }
}
