import { assertEquals, assertRejects } from "jsr:@std/assert@1";
import { HttpError, withHttp } from "../../functions/_shared/http.ts";
import {
  appleClientSecret,
  AppleRevokeError,
  appleRevokerFromEnv,
  createAppleRevoker,
} from "../../functions/delete-account/apple.ts";
import { createDeleteAccountHandler } from "../../functions/delete-account/handler.ts";

function setup(
  opts: {
    user?: string | null;
    gone?: boolean;
    result?: boolean;
    fail?: boolean;
    blockers?: number;
    revokeApple?: (code: string) => Promise<void>;
  } = {},
) {
  const deleted: string[] = [];
  const handler = withHttp(createDeleteAccountHandler({
    getUserId: () =>
      opts.gone
        ? Promise.resolve(null)
        : opts.user === null
        ? Promise.reject(new HttpError(401, "unauthorized", "Invalid or expired session"))
        : Promise.resolve(opts.user ?? "user-1"),
    deleter: {
      blockers: () => Promise.resolve(opts.blockers ?? 0),
      deleteUser: (id) => {
        if (opts.fail) return Promise.reject(new Error("boom"));
        deleted.push(id);
        return Promise.resolve(opts.result ?? true);
      },
    },
    revokeApple: opts.revokeApple,
  }));
  const call = (body: unknown, method = "POST") =>
    handler(
      new Request("http://localhost/delete-account", {
        method,
        headers: { "Content-Type": "application/json", Authorization: "Bearer t" },
        body: method === "POST" ? JSON.stringify(body) : undefined,
      }),
    );
  return { call, deleted };
}

Deno.test("delete-account: deletes the caller's own user", async () => {
  const { call, deleted } = setup({ user: "user-42" });
  const res = await call({ confirm: true, user_id: "someone-else" });
  assertEquals(res.status, 200);
  assertEquals(await res.json(), { status: "deleted" });
  assertEquals(deleted, ["user-42"]);
});

Deno.test("delete-account: needs an explicit confirmation", async () => {
  const { call, deleted } = setup();
  for (const body of [{}, { confirm: "yes" }, [true], null]) {
    const res = await call(body);
    assertEquals(res.status, 400);
    assertEquals((await res.json()).error.code, "confirmation_required");
  }
  assertEquals(deleted, []);
});

Deno.test("delete-account: rejects a missing or bad session before reading the body", async () => {
  const { call, deleted } = setup({ user: null });
  const res = await call({ confirm: true });
  assertEquals(res.status, 401);
  assertEquals(deleted, []);
});

Deno.test("delete-account: reports an already deleted user and backend failures", async () => {
  const gone = await setup({ result: false }).call({ confirm: true });
  assertEquals(await gone.json(), { status: "not_found" });

  const failed = await setup({ fail: true }).call({ confirm: true });
  assertEquals(failed.status, 502);
  assertEquals((await failed.json()).error.code, "delete_failed");
});

Deno.test("delete-account: only POST", async () => {
  const res = await setup().call(undefined, "GET");
  assertEquals(res.status, 405);
});

Deno.test("delete-account: a retry after the user is already gone answers not_found", async () => {
  const { call, deleted } = setup({ gone: true });
  const res = await call({ confirm: true });
  assertEquals(res.status, 200);
  assertEquals(await res.json(), { status: "not_found" });
  assertEquals(deleted, []);
});

Deno.test("delete-account: refuses while a family the user owns has other members", async () => {
  const { call, deleted } = setup({ blockers: 1 });
  const res = await call({ confirm: true });
  assertEquals(res.status, 409);
  assertEquals((await res.json()).error.code, "family_has_members");
  assertEquals(deleted, []);
});

Deno.test("delete-account: revokes Apple before deleting, with the code the app sent", async () => {
  const events: string[] = [];
  const { call, deleted } = setup({
    revokeApple: (code) => {
      events.push(code);
      assertEquals(deleted, [], "revoked first");
      return Promise.resolve();
    },
  });
  const res = await call({ confirm: true, apple_authorization_code: "code-1" });
  assertEquals(res.status, 200);
  assertEquals(events, ["code-1"]);
  assertEquals(deleted, ["user-1"]);
});

