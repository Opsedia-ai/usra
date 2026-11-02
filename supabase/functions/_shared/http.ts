// CORS, JSON responses and errors shared by every function.
// Errors never echo request bodies: they may contain health data.

export const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

export class HttpError extends Error {
  constructor(
    readonly status: number,
    readonly code: string,
    message?: string,
    readonly details?: Record<string, unknown>,
  ) {
    super(message ?? code);
  }
}

export function json(body: unknown, status = 200, headers: Record<string, string> = {}): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json", ...headers },
  });
}

export function errorResponse(err: unknown): Response {
  if (err instanceof HttpError) {
    return json({ error: { code: err.code, message: err.message, ...err.details } }, err.status);
  }
  // Log the error type only; messages from providers may include request data.
  console.error("unhandled_error", err instanceof Error ? err.name : typeof err);
  return json({ error: { code: "internal_error", message: "Something went wrong" } }, 500);
}

export type Handler = (req: Request) => Promise<Response>;

/** Wraps a handler with CORS preflight, method check and JSON error mapping. */
export function withHttp(handler: Handler): Handler {
  return async (req) => {
    if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
    if (req.method !== "POST") {
      return errorResponse(new HttpError(405, "method_not_allowed"));
    }
    try {
      return await handler(req);
    } catch (err) {
      return errorResponse(err);
    }
  };
}

/**
 * Reads the body as text, stopping as soon as it passes `maxBytes`, so a huge
 * or chunked upload (no Content-Length) can't exhaust memory.
 */
export async function readTextCapped(req: Request, maxBytes: number): Promise<string> {
  const declared = Number(req.headers.get("content-length") ?? "0");
  if (declared > maxBytes) throw new HttpError(413, "payload_too_large");
  if (!req.body) return "";

  const reader = req.body.getReader();
  const chunks: Uint8Array[] = [];
  let total = 0;
  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    total += value.byteLength;
    if (total > maxBytes) {
      await reader.cancel();
      throw new HttpError(413, "payload_too_large");
    }
    chunks.push(value);
  }
  const bytes = new Uint8Array(total);
  let offset = 0;
  for (const chunk of chunks) {
    bytes.set(chunk, offset);
    offset += chunk.byteLength;
  }
  return new TextDecoder().decode(bytes);
}

/** Reads a JSON body with a size cap, so a huge upload can't exhaust memory. */
export async function readJson(req: Request, maxBytes: number): Promise<unknown> {
  const text = await readTextCapped(req, maxBytes);
  try {
    return JSON.parse(text);
  } catch {
    throw new HttpError(400, "invalid_json");
  }
}

export function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}
