# GitHub refuses to rebase-merge about 100 commits or a branch with merge commits, so split at a packet boundary and rebuild linear

**Tags:** #github #git #release #measured
**Discovered:** the office screensaver's integration branch (T123–T140), [[Sessions/2026-10-23 — T124 office walking skeleton]] · [[Sessions/2026-10-23 — T133 office default pack]]
**Applies to:** [[Projects/aineo]]

## The insight

`main` and `dev` require linear history, so a pull request lands by rebase. GitHub refuses to rebase-merge a pull request of about 100 commits or more (the limit met here), and a branch that holds merge commits cannot be rebase-merged at all. The remedies:

- A feature too big for one pull request is split at a packet boundary: the office went into `dev` as two pull requests, #343 (T124–T128) and #344 (T129–T133), and its later work through a second integration branch (#355).
- A branch with merge commits is rebuilt linear by cherry-picking its commits in order onto the target. The office packets were rebuilt this way and replaced their first pull requests (for example #330 for #327, #335 for #334, #338 for #337, #350 for #348, #351 for #346, #353 for #349); the replaced pull requests were closed.

## Example

The packets of the first office pull requests carried about 89 commits (T124–T128) and about 95 (T129–T133) between them; together they were too many for one rebase merge, so they went into `dev` as two pull requests. Each packet's own pull request into the integration branch had been rebuilt linear first.

## Why it matters

- Plan the split before the integration branch grows, at a boundary where each half passes the suite on its own.
- A rebase merge replays commits under new hashes: record hashes in session notes after the merge, matched by subject on `dev`.
- The exact count at which GitHub refuses was not measured; "about 100" is the order met in practice.
