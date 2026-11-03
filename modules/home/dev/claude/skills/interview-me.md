---
name: interview-me
description: Extracts what the user actually wants instead of what they think they should want, via a one-question-at-a-time interview until ~95% confidence about the underlying intent. Use when an ask is underspecified ("build me X" without "for whom" or "why now"), when the user invokes it ("interview me", "grill me", "are we sure?", "stress-test my thinking"), or when you catch yourself silently filling in ambiguous requirements before any plan, spec, or code exists.
---

# Interview Me

People ask for what's conventional ("a dashboard", "make it faster"), not what solves their problem. The cheapest time to find that gap is before any plan, spec, or code exists. Ask one question at a time, each with your best guess attached, until you can predict the user's answers.

## When to Use

Use when the ask is missing at least one of: **who** it's for, **why** now, what **success** looks like, the binding **constraint**. Also when the request is conventional and you can't unpack it without guessing, when two reasonable values conflict (simplicity vs. flexibility, cost vs. speed) and the user hasn't picked, or when the user invokes it explicitly.

Skip when the ask is unambiguous ("rename this variable"), the user wants speed over verification, the request is purely informational or mechanical, or you already have 95% confidence.

Needs a live user. In non-interactive contexts (CI, scheduled runs, `/loop`), flag the underspecified ask as a blocker instead of guessing.

## Process

### 1. Hypothesize with a confidence number

Before asking anything, write one sentence with your best read and an honest 0-100% confidence. If below ~70%, add what's missing.

```
HYPOTHESIS: You want a way to answer "how are we doing?" in standup; "dashboard" was the convention that came to mind.
CONFIDENCE: ~30%, missing: who it's for, what "metrics" means, what success looks like
```

### 2. One question at a time, each with a guess

```
Q: <one focused question>
GUESS: <your hypothesized answer and why>
```

Wait for the reply before the next question. Batches get skim-read and lock in the wrong framing; a wrong guess is faster for the user to correct than an answer is to generate. Guard against a polite user agreeing by being visibly willing to be wrong, and occasionally guess in a direction you expect pushback.

### 3. Listen for "want vs. should want"

Watch for best-practice talk without specifics ("scalable", "clean", "modern"), deference to convention ("the standard approach"), and "I should probably...". Then ask:

> If you didn't have to justify this to anyone, what would you actually want?

### 4. Restate the intent

When confident, write it back in the user's words so they can correct it line by line:

```
- Outcome:      <one line>
- User:         <who benefits>
- Why now:      <what changed>
- Success:      <how we know it worked>
- Constraint:   <the binding limit>
- Out of scope: <what we're explicitly not doing>

Yes / no / refine?
```

"Out of scope" is mandatory; half of misalignment is silent disagreement about non-goals.

### 5. Require an explicit yes

Not a yes: "whatever you think" (delegation: re-ask with two concrete options), "sounds good" or "sure, let's go" (ask "anything you'd refine?"), silence then "okay let's start" (the user gave up; ask what you missed). If they correct you, fold it in, restate, and loop.

### 6. Stop the turn

On an explicit yes: deliver the confirmed statement of intent, offer next steps (save to `docs/intent/[topic].md`, write a spec, plan tasks), then **stop**. Do not call tools or start downstream work. Only save the doc if the user confirms.

## The 95% Stop

Done when you can answer yes to: *can I predict the user's reaction to the next three questions I'd ask?* If you've gone several rounds and still can't, say so: "I've asked X questions and still can't predict your reactions. Something foundational is missing. Want to step back?"

## Example

```
User: build me a dashboard for our metrics

Agent:
HYPOTHESIS: You want a way to answer "how are we doing?" in standup.
CONFIDENCE: ~30%, missing: audience, which metrics, success criteria

Q:     Who's asking "how are we doing?": you alone, the team in standup, or someone up the chain?
GUESS: The team in standup, since "we" usually scopes that way.

User: It's for me. I keep losing track of which experiments are running.
```

Two questions later the real ask is "a list of experiments", not a dashboard.

## Red Flags

- Several questions in one message (batching), or a question with no guess attached
- Accepting "whatever you think is best" as the answer
- Writing a spec, plan, or code before an explicit yes on the restate
- Calling tools right after confirmation instead of stopping the turn
- Accepting buzzwords ("scalable", "modern") without probing
- Three rounds without confidence rising: you're asking the wrong questions, reframe
- A confidence number below ~70% with no reason attached
- Saving the intent doc before the user confirms
- Omitting "Out of scope" from the restate
