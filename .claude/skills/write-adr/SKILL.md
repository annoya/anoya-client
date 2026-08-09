---
name: write-adr
description: Record an architecture decision for the vpn2 repository in docs/decisions/ once a feature is finished and work is moving to the next task. Use this at the moment a feature lands — the user says "готово", "двигаемся дальше", "переходим к следующей задаче", or asks to commit finished work — and also whenever they ask to document why something is built the way it is, to record a rejected approach, or to update an existing ADR after changing a subsystem it governs.
---

# Recording a decision

An ADR here exists to stop a settled question from being reopened with the same
wrong answer. That is its whole job. The most valuable part of the document is
not what we chose — it is the list of what we rejected and why, because the
cheap-looking alternative always looks cheap again in six months.

## When to write one

**When the feature is done and work moves to the next task.** That timing is
deliberate. Writing during the discussion produces a record of something that is
still changing; writing weeks later produces a record with the rationale
missing, because by then only the outcome is remembered. The moment of handover
is when both the decision and the reasons are still intact.

Concretely, the trigger is: the feature works, tests pass, and the conversation
is turning to something else.

## When not to write one

Not every fact about the codebase is a decision.

- **A bug is not a decision.** "The route exclusion never worked because a
  hostname was passed where numeric addresses were required" is a defect that
  was fixed. Git remembers it.
- **A temporary workaround is not a decision.** Pinning a dependency to a
  development snapshot because the stable line is broken upstream is a state to
  escape, not a choice to preserve. Recording it as a decision gives it a
  permanence it should not have.
- **A first attempt is not an alternative.** Exploratory work that happened
  before anyone understood the problem does not belong in "Alternatives
  Considered". A real alternative is one a competent person could still choose
  today.

The test: could someone reasonably decide otherwise, and would we want them to
know why we did not? If yes, it is an ADR.

## Granularity

**One record per feature, not per micro-decision.** Everything settled while
building a thing goes in that thing's record. Seamless config switching is one
ADR that also covers the routing question, the ICMP forwarding fix and the
connection-redial behaviour — not four documents that have to be read together
to make sense.

## Format

Copy the shape of an existing record in `docs/decisions/`:

```
# ADR-NNN: <what was decided, as a sentence>

## Status        Accepted / Superseded by ADR-NNN
## Date
## Context       what made this non-obvious — constraints, not history
## Decision      what we do now, the whole feature
## Invariants    what must never break, and which test pins it
## Alternatives Considered   each with why it was rejected
## Evidence      only when settled by measurement — with the numbers
## Consequences  costs, what this rules out, known gaps
## Where It Lives   code and test paths
```

Section by section, what actually matters:

- **Context** states the constraints that made the choice hard. It is not a
  narrative of what we tried. Write it so a reader who never saw the work
  understands the problem.
- **Invariants** is what a test protects. Name the test. The rule in this
  repository is that a failing invariant test means revisiting the decision,
  not fixing the test — so an invariant with no test behind it is a wish.
- **Alternatives Considered** gets one subsection per option with a plain
  reason. Options that other products actually ship deserve the most care,
  because that is where "why don't we just…" comes from.
- **Evidence** exists because many decisions here were settled by running the
  tunnel rather than by argument. Put the numbers in: packet counts, addresses,
  timings. Skip the section entirely for decisions settled by reasoning.
- **Where It Lives** points at the implementation and the test. This is what
  keeps the document honest — a path that no longer exists is a visible signal
  that the ADR needs revisiting.

## After writing

1. Add a row to the table in `docs/decisions/README.md`: number, product
   (`client` / `service` / `both`), one-line decision, what it covers.
2. If it changes what the system *is*, update `docs/SPEC-CLIENT.md` or
   `docs/SPEC-SERVICE.md` — those describe the present tense and carry no
   history.
3. If it establishes a rule an agent must not break, add it to the invariants
   or rules in `AGENTS.md`.
4. If it closes a door, add it to `docs/NON_GOALS.md`.

## Superseding

Never rewrite a record to match a new decision. Mark the old one
`Superseded by ADR-NNN` and leave it in place; the new one explains what
changed. The chain is often the most useful thing in the folder, because it
shows which attractive alternative was already tried and what it cost.

## Recovering context from earlier sessions

If the feature spans work from sessions that are no longer in context, the
reasoning is recoverable: the decisions live in what the user said, and their
messages are a small fraction of the transcript. Extract them with
`scripts/extract-session-messages.py` (in this skill) and read the result —
corrections and rejected ideas cluster in those messages.

```bash
python3 .claude/skills/write-adr/scripts/extract-session-messages.py \
  ~/.claude/projects/<project-dir>/<session-id>.jsonl /tmp/messages.txt
```

Transcripts for this repository live in
`~/.claude/projects/-Users-nethius-Documents-git-startups-vpn2/`. The files are
tens of megabytes — never read one directly; always extract first. For a large
transcript, hand the extraction to a subagent with instructions to return a
registry of decisions grouped by feature, so the raw messages never enter the
main context.
