export const DATABASE_POOL = 'DATABASE_POOL';

export interface QueryResultLike<T = Record<string, unknown>> {
    rows: T[];
    rowCount: number | null;
}

export interface QueryableClient {
    query<T = Record<string, unknown>>(
        text: string,
        params?: any[],
    ): Promise<QueryResultLike<T>>;
    exec?(text: string): Promise<unknown>;
}

export interface DatabaseClient extends QueryableClient {
    release(): void;
}

export interface DatabasePool extends QueryableClient {
    connect(): Promise<DatabaseClient>;
    end(): Promise<void>;
}
