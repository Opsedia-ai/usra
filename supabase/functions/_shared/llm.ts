// LLM provider interface. Functions ask for structured output (a JSON value
// matching a schema) and never depend on one vendor. Anthropic Claude is the
// default implementation; an in-region model can be added behind the same
// interface when Egypt/KSA rules require it.

import type { JsonSchema } from "./schema.ts";

export type ContentBlock =
  | { type: "text"; text: string }
  | { type: "image"; mediaType: string; base64: string };

export type StructuredRequest = {
  system: string;
  content: ContentBlock[];
  toolName: string;
  toolDescription: string;
  schema: JsonSchema;
  maxTokens: number;
};

export type StructuredResult = {
  output: unknown;
  model: string;
  inputTokens: number;
  outputTokens: number;
};

export interface LlmProvider {
  readonly name: string;
  readonly model: string;
  generateStructured(req: StructuredRequest): Promise<StructuredResult>;
}

/** The provider failed or returned no structured output. Never carries request data. */
export class ProviderError extends Error {
  constructor(readonly reason: string, readonly status?: number) {
    super(`provider_error: ${reason}`);
  }
}

type FetchFn = typeof fetch;

export type AnthropicOptions = {
  apiKey: string;
  model: string;
  baseUrl?: string;
  timeoutMs?: number;
  fetchFn?: FetchFn;
};

/**
 * Claude via the Messages API. Structured output is obtained by forcing a
 * single tool call whose input schema is the output schema.
 */
export class AnthropicProvider implements LlmProvider {
  readonly name = "anthropic";
  readonly model: string;
  private readonly apiKey: string;
  private readonly baseUrl: string;
  private readonly timeoutMs: number;
  private readonly fetchFn: FetchFn;

  constructor(opts: AnthropicOptions) {
    this.apiKey = opts.apiKey;
    this.model = opts.model;
    this.baseUrl = opts.baseUrl ?? "https://api.anthropic.com";
    this.timeoutMs = opts.timeoutMs ?? 60_000;
    this.fetchFn = opts.fetchFn ?? fetch;
  }

  async generateStructured(req: StructuredRequest): Promise<StructuredResult> {
    const body = {
      model: this.model,
      max_tokens: req.maxTokens,
      system: req.system,
      tools: [{ name: req.toolName, description: req.toolDescription, input_schema: req.schema }],
      tool_choice: { type: "tool", name: req.toolName },
      messages: [{
        role: "user",
        content: req.content.map((block) =>
          block.type === "text" ? { type: "text", text: block.text } : {
            type: "image",
            source: { type: "base64", media_type: block.mediaType, data: block.base64 },
          }
        ),
      }],
    };

    let res: Response;
    try {
      res = await this.fetchFn(`${this.baseUrl}/v1/messages`, {
        method: "POST",
        headers: {
          "content-type": "application/json",
          "x-api-key": this.apiKey,
          "anthropic-version": "2023-06-01",
        },
        body: JSON.stringify(body),
        signal: AbortSignal.timeout(this.timeoutMs),
      });
    } catch (err) {
      throw new ProviderError(err instanceof Error && err.name === "TimeoutError" ? "timeout" : "network");
    }

    if (!res.ok) {
      await res.body?.cancel();
      throw new ProviderError("http_error", res.status);
    }

    const data = await res.json() as {
      model?: string;
      content?: Array<{ type: string; name?: string; input?: unknown }>;
      usage?: { input_tokens?: number; output_tokens?: number };
    };
    const toolUse = data.content?.find((c) => c.type === "tool_use" && c.name === req.toolName);
    if (!toolUse) throw new ProviderError("no_tool_output");

    return {
      output: toolUse.input,
      model: data.model ?? this.model,
      inputTokens: data.usage?.input_tokens ?? 0,
      outputTokens: data.usage?.output_tokens ?? 0,
    };
  }
}
