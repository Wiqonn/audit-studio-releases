# Wiqonn Audit Studio downloads

Linux desktop app built on [OpenHands Agent Canvas](https://github.com/OpenHands/OpenHands),
with audit data sources and downloadable chart artifacts.

This repository contains the installer and public release downloads. Development
source is maintained separately by Wiqonn.

## Install

For x86-64 Debian, Ubuntu and Pop!_OS:

```sh
curl -fsSL https://github.com/Wiqonn/audit-studio-releases/releases/download/v1.0.0/install.sh | sh
```

The installer verifies the package's SHA256 and native package identity before
installing it with apt. It may prompt for your sudo password.
Open **Wiqonn Audit Studio** from your application menu after installation.

Each OS user configures their own agent/model and data sources in the app.
The download includes no configured sources, database credentials, business demo
data, conversation history or saved user settings. Python and backend packages
are downloaded on first launch, with progress shown in the loading window.

Settings are stored under `~/.config/wiqonn-audit-studio` on Linux. Updates preserve
that user's configuration. Sources support databases, CSV/Parquet files,
directories and Swagger/OpenAPI endpoints.

## Downloads

Versioned assets are available from [Releases](https://github.com/Wiqonn/audit-studio-releases/releases).
Each release includes a `.deb`, an AppImage, SHA256 checksum sidecars, the installer,
and program metadata. The one-line installer uses the Debian package; AppImage
is available for manual use on compatible Linux systems.

The first release supports Linux x86-64. Windows and macOS packages are not
provided here yet.

## License and attribution

Audit Studio retains the native OpenHands interface. The OpenHands contributors'
MIT license is included in [LICENSE](LICENSE) and in the application package.
