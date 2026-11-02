// SMS providers behind one interface. Unifonic is the regional default;
// Twilio is the alternative. Errors carry status codes only, never the phone
// number or the message (which holds the OTP).

export interface SmsProvider {
  readonly name: string;
  send(toE164: string, body: string): Promise<void>;
}

export class SmsProviderError extends Error {
  constructor(readonly provider: string, readonly status?: number) {
    super(`${provider} send failed${status ? ` (${status})` : ""}`);
  }
}

type FetchFn = typeof fetch;

export type UnifonicOptions = {
  appSid: string;
  senderId: string;
  baseUrl?: string;
  fetchFn?: FetchFn;
};

/** Unifonic REST SMS API (POST /rest/SMS/messages, form-encoded). */
export class UnifonicProvider implements SmsProvider {
  readonly name = "unifonic";
  constructor(private readonly opts: UnifonicOptions) {}

  async send(toE164: string, body: string): Promise<void> {
    const form = new URLSearchParams({
      AppSid: this.opts.appSid,
      SenderID: this.opts.senderId,
      Recipient: toE164.replace(/^\+/, ""),
      Body: body,
      responseType: "JSON",
    });
    const res = await (this.opts.fetchFn ?? fetch)(
      `${this.opts.baseUrl ?? "https://el.cloud.unifonic.com"}/rest/SMS/messages`,
      {
        method: "POST",
        headers: { "Content-Type": "application/x-www-form-urlencoded", Accept: "application/json" },
        body: form,
        signal: AbortSignal.timeout(10_000),
      },
    );
    if (!res.ok) {
      await res.body?.cancel();
      throw new SmsProviderError(this.name, res.status);
    }
    const data = await res.json().catch(() => ({})) as { success?: boolean | string };
    if (data.success !== true && data.success !== "true") throw new SmsProviderError(this.name, res.status);
  }
}

export type TwilioOptions = {
  accountSid: string;
  authToken: string;
  /** Either a Messaging Service SID (MG...) or a sender number / alphanumeric id. */
  from: string;
  baseUrl?: string;
  fetchFn?: FetchFn;
};

/** Twilio Programmable Messaging (POST /2010-04-01/Accounts/{sid}/Messages.json). */
export class TwilioProvider implements SmsProvider {
  readonly name = "twilio";
  constructor(private readonly opts: TwilioOptions) {}

  async send(toE164: string, body: string): Promise<void> {
    const form = new URLSearchParams({ To: toE164, Body: body });
    if (this.opts.from.startsWith("MG")) form.set("MessagingServiceSid", this.opts.from);
    else form.set("From", this.opts.from);

    const res = await (this.opts.fetchFn ?? fetch)(
      `${this.opts.baseUrl ?? "https://api.twilio.com"}/2010-04-01/Accounts/${this.opts.accountSid}/Messages.json`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/x-www-form-urlencoded",
          Authorization: `Basic ${btoa(`${this.opts.accountSid}:${this.opts.authToken}`)}`,
        },
        body: form,
        signal: AbortSignal.timeout(10_000),
      },
    );
    await res.body?.cancel();
    if (!res.ok) throw new SmsProviderError(this.name, res.status);
  }
}
