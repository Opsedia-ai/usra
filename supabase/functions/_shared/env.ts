// Environment config. Secrets come from `supabase secrets set` (or
// supabase/functions/.env locally) and never from the app.

export function requireEnv(name: string): string {
  const value = Deno.env.get(name);
  if (!value) throw new Error(`Missing required env var ${name}`);
  return value;
}

export function optionalEnv(name: string, fallback: string): string {
  return Deno.env.get(name) || fallback;
}

export function intEnv(name: string, fallback: number): number {
  const raw = Deno.env.get(name);
  if (!raw) return fallback;
  const n = Number.parseInt(raw, 10);
  if (!Number.isFinite(n)) throw new Error(`Env var ${name} must be an integer`);
  return n;
}

export function boolEnv(name: string, fallback: boolean): boolean {
  const raw = Deno.env.get(name);
  if (!raw) return fallback;
  return raw === "true" || raw === "1";
}
