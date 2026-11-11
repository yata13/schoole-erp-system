import * as readline from "node:readline/promises";
import { stdin, stdout } from "node:process";
import Anthropic from "@anthropic-ai/sdk";
import { Chat } from "./llm/chat.js";

// Load the API key from .env. Node can do this by itself, so we need no extra package.
try {
  process.loadEnvFile(".env");
} catch {
  console.error("No .env file found. Copy .env.example to .env and put your API key in it.");
  process.exit(1);
}

const apiKey = process.env.ANTHROPIC_API_KEY;
if (!apiKey || apiKey === "your-key-here") {
  console.error("ANTHROPIC_API_KEY is missing in .env. Put your API key there.");
  process.exit(1);
}

/** Turn an error into a short message the user can act on. */
function explainError(error: unknown): string {
  if (error instanceof Anthropic.AuthenticationError) {
    return "Error: the API key is not valid. Check ANTHROPIC_API_KEY in .env.";
  }
  if (error instanceof Anthropic.RateLimitError) {
    return "Error: too many requests. Wait a minute and try again.";
  }
  if (error instanceof Anthropic.APIConnectionError) {
    return "Error: cannot reach the server. Check your internet connection.";
  }
  if (error instanceof Anthropic.APIError) {
    return `Error ${error.status}: ${error.message}`;
  }
  return `Error: ${String(error)}`;
}

async function main(): Promise<void> {
  const chat = new Chat();
  const rl = readline.createInterface({ input: stdin, output: stdout });

  // Ctrl+C or Ctrl+D closes the input. We stop the loop instead of crashing.
  let open = true;
  rl.on("close", () => {
    open = false;
  });

  console.log('JARVIS is ready. Type a message and press Enter. Type "exit" to quit.\n');

  while (open) {
    let text: string;
    try {
      text = (await rl.question("You: ")).trim();
    } catch {
      break; // Input was closed while waiting.
    }

    if (!text) continue;
    if (text.toLowerCase() === "exit") break;

    try {
      const answer = await chat.send(text);
      console.log(`\nJARVIS: ${answer}\n`);
    } catch (error) {
      // Show the problem but keep the chat running, so one bad call does not end the session.
      console.error(`\n${explainError(error)}\n`);
    }
  }

  rl.close();
  console.log("\nGoodbye!");
}

main();
