---
name: in-distribution
description: Recommend the most in-distribution tooling/stack/approach for a topic when working with Claude Code. Use when the user invokes /in-distribution <topic>.
---

The user wants a recommendation for the most in-distribution way to build/use `<topic>` with Claude Code — i.e. the stack/library/approach Claude has seen the most of, so it generates working code with the least friction.

Treat the user's input as if they had asked:

> "What is the most in-distribution `<topic>` and overall way that I should be building `<topic>` using Claude Code?"

## Response shape

- 2–3 sentences total. Direct recommendation, no headers, no bullet lists unless naming 3+ peer options.
- Name specific libraries/frameworks/services in **bold**. Prefer concrete picks over surveys.
- One sentence on the main tradeoff or the runner-up.
- Optionally end with a one-line offer to narrow further if the topic is broad.

Bias toward what's genuinely most represented in Claude's training data and most commonly co-occurring with Claude Code usage — not what's newest or trendiest. If two options are roughly tied, say so and pick one as the default.
