### search_skills → Source Mapping Table

Each persona's `search_skills` field determines which sources they prioritize. The agent prompt must include source-specific search instructions based on their skills:

| search_skill | Search Strategy |
|---|---|
| `github` | WebSearch for GitHub repos, issues, discussions relevant to the question |
| `context7` | Use `resolve-library-id` + `query-docs` for any libraries/frameworks mentioned in the question |
| `arxiv` | WebSearch `site:arxiv.org` for papers related to the question |
| `academic` | WebSearch for academic papers, Google Scholar results, university publications |
| `google-scholar` | WebSearch `site:scholar.google.com` or `"cited by"` patterns for the topic |
| `pubmed` | WebSearch `site:pubmed.ncbi.nlm.nih.gov` for biomedical/life science papers |
| `journals` | WebSearch for peer-reviewed journal articles (Nature, Science, IEEE, ACM, etc.) |
| `stackoverflow` | WebSearch `site:stackoverflow.com` for technical Q&A on the topic |
| `tech-blogs` | WebSearch for technical blog posts, engineering blogs (Netflix, Uber, Stripe, etc.) |
| `api-docs` | WebSearch for official API documentation and developer guides |
| `financial-data` | WebSearch for financial data, market analysis, Bloomberg/Reuters summaries |
| `sec-filings` | WebSearch `site:sec.gov` for SEC filings, 10-K, 10-Q reports |
| `market-reports` | WebSearch for market research reports (Gartner, Forrester, McKinsey, etc.) |
| `news` | WebSearch for recent news articles from major outlets |
| `earnings-transcripts` | WebSearch for quarterly earnings call transcripts |
| `reddit` | WebSearch `site:reddit.com` for community discussions and opinions |
| `forums` | WebSearch for forum discussions, community posts, Stack Exchange sites |
| `product-hunt` | WebSearch `site:producthunt.com` for product launches and reviews |
| `g2-reviews` | WebSearch `site:g2.com` for software reviews and comparisons |
| `cve-databases` | WebSearch `site:cve.mitre.org` or `site:nvd.nist.gov` for vulnerability data |
| `owasp` | WebSearch `site:owasp.org` for security guidelines and checklists |
| `cloud-docs` | WebSearch for AWS/GCP/Azure official documentation |
| `benchmarks` | WebSearch for performance benchmarks, comparison tests |
| `testing-resources` | WebSearch for testing methodology guides, framework docs |
| `dribbble` | WebSearch `site:dribbble.com` for design inspiration and patterns |
| `design-blogs` | WebSearch for design blogs (Smashing Magazine, A List Apart, etc.) |
| `figma-community` | WebSearch `site:figma.com/community` for design templates and systems |
| `mdn` | WebSearch `site:developer.mozilla.org` for web standards documentation |
| `css-tricks` | WebSearch `site:css-tricks.com` for web design techniques |
| `web-dev-resources` | WebSearch for web.dev, Can I Use, and web platform guides |
| `ux-research` | WebSearch for UX research studies, usability reports |
| `nielsen-norman` | WebSearch `site:nngroup.com` for UX research and guidelines |
| `trade-publications` | WebSearch for industry-specific trade publications and magazines |
| `youtube` | WebSearch `site:youtube.com` for tutorials, talks, demonstrations |
| `counter-narrative-sources` | WebSearch for contrarian viewpoints, critique articles, "problems with {topic}" |
| `methodology-guides` | WebSearch for research methodology handbooks, best practice guides |
| `statistics-resources` | WebSearch for statistics tutorials, methodology papers, statistical software docs |
