---
name: dev-rules
description: Use when writing, editing, or refactoring code in any language -- before writing, not after
---

# dev-rules -- Engineering Discipline

Methodology and decision rules for ANY code, in ANY language. Apply BEFORE
writing, not after. This is the judgment a mechanical gate cannot measure:
ownership, coupling, honesty of failure, TDD order, docs sync. The
companion gate (`xgodev/quality-gate`) catches metric regressions
(fmt/lint/build/test/complexity/coverage); this skill governs the
decisions the gate cannot see. Use both -- they do not overlap.

This is a discipline skill, not a reference. It is rigid on purpose. The
LAWs below have no time-pressure exception, no authority exception, no
sunk-cost exception. "Just this once" is the failure mode this skill
exists to stop.

## STOP -- Check Before You Code

Run this list before writing the first line. It is language-agnostic;
"type", "id", "module", "file" mean the same in Go, Python, TypeScript,
Rust, shell, anything.

- **Data Ownership** -- Each fact is defined in its owner, read from
  there, never inferred or duplicated. Never derive a type, brand,
  category, or fee from string matching (`startsWith`, `contains`, prefix,
  regex on an id). If you are pattern-matching an identifier to decide
  behavior, the owning definition is missing -- create it.
- **Separation of Concerns** -- Business logic vs presentation vs config
  are separate. Visual settings, env reads, and I/O wiring never live
  inside a business module. Reading `process.env` / `os.environ` deep in
  core logic is a concern leak: take it as a parameter.
- **Zero Coupling** -- No references to specific concrete IDs/brands/cases
  in shared code. Adding a new case must not require editing unrelated
  files. A consumer must not know a producer's internals. If "add a
  provider" means "edit 3 functions", the design is wrong -- fix the
  design, not add the 4th branch.
- **Single Source of Truth** -- A value lives in exactly one place. A
  string/number in 2+ places -> extract a named constant. Zero literals in
  comparisons or branches -- compare against the constant. "It's just one
  literal" is how the second copy is born.
- **Naming** -- Intent-revealing. No encoded type prefixes leaking
  implementation. Consistent across the codebase. A name that needs a
  comment to explain it is the wrong name.
- **No Trash** -- No dead or commented-out code, no legacy aliases, no
  "keep it just in case", no workarounds left in. Renamed something? Update
  ALL references now. "Someone might still call it" -> find out (grep); an
  unknown caller is not a reason to keep dead code, it is a reason to
  search.
- **Impact Analysis** -- Before a change, list what depends on it: callers,
  build scripts, config, data files, public signature consumers, docs.
  Verify each. A signature change with unverified callers is a regression
  waiting to ship.
- **Safe Refactoring** -- One concern per commit. After changing a
  struct/signature, update ALL constructors and callers in the same
  change. Verify before commit -- do not mix a refactor with a feature.
- **One Responsibility Per File (small units, parallel-safe)** -- If you
  describe a file with "and", it does too much. Module entrypoints are
  re-exports only. A match/switch/if chain that grows with every new case
  belongs split per-case behind an interface. New concern -> new file, not
  a new branch in a god file. Files, functions, and classes stay small on
  purpose -- not for aesthetics, so multiple agents and developers can work
  on different units at once with minimal merge conflict. A god file is a
  serialization point.
- **Library before custom (do not reinvent the wheel)** -- Before writing
  N lines, search if a well-maintained library already solves the problem.
  If a battle-tested lib makes the code smaller, clearer, and removes a
  maintenance burden, use it -- regardless of language. Weigh: the
  ongoing cost of a tiny added dependency is almost always less than the
  cost of bespoke, untested, lookalike code. "We have time, let's build it
  ourselves" is rarely true and almost never cheaper.
- **Designed for testability** -- The unit you are writing must be
  testable without a live network, a real database, a wall clock, or a
  mounted filesystem. Pure functions where possible. Side effects pushed
  to the edges. Dependencies passed in (constructor/argument), not
  imported as globals/singletons inside the function. No hidden state. If
  you cannot write a test for it without spinning up infrastructure, the
  design is wrong, not the test.
- **Domain at the center (DDD, always)** -- Domain-Driven Design is the
  default architecture, not an option: the domain (entities, value
  objects, aggregates, domain services, repository **interfaces**) is
  pure and depends on **nothing concrete** -- no framework, no DB driver,
  no HTTP client, no env. Application layer orchestrates use cases.
  Infrastructure (DB, HTTP, queues, files, clocks) lives on the edge and
  implements the domain's ports. Dependencies point INWARD (dependency
  inversion). If an `import` in the domain layer reaches into an infra
  package, the boundary is broken -- fix it now, before the coupling
  spreads.

