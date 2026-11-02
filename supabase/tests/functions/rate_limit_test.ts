import { assertEquals } from "jsr:@std/assert@1";
import { SlidingWindowLimiter } from "../../functions/_shared/rate_limit.ts";

function clock(start = 1_000_000) {
  let t = start;
  return { now: () => t, advance: (ms: number) => (t += ms) };
}

Deno.test("limiter allows up to the limit, then blocks with retry-after", () => {
  const c = clock();
  const limiter = new SlidingWindowLimiter(3, 60_000, c.now);
  assertEquals(limiter.check("u1"), { allowed: true, remaining: 2, retryAfterSeconds: 0 });
  limiter.check("u1");
  assertEquals(limiter.check("u1").remaining, 0);
  c.advance(10_000);
  assertEquals(limiter.check("u1"), { allowed: false, remaining: 0, retryAfterSeconds: 50 });
});

Deno.test("limiter window slides: old hits expire one by one", () => {
  const c = clock();
  const limiter = new SlidingWindowLimiter(2, 60_000, c.now);
  limiter.check("u1");
  c.advance(30_000);
  limiter.check("u1");
  assertEquals(limiter.check("u1").allowed, false);
  c.advance(30_001); // first hit is now outside the window
  assertEquals(limiter.check("u1").allowed, true);
  assertEquals(limiter.check("u1").allowed, false);
});

Deno.test("limiter keeps users separate", () => {
  const limiter = new SlidingWindowLimiter(1, 60_000, clock().now);
  assertEquals(limiter.check("u1").allowed, true);
  assertEquals(limiter.check("u2").allowed, true);
  assertEquals(limiter.check("u1").allowed, false);
});

Deno.test("limiter evicts least-recently-used keys beyond maxKeys", () => {
  const limiter = new SlidingWindowLimiter(1, 60_000, clock().now, 2);
  limiter.check("a");
  limiter.check("b");
  limiter.check("c"); // evicts "a"
  assertEquals(limiter.check("a").allowed, true);
  assertEquals(limiter.check("c").allowed, false);
});
