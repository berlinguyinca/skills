# Audit Threat Intelligence — Baseline Cache

## Cache Location

`~/.config/gw-skills/threat-intel.json`

## Baseline Cache Structure

When the cache file does not exist, create it with these baseline patterns:

```json
{
  "last_updated": "2026-03-19",
  "ttl_days": 7,
  "categories": {
    "credential_theft": {
      "patterns": ["process\\.env\\.[A-Z_]{4,}.*(?:fetch|http|axios|request)", "readFileSync.*(?:\\.ssh|id_rsa|id_ed25519|authorized_keys)", "keychain.*find-generic-password", "Security\\.itemCopyAttributesAndData", "chrome.*Login Data.*sqlite", "browser.*cookies.*sqlite"],
      "keywords": ["keychain", "credential_store", "browser_cookie", "ssh_key", "aws_credentials", "gcloud_credentials", "kubectl_config"],
      "recent_techniques": [
        {
          "name": "env var exfiltration via postinstall",
          "source": "https://socket.dev/blog/malicious-npm-packages",
          "date": "2026-01-01",
          "indicators": ["postinstall", "process.env", "fetch(", "http.request("]
        }
      ]
    },
    "crypto_theft": {
      "patterns": ["[13][a-km-zA-HJ-NP-Z1-9]{25,34}", "0x[a-fA-F0-9]{40}", "clipboard.*(?:replace|write|set).*(?:[13][a-km-zA-HJ-NP-Z1-9]{25,34}|0x[a-fA-F0-9]{40})", "(?:seed|mnemonic|phrase).*(?:read|steal|send|upload)", "\\.wallet\\b.*read"],
      "keywords": ["clipboard_replace", "wallet_steal", "seed_phrase", "mining_pool", "xmrig", "monero", "cryptonight"],
      "recent_techniques": [
        {
          "name": "clipboard hijack for crypto address substitution",
          "source": "https://blog.malwarebytes.com/",
          "date": "2026-01-01",
          "indicators": ["setInterval", "clipboard", "replace", "BTC", "ETH"]
        }
      ]
    },
    "data_exfiltration": {
      "patterns": ["(?:fetch|axios|http\\.request|curl|wget).*(?:pastebin\\.com|requestbin|webhook\\.site|burpcollaborator|ngrok\\.io|pipedream\\.net)", "btoa\\(|Buffer\\.from\\(.*base64|base64\\.b64encode.*decode.*eval", "dns\\.lookup.*(?:btoa|encodeURI|base64)", "screenshot.*(?:upload|send|post)", "keylog"],
      "keywords": ["exfiltrate", "data_theft", "phone_home", "beacon", "c2_server", "command_control"],
      "recent_techniques": [
        {
          "name": "DNS tunneling for data exfiltration",
          "source": "https://unit42.paloaltonetworks.com/",
          "date": "2026-01-01",
          "indicators": ["dns.lookup", "encode", "subdomain"]
        }
      ]
    },
    "backdoors": {
      "patterns": ["/bin/sh\\s+-i", "bash\\s+-c\\s+'exec bash", "nc\\s+.*\\s+-e\\s+/bin", "python.*socket.*subprocess", "eval\\((?:Buffer\\.from|atob|decode)\\(", "Function\\(['\"]return\\s+eval", "WebSocket.*(?:exec|spawn|eval)", "import\\(.*https?://"],
      "keywords": ["reverse_shell", "bind_shell", "netcat_listener", "meterpreter", "cobalt_strike", "beacon_payload"],
      "recent_techniques": [
        {
          "name": "dynamic import from remote URL",
          "source": "https://security.snyk.io/",
          "date": "2026-01-01",
          "indicators": ["import(", "https://", "eval("]
        }
      ]
    },
    "supply_chain": {
      "patterns": ["\"preinstall\"\\s*:", "\"postinstall\"\\s*:", "cmdclass.*install.*run", "build\\.rs.*Command.*new.*curl", "build\\.rs.*Command.*new.*wget"],
      "keywords": ["malicious_package", "typosquatting", "dependency_confusion", "protestware", "sabotage"],
      "recent_techniques": [
        {
          "name": "postinstall script with network call",
          "source": "https://socket.dev/",
          "date": "2026-01-01",
          "indicators": ["postinstall", "curl", "wget", "fetch"]
        },
        {
          "name": "known malicious package names",
          "source": "https://github.com/nicowillis/npm-malicious-packages",
          "date": "2026-01-01",
          "indicators": ["node-ipc", "colors@1.4.44-liberty-2", "event-source-polyfill@1.0.31", "ua-parser-js@0.7.29", "coa@2.0.3", "rc@1.2.9"]
        }
      ]
    },
    "persistence": {
      "patterns": ["crontab\\s+-[le]", "launchctl.*load", "plistlib.*dump.*LaunchAgents", "echo.*>>.*(?:\\.bashrc|\\.zshrc|\\.profile|\\.bash_profile)", "systemctl.*enable.*--now", "(?:HKCU|HKLM).*\\\\Run\\b"],
      "keywords": ["crontab_write", "launchagent_plist", "shell_profile_inject", "systemd_service", "registry_run_key", "startup_folder"],
      "recent_techniques": [
        {
          "name": "LaunchAgent plist for macOS persistence",
          "source": "https://objective-see.org/blog.html",
          "date": "2026-01-01",
          "indicators": ["LaunchAgents", "plistlib", "com.apple.launchd", "RunAtLoad"]
        }
      ]
    }
  }
}
```

## Refresh Logic

| Condition | Action |
|-----------|--------|
| Cache file does not exist | Create with bundled baseline patterns above, then run WebSearch for all 6 categories |
| `--refresh-threats` is set (FORCE_REFRESH=true) | Run WebSearch for all 6 categories regardless of cache age |
| Cache exists and is >7 days old | Run WebSearch for all 6 categories |
| Cache exists and is fresh (<7 days) | Surface scan: use as-is. Deep scan: run WebSearch only for categories relevant to detected languages |

## WebSearch Query Templates

Per category (substitute `{category}`, `{language}`, `{ecosystem}`, `{year}` as appropriate):
- `"latest {category} malware GitHub {year}"`
- `"malicious {language} package {ecosystem} discovered {year}"`
- `"{category} attack technique open source supply chain"`

For each result found, extract new patterns, keywords, and technique entries. **Merge into cache — do not remove existing entries.** Threat patterns accumulate over time; removing them would create blind spots.

After refresh (or confirming cache is fresh), print:
```
Threat intel: {N} patterns loaded across 6 categories (cache from {last_updated})
```
