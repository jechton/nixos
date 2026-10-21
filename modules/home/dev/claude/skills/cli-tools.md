---
name: cli-tools
description: Reference for token-optimized CLI tools (ast-grep, fastmod, rtk). Load before first use of any code search or rewrite tool, or before running rtk meta commands.
---

# CLI Tools Reference

Token-optimized tools for structural code search, rewriting, and rtk analytics.

## Which tool

1. Renaming a method call, function call, or expression, or any structural
   pattern (use metavariables when arguments vary): `ast-grep`.
2. Literal string replacement (config keys, identifiers, YAML): `fastmod`.
3. rtk token-savings analytics: `rtk gain` or `rtk discover`.

If the target is not a syntax fragment in the language (YAML keys, plain
strings, config values), use `fastmod`, not `ast-grep`.

## ast-grep

AST-aware search and structural rewrite. Metavariables (`$X`, `$$$ARGS`)
match varying expressions and argument lists.

```bash
ast-grep run --pattern '<pattern>' --lang <lang> .
ast-grep run --pattern '<old>' --rewrite '<new>' --lang <lang> -U .
```

Use for renaming a call or expression across a codebase, or when `fastmod`
would wrongly match inside comments and strings. Languages: Java, TypeScript,
JavaScript, Python, Go, Rust, C, C++. Do not use for bare identifiers in
config or YAML, or when the pattern is not a valid syntax fragment.

## fastmod

Fast literal string replacement across many files.

```bash
fastmod --accept-all --fixed-strings <old> <new> -e <ext> .
fastmod --accept-all --fixed-strings old_name new_name -e java,yaml .
```

`--fixed-strings` disables regex interpretation, `-e` restricts by extension.
Use for renaming a config key or identifier. Do not use for method calls or
expressions with structural variation.

## rtk

A PreToolUse hook transparently rewrites Bash commands to filtered `rtk`
equivalents, so run normal commands as usual. Call these meta commands
directly, they are not rewritten:

```bash
rtk gain              # token savings analytics
rtk gain --history    # per-command usage and savings
rtk discover          # scan Claude Code history for missed opportunities
rtk proxy <cmd>       # run a command unfiltered, for debugging
```