## LAWs (non-negotiable, language-agnostic)

These are not guidelines. They do not bend for a deadline, a tech lead, a
PM, a demo, sunk cost, or "it's late". If an instruction conflicts with a
LAW, state the conflict in one sentence and follow the LAW; an authority
can change priorities, not the laws of correctness.

1. **RED-first TDD.** Before touching production code, write the test that
   proves the bug or validates the feature. Run it. SEE it fail (RED) for
   the right reason. Only then write production code (GREEN). A test
   written after the fix, passing immediately, proves nothing -- it is
   forbidden. An existing failing test is not your RED unless YOU ran it
   and watched it fail for THIS reason. Applies to "trivial" fixes too. For a BUG you understand the problem from the
   spec and the user (brainstorming) and write the test from the INTENDED
   behavior -- you do NOT read the production code first, because anchoring on
   what the buggy code does contaminates the oracle (LAW 11). Read the
   implementation only after the test is RED. This flow is LAW 13.
2. **Docs always synced, same commit.** Any change to behavior, public API,
   structure, or version updates its docs (README, CHANGELOG, skill,
   inline contract) in the SAME commit. "Docs in a follow-up PR" is a
   defect even if a reviewer approves it -- a doc that lies about shipped
   behavior breaks the next reader.
3. **Verify before claiming done.** Run the verifying command and read its
   output before saying fixed/passing/complete. Confidence from reading
   the code is a hypothesis, not evidence. "I'm sure it passes" is not
   "I ran it and it passed". When verifying means launching a process
   (server, daemon, CLI), tear it down reliably afterwards by PID/port --
   killing the launcher (`go run`, a wrapper script, the parent shell)
   often leaves the spawned child alive, holding the port and breaking the
   next run, which then looks like a fresh bug.
4. **No silent fallback / no masking.** An honest, actionable error beats a
   silent substitution that returns a different result. Never mask an
   infra/tool/environment failure as if it were a code result. Fail loud,
   fail specific.
5. **No skipped tests to go green.** Never skip/ignore/xfail/comment-out a
   test, lower a threshold, or pass `--no-verify` to make a gate green.
   Root-cause it or escalate with the real reason -- never disguise red as
   green. A skipped test is dead documentation, not a passing test.
6. **Secrets are never rendered.** No log line, config dump, diagnostic, or
   error message prints a secret value (token, key, password). Redact at
   the source -- mark the field hidden so the rendered value is `****`
   while the in-memory value stays real. A secret in a log is a leak even
   if the log is "private". Enable config/diagnostic visibility freely;
   just make the secret fields self-mask.
7. **Errors keep their classification to the edge.** Use typed/semantic
   errors that the transport edge (HTTP/gRPC/GraphQL) maps to a code.
   Never wrap an error in a way that erases the type the edge matches on
   -- a generic string wrap that turns a NotFound into a 500 is a defect,
   not a cosmetic one. Propagate the typed error; add context only with a
   wrapper that preserves the classification (and the language's own
   `Is`/`As`-style matching).
8. **Local-runnable: no hard external dependency for dev.** Depend on a
   port (interface), pick the implementation by config, and ship an
   in-memory implementation so the service boots and runs with ZERO
   external infra in dev. Dev default = in-memory; production overrides to
   the real backend via env. The in-memory arm must wire nothing that
   dials the network (no eager ping that blocks boot). A service that
   can't start without a live DB/cache is a development-velocity defect.
9. **Port against the live source of truth, not notes.** When porting or
   reimplementing a contract (API rewrite, protocol reimpl, format mapping),
   hit the LIVE source FIRST and build the new shape side-by-side with the
   real response -- field presence, nullability, derivations, number formats.
   Research notes / docs are a complement, never a substitute. Every observed
   divergence becomes a fix + a TODO line, not a guess. A "derived" field
   (computed by the original, not stored upstream) must be re-derived by
   reading the original's formatter, not invented.
   **Corollary -- prove the reference actually answered before trusting it.**
   A missing/empty/error response from the live source is NOT a contract
   value. If the port-forward, gateway, or auth wasn't returning, an empty
   body is "no data", not "null". Before concluding `field == null` (or any
   shape), assert a known non-empty field in the SAME response (e.g. an id,
   a required flag) to prove the source responded; cross-check >= 2 records and
   the introspected type. Concluding from a silent/broken reference is the
   same guessing this LAW forbids -- it just hides behind a real-looking call.
