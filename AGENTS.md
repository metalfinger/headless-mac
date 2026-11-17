# For coding agents

This repo makes a Mac mini usable headless: a virtual screen, stay-awake settings and SSH
through a Cloudflare Tunnel. Read `README.md` for the user-facing description.

## Using it on a machine

- Run `./headless doctor --json` first. It changes nothing and returns
  `{"ok": bool, "checks": [{"status": "ok|warn|fail", "check", "detail", "fix"}]}`.
  Exit code 1 means a required check failed.
- Each failing check carries a `fix`. A fix that starts with "System Settings" or "Cloudflare
  dashboard" is a step for the person at the screen. Tell them; do not try to script around it.
- `./headless setup` and `./headless remote cloudflare` need `sudo` or a browser login. Ask
  the person to run them, or run them only when they have said so.
- Never approve a login, a consent page or a macOS permission prompt for the person.
- `./headless display install` restarts the virtual screen. For a few seconds the Mac has no
  screen; anyone connected by Screen Sharing loses the picture. Say so before running it.
- A hostname reported as "OPEN to the internet" is urgent. Tell the person at once.

## "Set up this Mac" (when a person points you at this repo)

1. `./headless doctor --json` to see the starting state.
2. `./headless setup`. It needs the Mac's password for `sudo`; the person types it.
3. If they gave you a join code: `./headless join <code> --github <their GitHub username>`.
   Treat the code as a secret: do not print it back, log it or put it in a commit or a chat.
4. `./headless doctor --json` again. Report every `warn` and `fail` with its `fix`. The ones
   that are System Settings switches are theirs to change; list them plainly.
5. Do not run `invite` or `remote cloudflare` unless the person owns the Cloudflare account on
   that machine and asked for it.

## Changing the code

- `headless` is bash and must run on macOS's own bash 3.2: no associative arrays, no `mapfile`,
  no `${var,,}`. Check with `/bin/bash -n headless`.
- `display/main.swift` builds with the command line developer tools only:
  `bash display/build.sh`. No Xcode project, no packages.
- `display/CGVirtualDisplay.h` declares private CoreGraphics classes. Keep the program small;
  it is the machine's only screen and must not crash.
- Keep every command safe to run twice.
- Keep README's "What is tested" table honest: mark anything you add as untested until it has
  run on a real Mac.
- When behaviour changes, update `README.md`, `docs/how-it-works.md` and `ROADMAP.md` in the same commit.
