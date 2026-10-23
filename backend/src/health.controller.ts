import { Controller, Get } from '@nestjs/common';
import { DatabaseService } from './database/database.service';

@Controller('health')
export class HealthController {
    constructor(private readonly database: DatabaseService) { }

    @Get()
    getHealth() {
        return {
            status: 'ok',
            service: 'aquaflow-backend',
            timestamp: new Date().toISOString(),
        };
    }

    @Get('live')
    getLive() {
        return { status: 'live' };
    }

    @Get('ready')
    async getReady() {
        await this.database.query('SELECT 1');
        return {
            status: 'ready',
            checks: {
                database: 'connected',
                cache: 'not-configured',
            },
        };
    }
}
