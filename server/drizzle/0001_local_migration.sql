ALTER TABLE accounts ADD COLUMN legacy_iterations INTEGER NOT NULL DEFAULT 0;
--> statement-breakpoint
ALTER TABLE accounts ADD COLUMN is_admin INTEGER NOT NULL DEFAULT 0;
--> statement-breakpoint
CREATE TABLE migration_runs (source_id TEXT PRIMARY KEY, payload_hash TEXT NOT NULL, result TEXT NOT NULL, completed_at INTEGER NOT NULL);
