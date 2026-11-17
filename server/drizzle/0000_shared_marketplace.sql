CREATE TABLE accounts (id TEXT PRIMARY KEY, username TEXT NOT NULL UNIQUE, email TEXT NOT NULL UNIQUE, phone TEXT NOT NULL UNIQUE, full_name TEXT NOT NULL, city TEXT NOT NULL, role TEXT NOT NULL CHECK(role IN ('customer','provider')), status TEXT NOT NULL DEFAULT 'active', password_hash TEXT NOT NULL, salt TEXT NOT NULL, created_at TEXT NOT NULL);
--> statement-breakpoint
CREATE TABLE sessions (hash TEXT PRIMARY KEY, user_id TEXT NOT NULL REFERENCES accounts(id), expires_at INTEGER NOT NULL);
--> statement-breakpoint
CREATE INDEX sessions_user ON sessions(user_id);
--> statement-breakpoint
CREATE TABLE requests (id TEXT PRIMARY KEY, customer_id TEXT NOT NULL REFERENCES accounts(id), selected_provider TEXT, stage TEXT NOT NULL, data TEXT NOT NULL, version INTEGER NOT NULL DEFAULT 1, updated_at INTEGER NOT NULL);
--> statement-breakpoint
CREATE INDEX requests_customer ON requests(customer_id);
--> statement-breakpoint
CREATE INDEX requests_stage ON requests(stage);
--> statement-breakpoint
CREATE INDEX requests_provider ON requests(selected_provider);
--> statement-breakpoint
CREATE TABLE uploads (id TEXT PRIMARY KEY, owner_id TEXT NOT NULL REFERENCES accounts(id), name TEXT NOT NULL, size INTEGER NOT NULL, created_at INTEGER NOT NULL);
--> statement-breakpoint
CREATE TABLE profiles (user_id TEXT PRIMARY KEY REFERENCES accounts(id), data TEXT NOT NULL DEFAULT '{}', withdrawn INTEGER NOT NULL DEFAULT 0, version INTEGER NOT NULL DEFAULT 1);
--> statement-breakpoint
CREATE TABLE rate_limits (key TEXT PRIMARY KEY, hits INTEGER NOT NULL, expires_at INTEGER NOT NULL);
--> statement-breakpoint
CREATE TABLE withdrawals (id TEXT PRIMARY KEY, user_id TEXT NOT NULL REFERENCES accounts(id), amount INTEGER NOT NULL);
