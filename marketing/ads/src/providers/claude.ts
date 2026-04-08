import Anthropic from '@anthropic-ai/sdk';

const client = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY });

export const SCRIPT_MODEL = 'claude-sonnet-4-6';

export async function generate(opts: {
  system: string;
  user: string;
  maxTokens?: number;
}): Promise<string> {
  const res = await client.messages.create({
    model: SCRIPT_MODEL,
    max_tokens: opts.maxTokens ?? 4096,
    system: opts.system,
    messages: [{ role: 'user', content: opts.user }],
  });
  const text = res.content
    .filter((b): b is Anthropic.TextBlock => b.type === 'text')
    .map((b) => b.text)
    .join('\n');
  return text;
}
