import { Ok, Error } from "../gleam.mjs";
import { readFileSync } from "node:fs";

export function getEnv(name) {
  const value = process.env[name];
  return value !== undefined ? new Ok(value) : new Error(undefined);
}

export function readStdin() {
  try {
    return new Ok(readFileSync(0, "utf-8"));
  } catch (e) {
    return new Error(undefined);
  }
}

export function exit(code) {
  process.exit(code);
}
