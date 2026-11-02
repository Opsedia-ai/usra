// Supabase Auth Send SMS hook. Set [auth.hook.send_sms] in config.toml (or the
// dashboard) to this function's URL with the same secret as SEND_SMS_HOOK_SECRETS.

import { optionalEnv, requireEnv } from "../_shared/env.ts";
import { errorResponse } from "../_shared/http.ts";
import { createSmsHookHandler } from "./handler.ts";
import { type SmsProvider, TwilioProvider, UnifonicProvider } from "./providers.ts";

function providerFromEnv(): SmsProvider {
  const name = optionalEnv("SMS_PROVIDER", "unifonic");
  switch (name) {
    case "unifonic":
      return new UnifonicProvider({
        appSid: requireEnv("UNIFONIC_APP_SID"),
        senderId: requireEnv("UNIFONIC_SENDER_ID"),
        baseUrl: optionalEnv("UNIFONIC_BASE_URL", "https://el.cloud.unifonic.com"),
      });
    case "twilio":
      return new TwilioProvider({
        accountSid: requireEnv("TWILIO_ACCOUNT_SID"),
        authToken: requireEnv("TWILIO_AUTH_TOKEN"),
        from: requireEnv("TWILIO_FROM"),
      });
    default:
      throw new Error(`Unknown SMS_PROVIDER ${name}`);
  }
}

const handler = createSmsHookHandler({
  // Several secrets may be given separated by "|", so the secret can be rotated.
  secrets: requireEnv("SEND_SMS_HOOK_SECRETS").split("|").filter(Boolean),
  provider: providerFromEnv(),
  androidAppHash: Deno.env.get("SMS_ANDROID_APP_HASH") || undefined,
});

Deno.serve(async (req) => {
  try {
    return await handler(req);
  } catch (err) {
    return errorResponse(err);
  }
});
