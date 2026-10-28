# Repository agent instructions

These instructions apply to work in this repository. Follow task-specific instructions as well; do not relax existing code quality, safety, or validation requirements.

## Pull requests

Write PR titles and descriptions for a human reviewer, not as an agent activity log. The goal is to explain **why the change matters, what it does, and how it was validated**. A reviewer unfamiliar with the task should grasp the purpose and review readiness within about 30 seconds.

### Before writing

- Examine the **actual PR diff against its target (base) branch**, which may be another feature branch in a stacked PR. Do not summarize changes already present in the base branch.
- Read the related issue or task for motivation. Verify that your proposed title, behavior claims, and issue references match the implementation.
- Use `Fixes #123` only when the PR truly resolves that issue; otherwise use `Refs #123` or a descriptive link.
- Verify test results, PR dependencies, limitations, and outstanding work from evidence available in this run. Do not claim independent review, CI success, physical-device testing, or other verification without evidence.

### Description format

Follow `.github/pull_request_template.md`; omit optional sections when they add no value.

1. **Summary:** One or two sentences explaining the problem, outcome, and user impact.
2. **What changed:** Usually 2–5 concise bullets, grouping meaningful behavior and significant design decisions. Focus on observable changes; mention implementation details only when they help reviewers understand the approach or risk.
3. **Testing:** Name meaningful automated tests and manual scenarios, and say what passed, failed, or was not run. Distinguish standalone Lua tests, CraftOS-PC/native tests, actual CC:Tweaked/Minecraft or monitor testing, and performance or balance experiments.
4. **Notes (optional):** Call out stacked-PR dependencies, breaking changes, migration steps, unresolved issues, risks, and next steps when relevant.

Keep ordinary PR descriptions around 100–250 words when practical. Longer descriptions are fine for genuinely complex changes, but keep them scannable with short paragraphs and bullets.

### Writing rules

- Prefer clear, outcome-oriented titles (e.g. `Make city banners and unit badges independently selectable`) over vague titles or implementation logs.
- Lead with the user-visible result, then relevant technical context. Be precise and avoid marketing language or unsupported generalizations.
- Do **not** include agent session IDs, temporary test-profile names, worker dispatch details, thread-limit failures, timestamps, or internal orchestration narratives.
- Omit commit hashes, exhaustive command transcripts, and test run identifiers unless they are genuinely needed for reviewer traceability. Link to CI or detailed evidence when it adds value rather than pasting logs.
- Avoid repetitive assertions that unrelated systems were not changed. Mention unchanged behavior only if it addresses an important compatibility concern.
- Do not hide a meaningful failure or unresolved finding to make the description shorter. State it succinctly in Testing or Notes.
- Do not leave template instructions, empty sections, or placeholder text in the submitted PR.

### When updating a PR

Recheck its current base branch, actual diff, and most recent known validation results. Revise the description when the implementation changes materially, preserve accurate caveats, and ensure it still describes **only this PR's changes**.

A PR description is a review summary—not a transcript, release announcement, or substitute for permanent documentation.
