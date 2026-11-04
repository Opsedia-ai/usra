import { assertEquals } from "jsr:@std/assert@1";
import { HttpError, withHttp } from "../../functions/_shared/http.ts";
import { createDeleteAccountHandler } from "../../functions/delete-account/handler.ts";

function setup(opts: { user?: string | null; result?: boolean; fail?: boolean } = {}) {
  const deleted: string[] = [];
  const handler = withHttp(createDeleteAccountHandler({
    getUserId: () =>
      opts.user === null
        ? Promise.reject(new HttpError(401, "unauthorized", "Invalid or expired session"))
        : Promise.resolve(opts.user ?? "user-1"),
    deleter: {
      deleteUser: (id) => {
        if (opts.fail) return Promise.reject(new Error("boom"));
        deleted.push(id);
        return Promise.resolve(opts.result ?? true);
      },
    },
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
