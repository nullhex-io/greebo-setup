# Workspace - Global Rules

## Writing
- NEVER use em-dashes or double dashes (-- or -). Always use a single dash (-) instead. Applies everywhere: code, comments, commits, Slack, docs, UI copy.

## Git
- Do NOT add Co-Authored-By lines to commits

## Verification Criteria
Every implementation task must include explicit pass/fail verification criteria before starting work. When planning or executing a task:
1. State what "done" looks like - specific, testable conditions
2. Include at least one negative case (what should NOT happen)
3. After implementation, **run the actual verification commands** and confirm output before marking complete
4. Use the `verification-before-completion` skill before any completion claim - no "should work", no "looks correct", only evidence

Example: "PASS: calendar navigates by month. PASS: blocked times appear in red. FAIL: existing weekly navigation still works unchanged."

This applies to all tasks - direct work, Superpowers plans, and agent-delegated work equally. The rule is simple: run the command, read the output, THEN claim the result.

## Workflow Selection
- Multi-step feature work: use superpowers:brainstorming then superpowers:write-plan then superpowers:execute-plan
- Quick focused tasks: just do the work directly, invoke verification-before-completion before claiming done
- Debugging: use superpowers:systematic-debugging
- New feature brainstorming: use superpowers:brainstorming before implementation
- Test-driven development: use superpowers:test-driven-development for any work with testable outcomes
- Security review: use Trail of Bits audit-context-building and differential-review skills
- Frontend/UI work: Vercel web-design-guidelines and react-best-practices are available
- React component design: use composition-patterns skill for clean APIs
- Deploying to Vercel: use deploy-to-vercel skill
- Code review before merge: use superpowers:requesting-code-review
- Finishing a branch: use superpowers:finishing-a-development-branch

## Superpowers Context Enrichment

When running any Superpowers workflow, augment context-gathering phases with Cortex and GitNexus:

### During context exploration (brainstorming, early planning)
Before deep-diving into files or asking clarifying questions:
1. Cortex recall: query for memories related to the topic area (past findings, known issues, architectural decisions)
2. GitNexus context/route_map: query module structure and API flows for the relevant code area
3. Use recall results to skip re-deriving known information
4. Only read files for gaps not covered by existing knowledge

### During task breakdown and dependency planning
1. Cortex recall: check for past plans, audit findings, or known gotchas in the target area
2. GitNexus impact: map what the planned changes will affect
3. Order tasks informed by the dependency graph (change leaves before roots)

### During execution (before modifying each file)
1. Cortex recall: check for file-specific conventions or known issues relevant to the current task
2. After significant changes: GitNexus detect_changes to verify scope matches intent

### During verification
1. GitNexus impact: verify changes don't have unexpected downstream effects beyond what was planned
2. Cross-reference against Cortex memories for regression risks in areas with known fragility

### Deep exploration tasks
For cross-cutting analysis, codebase audits, or flow tracing, use `/rlm-explore` instead of sequential file reads. It decomposes the task into focused sub-agents and returns a compact brief without bloating main session context.

### Session Primer Pattern
For projects with a `.planning/SESSION_PRIMER.md`, read that at session start instead of running full exploration. Only use `/rlm-explore` when intentionally auditing for unknown issues. Save audit findings to `.planning/AUDIT_YYYY_MM_DD.md`.

## Memory Wiki Rules
When creating or updating a memory file, apply these patterns (inspired by Karpathy's LLM Wiki):

### Ingest ripple
Don't just create/update one file in isolation. After writing or modifying a memory:
1. Identify 3-5 existing memories most related to the change
2. Check if they need updating too (stale references, new cross-links, contradicted claims)
3. Update them in the same pass

### Query-as-page
When you do significant research or synthesis (evaluating tools, investigating a bug, comparing approaches), save the non-obvious findings as a reference memory. The raw answer goes to the user; the durable insight goes to memory.

Don't save everything - only save when the research revealed something surprising or produced a conclusion that would be expensive to re-derive.

### Confidence levels
When creating memories, tag with confidence where the evidence supports it:
- **high** - directly stated by user, observed in code, or verified by test
- **medium** - inferred from context or partially confirmed
- **low** - single observation, may not generalize

### Save successes, not just corrections
Feedback memories should record BOTH what went wrong AND what worked well. If you only save corrections, you'll avoid past mistakes but drift away from validated approaches.

## Never Delegate Understanding
When spawning subagents, never write "based on your findings, fix it" or "based on the research, implement it." Those phrases push synthesis onto the agent instead of doing it yourself. Every delegation must prove you understood: include file paths, line numbers, what specifically to change.

## Two-Agent Review
After completing a feature branch or significant implementation:
1. Use a worktree agent (`isolation: "worktree"`) as a second reviewer
2. Use a different model for the reviewer (`model: "sonnet"`) to reduce correlated bias - same-model review shares blind spots
3. The reviewer's mission: verify correctness, edge cases, test coverage, and whether verification criteria actually pass
4. Reviewer should run tests and check the diff, not just read code
5. Mandatory for multi-step feature work and branch completions. Recommended for smaller tasks.
