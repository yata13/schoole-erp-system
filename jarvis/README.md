# JARVIS

A personal AI assistant for your Windows PC.
We build it step by step. **Now: Step 1, terminal chat.**

## Folders

```
jarvis/
  .env.example     example settings file (copy it to .env)
  package.json     packages and the "npm start" command
  tsconfig.json    TypeScript settings
  src/
    index.ts       starts JARVIS: reads what you type, prints the answer
    llm/
      chat.ts      talks to Claude and keeps the chat history
    speech/        (Step 2 and 3: voice output and voice input)
    memory/        (Step 4: saved facts)
```

Each part is its own module. Later we can add new parts (for example, PC control) without changing the others.

## Setup (one time)

1. Install **Node.js 22 or newer** (the "LTS" version) from https://nodejs.org
2. Open PowerShell in the `jarvis` folder.
3. Install the packages:

   ```
   npm install
   ```

4. Make your settings file and open it:

   ```
   copy .env.example .env
   notepad .env
   ```

5. Put your Claude API key after `ANTHROPIC_API_KEY=` and save.
   You get a key at https://platform.claude.com (API keys page).

## Run

```
npm start
```

Type a message and press Enter. Type `exit` (or press Ctrl+C) to quit.

## Test Step 1

1. Type `Hello`. JARVIS should answer.
2. Type `My name is Sam`. Then type `What is my name?`. JARVIS should say "Sam".
   This shows the history works.
3. Quit and start again. Ask `What is my name?`. JARVIS should NOT know.
   History lives only while the program runs. (Saved memory comes in Step 4.)
4. Put a wrong key in `.env` and start again. You should see a clear error message.

## Cost

JARVIS uses the model `claude-opus-5-5`, with low thinking effort to keep it fast and cheap.
To pay much less, open `src/llm/chat.ts` and change `MODEL` to `"claude-haiku-5-5"`.
