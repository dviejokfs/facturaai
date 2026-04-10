import { SQL } from "bun";
import { config } from "../config";

export const sql = new SQL(config.POSTGRES_URL);
