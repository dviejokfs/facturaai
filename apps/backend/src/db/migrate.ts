import { sql } from "./client";
import { readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";

const MIGRATIONS_DIR = join(import.meta.dir, "migrations");

async function ensureMigrationsTable() {
  await sql`
    CREATE TABLE IF NOT EXISTS schema_migrations (
      id SERIAL PRIMARY KEY,
      name VARCHAR NOT NULL UNIQUE,
      applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
  `;
}

async function getAppliedMigrations(): Promise<Set<string>> {
  const rows = await sql`SELECT name FROM schema_migrations ORDER BY name`;
  return new Set(rows.map((r: { name: string }) => r.name));
}

function getPendingMigrations(applied: Set<string>): string[] {
  const files = readdirSync(MIGRATIONS_DIR)
    .filter((f) => f.endsWith(".sql"))
    .sort();

  return files.filter((f) => !applied.has(f));
}

export async function runMigrations() {
  await ensureMigrationsTable();

  const applied = await getAppliedMigrations();
  const pending = getPendingMigrations(applied);

  if (pending.length === 0) {
    console.log("[migrate] All migrations already applied.");
    return;
  }

  console.log(`[migrate] ${pending.length} pending migration(s) to apply.`);

  for (const file of pending) {
    const filePath = join(MIGRATIONS_DIR, file);
    const content = readFileSync(filePath, "utf-8");

    console.log(`[migrate] Applying ${file}...`);

    await sql.unsafe(content);
    await sql`INSERT INTO schema_migrations (name) VALUES (${file})`;

    console.log(`[migrate] Applied ${file}.`);
  }

  console.log("[migrate] All migrations applied successfully.");
}

// Run standalone when executed directly
if (import.meta.main) {
  runMigrations()
    .then(() => process.exit(0))
    .catch((err) => {
      console.error("[migrate] Migration failed:", err);
      process.exit(1);
    });
}
