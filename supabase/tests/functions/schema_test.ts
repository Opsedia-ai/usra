import { assertEquals, assertStringIncludes } from "jsr:@std/assert@1";
import { validate } from "../../functions/_shared/schema.ts";
import { REPORT_SCHEMA } from "../../functions/ai-doctor/report_schema.ts";
import { validReport } from "./fixtures.ts";

Deno.test("report schema accepts the documented example", () => {
  assertEquals(validate(REPORT_SCHEMA, validReport), []);
});

Deno.test("report schema accepts an empty findings list", () => {
  assertEquals(validate(REPORT_SCHEMA, { findings: [], urgent: false, disclaimer: "x" }), []);
});

Deno.test("report schema rejects an unknown severity", () => {
  const bad = structuredClone(validReport);
  bad.findings[0].severity = "purple";
  const errors = validate(REPORT_SCHEMA, bad);
  assertEquals(errors.length, 1);
  assertStringIncludes(errors[0], "$.findings[0].severity");
});

Deno.test("report schema rejects missing fields and extra fields", () => {
  const bad = structuredClone(validReport) as Record<string, unknown>;
  delete bad.disclaimer;
  bad.diagnosis = "flu";
  const errors = validate(REPORT_SCHEMA, bad);
  assertEquals(errors.sort(), ["$.diagnosis: not allowed", "$.disclaimer: required"]);
});

Deno.test("report schema rejects wrong types deep in the tree", () => {
  const bad = structuredClone(validReport) as unknown as { findings: Array<Record<string, unknown>>; urgent: unknown };
  bad.findings[0].evidence = "med_81";
  bad.urgent = "no";
  const errors = validate(REPORT_SCHEMA, bad);
  assertEquals(errors.sort(), [
    "$.findings[0].evidence: expected array, got string",
    "$.urgent: expected boolean, got string",
  ]);
});

Deno.test("report schema enforces length limits and member id pattern", () => {
  const bad = structuredClone(validReport);
  bad.findings[0].title = "x".repeat(121);
  bad.findings[0].member = "Ahmed Ali";
  const errors = validate(REPORT_SCHEMA, bad);
  assertEquals(errors.length, 2);
});

Deno.test("validator: integer vs number, min/max, items", () => {
  assertEquals(validate({ type: "number", minimum: 0, maximum: 1 }, 0.5), []);
  assertEquals(validate({ type: "integer" }, 1.5), ["$: expected integer, got number"]);
  assertEquals(validate({ type: "number", maximum: 1 }, 2), ["$: above 1"]);
  assertEquals(validate({ type: "array", maxItems: 1, items: { type: "string" } }, ["a", 1]), [
    "$: more than 1 items",
    "$[1]: expected string, got integer",
  ]);
  assertEquals(validate({ type: "object" }, null), ["$: expected object, got null"]);
});
