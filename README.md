# Claude Code Configuration

A comprehensive, production-ready configuration for [Claude Code](https://claude.com/claude-code) — Anthropic's official CLI for Claude.

This repository contains a complete setup including global instructions, multi-language coding rules, custom skills, MCP server integrations, plugin marketplace management, and a self-improvement loop that learns from corrections across sessions.

## What's Included

```
.
├── CLAUDE.md                    # Global instructions (main config)
├── settings.json                # Claude Code settings (permissions, plugins, model)
├── rules/                       # Multi-language coding standards
│   ├── README.md                # Rules installation guide
│   ├── common/                  # Language-agnostic principles
│   │   ├── coding-style.md      #   Immutability, file organization, error handling
│   │   ├── git-workflow.md      #   Commit format, PR workflow, feature workflow
│   │   ├── testing.md           #   80% coverage, TDD workflow
│   │   ├── performance.md       #   Model selection, context management
│   │   ├── patterns.md          #   Repository pattern, API response format
│   │   ├── hooks.md             #   Pre/Post tool hooks, auto-accept
│   │   ├── agents.md            #   Agent orchestration, parallel execution
│   │   └── security.md          #   Security checks, secret management
│   ├── typescript/              # TypeScript/JavaScript specific
│   ├── python/                  # Python specific
│   └── golang/                  # Go specific
├── mcp/                         # MCP server configurations
│   ├── README.md                # MCP installation & usage guide
│   └── mcp-servers.json         # Server definitions (Context7, GitHub, Playwright)
├── plugins/                     # Plugin marketplace configurations
│   └── README.md                # Plugin installation guide (9 plugins, 5 marketplaces)
├── skills/                      # Custom skills
│   └── paper-reading/
│       └── SKILL.md             # Research paper summarization skill
├── memory/                      # Cross-session memory templates
│   ├── MEMORY.md                # Memory index template
│   └── lessons.md               # Self-correction log template
└── install.sh                   # One-command installer
```

## Quick Start

### Option 1: Install Everything

```bash
git clone https://github.com/YOUR_USERNAME/claude-code-config.git
cd claude-code-config
./install.sh
```

### Option 2: Install Selectively

```bash
./install.sh --rules python typescript  # Rules only
./install.sh --mcp                      # MCP servers only
./install.sh --plugins                  # Plugins only
./install.sh --mcp --plugins            # MCP + Plugins
./install.sh --dry-run                  # Preview all changes
```

### Option 3: Manual Installation

```bash
# 1. Copy global instructions
cp CLAUDE.md ~/.claude/CLAUDE.md

# 2. Merge settings (review first — do NOT overwrite blindly)
cat settings.json

# 3. Install rules (common is required, languages are optional)
cp -r rules/common ~/.claude/rules/common
cp -r rules/python ~/.claude/rules/python
cp -r rules/typescript ~/.claude/rules/typescript
cp -r rules/golang ~/.claude/rules/golang

# 4. Install skills
cp -r skills/paper-reading ~/.claude/skills/paper-reading

# 5. Install MCP servers
claude mcp add --scope user --transport stdio context7 -- npx -y @upstash/context7-mcp@latest
claude mcp add --scope user --transport http github https://api.githubcopilot.com/mcp/
claude mcp add --scope user --transport stdio playwright -- npx -y @playwright/mcp@latest

# 6. Install plugins (see plugins/README.md for full list)
claude plugin marketplace add https://github.com/obra/superpowers-marketplace
claude plugin install superpowers --marketplace superpowers-marketplace
# ... see plugins/README.md for all plugins
```

## Architecture

### Layered Rules System

Inspired by [OpenAI Codex's AGENTS.md](https://developers.openai.com/codex/guides/agents-md/) hierarchical approach, rules are organized in layers:

```
common/          → Universal principles (always loaded)
  ↓ extended by
python/          → Python-specific (PEP 8, pytest, black, bandit)
typescript/      → TypeScript-specific (Zod, Playwright, Prettier)
golang/          → Go-specific (gofmt, table-driven tests, gosec)
```

Each language file explicitly extends its common counterpart. This avoids duplication while allowing language-specific overrides.

### Self-Improvement Loop

The key differentiator: Claude Code **learns from corrections** across sessions.

```
User corrects Claude → Claude writes to memory/lessons.md
                           ↓
Next session starts  → Claude reviews lessons.md
                           ↓
Pattern confirmed    → Rule promoted to CLAUDE.md
```

This creates a feedback loop where recurring mistakes are permanently eliminated.

### Memory System

```
~/.claude/projects/<project>/memory/
├── MEMORY.md      # Index file — loaded into every conversation
└── lessons.md     # Correction log — reviewed at session start
```

## MCP Servers

Three recommended MCP servers for maximum productivity:

| Server | Transport | Purpose |
|--------|-----------|---------|
| **[Context7](https://github.com/upstash/context7)** | stdio | Injects up-to-date library docs into context — no more outdated API suggestions |
| **[GitHub](https://github.com/github/github-mcp-server)** | http | PR/Issue management, code review, CI/CD — all from Claude Code |
| **[Playwright](https://github.com/anthropics/anthropic-quickstarts)** | stdio | Browser automation, E2E testing, screenshots |

See [`mcp/README.md`](mcp/README.md) for detailed installation and configuration.

## Plugins

9 plugins across 5 marketplaces, covering development workflows, document creation, and ML/AI research:

| Category | Plugins | Marketplace |
|----------|---------|-------------|
| **Dev Workflows** | superpowers, everything-claude-code | obra, affaan-m |
| **Documents** | document-skills, example-skills | anthropics/skills |
| **ML/AI Research** | fine-tuning, post-training, inference-serving, distributed-training, optimization | zechenzhangAGI |

See [`plugins/README.md`](plugins/README.md) for the full list with installation commands.

## Key Features

| Feature | Description |
|---------|-------------|
| **Self-Improvement Loop** | Automatically records corrections and learns from them |
| **Plan Mode First** | Non-trivial tasks (3+ steps) always start in plan mode |
| **Subagent Strategy** | Offload research/exploration to subagents, keep main context clean |
| **Autonomous Bug Fixing** | Given a bug report, fix it directly without hand-holding |
| **Verification Before Done** | Never mark complete without proving it works |
| **80% Test Coverage** | TDD workflow enforced: RED → GREEN → REFACTOR |
| **Multi-Language Rules** | Python, TypeScript, Go — extensible to any language |
| **MCP Integration** | Context7 + GitHub + Playwright recommended stack |
| **Plugin Ecosystem** | 9 plugins for dev workflows, docs, and ML research |
| **Bypass Permissions** | All tools auto-allowed for maximum speed (opt-in) |

## Best Practices: Software Development Workflow

This section describes how all the tools in this configuration work together across every phase of development. Each phase shows which tools, skills, MCP servers, and rules are activated.

### Overview: The Full Pipeline

```
Feature Request / Bug Report
         │
         ▼
┌──────────────────┐
│  1. PLANNING     │  brainstorming → writing-plans → Plan Mode
│                  │  MCP: Context7 (lookup API docs)
└────────┬─────────┘
         ▼
┌──────────────────┐
│  2. TDD          │  test-driven-development, tdd-workflow
│  Write tests     │  Rules: testing.md (80% coverage)
│  first           │  Agent: tdd-guide
└────────┬─────────┘
         ▼
┌──────────────────┐
│  3. IMPLEMENT    │  coding-standards, *-patterns
│                  │  Rules: coding-style.md, patterns.md
│                  │  MCP: Context7 (live docs)
└────────┬─────────┘
         ▼
┌──────────────────┐
│  4. REVIEW       │  code-review, security-review
│                  │  python-review / go-review
│                  │  Rules: security.md
└────────┬─────────┘
         ▼
┌──────────────────┐
│  5. E2E TEST     │  e2e, webapp-testing
│                  │  MCP: Playwright (browser)
└────────┬─────────┘
         ▼
┌──────────────────┐
│  6. COMMIT & PR  │  verification-before-completion
│                  │  Rules: git-workflow.md
│                  │  MCP: GitHub (create PR)
└────────┬─────────┘
         ▼
       Done ✓
```

---

### Phase 1: Planning

> "Measure twice, cut once." Never jump into code for non-trivial tasks.

**When**: Any task with 3+ steps, multi-file changes, or architectural decisions.

**Example prompts you can use**:

```bash
# Prompt 1: Open-ended feature — let Claude brainstorm first
> I need to add user authentication to this Next.js app. What are my options?

# Prompt 2: Specific feature — go straight to planning
> Plan the implementation of JWT-based auth with refresh tokens for this Express API.
> Break it into phases with risks and dependencies.

# Prompt 3: Enter plan mode manually for complex tasks
> [Press Shift+Tab twice to enter Plan Mode]
> Analyze this codebase and plan how to refactor the database layer
> from raw SQL to Prisma ORM. Don't change anything yet.

# Prompt 4: Force brainstorming before planning
> /brainstorming — I want to add real-time notifications.
> Consider WebSockets, SSE, polling, and any other approaches.
> Evaluate each on complexity, scalability, and browser support.

# Prompt 5: Delegate research to subagents
> Research these 3 state management options in parallel:
> 1. Redux Toolkit  2. Zustand  3. Jotai
> Compare bundle size, learning curve, and TypeScript support.
```

**What Claude does behind the scenes**:

| Step | Tool | What happens |
|------|------|-------------|
| 1 | `superpowers:brainstorming` | Generates 3-5 approaches, evaluates trade-offs |
| 2 | `superpowers:writing-plans` | Creates phased plan with checkpoints and risks |
| 3 | `everything-claude-code:plan` | Restates requirements, waits for your confirmation |
| 4 | **Context7 MCP** | Pulls latest docs for chosen libraries |
| 5 | `rules/common/agents.md` | Dispatches parallel subagents for research |

**Anti-pattern**: Jumping straight to `vim` or `code .` without a plan.

---

### Phase 2: Test-Driven Development

> Write the test first. Watch it fail. Then make it pass.

**When**: Every feature and every bug fix.

**Example prompts you can use**:

```bash
# Prompt 1: New feature with TDD
> Implement a password strength validator using TDD.
> Write the tests first, then implement.

# Prompt 2: Bug fix with TDD
> Users report that discount codes over 50% break the checkout total.
> Write a failing test that reproduces this, then fix it.

# Prompt 3: Explicit TDD for an existing module
> Add input validation to the /api/users endpoint using TDD:
> 1. Write tests for valid/invalid email, missing fields, SQL injection
> 2. Make them fail
> 3. Implement the validation
> 4. Check coverage

# Prompt 4: Python-specific TDD
> Using pytest, write table-driven tests for the calculate_shipping() function.
> Cover edge cases: zero weight, international, oversized packages.
> Then implement to make them pass.

# Prompt 5: Go-specific TDD
> Write table-driven tests with race detection for the concurrent cache.
> go test -race -cover ./...
```

**The TDD cycle Claude follows**:

```
  RED       → Write a failing test that defines expected behavior
  GREEN     → Write minimal code to make the test pass
  REFACTOR  → Clean up while keeping tests green
  VERIFY    → Check coverage ≥ 80%
```

**Tools activated**:

| Step | Tool | What happens |
|------|------|-------------|
| RED | `superpowers:test-driven-development` | Enforces write-test-first discipline |
| RED | `everything-claude-code:tdd` | Scaffold interfaces → generate tests |
| GREEN | `everything-claude-code:tdd-workflow` | Minimal implementation to pass |
| VERIFY | `everything-claude-code:python-testing` | pytest fixtures, parametrize, mocking |
| VERIFY | `everything-claude-code:golang-testing` | Table-driven tests, `-race` flag |
| VERIFY | `rules/common/testing.md` | 80% coverage minimum |

**Anti-pattern**: Writing implementation first, then retroactively adding tests.

---

### Phase 3: Implementation

> Immutability, small files, small functions. Let Context7 handle the docs.

**When**: After tests are written (Phase 2) and the plan is approved (Phase 1).

**Example prompts you can use**:

```bash
# Prompt 1: Implement to pass tests (continues from Phase 2)
> Now implement the password strength validator to make all tests pass.
> Use immutable patterns. No mutation.

# Prompt 2: Ask Context7 for latest API before coding
> I need to use Zod for validation in this Express app.
> Look up the latest Zod API docs first, then implement
> the request validation middleware.

# Prompt 3: Full-stack feature
> Implement the user profile page:
> - Backend: GET /api/profile endpoint with Prisma
> - Frontend: React component with SWR for data fetching
> - Use the repository pattern for data access
> Check latest Prisma and SWR docs before writing code.

# Prompt 4: Database work
> Add a PostgreSQL migration for the orders table.
> Include proper indexes for the queries in orders.service.ts.
> Use parameterized queries — no string concatenation.

# Prompt 5: Refactor with constraints
> Refactor src/utils/helpers.ts — it's 1200 lines.
> Split into focused modules under src/utils/.
> Each file should be under 400 lines. Keep all existing tests passing.
```

**Coding standards Claude enforces**:

```
  - Immutable data patterns (no mutation)
  - Small files (200-400 lines, 800 max)
  - Small functions (<50 lines)
  - Schema-based validation at boundaries
  - Context7 for latest API usage
```

**Tools activated**:

| Tool | Role |
|------|------|
| `rules/common/coding-style.md` | Immutability, file organization, error handling |
| `everything-claude-code:coding-standards` | Universal best practices |
| `everything-claude-code:python-patterns` | Pythonic idioms, type hints |
| `everything-claude-code:golang-patterns` | Idiomatic Go, interfaces, error wrapping |
| `everything-claude-code:frontend-patterns` | React, Next.js, state management |
| `everything-claude-code:backend-patterns` | API design, database optimization |
| `everything-claude-code:postgres-patterns` | Query optimization, indexing, schema design |
| **Context7 MCP** | Real-time documentation lookup — never use outdated APIs |
| `rules/common/patterns.md` | Repository pattern, API response envelope |

**Key rule**: If you're unsure about an API, ask Context7 before guessing.

---

### Phase 4: Code Review & Security

> Review immediately after writing. Don't wait for PR.

**When**: After any code is written or modified.

**Example prompts you can use**:

```bash
# Prompt 1: Review code you just wrote
> Review the code I just wrote in src/auth/.
> Check for security issues, edge cases, and code quality.

# Prompt 2: Security-focused review
> Run a security review on the entire /api directory.
> Focus on: injection, auth bypass, secrets leakage, CSRF.

# Prompt 3: Language-specific review
> Review src/services/payment.py for Pythonic idioms,
> type hint completeness, and potential security issues.

# Prompt 4: Review before committing
> I'm about to commit. Review all staged changes.
> Flag anything a senior engineer would reject.

# Prompt 5: Review someone else's code (from a PR)
> Review PR #42 on this repo. Focus on correctness,
> security, and whether it follows our coding standards.
```

**What Claude checks**:

```
  1. Code review    → Style, correctness, edge cases
  2. Security scan  → OWASP Top 10, secrets, injection
  3. Language review → Python/Go/TS-specific idioms
```

**Tools activated**:

| Tool | Role |
|------|------|
| `superpowers:requesting-code-review` | Comprehensive review against requirements |
| `everything-claude-code:security-review` | Auth, input validation, secrets, XSS, CSRF |
| `everything-claude-code:python-review` | PEP 8, type hints, security, Pythonic idioms |
| `everything-claude-code:go-review` | Concurrency safety, error handling, idiomatic Go |
| `rules/common/security.md` | Pre-commit security checklist |
| **Language-specific security** | `python/security.md` (bandit), `golang/security.md` (gosec) |

**Severity handling**:
- **CRITICAL/HIGH** → Fix immediately, no exceptions
- **MEDIUM** → Fix when possible
- **LOW** → Note for future cleanup

**Anti-pattern**: Skipping review because "it's a small change."

---

### Phase 5: E2E Testing

> Trust, but verify. In a real browser.

**When**: Critical user flows, UI changes, API integration points.

**Example prompts you can use**:

```bash
# Prompt 1: Generate E2E tests for a user flow
> Write Playwright E2E tests for the login flow:
> 1. Navigate to /login
> 2. Fill email and password
> 3. Click submit
> 4. Assert redirect to /dashboard
> 5. Screenshot each step

# Prompt 2: Test a specific page visually
> Open http://localhost:3000/settings in the browser,
> take a screenshot, and verify all form fields are present.

# Prompt 3: Test form validation
> Test the registration form E2E:
> - Submit with empty fields → expect error messages
> - Submit with invalid email → expect email error
> - Submit with valid data → expect success redirect

# Prompt 4: Debug a visual issue
> Users say the checkout button is hidden on mobile.
> Open the page at 375px width, screenshot it, and check.

# Prompt 5: Full test suite
> Generate a complete E2E test suite for the checkout flow:
> cart → shipping → payment → confirmation.
> Run it and report results with screenshots.
```

**Tools activated**:

| Tool | Role |
|------|------|
| `everything-claude-code:e2e` | Generate Playwright test journeys, run them, capture artifacts |
| `document-skills:webapp-testing` | Interact with and verify local web apps |
| **Playwright MCP** | Direct browser control — click, type, screenshot, assert |
| `rules/typescript/testing.md` | Playwright as E2E framework |

**Anti-pattern**: Only testing with unit tests and hoping the UI works.

---

### Phase 6: Git Workflow & PR

> Conventional commits. Comprehensive PRs. Verify before claiming done.

**When**: Code is reviewed, tests pass, ready to ship.

**Example prompts you can use**:

```bash
# Prompt 1: Commit with verification
> Run all tests, verify everything passes, then commit
> the changes in src/auth/ with an appropriate message.

# Prompt 2: Create a PR
> Create a PR for this branch. Include:
> - Summary of all changes (not just the last commit)
> - Test plan
> - Link to issue #23

# Prompt 3: Work in isolation with worktrees
> Start a worktree for the payment-refactor feature.
> I want to keep my current workspace clean.

# Prompt 4: Review before pushing
> Before I push: run tests, check for secrets in staged files,
> verify no console.log statements. Then push.

# Prompt 5: Squash and merge
> This branch has 12 commits. Squash them into one clean commit,
> then create a PR to main.

# Prompt 6: Simple commit
> /commit
```

**The commit flow**:

```
1. Verify everything works        → run tests, check logs
2. Stage specific files            → git add (never git add -A blindly)
3. Commit with conventional format → feat: / fix: / refactor: / test:
4. Push and create PR              → GitHub MCP handles it
5. PR includes summary + test plan
```

**Tools activated**:

| Tool | Role |
|------|------|
| `superpowers:verification-before-completion` | Run tests, check logs, prove correctness before committing |
| `superpowers:finishing-a-development-branch` | Decide: merge, squash, or rebase |
| `superpowers:using-git-worktrees` | Isolate feature work from main workspace |
| `rules/common/git-workflow.md` | Commit format, PR checklist, branch strategy |
| **GitHub MCP** | Create PR, link issues, manage reviews — without leaving the terminal |

---

### Phase 7: Debugging

> Reproduce → Isolate → Fix → Verify. No guessing.

**When**: Any bug, test failure, or unexpected behavior.

**Example prompts you can use**:

```bash
# Prompt 1: Bug report — just fix it
> Users report 500 errors on POST /api/orders when quantity is 0.
> Find the root cause and fix it.

# Prompt 2: Failing test
> test_calculate_discount is failing. Debug it systematically:
> reproduce, isolate, fix, verify.

# Prompt 3: Build errors
> The Go build is broken after the last merge.
> Fix all build errors and vet warnings.

# Prompt 4: UI bug with visual debugging
> The sidebar overlaps the main content on screens < 768px.
> Open the page in the browser, screenshot it, identify the CSS issue, fix it.

# Prompt 5: Performance issue
> The /api/search endpoint takes 3 seconds.
> Profile the database queries, find the bottleneck, and optimize.

# Prompt 6: Mysterious failure
> CI is green locally but fails on GitHub Actions.
> Check the CI logs, identify environment differences, and fix.
```

**The debugging cycle Claude follows**:

```
  1. Reproduce the issue with a minimal test case
  2. Form hypothesis about root cause
  3. Add diagnostic logging/assertions
  4. Fix the root cause (not symptoms)
  5. Verify fix with the reproduction test
  6. Check for similar issues elsewhere
```

**Tools activated**:

| Tool | Role |
|------|------|
| `superpowers:systematic-debugging` | Structured debugging workflow — no guessing |
| `everything-claude-code:go-build` | Fix Go build errors, vet warnings incrementally |
| `rules/common/coding-style.md` | Error handling patterns |
| **Playwright MCP** | Debug UI issues visually with screenshots |
| **Context7 MCP** | Look up correct API usage when the bug is "wrong API call" |

**Anti-pattern**: Changing random things until tests pass.

---

### Parallel Execution

> Independent tasks should run concurrently, not sequentially.

**When**: 2+ tasks with no shared state or sequential dependency.

**Example prompts you can use**:

```bash
# Prompt 1: Parallel reviews
> In parallel:
> 1. Security review of src/auth/
> 2. Code review of src/api/
> 3. Check test coverage for src/utils/

# Prompt 2: Parallel research
> Research these 3 ORMs in parallel and compare:
> Prisma, Drizzle, TypeORM.
> I need: type safety, performance, migration support.

# Prompt 3: Multi-agent team for a large feature
> Use an agent team to build the notification system:
> - Agent 1: Backend API endpoints
> - Agent 2: Database schema + migrations
> - Agent 3: Frontend notification component

# Prompt 4: Parallel testing
> Run these test suites in parallel:
> 1. Unit tests for services/
> 2. Integration tests for api/
> 3. E2E tests for the checkout flow
```

**Tools activated**:

| Tool | Role |
|------|------|
| `superpowers:dispatching-parallel-agents` | Identify and launch independent parallel tasks |
| `rules/common/agents.md` | Agent orchestration patterns |
| `settings.json` → `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` | Enable multi-agent teams |

---

### Cross-Session Learning

> Every correction makes the system permanently smarter.

**Example prompts you can use**:

```bash
# Prompt 1: Correct Claude (triggers auto-learning)
> No, that's wrong. In this project we use dayjs, not moment.
> Remember this for future sessions.
# → Claude auto-saves to memory/lessons.md

# Prompt 2: Teach a preference
> Always use pnpm in this project, never npm or yarn.
# → Claude saves to memory/MEMORY.md

# Prompt 3: Review what Claude has learned
> Show me your lessons.md — what have you learned from past corrections?

# Prompt 4: Promote a lesson to a permanent rule
> The lesson about using dayjs keeps coming up.
> Add it to CLAUDE.md as a permanent rule.
```

**How it works**:

```
Session 1: User corrects Claude → lesson saved to memory/lessons.md
Session 2: Claude reads lessons.md at start → avoids same mistake
Session N: Pattern confirmed across sessions → rule promoted to CLAUDE.md
```

**Tools activated**:

| Tool | Role |
|------|------|
| `CLAUDE.md` → Self-Improvement Loop | Core instruction to record and review lessons |
| `memory/lessons.md` | Persistent correction log |
| `memory/MEMORY.md` | Index of environment info and preferences |
| `everything-claude-code:continuous-learning` | Auto-extract reusable patterns from sessions |
| `everything-claude-code:continuous-learning-v2` | Instinct-based learning with confidence scores |

---

### Quick Reference: Which Tool for What

| I want to... | Use this |
|---|---|
| Plan a feature | `superpowers:brainstorming` → `superpowers:writing-plans` |
| Write tests first | `superpowers:test-driven-development` |
| Look up library docs | **Context7 MCP** |
| Review my code | `superpowers:requesting-code-review` |
| Check for security issues | `everything-claude-code:security-review` |
| Run E2E browser tests | `everything-claude-code:e2e` + **Playwright MCP** |
| Create a PR | **GitHub MCP** |
| Debug a failing test | `superpowers:systematic-debugging` |
| Run parallel tasks | `superpowers:dispatching-parallel-agents` |
| Fix build errors (Go) | `everything-claude-code:go-build` |
| Fix build errors (TS) | `everything-claude-code:coding-standards` |
| Create a PDF/DOCX/PPTX | `document-skills:pdf` / `docx` / `pptx` |
| Fine-tune a model | `fine-tuning:unsloth` or `fine-tuning:axolotl` |
| Deploy model inference | `inference-serving:vllm` or `inference-serving:sglang` |
| Read a research paper | `paper-reading` skill |
| Optimize model (quantize) | `optimization:awq` / `gptq` / `gguf` |

---

## Customization

### Adding a New Language

1. Create `rules/<language>/` directory
2. Add files extending common rules: `coding-style.md`, `testing.md`, `patterns.md`, `hooks.md`, `security.md`
3. Each file should start with:
   ```
   > This file extends [common/xxx.md](../common/xxx.md) with <Language> specific content.
   ```

### Creating Custom Skills

Place skill files in `skills/<skill-name>/SKILL.md`. See `skills/paper-reading/SKILL.md` for the format.

### Adapting CLAUDE.md

The `CLAUDE.md` file is the most personal — adapt it to your:
- Shell environment (bash/zsh/fish)
- Package manager (conda/pip/uv/npm/pnpm)
- Project context (web dev, ML, robotics, etc.)
- Communication preferences

### Adding More MCP Servers

```bash
# Sentry — Error monitoring
claude mcp add --scope user --transport http sentry https://mcp.sentry.dev/mcp

# Database — PostgreSQL access
claude mcp add --scope user --transport stdio db -- npx -y @bytebase/dbhub \
  --dsn "postgresql://user:pass@host:5432/dbname"
```

## Acknowledgements

The **Workflow Orchestration** section in `CLAUDE.md` (Plan Mode Default, Subagent Strategy, Self-Improvement Loop, Verification Before Done, Demand Elegance, Autonomous Bug Fixing) is inspired by [**@OmerFarukOruc**](https://github.com/OmerFarukOruc)'s excellent [AI Agent Workflow Orchestration Guidelines](https://gist.github.com/OmerFarukOruc/a02a5883e27b5b52ce740cadae0e4d60). His work on structured agent workflows and the `tasks/lessons.md` self-improvement pattern was a key influence on this configuration.

## License

MIT
