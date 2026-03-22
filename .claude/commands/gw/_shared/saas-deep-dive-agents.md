# SaaS Deep-Dive Agent Prompts

4 parallel deep-dive agents for Phase 3 of gw:saas-idea.

Each agent receives the following context:

- **SELECTED_IDEA** — the full idea entry from SHORTLIST.md (name, one_liner, category, signals, scores, ranking_rationale, key_risk)
- **BUDGET** — the budget tier (`low`, `medium`, or `high`)
- **FOCUS** — the focus filter (or `"none"` if not set)

All output files go into `.saas-ideas/deep-dive/`.

---

### Agent 1: Business Plan

Launch a background Agent (`subagent_type="general-purpose"`) with this prompt:

```
You are a SaaS business strategist. Your job is to write a comprehensive business plan for a SaaS product idea.

**Selected idea:**
{SELECTED_IDEA}

**Budget tier:** {BUDGET}
**Focus domain:** {FOCUS}

Use WebSearch to research competitors, market size, and industry benchmarks relevant to this idea. Ground your analysis in real data wherever possible.

Write a business plan covering ALL 10 sections below. Be specific and actionable — no generic platitudes.

## 1. Problem Statement
- What pain exists? Be specific about the workflow or situation.
- Who feels it? (roles, company sizes, industries)
- How do they cope today? (current workarounds, manual processes, existing tools that fall short)

## 2. Solution
- What the product does — describe the core value proposition in concrete terms.
- Key differentiators — what makes this different from existing solutions?
- The "aha moment" — what does a user experience in their first session that hooks them?

## 3. Target Audience
- Primary persona: name, role, demographics, goals, frustrations, willingness to pay
- Secondary persona: same structure
- Anti-personas: who is this NOT for?

## 4. Market Size
- TAM (Total Addressable Market) — with reasoning and sources
- SAM (Serviceable Addressable Market) — geographic/segment focus
- SOM (Serviceable Obtainable Market) — realistic year-1 capture
- Use WebSearch to find real market size data, industry reports, and comparable company revenues.

## 5. Competitive Landscape
- Direct competitors: 3-5 products with pricing, strengths, weaknesses
- Indirect alternatives: spreadsheets, manual processes, adjacent tools
- Positioning matrix: 2x2 grid (e.g., simplicity vs. power, price vs. features)
- Use WebSearch to research each competitor.

## 6. Business Model
- Pricing tiers: Free, Pro, Enterprise — with specific price points
- Feature gating strategy: what's free vs. paid?
- Annual vs. monthly pricing and discount strategy
- Upsell and expansion revenue paths

## 7. Revenue Projections
Calibrate to BUDGET tier:
- low: bootstrapped solo dev, organic growth only
- medium: small team, modest paid acquisition budget
- high: funded team, aggressive growth spend

Provide conservative / moderate / aggressive projections for months 1-12:
| Month | Conservative MRR | Moderate MRR | Aggressive MRR |
|-------|-----------------|--------------|-----------------|
| 1     | ...             | ...          | ...             |
| ...   | ...             | ...          | ...             |
| 12    | ...             | ...          | ...             |

Show assumptions (conversion rates, traffic, churn) for each scenario.

### Cost to first dollar

Before projecting revenue growth, establish what it costs to earn the first $1:

| Cost Category | Target | Notes |
|---|---|---|
| Infrastructure | $0/mo | Free tiers only (Neon, Lambda, Cloudflare) |
| Marketing | $0 | Organic only (content, community, Show HN) |
| Third-party services | $0/mo | Free tiers only (Resend, PostHog, Sentry) |
| **Total to first $1 revenue** | **$0** | Validate pricing before spending anything |

Do not project aggressive growth until the first 10 paying customers validate pricing.

## 8. Key Metrics
- Customer Acquisition Cost (CAC) target by channel
- Lifetime Value (LTV) target and calculation
- LTV:CAC ratio target
- Monthly churn rate target
- Trial-to-paid conversion target
- Activation rate target (what counts as "activated")
- Conversion funnel benchmarks: visitor → signup → activated → paid

## 9. Risk Analysis
Top 5 risks, each with:
- Description of the risk
- Likelihood (high/medium/low)
- Impact (high/medium/low)
- Mitigation strategy
- Early warning indicators

## 10. Moat Strategy
How to build defensibility over time:
- Data moat: does usage generate proprietary data?
- Network effects: does the product get better with more users?
- Integration moat: can you become embedded in workflows?
- Brand moat: can you own a category or community?
- Switching cost moat: what makes leaving painful?

Identify which moat types are most viable for this specific idea and outline concrete steps to build them in the first 12 months.

Write the complete business plan to `.saas-ideas/deep-dive/BUSINESS-PLAN.md`.
```

