import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { PGlite, Transaction } from '@electric-sql/pglite';
import { QueryResultRow } from 'pg';
import { AppModule } from '../src/app.module';
import { DatabaseService, QueryExecutor, QueryResult } from '../src/database/database.service';
import { DATABASE_POOL } from '../src/database/database.types';

export class PGliteDatabaseAdapter {
    constructor(readonly instance: PGlite = new PGlite()) { }

    async query<T extends QueryResultRow = QueryResultRow>(
        text: string,
        values?: any[],
    ): Promise<QueryResult<T>> {
        const result = await this.instance.query<T>(text, values);
        return { rows: result.rows, rowCount: result.affectedRows ?? result.rows.length };
    }

    withTransaction<T>(operation: (client: QueryExecutor) => Promise<T>) {
        return this.instance.transaction((transaction) => operation(this.executor(transaction)));
    }

    async close() {
        await this.instance.close();
    }

    private executor(transaction: Transaction): QueryExecutor {
        return {
            exec: async (text: string) => transaction.exec(text),
            query: async <T extends QueryResultRow = QueryResultRow>(text: string, values?: any[]) => {
                const result = await transaction.query<T>(text, values);
                return {
                    rows: result.rows,
                    rowCount: result.affectedRows ?? result.rows.length,
                };
            },
        };
    }
}

export async function createTestApplication(database?: PGliteDatabaseAdapter) {
    const ownedDatabase = database ?? new PGliteDatabaseAdapter();
    await ownedDatabase.instance.waitReady;

    const moduleFixture = await Test.createTestingModule({
        imports: [AppModule],
    })
        .overrideProvider(DatabaseService)
        .useValue(ownedDatabase)
        .overrideProvider(DATABASE_POOL)
        .useValue(ownedDatabase)
        .compile();

    const app: INestApplication = moduleFixture.createNestApplication({ rawBody: true });
    app.setGlobalPrefix('api/v1');
    app.useGlobalPipes(new ValidationPipe({
        whitelist: true,
        forbidNonWhitelisted: true,
        transform: true,
    }));
    await app.init();

    return {
        app,
        database: ownedDatabase,
        close: async () => {
            await app.close();
            if (!database) {
                await ownedDatabase.close();
            }
        },
    };
}
