# How it works, and what we learned building it

Notes from setting up the first Mac minis by hand in November 2026. They explain why the
`headless` command does what it does.

## The virtual screen

- A Mac mini with nothing plugged in has no real monitor. Screen Sharing then shows a basic
  fallback screen, and tools that take screenshots or click through Accessibility have nothing
  dependable to work on.
- `factory-display` creates a monitor in software with CoreGraphics' `CGVirtualDisplay`,
  `CGVirtualDisplayDescriptor`, `CGVirtualDisplaySettings` and `CGVirtualDisplayMode`. These
  classes ship in CoreGraphics but are not in the public SDK, so `display/CGVirtualDisplay.h`
  declares them.
- The monitor exists only while the process holds the `CGVirtualDisplay` object. That is why it
  is a long-running program and not a one-off command.
- It has a fixed vendor, product and serial number, so macOS treats it as the same monitor after
  every restart.
- All sizes are registered when the monitor is created. Switching size from the menu is an
  ordinary display-mode change and needs no restart.
- With the 2x (HiDPI) setting, a 1920x1080 size is 3840x2160 pixels. Screenshots are taken in
  pixels, so anything that crops screenshots must allow for the factor of two.

## Starting by itself

- Everything is a launchd **login item** (`~/Library/LaunchAgents`), not a boot service. A
  virtual screen needs the logged-in desktop session, and login items need no administrator
  rights to install.
- So **automatic login** is what makes a reboot unattended, and automatic login needs FileVault
  off. `doctor` treats both as required.
- The virtual screen's login item restarts it after a crash but not after a deliberate quit
  (`KeepAlive` with `SuccessfulExit = false`), so "Turn off until next login" stays off.

## Remote access through Cloudflare

- `cloudflared` on the mini keeps an outbound connection to Cloudflare. No port is opened on the
  router. A hostname on your domain is routed through that connection to `ssh://localhost:22`.
- **`cloudflared service install` without `sudo` writes a login item that runs plain
  `cloudflared` with no arguments.** It starts, prints "use `cloudflared tunnel run`" and never
  connects. `headless remote cloudflare` writes its own login item with
  `tunnel --config ... run`.
- **`cloudflared` reads `~/.cloudflared/config.yml` even for management commands.** If that file
  has a `tunnel:` line, `cloudflared tunnel route dns <other tunnel> <host>` quietly points the
  hostname at the tunnel from the file, not the one you named. `invite` runs these commands with
  an empty config and checks the tunnel id in the reply.
- A join code is the hostname plus the tunnel's token. `join` turns the token into a
  credentials file and runs the tunnel with a local config, the same form as a tunnel created
  on the machine itself.
- A new tunnel hostname is **open to everyone** until an Access application is added for it.
  A request to it returns HTTP 200. Once protected, it returns a 302 to
  `<team>.cloudflareaccess.com`. `doctor` and `client` test exactly that.
- An existing Access policy can be reused for the new application.
- The laptop connects with `ProxyCommand cloudflared access ssh --hostname %h`. The first
  connection opens a browser for the Cloudflare login.
- Cloudflare Tunnel carries TCP only, so mosh (UDP) cannot use it.

## macOS behaviour worth knowing

- **Keychain over SSH.** The login keychain is unlocked for the desktop session only. In an SSH
  session, tools that store tokens there report being logged out. `security unlock-keychain
  ~/Library/Keychains/login.keychain-db` fixes that session. Programs started by launchd run in
  the desktop session and are not affected.
- **Permission prompts follow the program, not the user.** A tool started from Terminal and the
  same tool started by launchd are different programs to macOS, and each gets its own prompts
  for Automation, Accessibility and Screen Recording. Expect a second round of prompts after
  the first reboot, approve them over Screen Sharing, then reboot once more to prove it.
- **Remote Login** can sometimes be turned on with `sudo systemsetup -setremotelogin on`; newer
  macOS may refuse and want the switch in System Settings.
- **Screen Sharing, automatic login and FileVault** cannot be changed by a script.
- **Wi-Fi addresses change.** Use the `.local` name on the same network, or the tunnel hostname.
- A terminal such as Ghostty can fail over SSH with "missing or unsuitable terminal". Prefix
  the command with `TERM=xterm-256color`.

## Alternatives we looked at

| Option | Why not, for us |
|---|---|
| HDMI dummy plug | Works, costs little, but it is hardware to buy and fit on every machine |
| BetterDisplay | Works well. Preset virtual screens stay free after the trial; custom sizes need Pro, and business use needs a licence |
| Other open-source virtual display tools | Either archived, built for a different job, or very new with unreviewed binaries |
| Remote desktop tools that bring their own screen | The screen exists only while someone is connected; we need one all the time |
| Tailscale | Simplest for people; free for personal use, paid per user for a company domain |
