// Supabase Auth "Send SMS" hook. Auth posts { user, sms: { otp } } signed
// with Standard Webhooks; we send the OTP through the configured provider.
// Response contract: 200 {} on success, or { error: { http_code, message } }.

import { type Handler, HttpError, isRecord, readTextCapped } from "../_shared/http.ts";
import { verifyWebhook, WebhookVerificationError } from "../_shared/standard_webhooks.ts";
import type { SmsProvider } from "./providers.ts";

export type SmsHookDeps = { secrets: string[]; provider: SmsProvider; androidAppHash?: string };

const E164_RE = /^\+?[1-9]\d{7,14}$/;
const OTP_RE = /^\d{4,10}$/;

/** Bilingual OTP text. The optional app hash lets Android read the code automatically. */
export function otpMessage(otp: string, androidAppHash?: string): string {
  const lines = [`رمز أسرة: ${otp}`, `Usra code: ${otp}`];
  if (androidAppHash) lines.push(androidAppHash);
  return lines.join("\n");
}

function hookError(status: number, message: string): Response {
  return new Response(JSON.stringify({ error: { http_code: status, message } }), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

async function verifiedByAny(secrets: string[], headers: Headers, body: string): Promise<boolean> {
  for (const secret of secrets) {
    try {
      await verifyWebhook(secret, headers, body);
      return true;
    } catch (err) {
      if (!(err instanceof WebhookVerificationError)) throw err;
    }
  }
  return false;
}

export function createSmsHookHandler(deps: SmsHookDeps): Handler {
  return async (req) => {
    let body: string;
    try {
      // Auth hook payloads are tiny; cap before verifying the signature.
      body = await readTextCapped(req, 16 * 1024);
    } catch (err) {
      if (err instanceof HttpError) return hookError(413, "Payload too large");
      throw err;
    }
    if (!(await verifiedByAny(deps.secrets, req.headers, body))) {
      return hookError(401, "Invalid hook signature");
    }

    let payload: unknown;
    try {
      payload = JSON.parse(body);
    } catch {
      return hookError(400, "Invalid payload");
    }
    const user = isRecord(payload) && isRecord(payload.user) ? payload.user : undefined;
    const sms = isRecord(payload) && isRecord(payload.sms) ? payload.sms : undefined;
    const phone = typeof user?.phone === "string" ? user.phone : "";
    const otp = typeof sms?.otp === "string" ? sms.otp : "";
    if (!E164_RE.test(phone) || !OTP_RE.test(otp)) return hookError(400, "Invalid phone or code");

    const to = phone.startsWith("+") ? phone : `+${phone}`;
    try {
      await deps.provider.send(to, otpMessage(otp, deps.androidAppHash));
    } catch (err) {
      // Never log the phone number or the code.
      console.error("sms_send_failed", deps.provider.name, err instanceof Error ? err.message : "");
      return hookError(502, "Could not send the SMS, please try again");
    }
    return new Response("{}", { status: 200, headers: { "Content-Type": "application/json" } });
  };
}
