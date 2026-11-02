// In-memory sliding-window rate limiter. It lives inside one function
// instance, so it only stops bursts; the durable quota is in Postgres
// (consume_ocr_quota). The clock is injectable for tests.

export type RateLimitDecision = {
  allowed: boolean;
  remaining: number;
  retryAfterSeconds: number;
};

export class SlidingWindowLimiter {
  private readonly hits = new Map<string, number[]>();

  constructor(
    private readonly limit: number,
    private readonly windowMs: number,
    private readonly now: () => number = Date.now,
    private readonly maxKeys = 10_000,
  ) {}

  check(key: string): RateLimitDecision {
    const now = this.now();
    const since = now - this.windowMs;
    const recent = (this.hits.get(key) ?? []).filter((t) => t > since);

    if (recent.length >= this.limit) {
      this.hits.set(key, recent);
      const retryAfterMs = recent[0] + this.windowMs - now;
      return { allowed: false, remaining: 0, retryAfterSeconds: Math.max(1, Math.ceil(retryAfterMs / 1000)) };
    }

    recent.push(now);
    this.hits.delete(key); // re-insert so the map stays in least-recent order
    this.hits.set(key, recent);
    this.evict();
    return { allowed: true, remaining: this.limit - recent.length, retryAfterSeconds: 0 };
  }

  private evict(): void {
    while (this.hits.size > this.maxKeys) {
      const oldest = this.hits.keys().next().value;
      if (oldest === undefined) break;
      this.hits.delete(oldest);
    }
  }
}