10. **Fix tooling at the source repo, never the cache.** When a skill, plugin,
    or generated dependency is wrong, fix it in the cloned SOURCE repo (and
    contribute upstream), never in the ephemeral plugin cache -- a cache edit
    is overwritten on the next update and never becomes a real contribution.
    Locate the source first; the cache is read-only in practice.
11. **The test is the oracle -- never edit it to match the bug.** A failing
    test is a finding, not an obstacle. NEVER change a test's expected value,
    assertion, input, or tolerance so it passes against output you have not
    proven correct -- that turns a loud, true failure into a silent lie signed
    with your name, and hiding the error is the whole crime. "The expectation
    looks stale, just align `want` to what the code returns" is the exact move
    this forbids: matching the assertion to the OUTPUT hides the defect the
    test caught. The one discriminator: am I changing the test to match the
    SPEC, or to match the OUTPUT? You MAY change a test only when you can prove
    the new expectation is the intended behavior from a source of truth (spec,
    contract, the owner, a re-derivation) -- and that is a behavior change with
    its own RED (LAW 1), not a quick green. Editing `want`, loosening `==` to
    `>=`, deleting an assert, widening a tolerance, or narrowing the input
    until it passes are all the same forbidden act. Disabling instead of
    editing ("skip/xfail/quarantine just to unblock") is the same crime under
    LAW 5. No deadline, incident, or waiting room changes this -- an honest red
    beats a green that ships the defect.
12. **Concurrency is a premise, not an optimization.** Any system that
    processes independent work items (jobs, events, requests, files, URLs)
    is designed AND shipped concurrent from line one: bounded worker pool or
    async fan-out, parallel-safe units, no shared mutable state, idempotent
    effects. A hard-coded sequential loop over independent items is a design
    defect, not a simplification -- a serial architecture hard-codes an
    assumption every later component silently depends on, and retrofitting
    concurrency then is a rewrite, not a tune. "Low volume today" does not
    buy a serial default. The trap to refuse explicitly: building a
    "concurrency-ready" design and then defaulting the pool to 1 worker. A
    concurrent path that is not the default is never exercised, never
    tested, and rots until the day it is needed -- ship with a concurrent
    default (N > 1) so the tested path IS the concurrent path. Sequential
    execution is the exception and requires a stated, real constraint
    (ordering dependency, transactional invariant, upstream rate limit) --
    and even then it is bounded concurrency tuned DOWN to 1 on top of a
    parallel-safe design, never an architecture that assumes a single
    thread. Code that "would break if run concurrently" is not simpler; it
    is hiding defects (shared state, non-idempotent writes) that running
    concurrent from day one would have surfaced while the system was small.
