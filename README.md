# QuotaMeter

A macOS menu bar app that shows how much **Claude** and **Codex** plan quota you have left — across every account at once.

The menu bar always reports your *binding constraint*: the single window closest to running out, whichever account and whichever limit that happens to be. Everything counts down, so the number on screen is what you have left, not what you've spent.

```
MENU BAR: 0% left → Weekly Fable

claude   you@example.com        Max       5-hour  66% left    Weekly  20% left    Weekly Fable   0% left
claude   other@example.com      Max       5-hour  78% left    Weekly  65% left    Weekly Fable  46% left
codex    you@example.com        ProLite   Weekly  86% left
```

## How it works

QuotaMeter does not handle OAuth, cookies, or provider credentials. It reads usage through a locally running [CLIProxyAPI](https://github.com/router-for-me/CLIProxyAPI) daemon, which already holds your credentials and refreshes them:

```
QuotaMeter (menu bar)
  └─ POST 127.0.0.1:8317/v0/management/api-call
       { authIndex, method: GET, url: <provider usage endpoint> }
          └─ daemon injects a fresh access token, proxies upstream, returns the body
```

That means token refresh, multi-account handling, and provider user-agent quirks are the daemon's job. When a provider changes something, the daemon absorbs it — no app rebuild required.

### What it reads

| Provider | Endpoint | Windows surfaced |
|---|---|---|
| Claude | `api.anthropic.com/api/oauth/usage` + `/oauth/profile` | 5-hour session, weekly, and model-scoped weekly caps (e.g. Fable), plus plan tier |
| Codex | `chatgpt.com/backend-api/wham/usage` | rate-limit windows labelled by duration, per-feature sub-limits, plan tier |

Two details worth knowing, because they're easy to get wrong:

- **Codex window names are not fixed.** `primary_window` can be the *weekly* one depending on plan, so windows are labelled from `limit_window_seconds` rather than field position.
- **Claude's model-scoped caps arrive only via `limits[]`.** The matching top-level keys (`iguana_necktie`, `seven_day_opus`, …) are `null` in practice. These caps are frequently the binding constraint, so they're shown by default.

## Requirements

- macOS 14 (Sonoma) or later
- A running [CLIProxyAPI](https://github.com/router-for-me/CLIProxyAPI) instance with at least one Claude or Codex credential
- Xcode 16+ to build

## Setup

1. Install and start CLIProxyAPI, and authenticate your Claude / Codex accounts through its web panel (`http://<host>:<port>/management.html`).
2. Build and run QuotaMeter (see below).
3. It finds the management key on its own. If it can't, enter it once in **Settings → Connection**.

### Key resolution

QuotaMeter looks for the daemon's management key in this order, so there's usually nothing to type:

1. `QUOTAMETER_MANAGEMENT_KEY` environment variable
2. `~/.quotameter/management-key`
3. `~/cliproxyapi/credentials.txt` or `~/.cli-proxy-api/credentials.txt` (a `MANAGEMENT_KEY=…` line)

A key discovered via (3) is copied into (2), so the app stops depending on the daemon's own files. The key is stored as an owner-only (`0600`) file rather than in the Keychain — see [Security](#security).

> The daemon bcrypt-hashes `secret-key` in its `config.yaml` on first start, so the key **cannot** be recovered from there. It has to come from wherever it was recorded in plaintext.

## Features

- One row per quota window, per account, with a draining bar and the exact reset time
- Menu bar icon in six styles, colour-coded, showing the tightest constraint
- Pacing indicator that flags when you're burning a window faster than it refills
- Per-account, per-window notifications, so a busy account can't mute the others
- Model-scoped caps (Claude) and per-feature sub-limits (Codex)
- Exports to `~/.quotameter/usage.json` for statusline scripts and other tooling

### JSON export

```json
{
  "last_updated": "2026-08-11T19:00:05Z",
  "accounts": [
    {
      "provider": "claude",
      "label": "you@example.com",
      "plan_label": "Max",
      "windows": [
        {
          "id": "five_hour",
          "label": "5-hour session",
          "is_primary": true,
          "limit": { "utilization": 34, "remaining": 66, "reset_at": "2026-08-11T23:10:00Z" }
        }
      ]
    }
  ]
}
```

`remaining` is written for convenience; `utilization` is the value the providers actually report.

## Build

```bash
xcodebuild build -project ClaudeMeter.xcodeproj -scheme ClaudeMeter -configuration Release \
  -derivedDataPath build CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="-"
cp -R build/Build/Products/Release/QuotaMeter.app /Applications/
```

Run the tests with:

```bash
xcodebuild test -project ClaudeMeter.xcodeproj -scheme ClaudeMeter -configuration Debug \
  -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO
```

> The Xcode project, scheme, and source folders are still named `ClaudeMeter`, inherited from the project this was forked from. Only the built product is renamed. Renaming the target was not worth the risk of breaking the build.

Ad-hoc signing (`CODE_SIGN_IDENTITY="-"`) works fine for local use. If you sign with a real identity instead, the signature stays stable across rebuilds.

## Security

The management key is stored as a `0600` file in your home directory rather than in the Keychain. This is a deliberate trade-off: Keychain access prompts fired on every refresh and required manual entry, which defeated the point of a passive menu bar app.

In context the exposure is unchanged — the daemon's own `config.yaml` and its OAuth token files (`~/.cli-proxy-api/*.json`) are already plaintext `0600` files owned by you, and the daemon listens on `127.0.0.1` by default. The key is protected exactly as well as the credentials it guards.

## Credits

- Forked from [**ClaudeMeter**](https://github.com/eddmann/ClaudeMeter) by Edd Mann (MIT). The menu bar icon rendering, pacing heuristic, notification scheduling, and settings persistence all originate there. The credential layer, multi-account model, and both provider parsers were rewritten.
- Talks to [**CLIProxyAPI**](https://github.com/router-for-me/CLIProxyAPI) by router-for-me (MIT).
- Provider parsers ported from the [**CLI Proxy API Management Center**](https://github.com/router-for-me/Cli-Proxy-API-Management-Center) (MIT), which also supplied the provider logos (from [lobe-icons](https://github.com/lobehub/lobe-icons), MIT).

## Disclaimer

**Unofficial.** Not affiliated with, endorsed by, or supported by Anthropic or OpenAI. The Claude and Codex names and logos are trademarks of their respective owners, used here only to identify which account a row refers to.

This reads private, undocumented usage endpoints, which may change or stop working without notice, and doing so may conflict with the providers' terms of service. Usage is read-only — QuotaMeter never sends prompts or modifies your account. Use at your own risk.

## License

MIT — see [LICENSE](LICENSE). Original copyright retained; see [Credits](#credits).
