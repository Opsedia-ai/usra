import { assertEquals, assertThrows } from "jsr:@std/assert@1";
import { parseStrictJson, StrictJsonError } from "../../functions/_shared/strict_json.ts";

const enc = (s: string) => new TextEncoder().encode(s);
const parse = (s: string | Uint8Array, maxBytes = 16384) =>
  parseStrictJson(typeof s === "string" ? enc(s) : s, { maxBytes, maxDepth: 8 });

function rejects(input: string | Uint8Array, reason: string, maxBytes?: number) {
  const err = assertThrows(() => parse(input, maxBytes), StrictJsonError);
  assertEquals(err.reason, reason, typeof input === "string" ? input : "(bytes)");
}

Deno.test("strict json: parses a log entry", () => {
  const value = parse('{"v":1,"seq":2,"prev":null,"at":"019300f8a1b20003","ok":true,"devices":[{"id":"x"}]}');
  assertEquals(
    JSON.stringify(value),
    '{"v":1,"seq":2,"prev":null,"at":"019300f8a1b20003","ok":true,"devices":[{"id":"x"}]}',
  );
});

Deno.test("strict json: duplicate keys are rejected, also when escaped differently", () => {
  rejects('{"role":"viewer","role":"owner"}', "duplicate_key");
  rejects('{"role":"viewer","\\u0072ole":"owner"}', "duplicate_key");
  rejects('{"a":{"b":1,"b":2}}', "duplicate_key");
});

Deno.test("strict json: invalid UTF-8 and a byte-order mark are rejected", () => {
  rejects(Uint8Array.from([0x7b, 0x22, 0x61, 0x22, 0x3a, 0x22, 0xc3, 0x28, 0x22, 0x7d]), "invalid_utf8");
  rejects(Uint8Array.from([0xef, 0xbb, 0xbf, ...enc('{"a":1}')]), "syntax");
});

Deno.test("strict json: depth, size and trailing data", () => {
  const deep = (n: number) => "[".repeat(n) + "]".repeat(n);
  parse(`{"a":${deep(7)}}`);
  rejects(`{"a":${deep(8)}}`, "too_deep");
  rejects('{"a":"' + "x".repeat(100) + '"}', "too_large", 50);
  rejects('{"a":1} {"a":2}', "trailing_data");
  rejects('{"a":1},', "trailing_data");
});

Deno.test("strict json: only plain safe integers", () => {
  assertEquals(parse('{"n":-9007199254740991}'), { n: -9007199254740991 });
  rejects('{"n":1.0}', "not_integer");
  rejects('{"n":1e2}', "not_integer");
  rejects('{"n":9007199254740992}', "not_integer");
  rejects('{"n":01}', "syntax");
  rejects('{"n":+1}', "syntax");
});

Deno.test("strict json: strings Postgres would refuse are rejected", () => {
  rejects('{"a":"\\u0000"}', "nul_character");
  rejects('{"a":"\\ud800"}', "lone_surrogate");
  rejects('{"a":"tab\there"}', "control_character");
  rejects('{"a":"\\x"}', "bad_escape");
  assertEquals(parse('{"a":"\\ud83d\\ude00 مرحبا"}'), { a: "😀 مرحبا" });
});

Deno.test("strict json: __proto__ is an ordinary key", () => {
  const value = parse('{"__proto__":{"polluted":true}}') as Record<string, unknown>;
  assertEquals(Object.keys(value), ["__proto__"]);
  assertEquals(({} as Record<string, unknown>).polluted, undefined);
});

Deno.test("strict json: syntax errors", () => {
  for (const bad of ["", "{", '{"a"}', '{"a":}', "{'a':1}", '{"a":1,}', "[1,]", "tru", "nul", '"open']) {
    assertThrows(() => parse(bad), StrictJsonError, undefined, bad);
  }
});
