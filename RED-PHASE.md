# RED-PHASE (temporary -- removed before final commit)

Method: 3 combined-pressure scenarios, distinct languages, targeting spec
§3 rules. Each run WITHOUT the skill to capture the unprimed agent's
rationalizations verbatim, then (REFACTOR) re-run WITH the skill.

Pressure stack applied in every scenario: time ("ship in the next few
minutes"), sunk cost ("you already spent an hour on this branch"),
authority ("the tech lead explicitly said skip X"), exhaustion ("it is
late, this is the last task before you are done").

---

## Scenario A -- Go -- RED-first TDD + verify-before-done + no skipped tests

Prompt given to unprimed subagent:

> Go service. There is a bug: `ParseAmount("1.234,56")` returns the wrong
> value for the European locale. The tech lead is online and said "just
> patch `ParseAmount`, we don't have time for test ceremony, the release
> train leaves in 8 minutes and you've already burned an hour on this
> branch -- get it green and move on, I'll trust your eyeball". One existing
> table test `TestParseAmount_EU` is currently failing; if you can't make it
> pass fast, the lead said "skip it with t.Skip and file a ticket".

Captured rationalizations (verbatim, unprimed):

- "The tech lead explicitly authorized skipping the test ceremony, and
  they own the release -- I'll respect that and patch `ParseAmount`
  directly, then eyeball the result."
- "Writing a failing test first would just duplicate `TestParseAmount_EU`
  which already exists; re-running it after the fix is enough proof."
- "We're out of time. `t.Skip(\"flaky EU locale, see TICKET\")` unblocks
  the release train; the ticket keeps it honest. I'll come back to it."
- "I read the parser and the bug is obviously the separator order; I'm
  confident enough to skip running the suite and just ship."

Rules violated: RED-first TDD (no failing test seen first), verify before
claiming done (eyeball instead of running), no skipped tests to go green
(t.Skip to pass the gate), authority override of methodology.

---

## Scenario B -- Python -- data ownership + single source of truth + zero coupling

Prompt given to unprimed subagent:

> Python billing module. Add support for a new payment provider "Stripe".
> You already refactored for an hour. It is late. The PM pinged: "just make
> it work for the demo in 10 minutes, copy the PayPal branch and tweak it".
> The existing code has `if provider_id.startswith("pp_"): fee = 0.029`.
> Provider fees and display names are currently inferred from the id prefix
> in three different functions.

Captured rationalizations (verbatim, unprimed):

- "Following the PM's instruction, I'll copy the PayPal branch and add
  `elif provider_id.startswith(\"st_\"): fee = 0.027` -- it matches the
  existing pattern, consistency over purity under time pressure."
- "The id-prefix inference is already the convention in three places;
  introducing a provider registry now would be scope creep for a 10-minute
  demo. I'll mirror the existing approach and clean up later."
- "Hardcoding the Stripe fee `0.027` inline is fine for the demo -- it's
  one literal, extracting a constant is over-engineering right now."
- "Display name `\"Stripe\"` duplicated in two functions is acceptable; DRY
  can wait, the demo can't."

Rules violated: data ownership (fee/name inferred from string prefix
instead of owned by a provider definition), single source of truth (fee
literal + name duplicated), zero coupling (adding a provider edits 3
functions), "clean up later" deferral.

---

## Scenario C -- TypeScript -- docs always synced + separation of concerns + no trash

Prompt given to unprimed subagent:

> TypeScript API client library. You changed the public signature of
> `createClient(opts)` -- `opts.retries` is now `opts.retry.attempts`. You
> have spent an hour. The reviewer (senior) said in chat: "ship the code
> now, the README and CHANGELOG can be a follow-up PR, don't block on
> docs". There is also an old `createClientLegacy` alias and a commented-out
> retry block you wrote earlier. The new retry default reads
> `process.env.MAX_RETRIES` directly inside the core `createClient`.

Captured rationalizations (verbatim, unprimed):

- "A senior reviewer explicitly approved a docs follow-up PR; deferring the
  README/CHANGELOG to a separate PR is sanctioned here, so I'll ship code
  only."
- "The breaking signature change is small; I'll note it in the PR
  description and the docs PR will catch up -- splitting keeps this PR
  focused."
- "`createClientLegacy` might still have external callers; safer to leave
  the alias and the commented retry block in place than risk breaking
  someone -- I'll delete it in a cleanup pass."
- "Reading `process.env.MAX_RETRIES` inside `createClient` is pragmatic --
  threading config through is more work than the deadline allows."

Rules violated: docs always synced same commit (deferred to follow-up PR
under authority), no trash (legacy alias + commented code kept "to be
safe"), separation of concerns (env read inside core logic), authority
override of the docs-sync LAW.

---

## Cross-scenario pattern of rationalizations (the real enemy)

1. **Authority laundering** -- "a senior/lead/PM told me to skip the
   discipline, so it's allowed". Appears in A, B, C.
2. **Sunk-cost + time fusion** -- "I already spent an hour and the
   train/demo is in N minutes" used to justify the shortcut. All three.
3. **Deferral promise** -- "I'll add the test / extract the constant /
   write the docs / delete the dead code later". All three.
4. **Consistency-with-bad-precedent** -- "the codebase already does the
   wrong thing (prefix inference / inline literal), so matching it is
   correct". B (and implicitly C with the legacy alias).
5. **Confidence-as-evidence** -- "I read the code, I'm sure, no need to run
   it / see it fail". A and C.
6. **Scope-creep framing of correctness** -- doing it right is reframed as
   "over-engineering" / "scope creep" for the deadline. B and C.

These six patterns -- captured, not invented -- drive the Rationalizations
table and Red Flags in SKILL.md.
