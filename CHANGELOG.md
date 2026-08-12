# Changelog

## Unreleased

Initial public release, forked from [ClaudeMeter](https://github.com/eddmann/ClaudeMeter) 1.4.0.

### Changed

- **Credentials.** Replaced browser-cookie session-key extraction with a local
  [CLIProxyAPI](https://github.com/router-for-me/CLIProxyAPI) daemon, which owns
  OAuth refresh for every account. The management key is discovered automatically
  from the environment, `~/.quotameter/management-key`, or the daemon's
  `credentials.txt`; there is nothing to enter by hand.
- **Multiple accounts.** The single-account model became a list of accounts, each
  with its own set of quota windows. A failing credential renders as one error row
  instead of blanking the display.
- **Counts down.** Bars drain and labels read "% left" rather than "% used".
  Status colours still track consumption, so an exhausted window is red.
- **Notifications** fire per account and per window, so a busy account cannot mute
  the others.
- Minimum refresh interval raised to 5 minutes; Anthropic rate-limits its usage
  endpoint aggressively.

### Added

- Codex support, with windows labelled from `limit_window_seconds` rather than
  field position, plus per-feature sub-limits.
- Claude model-scoped weekly caps (e.g. Fable), surfaced as primary windows since
  they are frequently the binding constraint.
- Provider logos for Claude and Codex.
- `remaining` in the `~/.quotameter/usage.json` export.

### Removed

- Browser cookie import, the session-key setup wizard, and organization lookup.
- Keychain storage, which prompted for authorisation on every refresh.