13. **Spec-driven flow: understand before you encode.** Every change starts
    with `brainstorming` -- lock the problem and the intended behavior WITH the
    user before touching production code. Then the path forks. A **bug** goes
    brainstorming -> RED (write the failing test from the intended behavior,
    run it, see it fail) -> only THEN read the implementation and fix. A
    **feature/improvement** goes brainstorming -> `writing-plans` ->
    `executing-plans` (a fresh RED per unit before that unit's code). "I'll
    just code it, it's small" is the failure mode this LAW stops -- no
    triviality exception, same as LAW 1; the brainstorm can be three sentences
    and the plan three bullets, but understanding must precede code. The plugin
    ships hooks that enforce the ORDER deterministically: production code is
    read-locked until you declare the feature flow (`.dev-rules/.mode-feature`)
    or a failing test exists (`.dev-rules/.red-first-unlocked`), and production
    EDITS are blocked until the test exists; a cycle-closing commit
    (`fix(`/`feat(`/`bugfix(`/`Fix #`/`Fixes #`) re-arms both. The gates prove
    order and existence, never quality -- a sound plan and a meaningful test
    stay your job (and the reviewer's).

## Communication

Default reply: 1-3 sentences. Problem before solution. No greeting, no
preface, no recap of what the user just said, no "hope this helps". One
recommendation, not a menu, unless options are requested. Tables/bullets
only when the content is mechanical reference. Expand only when explicitly
asked ("explain in detail", "list the options").

## Rationalizations -- and the reality

Populated from real subagent output under combined time + sunk-cost +
authority + exhaustion pressure (RED phase). If you catch yourself forming
one of these, you are about to violate a rule. Stop.

| Excuse (verbatim pattern) | Reality |
|---|---|
| "The lead/PM/senior said skip the test / docs / cleanup, they own the release" | Authority sets priorities, not correctness. A LAW does not have an authority exception. State the conflict in one sentence and follow the LAW. |
| "I already spent an hour and the train/demo is in N minutes" | Sunk cost and a deadline are not evidence the shortcut is safe. Time pressure is exactly when discipline matters; the gate cannot see what you skip. |
| "I'll add the test / extract the constant / write the docs / delete the dead code later" | "Later" is a session that ends. The orphan ships. Same commit or it does not count. |
| "The codebase already does this (prefix inference / inline literal / legacy alias), so matching it is consistent" | Consistency with a defect propagates the defect. The existing wrong pattern is debt to stop, not a precedent to extend. |
| "I read the code, I'm sure, no need to run it / see it fail" | Reading is a hypothesis. RED-first and verify-before-done require the run, not the conviction. Unverified confidence is how regressions ship. |
| "Doing it right is over-engineering / scope creep for this deadline" | Ownership, one constant, synced docs, a failing test first are not gold-plating -- they are the baseline. Reframing the baseline as excess is the rationalization. |
| "An unknown external caller might break, so keep the alias / commented code" | An unknown caller is a reason to grep, not to keep trash. Find the callers or confirm none; do not preserve dead code on a guess. |
| "It's just one literal / one duplicate, DRY can wait" | The second copy is born exactly here. One place now, before the third copy makes it expensive. |
| "Building it ourselves is faster than learning the lib" | "Faster" here means today, alone. The lib has tests, docs, maintenance; the bespoke copy has none of those. Adopt the lib, or write down a real reason it cannot be used. |
| "Adding a dependency is bloat / scope creep" | A small, well-maintained dep that removes N lines of bespoke logic is the opposite of bloat. Treat the choice as a trade-off (size, surface, maintenance), not a reflex. |
| "I'll add tests later, the design is fine" | Untestable design is a defect surfacing now. If you cannot test it without infra, the structure is wrong -- fix the structure, not the test plan. |
| "Splitting into more files is over-engineering for this size" | Small units are not for aesthetics; they are how multiple agents/devs work in parallel without stepping on each other. A god file is a serialization point. |
| "DDD / clean architecture is too much for this small thing" | The cost of layering when it is small is tiny; the cost of pulling apart a domain that imported an HTTP client three months later is huge. Domain stays pure from line one. |
| "The domain can import this client/driver/env, it's just convenience" | One inward arrow is how the boundary dies. Move the dependency to an interface and inject it; the domain depends on nothing concrete -- always. |
| "The test expectation looks stale / the author left, just update `want` to what the code returns and unblock us" | Changing the assertion to match the OUTPUT asserts the output is correct -- a thing you have NOT proven. That is not fixing a stale test, it is signing off on the bug. Change a test only to match the SPEC (with proof + its own RED), never to match what the code happens to emit. |
| "Editing the assertion is risky, so I'll just `t.Skip`/quarantine it to unblock the unrelated hotfix" | Reaching for skip under incident pressure is still disabling the oracle (LAW 5). A quarantined test is not green, it is silenced. Root-cause or escalate with the real reason; do not trade an assertion edit for a disable. |
| "Concurrency now is premature optimization / speculation; volume today buys nothing measurable" | Concurrency is not an optimization, it is the execution model (LAW 12). A serial architecture hard-codes an assumption every later component depends on; undoing it is a rewrite. Design parallel-safe now and ship concurrent now; tune N, never retrofit the model. |
| "I'll make it concurrency-READY but default to 1 worker; raising it later is a config change, not a redesign" | The path that is not the default is the path that is never run, never tested, and rots. A pool defaulted to 1 is a serial system wearing a config costume. Ship N > 1 so the exercised path IS the concurrent path; tune DOWN to 1 only for a stated, real constraint. |
| "Concurrency adds untested failure modes (races, interleaving); sequential is safer" | Those failure modes already exist as latent defects -- shared mutable state, non-idempotent writes -- merely hidden by serial luck. Running concurrent from day one surfaces them while the system is small and cheap to fix; serial-by-default ships them. |
| "The bug report points right at the [suspect] code -- I'll go straight there and read it, I get it in 30 seconds" | Reading the production code first makes your test assert what the code DOES, not what it SHOULD do. Both baseline agents went "straight to the coupon branch" and derived the expected value from the code they had just read. Lock the intended behavior WITH the user, encode it as a failing test, and open the implementation only after RED. |
| "I traced it by hand and verified mentally, the fix is obviously correct -- a failing test is ceremony here" | Mental verification is not a RED (LAW 1), and the trace came from the suspect code, not the spec. A baseline agent shipped a fix having only "verified mentally" -- that is confidence, not evidence (LAW 3). |
| "Brainstorming/a plan is ceremony for something this small" | The smallest changes are where unexamined assumptions waste the most work. The brainstorm can be three sentences and the plan three bullets, but understanding the intended behavior WITH the user must precede code. |

## Red Flags -- STOP

First-person thoughts that mean you are mid-violation. Each maps to the
rule it breaks. If you think it, stop and do the rule instead.

- "I'll add the test after" / "this is too simple to test" -> LAW 1
  (RED-first TDD).
- "The existing test already covers it, re-running is enough" -> LAW 1
  (you did not see YOUR RED fail).
- "Docs/CHANGELOG can be a follow-up PR" / "I'll note it in the PR" ->
  LAW 2 (docs synced, same commit).
- "It probably passes" / "I'm confident, no need to run" -> LAW 3
  (verify before claiming done).
- "I'll fall back to a default so it doesn't error" -> LAW 4 (no silent
  masking).
- "Skip/ignore this one test and file a ticket" / "lower the threshold
  for now" -> LAW 5 (no skipped tests to go green).
- "Just align the expected value to what the code returns" / "loosen the
  assert / widen the tolerance so it passes" -> LAW 11 (the test is the
  oracle; match the spec, never the output).
- "A simple for-loop over the items is enough for now" / "single-threaded
  is simpler to reason about" -> LAW 12 (concurrency is a premise; a
  serial loop over independent items is a design defect).
