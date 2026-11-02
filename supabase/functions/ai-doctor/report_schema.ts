// Output contract for Dr. Usra AI. The app renders each finding as a card in
// the severity colour and links it to the records listed in `evidence`.

import type { JsonSchema } from "../_shared/schema.ts";

export const SEVERITIES = ["blue", "green", "yellow", "orange", "red"] as const;
export type Severity = typeof SEVERITIES[number];

export type Finding = {
  member: string;
  severity: Severity;
  title: string;
  why: string;
  evidence: string[];
  action: string;
};

export type AiDoctorReport = {
  findings: Finding[];
  urgent: boolean;
  disclaimer: string;
};

export const REPORT_SCHEMA: JsonSchema = {
  type: "object",
  additionalProperties: false,
  required: ["findings", "urgent", "disclaimer"],
  properties: {
    findings: {
      type: "array",
      maxItems: 20,
      items: {
        type: "object",
        additionalProperties: false,
        required: ["member", "severity", "title", "why", "evidence", "action"],
        properties: {
          member: {
            type: "string",
            pattern: "^[A-Za-z0-9_-]{1,32}$",
            description: "Member id from the snapshot, e.g. P2",
          },
          severity: {
            type: "string",
            enum: SEVERITIES,
            description: "blue info, green good, yellow heads-up, orange act soon, red urgent",
          },
          title: { type: "string", minLength: 1, maxLength: 120 },
          why: { type: "string", minLength: 1, maxLength: 600 },
          evidence: {
            type: "array",
            maxItems: 20,
            items: { type: "string", minLength: 1, maxLength: 64 },
            description: "Record ids from the snapshot that this finding is based on",
          },
          action: { type: "string", minLength: 1, maxLength: 300 },
        },
      },
    },
    urgent: { type: "boolean" },
    disclaimer: { type: "string", minLength: 1, maxLength: 300 },
  },
};
