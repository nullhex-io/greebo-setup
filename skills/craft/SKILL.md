---
name: craft
description: "Turn vague developer intent into precise, file-specific agent delegation prompts. Use when delegating work to subagents, new sessions, or worktrees. Explores the codebase, queries memory for proven patterns, and outputs a ready-to-execute prompt."
---

# Craft - Agent Delegation Prompt Generator

Transform vague intent ("audit the payment flow") into precise, file-specific delegation prompts that complete in 1 round trip instead of 10.

## When to Use

- Before spawning a subagent for complex work
- Before starting a new session for a specific task
- Before handing off work to a worktree agent
- When you know WHAT you want done but haven't mapped the HOW yet

## Pipeline

```
Intent -> Explore -> Clarify -> Recall -> Render -> Output
```

### Phase 1: Parse Intent

Extract from the user's request:
- **Domain**: What area of the codebase? (auth, payments, calendar, etc.)
- **Action**: What kind of work? (audit, fix, refactor, add, test)
- **Project**: Which project directory? (infer from cwd or ask)

### Phase 2: Explore (Read-Only Sub-Agent)

Spawn an Explore agent to map the relevant codebase area. The agent MUST be read-only - no edits, no writes.

The explorer uses these tools in this order:

1. **GitNexus route_map** - find API entry points and flows for the domain
   ```
   mcp__gitnexus__route_map(query: "<domain keywords>")
   ```

2. **GitNexus context** - resolve module structure, imports, middleware chains
   ```
   mcp__gitnexus__context(query: "<entry point files>")
   ```

3. **Grep** - find specific patterns, function names, anti-patterns
   ```
   Grep(pattern: "<domain-specific patterns>", type: "ts")
   ```

4. **GitNexus impact** - map blast radius and downstream consumers
   ```
   mcp__gitnexus__impact(query: "<target files>")
   ```

The explorer returns a structured fact sheet:
```json
{
  "entry_points": ["path:line"],
  "core_files": ["path:line_start-line_end"],
  "dependencies": ["path"],
  "patterns_found": ["description"],
  "data_models": ["table/type names"],
  "external_services": ["Stripe, Supabase, etc."]
}
```

<IMPORTANT>
Do NOT send the entire fact sheet as-is. Synthesize it. The prompt you generate must prove YOU understood the codebase - don't delegate understanding to the execution agent.
</IMPORTANT>

### Phase 3: Clarify (0-2 Questions)

Evaluate confidence in scope:
- If the explorer found >3 distinct sub-domains (e.g., "payments" splits into subscriptions, one-off purchases, refunds, payouts), ask which to focus on
- If the action is ambiguous (e.g., "fix" could mean bug fix or refactor), ask what's broken
- If confidence is high and scope is clear, skip questions entirely

Maximum 2 questions. Use AskUserQuestion tool with concrete options derived from exploration, not open-ended questions.

### Phase 4: Recall (Memory Pattern Matching)

Query Cortex for past successful prompts in the same domain:

```
mcp__plugin_cortex_cortex__recall(query: "<action> <domain> prompt", scope: "project")
```

If Cortex returns a past prompt that worked:
- Extract its structural skeleton (what sections it had, what checks it included)
- Adapt the skeleton to the current domain
- Inject proven cross-cutting checks from past audits

If no past prompts exist, use the default template below.

### Phase 5: Render

Apply the strict template. Every field must be filled with concrete facts from the exploration, not placeholders.

```markdown
# TASK: <action> <domain> in <project>

## MISSION
<1-2 sentences. What must be true when the agent is done. No role labels.>

## SCOPE & BOUNDARIES
- Include: <specific flows/features to cover>
- Exclude: <what to NOT touch - test files, unrelated modules, etc.>

## TARGET FILES
<List every relevant file with line ranges where applicable>
- `src/path/to/file.ts` (lines XX-YY) - <what this file does>
- `src/path/to/other.ts` - <role in the flow>

## CROSS-CUTTING CHECKS
<Domain-specific verification points. Be specific to the codebase, not generic.>
1. <Check 1 - name the function/pattern to verify>
2. <Check 2>
3. <Check 3>

## VERIFICATION CRITERIA
<How the execution agent proves the task is done>
1. <Concrete command or assertion>
2. <Negative case - what should NOT happen>

## CONSTRAINTS
<Hard rules the agent must follow>
- Do not modify files outside the scope
- <Project-specific constraints from CLAUDE.md or memory>
```

### Phase 6: Output

