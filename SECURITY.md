# Security Policy

## Reporting a vulnerability

If you find a security issue in Flytrap, please **don't** open a public GitHub issue.

Instead, email **<jfaber@caltech.edu>** with:

- A description of the vulnerability
- Steps to reproduce
- The version / commit you reproduced it on (e.g. output of `git rev-parse HEAD` if you built from source, or "downloaded build of YYYY-MM-DD")
- Optional: your suggested fix

I'll acknowledge within a few days and aim to ship a fix or coordinate a disclosure timeline. This is a personal project, so response times are best-effort, not contractual.

## Scope

Flytrap runs entirely on your local machine. It writes Markdown files into a vault path you configure, optionally talks to Apple's local Speech Recognition framework, and (if you opt in by setting `claudeApiKey` in Settings) makes outbound HTTPS requests to `api.anthropic.com`.

Things that count as security issues:

- The app reading or writing files outside the configured vault path.
- The app exfiltrating data over the network without explicit user action (i.e. setting an API key and triggering cleanup).
- A way for another local process to recover or replay your saved Claude API key beyond what `UserDefaults` already exposes.
- Crashes or panics triggered by malformed pasted/dropped media that could be weaponised in any way.

Things that don't:

- "An attacker with full filesystem access can read your vault" — that's the trust model of any local-first app.
- "An attacker who knows your Anthropic API key can use it" — that's true of every Anthropic-API-using app.
- Issues in upstream dependencies (`HotKey`, Apple frameworks). Report those upstream.
