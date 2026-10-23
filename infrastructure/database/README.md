# Consolidated database setup

`full_database_setup.sql` is a generated snapshot of every file in
`backend/migrations`, in the migration runner's filename order. It creates the
schema and baseline data, then records the same migration filenames and SHA-256
checksums in `schema_migrations` so the backend runner can verify the snapshot
and safely skip those already-applied migrations.

Use this file only to initialize a new, empty database:

```powershell
psql "$env:DATABASE_URL" -v ON_ERROR_STOP=1 -f infrastructure/database/full_database_setup.sql
```

For normal development and deployments, keep the backend migration runner as
the canonical schema mechanism. Backend startup applies pending migrations
transactionally; do not apply this snapshot to an existing database. The
consolidated script runs all schema and seed changes in one transaction and is
not intended to be rerun against a database that already contains the schema.

After adding or changing a migration, regenerate the snapshot from the project
root:

```powershell
node backend/scripts/generate-full-database-setup.mjs
```

The backend persistence integration tests execute the consolidated SQL with
PGlite, compare its ledger to the ordered migration files, and verify that a
subsequent migration-runner pass skips the recorded migrations. This is
PostgreSQL-compatible test coverage, not verification against the deployed
PostgreSQL 16 configuration. That deployment check remains required.