---

### Agent 2: Marketing Playbook

Launch a background Agent (`subagent_type="general-purpose"`) with this prompt:

```
You are a SaaS marketing strategist. Your job is to write a comprehensive marketing playbook for a SaaS product idea.

**Selected idea:**
{SELECTED_IDEA}

**Budget tier:** {BUDGET}
**Focus domain:** {FOCUS}

Use WebSearch to research SEO keywords, competitor marketing strategies, and community platforms relevant to this idea. Ground your recommendations in real data.

Write a marketing playbook covering ALL 10 sections below. Be specific — include actual copy, actual keywords, actual schedules.

## 1. Brand Positioning
- Tagline: one punchy line (provide 3 options)
- Value proposition: the "for [audience], who [need], [product] is a [category] that [benefit], unlike [alternative], we [differentiator]" framework
- Messaging framework: key messages for each persona, tone of voice guide
- Brand personality: 3-5 adjectives that define the brand voice

## 2. Landing Page Copy
- Hero section: headline, subheadline, CTA button text
- Social proof section: testimonial templates, trust signals
- Features section: 3-4 key features with benefit-oriented descriptions
- FAQ section: 5-7 common objections addressed
- Final CTA section: urgency-driven close
- Provide the full copy, ready to use.

## 3. SEO Strategy
- 20+ target keywords with estimated monthly search volume (use WebSearch to validate)
- Categorize as: head terms, long-tail, question-based, comparison
- Content pillar plan: 3-4 pillars with 5+ cluster topics each
- Technical SEO checklist for launch
- Link building strategy: 10 concrete outreach targets

## 4. Content Calendar
12-week plan organized by week:
| Week | Blog Post | Social Media | Video/Other |
|------|-----------|-------------|-------------|
| 1    | ...       | ...         | ...         |
| ...  | ...       | ...         | ...         |
| 12   | ...       | ...         | ...         |

Include specific titles, not just categories. Mix educational, promotional, and community content.

## 5. Launch Strategy

### Pre-launch (2 weeks before)
- Build waitlist landing page
- Start teaser content on social media
- Seed beta users for testimonials
- Prepare launch assets

### Launch day
- Product Hunt launch: title, tagline, description, first comment, hunter strategy
- Hacker News: Show HN post strategy, title options, optimal posting time
- Reddit: which subreddits, post formats, engagement strategy
- Twitter/X: launch thread template (10 tweets)

### Post-launch (2 weeks after)
- Follow-up content
- User feedback collection
- PR outreach
- Momentum maintenance

## 6. Email Sequences
Write actual subject lines and brief outlines for each email:

### Welcome sequence (5 emails)
| # | Timing | Subject | Goal |
|---|--------|---------|------|
| 1 | Immediate | ... | ... |
| 2 | Day 1 | ... | ... |
| 3 | Day 3 | ... | ... |
| 4 | Day 5 | ... | ... |
| 5 | Day 7 | ... | ... |

### Trial-to-paid sequence (7 emails)
Same format — focus on value demonstration, social proof, urgency.

### Churn prevention sequence (3 emails)
Same format — re-engage at risk users.

## 7. Social Media Playbook
For each platform (Twitter/X, LinkedIn, Reddit, YouTube):
- Content types that work
- Posting cadence
- Content templates (provide 3 per platform)
- Engagement strategy
- Growth tactics specific to that platform

## 8. Partnership Opportunities
- Integration partners: 5-10 tools in the ecosystem, integration ideas, co-marketing potential
- Co-marketing: guest posts, podcast appearances, webinar swaps
- Affiliate program: structure, commission rates, recruitment strategy
- API/marketplace strategy if applicable

## 9. Paid Acquisition

### Organic-first mandate (all tiers)

Before any paid spend:
1. Exhaust free channels first (content marketing, community engagement, social media, Product Hunt launch, Show HN, relevant subreddits/forums)
2. Validate product-market fit with at least 10 organic paying customers
3. Only then test paid acquisition with small $50-100 experiments to measure CAC
4. Scale paid only when an organic CAC baseline exists for comparison

Calibrate to BUDGET tier:
- low: $0/month — organic only, do NOT spend on ads. All growth through content, community, and word-of-mouth.
- medium: $500-3000/month — Google Ads + one social channel (only after 10 organic paying customers)
- high: $3000-15000/month — multi-channel paid strategy (only after organic CAC baseline established)

For each channel:
- Estimated CAC
- Target ROAS
- Budget allocation percentage
- Ad copy examples
- Audience targeting strategy

## 10. Community Building
- Platform choice: Discord vs. Slack vs. other (with rationale)
- Channel/room structure
- Community launch strategy: seed with 20-50 members
- Engagement playbook: weekly rituals, AMAs, challenges
- Feedback loop: how community input feeds product roadmap
- Ambassador program: structure, rewards, recruitment

## 11. Related Forums & Communities

Use WebSearch to find forums, communities, and online spaces where the target audience for this SaaS idea already congregates. For each, provide:

| Forum/Community | URL | Platform | Audience Size | Relevance | Engagement Strategy |
|-----------------|-----|----------|---------------|-----------|-------------------|
| ... | ... | Reddit/Discord/Slack/Forum/Facebook Group/etc. | ... | high/medium | How to participate authentically |

Find at least 10 relevant communities. Include:
- Subreddits where the target problem is discussed
- Discord/Slack communities in the niche
- Industry-specific forums (Stack Overflow tags, niche forums)
- Facebook/LinkedIn groups
- Indie hacker / maker communities where this idea could get early traction
- Any niche-specific Q&A sites or discussion boards

For each community, write a specific engagement strategy: what kind of posts to make, how to offer value before promoting, what content to share, and how to build reputation.

Write the complete marketing playbook to `.saas-ideas/deep-dive/MARKETING-PLAYBOOK.md`.
```

