# Wiqonn Audit Studio downloads

Local desktop app built on [OpenHands Agent Canvas](https://github.com/OpenHands/OpenHands),
with audit data sources and downloadable chart artifacts.

This repository contains the installer and public release downloads. Development
source is maintained separately by Wiqonn.

## Install

For x86-64 Debian, Ubuntu and Pop!\_OS, or Apple Silicon Macs (M1 or newer) with
macOS Ventura 13.5 or newer:

```sh
curl -fsSL https://github.com/Wiqonn/audit-studio-releases/releases/download/v1.1.0/install.sh | sh
```

The script detects your platform and verifies the download's SHA256, application
identity and version. Linux uses apt and may prompt for your sudo password.
Open **Wiqonn Audit Studio** from your application menu after installation.

On macOS it installs **Wiqonn Audit Studio.app** into `~/Applications` without
sudo. Open it from Finder. Apple Silicon shells running under Rosetta are also
supported; Intel Macs are unsupported. Distribution uses GitHub, with no Apple
App Store installation. The Mac app is ad-hoc signed and is not Apple notarized;
macOS may require normal first-open approval in **System Settings > Privacy &
Security**. The script preserves those security checks.

Each OS user configures their own agent/model and data sources in the app.
The download includes no configured sources, database credentials, business demo
data, conversation history or saved user settings. Python and backend packages
are downloaded on first launch, with progress shown in the loading window.

Settings are stored under `~/.config/wiqonn-audit-studio` on Linux and
`~/Library/Application Support/wiqonn-audit-studio` on macOS. Updates preserve
that user's configuration. Sources support databases, CSV/Parquet files,
directories and Swagger/OpenAPI endpoints.

## Downloads

Versioned assets are available from [Releases](https://github.com/Wiqonn/audit-studio-releases/releases).
Version 1.1.0 includes a Linux `.deb`, an AppImage, an Apple Silicon `.app` ZIP,
SHA256 checksum sidecars, the installer and program metadata. The one-line
installer uses the Debian package on Linux and the ARM64 ZIP on macOS. AppImage
is available for manual use on compatible Linux systems.

The original Linux 1.0.0 release remains available at its versioned URL.
Windows packages are not provided here.

## License and attribution

Audit Studio retains the native OpenHands interface. The OpenHands contributors'
MIT license is included in [LICENSE](LICENSE) and in the application package.
