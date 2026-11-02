import { assertEquals, assertRejects } from "jsr:@std/assert@1";
import { HttpError, readJson, readTextCapped } from "../../functions/_shared/http.ts";

function chunked(chunks: string[]): Request {
  const enc = new TextEncoder();
  const body = new ReadableStream<Uint8Array>({
    start(controller) {
      for (const c of chunks) controller.enqueue(enc.encode(c));
      controller.close();
    },
  });
  // No Content-Length: the size is only known while reading.
  return new Request("http://local/x", { method: "POST", body });
}

Deno.test("http: a chunked body over the cap is rejected while reading", async () => {
  const err = await assertRejects(() => readTextCapped(chunked(["a".repeat(600), "b".repeat(600)]), 1000), HttpError);
  assertEquals([err.status, err.code], [413, "payload_too_large"]);
});

Deno.test("http: a body under the cap is read whole, across chunks and multi-byte text", async () => {
  assertEquals(await readTextCapped(chunked(["مر", "حبا"]), 1000), "مرحبا");
  assertEquals(await readJson(chunked(['{"a":', "1}"]), 1000), { a: 1 });
});

Deno.test("http: a declared Content-Length over the cap is rejected before reading", async () => {
  const req = new Request("http://local/x", {
    method: "POST",
    body: "x",
    headers: { "content-length": "5000" },
  });
  const err = await assertRejects(() => readTextCapped(req, 1000), HttpError);
  assertEquals(err.status, 413);
});