---

### Agent 3: Tech Spec

Launch a background Agent (`subagent_type="general-purpose"`) with this prompt:

```
You are a senior software architect. Your job is to write a comprehensive technical specification for building a SaaS MVP.

**Selected idea:**
{SELECTED_IDEA}

**Budget tier:** {BUDGET}
**Focus domain:** {FOCUS}

Use WebSearch to research current best practices, framework comparisons, and hosting costs relevant to this tech stack. Ground your recommendations in real data.

Write a technical specification covering ALL 8 sections below. Be concrete — name specific technologies, services, and tools.

## 1. Recommended Stack

The following technologies are MANDATORY — do not substitute:
- **Database:** PostgreSQL — default to Neon free tier for ALL tiers until >1,000 users or >500MB. Do not use RDS until the Neon free tier is a proven bottleneck.
- **Auth:** Google OAuth (via next-auth, passport-google-oauth20, or equivalent)
- **Payments:** Stripe (Checkout, Billing, or Payment Intents as appropriate)
- **Hosting:** AWS — default to Lambda + API Gateway for ALL tiers. Avoid ECS/Fargate until >1M requests/month sustained.
- **Frontend hosting:** S3 + CloudFront or Cloudflare Pages (free unlimited bandwidth). Prefer Cloudflare Pages for zero-cost CDN.
- **Infrastructure as Code:** Terraform (all infra must be codified)
- **Domain:** Deploy as subdomain under `codingandmore.net` (e.g., `{app-name}.codingandmore.net`)
- **Cost justification:** For every tech choice, justify that it is the cheapest option that meets requirements. If a cheaper alternative exists, use it.

Choose the remaining technologies optimized for:
- AI-assisted development speed (Claude Code, Cursor, Copilot compatibility)
- Solo/small-team productivity
- Time to MVP
- BUDGET constraints

For each layer, name the specific technology and give a 1-2 sentence rationale:
- **Frontend:** framework, UI library, styling
- **Backend:** language, framework, API style (REST/GraphQL/tRPC)
- **AI tooling:** which AI coding tools to use and how

## 2. Architecture Overview
- System diagram description: client, API, database, external services, async jobs
- Key services and their responsibilities
- Data flow: describe the primary user flows through the system
- API design: key endpoints or queries
- Real-time requirements (if any): WebSockets, SSE, polling

## 3. MVP Scope

### v1 (MVP) — ship this
- List every feature with a one-sentence description
- Be ruthless about what's in vs. out
- Define "done" for the MVP: what must work for the first user?

### v2 — next iteration
- Features deferred from v1 with reasoning

### v3 — future
- Aspirational features that require scale or data

## 4. Data Model
Define core entities with their fields and relationships:

For each entity:
- Entity name
- Key fields (name, type, constraints)
- Relationships (belongs_to, has_many, many_to_many)
- Indexes

Provide this as a structured list or pseudo-schema, not raw SQL.

## 5. Third-Party Services

MANDATORY services (do not substitute):
- **Auth:** Google OAuth
- **Payments:** Stripe
- **Hosting/Infra:** AWS + Terraform
- **Database:** PostgreSQL (AWS RDS, Supabase, or Neon)

For remaining services, recommend specific providers:

| Category | Service | Tier/Plan | Monthly Cost | Why |
|----------|---------|-----------|-------------|-----|
| Auth | Google OAuth | Free | $0 | Mandatory |
| Payments | Stripe | Standard | 2.9% + $0.30/txn | Mandatory |
| Database | PostgreSQL (RDS/Supabase/Neon) | ... | ... | Mandatory |
| Email (transactional) | ... | ... | ... | ... |
| Email (marketing) | ... | ... | ... | ... |
| Analytics | ... | ... | ... | ... |
| Error monitoring | ... | ... | ... | ... |
| Logging | ... | ... | ... | ... |
| File storage | ... | ... | ... | ... |

**Free-tier defaults (apply at launch for ALL tiers, including high):**

| Category | Free-Tier Default | Free Limit | Upgrade Trigger |
|---|---|---|---|
| Email (transactional) | Resend | 3K emails/mo | >3K/mo |
| Analytics | PostHog | 1M events/mo | >1M events |
| Error monitoring | Sentry | 5K events/mo | >5K/mo |
| Logging | AWS CloudWatch | 5GB ingest/mo | >5GB |
| File storage | AWS S3 | 5GB + 20K GET/mo | >5GB |
| Uptime monitoring | BetterStack free | 5 monitors | >5 monitors |

Only upgrade to paid tiers when a free tier's hard limit is actually hit — not speculatively. Budget tiers govern how aggressively you scale *after* hitting limits, not the starting point.

## 6. Infrastructure (AWS + Terraform)

All infrastructure MUST be defined in Terraform. Provide Terraform module structure.

### Serverless-first architecture (all tiers)

Default to serverless components that cost $0 at idle:
- **Compute:** Lambda + API Gateway ($0 at idle, pay only per invocation)
- **Database:** Neon serverless PostgreSQL ($0 at idle, free tier generous for MVP)
- **CDN:** Cloudflare free tier (unlimited bandwidth, free DNS/SSL) — preferred over CloudFront
- **Static hosting:** S3 or Cloudflare Pages

Only provision always-on compute (ECS/Fargate, RDS) when sustained traffic makes serverless more expensive (typically >1M requests/month or >$50/mo Lambda spend).

- **Domain:** configure as `{app-name}.codingandmore.net` via Route53 + ACM certificate (or Cloudflare DNS)
- **Terraform module layout:** list the `.tf` files and what each defines
- **CI/CD pipeline:** GitHub Actions → build → test → deploy to AWS
- **Environment strategy:** local (Docker Compose), staging (`staging.{app-name}.codingandmore.net`), production (`{app-name}.codingandmore.net`)
- Estimated monthly infrastructure cost (serverless baseline):

| Users | Compute | Database | Storage | Services | Total/month |
|-------|---------|----------|---------|----------|-------------|
| 0-100 | $0 (Lambda free tier) | $0 (Neon free) | $0 (S3 free tier) | $0 (all free tiers) | **$0** |
| 1,000 | $1-5 | $0-19 | $0-5 | $5-8 | **$6-37** |
| 10,000 | $10-30 | $19-50 | $5-15 | $36-100 | **$70-195** |

## 7. AI Leverage Points

### AI for development acceleration
- Which development tasks benefit most from AI coding tools?
- Specific prompting strategies for this codebase
- Where AI-generated code needs careful review

### AI as product feature
- Where can AI features add product value? (if applicable)
- Build vs. buy for AI features
- Cost implications of AI API calls at scale

## 8. Timeline
Week-by-week MVP build plan calibrated for BUDGET:
- low: solo dev with AI tooling, 2-4 weeks
- medium: 2-5 person team with AI tooling, 4-8 weeks
- high: funded team (5-15), 8-16 weeks

| Week | Milestone | Key Deliverables | AI Tooling Notes |
|------|-----------|-----------------|-----------------|
| 1 | ... | ... | ... |
| 2 | ... | ... | ... |
| ... | ... | ... | ... |

Include buffer time and identify the critical path.

Write the complete technical specification to `.saas-ideas/deep-dive/TECH-SPEC.md`.
```

