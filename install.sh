#!/bin/sh
# @spec AI-003 — Verified Linux desktop installation
# Install public release packages only. User state is owned by the desktop app.
set -eu

audit_version=1.0.0
audit_release_repository=Wiqonn/audit-studio-releases
audit_work_dir=

fail() {
  printf 'Wiqonn Audit Studio: %s\n' "$1" >&2
  exit 1
}

help() {
  cat <<'HELP'
Install Wiqonn Audit Studio for Debian, Ubuntu, or Pop!_OS on x86_64.
Usage: sh install-audit-studio.sh [--version X.Y.Z] [--help]
The default release is 1.0.0. Packages and exact-file SHA256 checksums are
downloaded over HTTPS from Wiqonn/audit-studio-releases before apt installs.
Use AUDIT_STUDIO_TMPDIR (or TMPDIR) to choose an existing scratch directory.
HELP
}

cleanup() {
  if [ -n "$audit_work_dir" ]; then
    rm -rf "$audit_work_dir"
  fi
}
trap cleanup 0
trap 'exit 129' 1
trap 'exit 130' 2
trap 'exit 143' 15

while [ "$#" -gt 0 ]; do
  case "$1" in
    --version)
      [ "$#" -ge 2 ] || fail '--version requires a numeric X.Y.Z version.'
      audit_version=$2
      shift 2
      ;;
    --help|-h)
      help
      exit 0
      ;;
    *) fail 'Unknown option. Use --help for usage.' ;;
  esac
done

case "$audit_version" in
  ''|*[!0-9.]*|.*|*.|*..*) fail 'Invalid version; expected numeric X.Y.Z.' ;;
  *.*.*) ;;
  *) fail 'Invalid version; expected numeric X.Y.Z.' ;;
esac
audit_version_tail=${audit_version#*.}
audit_version_patch=${audit_version_tail#*.}
case "$audit_version_patch" in
  *.*) fail 'Invalid version; expected numeric X.Y.Z.' ;;
esac

[ "$(uname -s)" = Linux ] || fail 'This installer supports Linux only.'
case "$(uname -m)" in
  x86_64|amd64) ;;
  *) fail 'Unsupported architecture; this release requires x86_64 (amd64).' ;;
esac

for audit_command in curl sha256sum cmp mktemp apt-get dpkg-deb; do
  command -v "$audit_command" >/dev/null 2>&1 ||
    fail "Missing $audit_command. This installer requires Debian, Ubuntu, or Pop!_OS with apt-get."
done
audit_install_as_root=false
if [ "$(id -u)" = 0 ]; then
  audit_install_as_root=true
else
  command -v sudo >/dev/null 2>&1 || fail 'sudo is required to install the verified package.'
fi

audit_scratch_root=${AUDIT_STUDIO_TMPDIR:-${TMPDIR:-/tmp}}
case "$audit_scratch_root" in
  /*) ;;
  *) audit_scratch_root=$(pwd)/$audit_scratch_root ;;
esac
[ -d "$audit_scratch_root" ] || fail 'The configured scratch directory does not exist.'
umask 077
audit_work_dir=$(mktemp -d "$audit_scratch_root/wiqonn-audit-studio.XXXXXXXX") ||
  fail 'Could not create a private download directory.'

audit_asset=wiqonn-audit-studio_${audit_version}_amd64.deb
audit_package=$audit_work_dir/$audit_asset
audit_checksum=$audit_package.sha256
audit_base_url=https://github.com/$audit_release_repository/releases/download/v$audit_version

download() {
  curl --disable --fail --location --show-error \
    --proto '=https' --proto-redir '=https' \
    --connect-timeout 15 --max-time 1800 --retry 2 \
    --output "$2" "$1" || fail "Download failed for $3. Check the release version and network connection."
  [ -s "$2" ] || fail "The downloaded $3 is missing or empty."
}

printf 'Downloading Wiqonn Audit Studio %s (amd64)...\n' "$audit_version"
download "$audit_base_url/$audit_asset" "$audit_package" "$audit_asset"
download "$audit_base_url/$audit_asset.sha256" "$audit_checksum" "$audit_asset.sha256"

audit_expected_digest=
audit_checksum_name=
audit_extra=
IFS=' ' read -r audit_expected_digest audit_checksum_name audit_extra < "$audit_checksum" ||
  fail 'Malformed SHA256 checksum sidecar.'
case "$audit_expected_digest" in
  ''|*[!0-9a-f]*) fail 'Malformed SHA256 checksum digest.' ;;
esac
[ "${#audit_expected_digest}" -eq 64 ] || fail 'Malformed SHA256 checksum digest.'
[ "$audit_checksum_name" = "$audit_asset" ] && [ -z "$audit_extra" ] ||
  fail 'The SHA256 checksum must name exactly the selected package.'
# Compare raw bytes against one canonical line. This also rejects extra lines,
# trailing bytes and NULs that shell read implementations may discard.
printf '%s  %s\n' "$audit_expected_digest" "$audit_asset" > "$audit_work_dir/expected.sha256"
cmp -s "$audit_work_dir/expected.sha256" "$audit_checksum" ||
  fail 'Malformed SHA256 checksum sidecar; expected one exact-file checksum line.'
audit_actual_digest=$(sha256sum < "$audit_package")
audit_actual_digest=${audit_actual_digest%% *}
[ "$audit_actual_digest" = "$audit_expected_digest" ] ||
  fail 'SHA256 checksum mismatch. Installation was not attempted.'

audit_package_name=$(dpkg-deb --field "$audit_package" Package 2>/dev/null) ||
  fail 'Invalid Debian package metadata.'
audit_package_version=$(dpkg-deb --field "$audit_package" Version 2>/dev/null) ||
  fail 'Invalid Debian package metadata.'
audit_package_architecture=$(dpkg-deb --field "$audit_package" Architecture 2>/dev/null) ||
  fail 'Invalid Debian package metadata.'
[ "$audit_package_name" = wiqonn-audit-studio ] ||
  fail 'Unexpected Debian package identity; required wiqonn-audit-studio.'
[ "$audit_package_version" = "$audit_version" ] ||
  fail 'The Debian package version does not match the requested release.'
[ "$audit_package_architecture" = amd64 ] ||
  fail 'Unexpected Debian package architecture; required amd64.'

printf 'SHA256 and package metadata verified. Installing Wiqonn Audit Studio %s...\n' "$audit_version"
if [ "$audit_install_as_root" = true ]; then
  apt-get install -y "$audit_package"
else
  sudo apt-get install -y "$audit_package"
fi
printf 'Wiqonn Audit Studio installed successfully. Open it from your application launcher.\n'
