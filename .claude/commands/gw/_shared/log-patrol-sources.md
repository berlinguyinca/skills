# Log Patrol — Source Type Detection Patterns

## Source format connection strings

| Type | Format | Example |
|------|--------|---------|
| SSH | `ssh:user@host:/path/to/file.log` | `ssh:deploy@prod1.example.com:/var/log/app/application.log` |
| CloudWatch | `cloudwatch:log-group-name` | `cloudwatch:/ecs/my-app-prod` |
| Local | `local:/path/to/file.log` | `local:/var/log/app/app.log` |
| Docker | `docker:container-name` | `docker:web-api` |

---

## Auto-discovery: project file analysis patterns

Scan the project for infrastructure hints. Read/glob for these files and extract relevant information:

| File/Pattern | What to extract |
|-------------|-----------------|
| `docker-compose.yml` / `docker-compose.*.yml` | Service names, log driver config, volume mounts |
| `Dockerfile` / `*.dockerfile` | Base image (implies log paths), exposed ports |
| `*.tf` / `terraform/` | AWS resources (CloudWatch log groups, EC2 instances, ECS tasks, Lambda functions) |
| `.env` / `.env.*` | Host addresses, AWS regions, service URLs |
| `deploy/` / `scripts/` / `Makefile` | SSH targets, deployment hosts, rsync destinations |
| `ansible/` / `playbook*.yml` | Inventory hosts, log path configurations |
| `k8s/` / `kubernetes/` / `helm/` | Pod names, namespaces, container names |
| CI/CD configs (`.github/workflows/`, `Jenkinsfile`, `.gitlab-ci.yml`) | Deploy targets, environment variables |
| `CLAUDE.md` / `README.md` | Infrastructure descriptions, architecture notes |
| Logging configs (`log4j*.xml`, `logback.xml`, `logging.conf`, winston config) | Log file paths, log formats, rotation settings |

---

## Auto-discovery: active probing commands (parallel agents, 1 per target type)

| Source type | Probe action |
|-------------|-------------|
| SSH | `ssh user@host "find /var/log -name '*.log' -mmin -1440 2>/dev/null; ls -la /var/log/app/ 2>/dev/null; systemctl list-units --type=service --state=running 2>/dev/null"` |
| CloudWatch | `aws logs describe-log-groups --query 'logGroups[*].[logGroupName,storedBytes]' --output table` |
| Docker | `docker ps --format '{{.Names}} {{.Image}} {{.Status}}'` to list running containers |
| Local | `find . -name '*.log' -o -name '*.err' \| head -20; ls /var/log/ 2>/dev/null` |

Each probe agent returns discovered log files/streams with metadata (size, last modified, service association). If a probe fails (e.g., ssh unreachable, aws not configured), note it as failed and continue with other probes.

---

## Log fetch commands per source type

**SSH source** (`ssh:user@host:/path/to/file.log`):
```bash
# Parse connection: user@host and path
ssh user@host "cat /path/to/file.log" > .log-patrol/raw/source-INDEX.log
# If --since is set, use awk/sed to filter by timestamp if log format is recognized
# If file is very large (>50MB), tail the last 10000 lines instead
```

**CloudWatch source** (`cloudwatch:log-group-name`):
```bash
aws logs filter-log-events \
  --log-group-name "log-group-name" \
  --start-time START_EPOCH_MS \
  --output json \
  --query 'events[*].message' > .log-patrol/raw/source-INDEX.log
```
Note: `--start-time` requires epoch milliseconds. Convert the computed start timestamp.

**Local source** (`local:/path/to/file.log`):
```bash
cp /path/to/file.log .log-patrol/raw/source-INDEX.log
# If --since is set and file is large, filter by timestamp or tail
```

**Docker source** (`docker:container-name`):
```bash
docker logs container-name --since START_TIMESTAMP > .log-patrol/raw/source-INDEX.log 2>&1
```

Each agent should:
1. Fetch the log content using the appropriate command
2. Write to `.log-patrol/raw/source-{INDEX}.log` where INDEX is the source index from config
3. Report back: success with line count + byte size, or failure with error message

---

## Error detection patterns (Step 4 grep scan)

| Category | Patterns |
|----------|----------|
| Explicit errors | `\bERROR\b`, `\bFATAL\b`, `\bCRITICAL\b` |
| Exceptions | `\bException\b`, `\bTraceback\b`, `\bpanic:\b` |
| HTTP 5xx | `\bHTTP[/ ][12]\.[01].\s+5[0-9]{2}\b` or `\b5[0-9]{2}\b` with HTTP context (e.g., near `GET`, `POST`, `HTTP`) |
| Memory | `\bOOM\b`, `\bOutOfMemory\b`, `\bsegfault\b`, `\bSIGKILL\b` |
| Timeouts | `\btimeout\b`, `\bdeadlock\b`, `\bconnection refused\b` |
| Disk/IO | `\bNo space left\b`, `\bDisk full\b`, `\bI/O error\b` |
| Custom | User-defined patterns from `config.json` `custom_patterns` array |

Use case-insensitive matching for timeout/deadlock patterns but case-sensitive for ERROR/FATAL/CRITICAL.

## Log classification tables

### Severity criteria

| Severity | Criteria |
|----------|----------|
| CRITICAL | Data loss, security breach, complete service outage, OOM kills |
| HIGH | Partial outage, persistent errors affecting users, failing dependencies |
| MEDIUM | Intermittent errors, degraded performance, non-critical timeouts |
| LOW | Occasional warnings, deprecation notices, minor configuration issues |

### Error categories

`Application Error`, `Infrastructure Error`, `Dependency Error`, `Configuration Error`, `Performance Error`, `Security Event`

### Trend values

`increasing`, `decreasing`, `steady`, `periodic`, `new` (first time seen)

### Graceful degradation fallback severity mapping

| Pattern category | Fallback severity |
|-----------------|-------------------|
| Exceptions, Memory | HIGH |
| HTTP 5xx, Timeouts | MEDIUM |
| Others | LOW |