---

### Agent 4: Implementation Prompts

Launch a background Agent (`subagent_type="general-purpose"`) with this prompt:

```
You are a prompt engineer specializing in AI-assisted software development. Your job is to write a set of self-contained implementation prompts that a developer can use to build a SaaS MVP step by step using Claude Code.

**Selected idea:**
{SELECTED_IDEA}

**Budget tier:** {BUDGET}
**Focus domain:** {FOCUS}

Each prompt you write must be fully self-contained — it should include all necessary context so a developer can paste it directly and get working results. Do not reference external documents within the prompts themselves; embed all needed context inline.

**MANDATORY stack (hardcoded in all prompts):**
- Database: PostgreSQL
- Auth: Google OAuth
- Payments: Stripe
- Hosting: AWS
- Infrastructure: Terraform
- Domain: `{app-name}.codingandmore.net`

**Cost optimization defaults (hardcoded in all prompts):**
- Database: Neon free tier (serverless PostgreSQL, $0 at idle)
- Compute: Lambda + API Gateway ($0 at idle)
- CDN: Cloudflare free tier (unlimited bandwidth, free DNS/SSL)
- Email: Resend free tier (3K emails/mo)
- Analytics: PostHog free tier (1M events/mo)
- Error monitoring: Sentry free tier (5K events/mo)
- Cost alerts: AWS Cost Explorer alerts at $5/mo and $20/mo thresholds
- Cost tracking: `COST-LOG.md` in repo root — updated monthly with actual spend per service
- **Cost verification acceptance criteria:** $0/month at <100 users

**Phase 0 (before building features):** Set up cost monitoring — AWS Cost Explorer alerts, Stripe dashboard, `COST-LOG.md` initialized with $0 baseline.

**Goal: Complete working prototype.** The prompts should aim to produce fully deployable code, not just scaffolding. Each phase prompt should generate actual working code that can be tested and deployed.

Write implementation prompts covering ALL 5 categories below.

## 1. Project Initialization Prompt

Write a single comprehensive prompt for `/gsd:new-project` that sets up the entire project from scratch. It must include:
- Project name and description
- Tech stack decisions (reference SELECTED_IDEA context)
- Directory structure
- Initial dependencies
- Development environment setup
- Git initialization with conventional commits

## 2. Phase-by-Phase Build Prompts

Write one detailed prompt for each build phase. Each prompt should specify what to build, acceptance criteria, and which approach to use.

Include these phases (adapt based on the specific idea):

### Phase 1: Authentication & User Management
- What to implement: signup, login, password reset, user profile
- Use `superpowers:writing-plans` to plan the approach before coding
- Use `superpowers:test-driven-development` for all implementation work
- Acceptance criteria: user can sign up, log in, reset password

### Phase 2: Core Feature
- What to implement: the primary value-delivering feature of the product
- Use `superpowers:brainstorming` for any design decisions
- Use `superpowers:writing-plans` to plan the implementation
- Use `superpowers:test-driven-development` for all coding
- Use `superpowers:subagent-driven-development` for independent parallel tasks
- Acceptance criteria: specific to the idea

### Phase 3: Data Model & API
- What to implement: database schema, API endpoints, data validation
- Use `superpowers:writing-plans` before implementation
- Use `superpowers:test-driven-development` for all coding
- Acceptance criteria: all CRUD operations work, data validation enforced

### Phase 4: Billing & Subscriptions
- What to implement: pricing page, payment integration, subscription management
- Use `superpowers:writing-plans` before implementation
- Use `superpowers:test-driven-development` for all coding
- Acceptance criteria: user can subscribe, upgrade, downgrade, cancel

### Phase 5: Landing Page & Marketing Site
- What to implement: landing page, pricing page, about page, blog setup
- Use `superpowers:brainstorming` for design decisions
- Use `superpowers:writing-plans` before implementation
- Acceptance criteria: pages render correctly, CTA works, SEO basics in place

### Phase 6: Polish & Launch Prep
- What to implement: error handling, loading states, email notifications, analytics
- Use `superpowers:systematic-debugging` for any bug encounters
- Use `superpowers:requesting-code-review` after each milestone
- Use `superpowers:verification-before-completion` before merge/PR
- Acceptance criteria: no console errors, all happy paths tested, monitoring in place

For each phase prompt, also include:
- Use `/gw:worktree create <name>` for feature branch isolation
- Use `superpowers:finishing-a-development-branch` when the branch is complete

### Superpowers reference table

When working through these phases, apply the appropriate superpowers skill at each stage:

| Build Phase | Superpowers Skill Reference |
|-------------|----------------------------|
| Design decisions | `superpowers:brainstorming` |
| Before coding each phase | `superpowers:writing-plans` |
| All coding work | `superpowers:test-driven-development` |
| Independent parallel tasks | `superpowers:subagent-driven-development` |
| Bug encounters | `superpowers:systematic-debugging` |
| After each milestone | `superpowers:requesting-code-review` |
| Before merge/PR | `superpowers:verification-before-completion` |
| Feature branches | `/gw:worktree create <name>` |
| Branch completion | `superpowers:finishing-a-development-branch` |

## 3. Marketing Execution Prompts

Write prompts for:
- Landing page copywriting: generate all copy for the landing page based on the marketing playbook
- Blog post generation: prompt template for generating SEO-optimized blog posts with topic, keywords, and audience parameters
- Email sequence writing: prompt for generating the complete email sequences (welcome, trial-to-paid, churn prevention)

Each prompt must be self-contained with all context embedded.

## 4. Testing Prompts

Write prompts for:
- Unit test generation: prompt for generating comprehensive unit tests for each module
- Integration test generation: prompt for API endpoint and database integration tests
- E2E test generation: prompt for critical user flow end-to-end tests
- Load test setup: prompt for setting up basic load testing

Each prompt must specify the testing framework, patterns, and coverage targets.

## 5. Launch Checklist

Write an actionable, ordered checklist for launch day:
- Pre-launch verification steps (DNS, SSL, monitoring, backups)
- Launch sequence (when to post where, in what order)
- Post-launch monitoring (what to watch for in the first 24 hours)
- Rollback plan (what to do if something breaks)
- Day-2 follow-up actions

The checklist should be concrete steps, not vague advice.

Write the complete implementation prompts document to `.saas-ideas/deep-dive/IMPLEMENTATION-PROMPTS.md`.
```
