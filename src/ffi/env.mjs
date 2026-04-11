import { Ok, Error } from "../gleam.mjs";

export function getEnv(name) {
  const value = process.env[name];
  return value !== undefined ? new Ok(value) : new Error(undefined);
}

export function exit(code) {
  process.exit(code);
}
