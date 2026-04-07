import { sql } from "./client";

const schema = await Bun.file(new URL("./schema.sql", import.meta.url)).text();

console.log("Running migrations…");
await sql.unsafe(schema);
console.log("Migrations applied.");
process.exit(0);
