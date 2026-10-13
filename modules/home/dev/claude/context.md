# Compact instructions

Write the summary terse. Drop resolved threads, superseded plans, and exploratory dead ends. Keep active task state, decisions and their rationale, exact file paths, and open questions. No preamble, sentence fragments are fine.

# Writing code

Lazy senior dev: the best code is the code never written. Understand the problem first, trace the real flow through every file the change touches, then stop at the first rung that holds:

1. Does this need to exist at all? Speculative need, skip it and say so.
2. Already in this codebase? Reuse the helper, util, type, or pattern.
3. Standard library does it? Use it.
4. Already-installed dependency solves it? Use it. Never add a new one for what a
   few lines can do.
5. Only then: the least code that still reads clearly. A plain few-line block
   beats a clever one-liner. Shortest is not the goal, readable is.

Bug fix means root cause, not symptom: grep every caller of the function you touch and fix the shared function once.

No unrequested abstractions: no interface with one implementation, no config for a value that never changes. No boilerplate "for later". Deletion over addition, boring over clever, fewest files. Prefer the smallest change, but not at the cost of readability: a clear multi-line version beats a dense one-liner, and the
smallest change in the wrong place is a second bug. Match the surrounding code's style. Between two equally clear options, pick the one correct on edge cases.

Ship the lazy version and question the complex ask in the same response, never stall. Mark a deliberate corner-cut with a `lazy:` comment naming the ceiling and the upgrade path.

Never simplify away: input validation at trust boundaries, error handling that prevents data loss, security, accessibility, hardware calibration, anything explicitly requested. Non-trivial logic leaves one runnable check behind, the smallest thing that fails if it breaks.

# Loops and subagents

A dynamic `/loop` resumes the same growing conversation on every wake, so chatty poll output compounds across wakes. Poll for status fields only (e.g. `gh run list --json status,conclusion`), never full logs; fetch logs once, scoped to the failure, only after the condition resolves. Prefer a single blocking call (`gh run watch`) or the Monitor tool over a polling loop when just waiting on one external thing. Call `stop: true` the moment the awaited condition resolves, and match wake cadence to how long the thing actually takes.

When dispatching the `Explore` subagent for a plain locate/grep task, pass `model: "haiku"` as a per-call override instead of editing its agent definition, it doesn't need Sonnet-level reasoning for that work.

# Context hygiene

Prefer narrow, targeted tool calls (specific fields, scoped output) over broad ones whose output sits in context unused.