1. **Write** the rendered prompt to `.planning/craft/<project>_<domain>_<action>_<date>.md`
2. **Token check**: If the rendered prompt exceeds ~6,000 tokens:
   - Extract the TARGET FILES section with code context into `.planning/SESSION_PRIMER.md`
   - Keep the core prompt lean (MISSION + CHECKS + VERIFICATION)
   - Add instruction: "Read `.planning/SESSION_PRIMER.md` first for file context."
3. **Display** the prompt to the user for review and editing
4. **Remember**: Log to Cortex for future pattern matching
   ```
   mcp__plugin_cortex_cortex__remember(
     content: "<the rendered prompt>",
     metadata: { type: "craft_prompt", project: "<project>", domain: "<domain>", action: "<action>" }
   )
   ```

### Phase 7: Handoff Options

After displaying the prompt, offer the user:
- **Copy**: The prompt is ready to paste into a new session or Agent tool call
- **Spawn**: Launch an Agent with the prompt directly: `Agent(prompt: "<prompt>", description: "<domain> <action>")`
- **Worktree**: Launch in isolation: `Agent(prompt: "<prompt>", isolation: "worktree")`
- **Save only**: Just save to `.planning/craft/` for later use

## Quality Gates

Before outputting, verify:
- [ ] Every file in TARGET FILES actually exists (Glob check)
- [ ] Line numbers reference real code (spot-check 2-3 with Read)
- [ ] No role labels in the prompt ("You are a..." is forbidden)
- [ ] MISSION is 1-2 sentences, not a paragraph
- [ ] CROSS-CUTTING CHECKS are specific to this codebase, not generic advice
- [ ] At least one VERIFICATION criterion is a runnable command
- [ ] Prompt is under 6k tokens (or has been split)

## Anti-Patterns

**Do NOT:**
- Generate a prompt without exploring first. "Audit the auth flow" without knowing what auth files exist is useless.
- Use role labels. "You are a senior security engineer" wastes tokens and constrains the model. State the mission.
- Include generic checks. "Check for SQL injection" when the project uses an ORM with parameterized queries is noise.
- Over-explore. The exploration phase should take 30-60 seconds, not 5 minutes. Use GitNexus graph queries, not sequential file reads.
- Skip the clarify step when scope is genuinely ambiguous. A prompt for "all of payments" when there are 4 distinct payment flows will produce shallow work.

## Examples

### Input: "audit the payment flow in coachsync"

Explorer finds: webhook handler, checkout components, Stripe Connect, credit system, payment links.

Clarify: "I found 5 payment sub-domains: (1) Stripe webhook handlers, (2) Checkout/package purchases, (3) Payment links, (4) Stripe Connect onboarding, (5) Credit deduction. Which to focus on?"

User: "Webhooks and credits"

Cortex returns: past auth audit prompt with 6 flows, 12 files, 5 checks.

Output:
```
# TASK: Audit payment webhooks and credit system in CoachSync

## MISSION
Verify all Stripe webhook handlers and credit deduction paths are idempotent,
tenant-isolated, and handle edge cases (failed payments, refunds, concurrent requests).

## SCOPE & BOUNDARIES
- Include: Webhook route, credit deduction, package fulfillment
- Exclude: Checkout UI, payment link creation, Stripe Connect onboarding, test files

## TARGET FILES
- `src/app/api/stripe/webhook/route.ts` (lines 1-180) - main webhook handler, switch on event type
- `src/lib/stripe.ts` - Stripe client initialization and helpers
- `src/app/api/student/packages/fulfill/route.ts` - client-side fulfillment path
- `src/lib/queries/credits.ts` - credit balance queries and mutations

## CROSS-CUTTING CHECKS
1. Webhook signature validation uses `stripe.webhooks.constructEvent` not manual parsing
2. `checkout.session.completed` handler is idempotent (check for existing fulfillment before inserting)
3. Credit deduction in `deduct_credits` RPC is atomic (single DB call, not read-then-write)
4. Dual fulfillment paths (webhook + client API) cannot double-allocate credits
5. Coach A's webhook cannot affect Coach B's students (tenant isolation via stripe_account_id)

## VERIFICATION CRITERIA
1. Run `npx tsc --noEmit` - zero errors after any changes
2. Trace: a webhook replay of `checkout.session.completed` with same session ID does NOT create duplicate credits
3. FAIL case: removing `stripe.webhooks.constructEvent` should be caught as a finding

## CONSTRAINTS
- Do not modify Stripe API calls or change webhook event subscriptions
- Use existing Supabase client patterns (service role for webhooks)
- Follow existing error handling pattern (log + return 200 to prevent Stripe retries)
```
