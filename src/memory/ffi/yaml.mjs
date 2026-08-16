import yaml from "js-yaml";
import { Error, Ok } from "../../gleam.mjs";

function requirePlainData(value) {
  if (
    value === null ||
    typeof value === "string" ||
    typeof value === "number" ||
    typeof value === "boolean"
  ) {
    return;
  }

  if (Array.isArray(value)) {
    for (const item of value) {
      requirePlainData(item);
    }
    return;
  }

  if (typeof value === "object") {
    const prototype = Object.getPrototypeOf(value);
    if (prototype !== Object.prototype && prototype !== null) {
      throw new TypeError("YAML contains a non-plain value");
    }
    for (const item of Object.values(value)) {
      requirePlainData(item);
    }
    return;
  }

  throw new TypeError("YAML contains an unsupported value");
}

export function parseDocument(source) {
  try {
    const document = yaml.load(source, { json: false });
    if (document === undefined) {
      throw new TypeError("YAML document is empty");
    }
    requirePlainData(document);
    return new Ok(JSON.stringify(document));
  } catch (_) {
    return new Error(undefined);
  }
}
