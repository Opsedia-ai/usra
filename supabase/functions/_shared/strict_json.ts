// Strict JSON for signed sync objects (docs/sync-design.md, section 5). The
// signature covers the exact bytes; this parser decides whether those bytes are
// acceptable before anything reads them, and rejects instead of guessing:
// invalid UTF-8 (or a byte-order mark), duplicate object keys (compared after
// unescaping), nesting deeper than `maxDepth`, more than `maxBytes`, numbers that
// are not plain safe integers, "\u0000" and lone surrogates (which Postgres
// jsonb would refuse), and anything after the value. Postgres re-checks the same
// rules (private.strict_json), so the server and the phones parse alike.

export class StrictJsonError extends Error {
  constructor(readonly reason: string) {
    super(reason);
  }
}

export type JsonValue = null | boolean | number | string | JsonValue[] | { [key: string]: JsonValue };

export type StrictJsonOptions = { maxBytes: number; maxDepth?: number };

export function parseStrictJson(bytes: Uint8Array, options: StrictJsonOptions): JsonValue {
  if (bytes.length > options.maxBytes) throw new StrictJsonError("too_large");
  let text: string;
  try {
    text = new TextDecoder("utf-8", { fatal: true, ignoreBOM: true }).decode(bytes);
  } catch {
    throw new StrictJsonError("invalid_utf8");
  }
  return new Parser(text, options.maxDepth ?? 8).parseDocument();
}

class Parser {
  private pos = 0;

  constructor(private readonly text: string, private readonly maxDepth: number) {}

  parseDocument(): JsonValue {
    this.skipWhitespace();
    const value = this.parseValue(0);
    this.skipWhitespace();
    if (this.pos !== this.text.length) this.fail("trailing_data");
    return value;
  }

  private fail(reason: string): never {
    throw new StrictJsonError(reason);
  }

  private skipWhitespace() {
    while (this.pos < this.text.length) {
      const c = this.text[this.pos];
      if (c !== " " && c !== "\t" && c !== "\n" && c !== "\r") break;
      this.pos++;
    }
  }

  private expect(literal: string) {
    if (this.text.startsWith(literal, this.pos)) {
      this.pos += literal.length;
    } else {
      this.fail("syntax");
    }
  }

  private parseValue(depth: number): JsonValue {
    const c = this.text[this.pos];
    if (c === "{") return this.parseObject(depth + 1);
    if (c === "[") return this.parseArray(depth + 1);
    if (c === '"') return this.parseString();
    if (c === "t") return this.expect("true"), true;
    if (c === "f") return this.expect("false"), false;
    if (c === "n") return this.expect("null"), null;
    if (c === "-" || (c >= "0" && c <= "9")) return this.parseNumber();
    return this.fail("syntax");
  }

  private parseObject(depth: number): { [key: string]: JsonValue } {
    if (depth > this.maxDepth) this.fail("too_deep");
    this.pos++; // {
    // No prototype, so a "__proto__" key is just a key.
    const out: { [key: string]: JsonValue } = Object.create(null);
    const seen = new Set<string>();
    this.skipWhitespace();
    if (this.text[this.pos] === "}") {
      this.pos++;
      return out;
    }
    while (true) {
      this.skipWhitespace();
      if (this.text[this.pos] !== '"') this.fail("syntax");
      const key = this.parseString();
      if (seen.has(key)) this.fail("duplicate_key");
      seen.add(key);
      this.skipWhitespace();
      this.expect(":");
      this.skipWhitespace();
      out[key] = this.parseValue(depth);
      this.skipWhitespace();
      const c = this.text[this.pos++];
      if (c === "}") return out;
      if (c !== ",") this.fail("syntax");
    }
  }

  private parseArray(depth: number): JsonValue[] {
    if (depth > this.maxDepth) this.fail("too_deep");
    this.pos++; // [
    const out: JsonValue[] = [];
    this.skipWhitespace();
    if (this.text[this.pos] === "]") {
      this.pos++;
      return out;
    }
    while (true) {
      this.skipWhitespace();
      out.push(this.parseValue(depth));
      this.skipWhitespace();
      const c = this.text[this.pos++];
      if (c === "]") return out;
      if (c !== ",") this.fail("syntax");
    }
  }

  private parseNumber(): number {
    const m = /^-?(0|[1-9][0-9]*)/.exec(this.text.slice(this.pos, this.pos + 40));
    if (!m) this.fail("syntax");
    const next = this.text[this.pos + m[0].length];
    if (next === "." || next === "e" || next === "E") this.fail("not_integer");
    const n = Number(m[0]);
    if (!Number.isSafeInteger(n)) this.fail("not_integer");
    this.pos += m[0].length;
    return n;
  }

  private parseString(): string {
    this.pos++; // opening quote
    let out = "";
    while (true) {
      if (this.pos >= this.text.length) this.fail("syntax");
      const c = this.text[this.pos++];
      if (c === '"') break;
      if (c < " ") this.fail("control_character");
      if (c !== "\\") {
        out += c;
        continue;
      }
      const e = this.text[this.pos++];
      switch (e) {
        case '"':
        case "\\":
        case "/":
          out += e;
          break;
        case "b":
          out += "\b";
          break;
        case "f":
          out += "\f";
          break;
        case "n":
          out += "\n";
          break;
        case "r":
          out += "\r";
          break;
        case "t":
          out += "\t";
          break;
        case "u":
          out += String.fromCharCode(this.parseHex4());
          break;
        default:
          this.fail("bad_escape");
      }
    }
    // Lone surrogates (from \u escapes) and NUL are refused: Postgres would.
    if (out.includes("\u0000")) this.fail("nul_character");
    if (!out.isWellFormed()) this.fail("lone_surrogate");
    return out;
  }

  private parseHex4(): number {
    const h = this.text.slice(this.pos, this.pos + 4);
    if (!/^[0-9a-fA-F]{4}$/.test(h)) this.fail("bad_escape");
    this.pos += 4;
    return parseInt(h, 16);
  }
}

export function isJsonObject(value: JsonValue | undefined): value is { [key: string]: JsonValue } {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}
