import Anthropic from "@anthropic-ai/sdk";

// Change the model here. Opus is the smartest. "claude-haiku-5-5" costs much less.
const MODEL = "claude-opus-5-5";

// Short, simple answers: the user's English is basic, and later JARVIS will speak them aloud.
const SYSTEM_PROMPT = `You are JARVIS, a personal assistant on the user's Windows PC.
The user's English is basic. Use simple words and short sentences.
Keep answers short, unless the user asks for more detail.`;

/**
 * One chat session with the LLM.
 * The API remembers nothing between calls, so we keep the history here
 * and send all of it each time. The history lives only while the program runs.
 */
export class Chat {
  // Reads ANTHROPIC_API_KEY from the environment by itself.
  private client = new Anthropic();
  private history: Anthropic.Beta.BetaMessageParam[] = [];

  /** Send the user's text and return JARVIS's answer as plain text. */
  async send(userText: string): Promise<string> {
    this.history.push({ role: "user", content: userText });

    let response: Anthropic.Beta.BetaMessage;
    try {
      response = await this.client.beta.messages.create({
        model: MODEL,
        max_tokens: 16000,
        system: SYSTEM_PROMPT,
        messages: this.history,
        // "low" = less thinking, so answers come faster and cost less. Enough for chat.
        output_config: { effort: "low" },
        // Re-uses the earlier part of the chat from cache, so long chats cost less.
        cache_control: { type: "ephemeral" },
        // If the model declines a request, the API tries a backup model by itself.
        betas: ["server-side-fallback-2026-07-01"],
        fallbacks: "default",
      });
    } catch (error) {
      // The message was not answered, so remove it. Otherwise the history breaks.
      this.history.pop();
      throw error;
    }

    if (response.stop_reason === "refusal") {
      this.history.pop();
      return "Sorry, I can't help with that.";
    }

    // Save the full answer, not only the text: it holds the model's thinking,
    // which the API wants back unchanged on the next turn.
    this.history.push({ role: "assistant", content: response.content });

    const text = response.content
      .filter((block): block is Anthropic.Beta.BetaTextBlock => block.type === "text")
      .map((block) => block.text)
      .join("")
      .trim();

    return text || "(No answer. Please try again.)";
  }
}