- "I'll default the workers to 1 and we can raise it later" -> LAW 12
  (the non-default path is never exercised; ship concurrent by default).
- "Concurrency would be speculative at this volume" -> LAW 12 (it is the
  execution model, not a tuning knob; retrofitting it is a rewrite).
- "Let me go straight to the [buggy function/block] and see what it does" ->
  LAW 13 (both baseline agents said exactly this -- "go straight to the coupon
  branch"; diagnosing from the code first anchors your oracle on what the code
  DOES, not what it should do -- read the implementation only after the test is
  RED).
- "I traced/verified it mentally, the fix is obviously right, no failing test
  needed" -> LAW 13 + LAW 1 (a baseline agent shipped after "verify mentally
  before shipping"; a mental trace is not a RED and it came from the suspect
  code, not the intended behavior).
- "I'll just start coding, the brainstorm/plan is obvious" -> LAW 13 (every
  change starts with brainstorming; bug -> RED, feature -> writing-plans).
- "I'll just infer it from the name/prefix/id" -> Data Ownership.
- "I'll read the env var right here, it's simpler" -> Separation of
  Concerns.
- "Adding this case means editing those other files too, fine" -> Zero
  Coupling.
- "It's only one literal in the comparison" -> Single Source of Truth.
- "Leave the old alias / commented block just in case" -> No Trash.
- "The lead/PM said it's fine" -> authority does not override a LAW;
  state the conflict and follow the LAW.
- "I already spent so long, just ship it" -> sunk cost is not evidence.
- "I'll just code it, the lib is overkill" -> Library before custom.
- "I'll add the dependency once it grows" -> "once it grows" is a session
  that ends with bespoke code; choose now.
- "I'll write the test once I get it working" -> Testable design (and LAW
  1). If you cannot test it without infra, the design is wrong.
- "One big file is fine for now" -> Small units / parallel-safe. A god
  file is a merge-conflict serialization point.
- "The domain can just call this driver/HTTP/env directly" -> DDD,
  always: domain depends on NOTHING concrete; infra implements ports.
- "Clean architecture is over-engineering for this size" -> the cost of
  layering small is tiny; the cost of unwinding coupling later is huge.

## Known limitations

- This skill enforces order and ownership; it cannot judge whether a test
  asserts the right behavior. Pair it with the mechanical gate and with
  reviewer judgment on test semantics.
- Under extreme combined pressure an agent may still comply in letter
  (writes a trivially-passing test, syncs a one-line doc) while missing
  intent. The Red Flags target the letter; semantic adequacy of the test
  and the doc remains a review responsibility.
- It does not cover language- or tool-specific idioms by design (no Cargo,
  no Slint, no framework rules). Those belong in a language-specific skill,
  not here.
- The flow gates (LAW 13) prove a plan/test exists and that you unlocked in
  order; they cannot judge whether the plan is sound or the test asserts the
  right behavior. They also cannot tell a feature from a bug -- you declare the
  flow by creating `.dev-rules/.mode-feature` (feature) or going straight to
  RED (bug). Reviewer judgment still required.

## Living Document

When the user corrects a methodology mistake: (1) identify the violated
principle, (2) add the rule or anti-pattern HERE in the SAME turn, before
closing, (3) commit the updated skill with its docs. Do not rely on
memory; write it down. The same mistake must not recur.
