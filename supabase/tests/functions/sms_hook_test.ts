import { assertEquals, assertRejects } from "jsr:@std/assert@1";
import { bytesToBase64 } from "../../functions/_shared/crypto.ts";
import { signPayload, verifyWebhook, WebhookVerificationError } from "../../functions/_shared/standard_webhooks.ts";
import { createSmsHookHandler, otpMessage } from "../../functions/send-sms-hook/handler.ts";
import {
  type SmsProvider,
  SmsProviderError,
  TwilioProvider,
  UnifonicProvider,
} from "../../functions/send-sms-hook/providers.ts";

const SECRET = `v1,whsec_${bytesToBase64(new TextEncoder().encode("test-secret-not-real-0123456789"))}`;
const OTHER = `v1,whsec_${bytesToBase64(new TextEncoder().encode("another-secret"))}`;

async function signedRequest(body: string, secret = SECRET, ts = Math.floor(Date.now() / 1000)) {
  const id = "msg_123";
  return new Request("http://local/send-sms-hook", {
    method: "POST",
    headers: {
      "webhook-id": id,
      "webhook-timestamp": String(ts),
      "webhook-signature": await signPayload(secret, id, ts, body),
    },
    body,
  });
}

Deno.test("standard webhooks: valid signature passes; tampering, wrong secret and old timestamps fail", async () => {
  const body = '{"a":1}';
  const now = 1_800_000_000;
  const headers = new Headers({
    "webhook-id": "msg_1",
    "webhook-timestamp": String(now),
    "webhook-signature": `v1,bogus ${await signPayload(SECRET, "msg_1", now, body)}`,
  });
  await verifyWebhook(SECRET, headers, body, now);
  await assertRejects(() => verifyWebhook(SECRET, headers, '{"a":2}', now), WebhookVerificationError, "bad_signature");
  await assertRejects(() => verifyWebhook(OTHER, headers, body, now), WebhookVerificationError, "bad_signature");
  await assertRejects(
    () => verifyWebhook(SECRET, headers, body, now + 301),
    WebhookVerificationError,
    "timestamp_out_of_range",
  );
  await assertRejects(
    () => verifyWebhook(SECRET, new Headers(), body, now),
    WebhookVerificationError,
    "missing_headers",
  );
});

class FakeSms implements SmsProvider {
  readonly name = "fake";
  sent: Array<{ to: string; body: string }> = [];
  fail = false;
  send(to: string, body: string) {
    if (this.fail) return Promise.reject(new SmsProviderError("fake", 500));
    this.sent.push({ to, body });
    return Promise.resolve();
  }
}

const payload = JSON.stringify({ user: { id: "u1", phone: "201001234567" }, sms: { otp: "123456" } });

Deno.test("sms hook: sends the OTP to the E.164 number and returns {}", async () => {
  const sms = new FakeSms();
  const handler = createSmsHookHandler({ secrets: [OTHER, SECRET], provider: sms });
  const res = await handler(await signedRequest(payload));
  assertEquals(res.status, 200);
  assertEquals(await res.json(), {});
  assertEquals(sms.sent, [{ to: "+201001234567", body: otpMessage("123456") }]);
});

Deno.test("sms hook: bad signature is 401 and nothing is sent", async () => {
  const sms = new FakeSms();
  const handler = createSmsHookHandler({ secrets: [SECRET], provider: sms });
  const res = await handler(await signedRequest(payload, OTHER));
  assertEquals(res.status, 401);
  assertEquals((await res.json()).error.http_code, 401);
  assertEquals(sms.sent.length, 0);
});

Deno.test("sms hook: invalid phone or code is 400; provider failure is 502", async () => {
  const sms = new FakeSms();
  const handler = createSmsHookHandler({ secrets: [SECRET], provider: sms });
  const bad = JSON.stringify({ user: { phone: "abc" }, sms: { otp: "12" } });
  assertEquals((await handler(await signedRequest(bad))).status, 400);
  sms.fail = true;
  assertEquals((await handler(await signedRequest(payload))).status, 502);
});

Deno.test("otp message is bilingual and can carry the Android app hash", () => {
  assertEquals(otpMessage("4321"), "رمز أسرة: 4321\nUsra code: 4321");
  assertEquals(otpMessage("4321", "FA+9qCX9VSu").split("\n").length, 3);
});

// --- provider request shapes (no network) ------------------------------------------

function captureFetch(response: Response) {
  const calls: Array<{ url: string; init: RequestInit }> = [];
  const fn = ((url: string, init: RequestInit) => {
    calls.push({ url, init });
    return Promise.resolve(response.clone());
  }) as unknown as typeof fetch;
  return { calls, fn };
}

Deno.test("Unifonic provider posts AppSid, SenderID, Recipient without +", async () => {
  const f = captureFetch(new Response(JSON.stringify({ success: true }), { status: 200 }));
  await new UnifonicProvider({ appSid: "APP", senderId: "Usra", fetchFn: f.fn }).send("+201001234567", "hi");
  assertEquals(f.calls[0].url, "https://el.cloud.unifonic.com/rest/SMS/messages");
  const form = f.calls[0].init.body as URLSearchParams;
  assertEquals([form.get("AppSid"), form.get("SenderID"), form.get("Recipient"), form.get("Body")], [
    "APP",
    "Usra",
    "201001234567",
    "hi",
  ]);
});

Deno.test("Unifonic provider treats success:false as an error", async () => {
  const f = captureFetch(new Response(JSON.stringify({ success: false }), { status: 200 }));
  await assertRejects(
    () => new UnifonicProvider({ appSid: "APP", senderId: "Usra", fetchFn: f.fn }).send("+201001234567", "hi"),
    SmsProviderError,
  );
});

Deno.test("Twilio provider uses basic auth and a messaging service or From", async () => {
  const f = captureFetch(new Response("{}", { status: 201 }));
  await new TwilioProvider({ accountSid: "AC1", authToken: "tok", from: "MG1", fetchFn: f.fn }).send(
    "+201001234567",
    "hi",
  );
  assertEquals(f.calls[0].url, "https://api.twilio.com/2010-04-01/Accounts/AC1/Messages.json");
  assertEquals((f.calls[0].init.headers as Record<string, string>).Authorization, `Basic ${btoa("AC1:tok")}`);
  const form = f.calls[0].init.body as URLSearchParams;
  assertEquals([form.get("To"), form.get("MessagingServiceSid"), form.get("From")], ["+201001234567", "MG1", null]);

  const g = captureFetch(new Response("{}", { status: 400 }));
  await assertRejects(
    () =>
      new TwilioProvider({ accountSid: "AC1", authToken: "tok", from: "+15005550006", fetchFn: g.fn }).send("+1", "x"),
    SmsProviderError,
  );
});
