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
