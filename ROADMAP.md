# Roadmap

What is planned, in rough order. Open an issue to suggest something.

## Next

- [ ] Run `setup`, `remote cloudflare` and `client` end to end on a fresh Mac mini and fix what
      breaks. Update "What is tested" in the README.
- [ ] Test `--screen` (Screen Sharing through the tunnel).
- [ ] `headless remote tailscale`: the same guided setup for people without a domain.
- [ ] Show the tunnel's state in the virtual screen's menu ("Tunnel: connected").

## Later

- [ ] One-line install (Homebrew tap or `curl | bash`), so no `git clone` is needed.
- [ ] `headless doctor --watch`: run the checks on a schedule and notify on a failure.
- [ ] Custom screen sizes from the config file.
- [ ] Check after each major macOS release and record the result in the README.

## Done

- 2026-11-17: virtual screen with size menu and saved choice; `headless` command with `setup`,
  `display`, `remote cloudflare`, `doctor` and `client`; first public version.
