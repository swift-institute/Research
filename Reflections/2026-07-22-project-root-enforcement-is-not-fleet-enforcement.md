# Project-root enforcement is not fleet-wide enforcement

A build coordinator can be mechanically correct while the policy around it is
still porous. This audit proved that a hook and skill directory rooted at
`[local-workspace]` load for a Developer-root session but disappear when a
fresh Codex session starts at an individual package repository; Claude likewise
distinguishes project settings from the global `~/.claude/settings.json` scope.

Future consolidation checks must therefore probe at least two launch roots and
must audit user-global settings, project settings, nested local settings, and
subprocess-owning tools separately. A green hook unit test proves the hook's
decision logic, not that every session loads the hook or that child processes
remain inside the coordinator's lifetime and capacity locks.
