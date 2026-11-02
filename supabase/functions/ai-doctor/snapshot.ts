// Checks on the de-identified snapshot the user previewed in the app.
// The app builds it without names, phone numbers, IDs, photos or free-text
// notes; this is a second line of defence, not the main one.

import { isRecord } from "../_shared/http.ts";
import type { AiDoctorReport } from "./report_schema.ts";

export const MAX_SNAPSHOT_BYTES = 64 * 1024;

// Keys that identify a person, compared after lower-casing and removing _ and -.
const FORBIDDEN_KEYS = new Set([
  "fullname",
  "firstname",
  "lastname",
  "familyname",
  "phone",
  "phonenumber",
  "mobile",
  "email",
  "nationalid",
  "passport",
  "passportnumber",
  "birthdate",
  "dateofbirth",
  "dob",
  "address",
  "photo",
  "image",
  "picture",
  "notes",
  "note",
  "freetext",
]);

const EMAIL_RE = /[^\s@]+@[^\s@]+\.[^\s@]+/;
const NUMBER_RUN_RE = /\+?\d[\d\s-]*\d/g;

/** Phone numbers and national ids have 9+ digits; dates like 2026-11-02 have 8. */
function hasLongNumber(text: string): boolean {
  return (text.match(NUMBER_RUN_RE) ?? []).some((run) => run.replace(/\D/g, "").length >= 9);
}

export type Snapshot = {
  members: Array<{ id: string } & Record<string, unknown>>;
} & Record<string, unknown>;

export function validateSnapshot(value: unknown): { snapshot?: Snapshot; issues: string[] } {
  if (!isRecord(value)) return { issues: ["$: snapshot must be an object"] };

  const issues: string[] = [];
  const size = new TextEncoder().encode(JSON.stringify(value)).byteLength;
  if (size > MAX_SNAPSHOT_BYTES) issues.push(`$: snapshot larger than ${MAX_SNAPSHOT_BYTES} bytes`);

  const members = value.members;
  if (!Array.isArray(members) || members.length === 0) {
    issues.push("$.members: must be a non-empty array");
  } else {
    members.forEach((m, i) => {
      if (!isRecord(m) || typeof m.id !== "string" || m.id.length === 0) {
        issues.push(`$.members[${i}].id: required`);
      } else if ("name" in m) {
        issues.push(`$.members[${i}].name: names are not allowed`);
      }
    });
  }

  walk(value, "$", issues);
  return issues.length ? { issues } : { snapshot: value as Snapshot, issues };
}

function walk(value: unknown, path: string, issues: string[]): void {
  if (typeof value === "string") {
    if (EMAIL_RE.test(value)) issues.push(`${path}: looks like an email address`);
    else if (hasLongNumber(value)) issues.push(`${path}: looks like a phone or ID number`);
    return;
  }
  if (Array.isArray(value)) {
    value.forEach((v, i) => walk(v, `${path}[${i}]`, issues));
    return;
  }
  if (isRecord(value)) {
    for (const [key, child] of Object.entries(value)) {
      if (FORBIDDEN_KEYS.has(key.toLowerCase().replace(/[_-]/g, ""))) {
        issues.push(`${path}.${key}: identifying field not allowed`);
      } else {
        walk(child, `${path}.${key}`, issues);
      }
    }
  }
}

/** Findings may only refer to members that are in the snapshot. */
export function crossCheckReport(report: AiDoctorReport, snapshot: Snapshot): string[] {
  const memberIds = new Set(snapshot.members.map((m) => m.id));
  return report.findings.flatMap((f, i) =>
    memberIds.has(f.member) ? [] : [`$.findings[${i}].member: unknown member ${f.member}`]
  );
}
