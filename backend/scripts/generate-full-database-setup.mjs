import { createHash } from 'node:crypto';
import { readdir, readFile, writeFile } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const backendDirectory = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const migrationsDirectory = resolve(backendDirectory, 'migrations');
const outputFile = resolve(backendDirectory, '..', 'infrastructure', 'database', 'full_database_setup.sql');
const migrationPattern = /^(\d{3,})_[a-z0-9_]+\.sql$/i;
const filenames = (await readdir(migrationsDirectory))
    .filter((filename) => migrationPattern.test(filename))
    .sort();

if (filenames.length === 0) {
    throw new Error(`No migration files found in ${migrationsDirectory}`);
}

const migrations = [];
const versions = new Set();
for (const filename of filenames) {
    const [, version] = migrationPattern.exec(filename);
    if (versions.has(version)) {
        throw new Error(`Duplicate migration version ${version}`);
    }
    versions.add(version);
    const sql = (await readFile(resolve(migrationsDirectory, filename), 'utf8')).replace(/\r\n/g, '\n');
    const checksum = createHash('sha256').update(sql).digest('hex');
    migrations.push({ filename, version, checksum, sql });
}

const output = [
    '-- GENERATED from backend/migrations in filename order.',
    '-- Apply only to a new, empty database. The backend migration runner remains canonical.',
    'BEGIN;',
    '',
];

for (const migration of migrations) {
    output.push(
        `-- BEGIN ${migration.filename}`,
        migration.sql.trimEnd(),
        `-- END ${migration.filename}`,
        '',
    );
}

output.push(
    '-- Match the ledger schema maintained by backend/src/database/migration-runner.ts.',
    'CREATE TABLE IF NOT EXISTS schema_migrations (',
    '    version VARCHAR(32) NOT NULL PRIMARY KEY,',
    '    filename TEXT NOT NULL,',
    '    checksum VARCHAR(64) NOT NULL,',
    '    applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW()',
    ');',
    'INSERT INTO schema_migrations (version, filename, checksum) VALUES',
    migrations
        .map(({ version, filename, checksum }) => `    ('${version}', '${filename}', '${checksum}')`)
        .join(',\n') + ';',
    'COMMIT;',
    '',
);

await writeFile(outputFile, output.join('\n'), 'utf8');
console.log(`Generated ${outputFile} from ${migrations.length} ordered migrations.`);
