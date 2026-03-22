# Weekly Review — JSON Data Schema

Write all synthesized content to `/tmp/weekly_review_data.json` with this structure:

```json
{
  "sources": ["metabolomics-us", "berlinguyinca/skills"],
  "org_sources": ["metabolomics-us"],
  "personal_sources": ["berlinguyinca/skills"],
  "author": "...",
  "author_name": "...",
  "start_date": "YYYY-MM-DD",
  "end_date": "YYYY-MM-DD",
  "executive": {
    "metadata": {
      "date_range": "2026-03-11 – 2026-03-17",
      "org": "metabolomics-us",
      "repos": ["repo1", "repo2"]
    },
    "headline": {
      "text": "Sample processing got dramatically faster",
      "subtitle": "Auto-recovery, smarter scheduling, and a 1000x query speedup",
      "kpis": [
        {"value": "30 min", "label": "Auto-Recovery", "color": "accent"},
        {"value": "1000x", "label": "Queue Speedup", "color": "accent"},
        {"value": "3", "label": "Bugs Eliminated", "color": "success"}
      ]
    },
    "themes": [
      {
        "title": "Turnaround Time Overhaul",
        "subtitle": "Faster results for lab users, less manual work for operators",
        "evidence": [
          {
            "claim": "Stuck samples auto-recover in 30 minutes",
            "detail": "Previously required manual operator intervention"
          }
        ],
        "visual_anchor": {
          "type": "before_after",
          "before": {"value": "Hours", "detail": "Manual recovery, FIFO queue"},
          "after": {"value": "30 min", "detail": "Auto-recovery, priority queue"}
        }
      }
    ],
    "impact_focus": {
      "category": "Stability",
      "summary": "Self-healing pipeline, capacity guards, and temp file cleanup"
    },
    "whats_next": [
      {
        "title": "Interactive node dashboard",
        "detail": "Terminal UI for processing nodes",
        "status": "testing"
      }
    ],
    "side_projects": ""
  },
  "technical": {
    "stats": {
      "org_merged_prs": 0,
      "org_commits": 0,
      "org_repos": 0,
      "personal_merged_prs": 0,
      "personal_commits": 0,
      "personal_repos": 0,
      "total_additions": 0,
      "total_deletions": 0
    },
    "commits_by_repo": {"repo_name": 0},
    "commits_by_date": {"YYYY-MM-DD": 0},
    "category_counts": {"Feature": 0, "Bug Fix": 0},
    "impact_areas": {"Queue Management": 0, "Data Pipeline": 0},
    "architecture_notes": "...",
    "org_prs": [
      {
        "title": "...",
        "repo": "...",
        "url": "...",
        "category": "Feature|Bug Fix|Improvement|Docs|Maintenance|Other",
        "impact_area": "...",
        "what_changed": "...",
        "why": "...",
        "additions": 0,
        "deletions": 0,
        "merged_at": "...",
        "is_minor": false,
        "screenshot_worthy": false,
        "screenshot_hint": "Description of what screenshot would show, e.g. 'CLI table output of node-status command'"
      }
    ],
    "personal_prs": [
      {
        "title": "...",
        "repo": "...",
        "url": "...",
        "category": "...",
        "one_liner": "..."
      }
    ],
    "open_prs": [
      {
        "title": "...",
        "repo": "...",
        "url": "...",
        "technical_status": "..."
      }
    ],
    "harvested_assets": [
      {
        "source_repo": "org/repo",
        "source_file": "docs/gw/changes-presentation-feat-xyz.pptx",
        "slide_title": "...",
        "images": ["/tmp/harvested_repo_s3_i1.png"],
        "text_preview": "...",
        "asset_type": "chart|screenshot|diagram|comparison",
        "related_pr_url": "..."
      }
    ]
  },
  "highlights": [
    {
      "user_description": "The scheduling recovery system — really proud of how it handles all edge cases",
      "matched_pr_urls": ["https://github.com/..."],
      "matched_pr_titles": ["feat: scheduling recovery..."],
      "deep_dive": {
        "title": "Scheduling Recovery System",
        "problem": "Samples stuck in SCHEDULING state were lost forever when SQS sends failed",
        "approach": "Added Phase 1.5 detection with configurable 30-minute timeout and capacity-aware rescheduling",
        "result": "Stuck samples now auto-recover without operator intervention, with structured cycle metrics for visibility",
        "visual_anchor": {
          "type": "before_after",
          "before": {"value": "Lost", "detail": "Manual restart required"},
          "after": {"value": "30 min", "detail": "Auto-recovery with metrics"}
        },
        "screenshot_hint": "CLI table showing sync cycle metrics with recovery counts"
      }
    }
  ],
  "learnings": [
    {
      "title": "Bulk queries beat N+1",
      "insight": "Replacing per-sample DB lookups with a single bulk query improved performance 1000x for 100k samples",
      "visual_type": "analogy",
      "visual_data": {
        "before": {"label": "N+1 Queries", "value": "Minutes"},
        "after": {"label": "Bulk Query", "value": "Milliseconds"}
      }
    }
  ]
}
```

## Field Notes

### KPI color tokens
- `"accent"` → #3498DB
- `"success"` → #27AE60
- `"danger"` → #E74C3C
- `"warning"` → #F39C12

### visual_anchor types
- `"before_after"`: `{before: {value, detail}, after: {value, detail}}`
- `"metric_callout"`: `{value, label}`
- `"count_cards"`: `{cards: [{value, label}, ...]}`
- `"evidence_list"` (fallback): `{items: ["string", ...]}`

### impact_focus categories
Productivity | Quality of Service | Quality of Life | Features | Bug Fixes | Stability

### learning visual_type values
- `"analogy"`: `{before: {label, value}, after: {label, value}}`
- `"diagram"`: `{steps: ["Step 1", "Step 2", "Step 3"]}`
- `"quote_card"`: `{quote: "...", attribution: "..."}`
- `"chart"`: `{labels: ["A", "B"], values: [10, 90], chart_type: "bar"}`