Deno.test("delete-account: no code, no Apple call", async () => {
  let calls = 0;
  const { call, deleted } = setup({
    revokeApple: () => {
      calls++;
      return Promise.resolve();
    },
  });
  await call({ confirm: true });
  assertEquals(calls, 0);
  assertEquals(deleted, ["user-1"]);
});

Deno.test("delete-account: Apple failing or not set up never stops the deletion", async () => {
  for (const revokeApple of [() => Promise.reject(new Error("apple token 400")), undefined]) {
    const { call, deleted } = setup({ revokeApple });
    const res = await call({ confirm: true, apple_authorization_code: "code-1" });
    assertEquals(res.status, 200);
    assertEquals(deleted, ["user-1"]);
  }
});

Deno.test("delete-account: a blocked deletion leaves Apple alone", async () => {
  let calls = 0;
  const { call, deleted } = setup({
    blockers: 1,
    revokeApple: () => {
      calls++;
      return Promise.resolve();
    },
  });
  const res = await call({ confirm: true, apple_authorization_code: "code-1" });
  assertEquals(res.status, 409);
  assertEquals(calls, 0);
  assertEquals(deleted, []);
});

Deno.test("delete-account: a bad Apple code is refused and nothing is deleted", async () => {
  for (const bad of [42, "x".repeat(513)]) {
    const { call, deleted } = setup();
    const res = await call({ confirm: true, apple_authorization_code: bad });
    assertEquals(res.status, 400);
    assertEquals(deleted, []);
  }
});

async function appleConfig() {
  const { privateKey, publicKey } = await crypto.subtle.generateKey(
    { name: "ECDSA", namedCurve: "P-256" },
    true,
    ["sign", "verify"],
  );
  const pkcs8 = new Uint8Array(await crypto.subtle.exportKey("pkcs8", privateKey));
  // As a secret is usually stored: one line, with escaped newlines.
  const pem = `-----BEGIN PRIVATE KEY-----\\n${btoa(String.fromCharCode(...pkcs8))}\\n-----END PRIVATE KEY-----`;
  return {
    publicKey,
    config: { clientId: "com.opsedia.usra", teamId: "TEAM123456", keyId: "KEY1234567", privateKey: pem },
  };
}

const unb64url = (part: string) =>
  Uint8Array.from(atob(part.replaceAll("-", "+").replaceAll("_", "/")), (c) => c.charCodeAt(0));

Deno.test("apple: the client secret is an ES256 JWT Apple can check", async () => {
  const { config, publicKey } = await appleConfig();
  const jwt = await appleClientSecret(config, 1_800_000_000_000);
  const [header, payload, signature] = jwt.split(".");
  assertEquals(JSON.parse(new TextDecoder().decode(unb64url(header))), {
    alg: "ES256",
    kid: "KEY1234567",
    typ: "JWT",
  });
  assertEquals(JSON.parse(new TextDecoder().decode(unb64url(payload))), {
    iss: "TEAM123456",
    iat: 1_800_000_000,
    exp: 1_800_000_300,
    aud: "https://appleid.apple.com",
    sub: "com.opsedia.usra",
  });
  assertEquals(
    await crypto.subtle.verify(
      { name: "ECDSA", hash: "SHA-256" },
      publicKey,
      unb64url(signature),
      new TextEncoder().encode(`${header}.${payload}`),
    ),
    true,
  );
});

function fakeApple(token: Response, revoke = new Response("", { status: 200 })) {
  const calls: { url: string; form: URLSearchParams }[] = [];
  const fetchFn = ((url: string, init: RequestInit) => {
    calls.push({ url, form: init.body as URLSearchParams });
    return Promise.resolve(url.endsWith("/auth/token") ? token : revoke);
  }) as typeof fetch;
  return { calls, fetchFn };
}

