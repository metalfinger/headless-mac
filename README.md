# headless-mac

Run a Mac mini with no monitor, keyboard or mouse, and reach it from anywhere.

It gives you three things:

1. **A virtual screen** (`factory-display`). Screen Sharing and screenshots work with nothing
   plugged in. No HDMI dummy plug, no paid app.
2. **A machine that stays up.** No sleep, restart after a power cut, start everything at login.
3. **SSH from anywhere** through a Cloudflare Tunnel on your own domain, with a login in front.

One command, `headless`, sets these up and checks them.

> Status: built for our own Mac minis and shared as it is. Tested on macOS 27.2 on Apple silicon.
> See [What is tested](#what-is-tested).

## Quick start

On the Mac mini, in Terminal on its own desktop (not over SSH, the first time):

```sh
xcode-select --install          # if you have never installed the developer tools
git clone https://github.com/metalfinger/headless-mac.git && cd headless-mac
./headless setup                # power settings, Remote Login, virtual screen
./headless doctor               # shows what is still missing
```

`setup` ends with a short list of System Settings switches that macOS only lets a person change
(automatic login, FileVault off, Screen Sharing). Change them, then run `doctor` again.

For access from anywhere you need a domain on Cloudflare (the free plan is enough):

```sh
./headless remote cloudflare mini.example.com
```

A browser opens for the Cloudflare login. Afterwards the command tells you to add an Access
application for the hostname. **Do that straight away**: until then anyone can reach the Mac's
SSH password prompt. `doctor` fails loudly while the hostname is open.

On your laptop:

```sh
./headless client mini.example.com --user <account name on the mini>
ssh mini
```

## Commands

| Command | Where | What it does |
|---|---|---|
| `headless setup` | mini | Never sleep, restart after a power cut, updates download only, Remote Login, virtual screen |
| `headless display install` | mini | Build the virtual screen and start it at every login |
| `headless display status` | mini | Is it running, and at what size |
| `headless display uninstall` | mini | Stop and remove it |
| `headless remote cloudflare <host> [--screen <host2>]` | mini | Tunnel SSH (and optionally Screen Sharing) through your Cloudflare domain |
| `headless doctor [--json]` | mini | Check every piece; print the fix for each failure; exit 1 if any required check fails |
| `headless client <host> [--user u] [--name alias] [--screen host2]` | laptop | Add an SSH shortcut that goes through Cloudflare |

Everything is safe to run again. Finished steps are skipped or rewritten to the same result.

## The virtual screen

`factory-display` is one small Swift program. While it runs, macOS has a monitor called
"Factory Display". launchd starts it at login and restarts it if it crashes.

- **Menu bar icon:** a small display. Its menu shows the current size, lets you pick another and
  has "Turn off until next login".
- **Sizes:** 2560x1440 (default), 1920x1080, and MacBook sizes (1728x1117, 1710x1107, 1512x982,
  1470x956, 1440x900, 1280x800), all at 2x. Pick the one that matches the laptop you connect from
  and Screen Sharing fills its screen.
- The choice is saved in `~/.config/factory-display/config.json`.
- Log: `~/Library/Logs/factory-display.log`.

It uses CoreGraphics' private `CGVirtualDisplay` classes, the same mechanism other virtual
display apps use. **A major macOS update can break it.** `setup` turns off automatic macOS
installs so that you choose when to update; test after you do.

## What `doctor` checks

Sleep off, restart after power cut, automatic login, FileVault off, macOS auto-install off,
Remote Login, Screen Sharing, the virtual screen, the tunnel service, and that each tunnel
hostname asks for a Cloudflare login. `--json` prints the same as
`{"ok": bool, "checks": [{"status", "check", "detail", "fix"}]}`.

## Things to know

- **Keychain over SSH.** In an SSH session the login keychain is closed, so tools that keep
  tokens there (`gh`, Claude Code, Codex) look logged out. Nothing is lost. Run
  `security unlock-keychain ~/Library/Keychains/login.keychain-db` in that session.
- **mosh does not work through a Cloudflare Tunnel** (it carries TCP only). Use SSH with tmux.
- **Automatic login is what makes reboots unattended.** Everything here starts at login, not at
  boot. With automatic login off, nothing starts until someone logs in.
- **Tailscale is a fine alternative** to the Cloudflare part; this tool does not set it up.

## What is tested

| Piece | State |
|---|---|
| Virtual screen: create, sizes, restart after crash, back after reboot | Tested on one Mac mini, macOS 27.2.1, Apple silicon |
| `doctor` | Tested on that mini |
| Cloudflare SSH tunnel with Access login | Tested there, set up by hand with the same commands the script runs |
| `setup`, `remote cloudflare`, `client` as scripts | Written from those tested commands; not yet run end to end on a fresh Mac |
| `--screen` (Screen Sharing through the tunnel) | Not tested |
| Intel Macs, macOS before 27 | Not tested |

## Uninstall

```sh
./headless display uninstall
launchctl bootout gui/$(id -u)/com.cloudflare.cloudflared; rm ~/Library/LaunchAgents/com.cloudflare.cloudflared.plist
cloudflared tunnel delete <tunnel name>      # also remove the DNS record and Access application
```

## Licence

MIT. See `LICENSE`.