Deno.test("apple: swaps the code for a token and revokes that", async () => {
  const { config } = await appleConfig();
  const { calls, fetchFn } = fakeApple(Response.json({ access_token: "at", refresh_token: "rt" }));
  await createAppleRevoker(config, fetchFn)("code-1");
  assertEquals(calls.map((c) => c.url), [
    "https://appleid.apple.com/auth/token",
    "https://appleid.apple.com/auth/revoke",
  ]);
  assertEquals(calls[0].form.get("code"), "code-1");
  assertEquals(calls[0].form.get("grant_type"), "authorization_code");
  assertEquals(calls[0].form.get("client_id"), "com.opsedia.usra");
  assertEquals(calls[1].form.get("token"), "rt");
  assertEquals(calls[1].form.get("token_type_hint"), "refresh_token");
  assertEquals(calls[1].form.get("client_id"), "com.opsedia.usra");
});

Deno.test("apple: falls back to the access token when there's no refresh token", async () => {
  const { config } = await appleConfig();
  const { calls, fetchFn } = fakeApple(Response.json({ access_token: "at" }));
  await createAppleRevoker(config, fetchFn)("code-1");
  assertEquals(calls[1].form.get("token"), "at");
  assertEquals(calls[1].form.get("token_type_hint"), "access_token");
});

Deno.test("apple: failures carry only the status, never the code or a token", async () => {
  const { config } = await appleConfig();
  for (
    const [apple, message] of [
      [fakeApple(new Response("secret-body", { status: 400 })), "token_http_400"],
      [fakeApple(Response.json({ refresh_token: "rt" }), new Response("secret", { status: 500 })), "revoke_http_500"],
      [fakeApple(Response.json({})), "token_missing"],
    ] as const
  ) {
    const err = await assertRejects(() => createAppleRevoker(config, apple.fetchFn)("code-1"));
    assertEquals((err as Error).message, message);
  }
});

Deno.test("apple: an answer that isn't JSON is a fixed code, not a quote of it", async () => {
  const { config } = await appleConfig();
  const { fetchFn } = fakeApple(new Response("private-text", { status: 200 }));
  const err = await assertRejects(() => createAppleRevoker(config, fetchFn)("code-1"));
  assertEquals((err as Error).message, "token_bad_response");
});

async function logged(run: () => Promise<unknown>): Promise<string[]> {
  const lines: string[] = [];
  const original = console.error;
  console.error = (...args: unknown[]) => lines.push(args.join(" "));
  try {
    await run();
  } finally {
    console.error = original;
  }
  return lines;
}

Deno.test("delete-account: logs only fixed codes for Apple", async () => {
  const delete1 = setup({ revokeApple: () => Promise.reject(new AppleRevokeError("token_http_400")) });
  assertEquals(await logged(() => delete1.call({ confirm: true, apple_authorization_code: "c" })), [
    "apple_revoke_failed token_http_400",
  ]);
  const delete2 = setup({ revokeApple: () => Promise.reject(new Error("private text from apple")) });
  assertEquals(await logged(() => delete2.call({ confirm: true, apple_authorization_code: "c" })), [
    "apple_revoke_failed unexpected",
  ]);
});

Deno.test("delete-account: a revocation the app had to skip is logged, and still deletes", async () => {
  const { call, deleted } = setup();
  assertEquals(await logged(() => call({ confirm: true, apple_revoke_skipped: true })), ["apple_revoke_skipped"]);
  assertEquals(deleted, ["user-1"]);
});

Deno.test("apple: not set up means no revoker", () => {
  assertEquals(appleRevokerFromEnv(() => undefined), undefined);
  assertEquals(appleRevokerFromEnv((n) => (n === "APPLE_TEAM_ID" ? "T" : undefined)), undefined);
  const all = appleRevokerFromEnv(() => "x");
  assertEquals(typeof all, "function");
});
