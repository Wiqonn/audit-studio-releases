#!/bin/sh
# @spec AI-003 — Verified Linux and Apple Silicon desktop installation
# Install public release packages only. User state is owned by the desktop app.
set -eu

audit_version=1.1.0
audit_release_repository=Wiqonn/audit-studio-releases
audit_work_dir=
audit_stage_dir=
audit_previous_app=
audit_destination=

fail() {
  printf 'Wiqonn Audit Studio: %s\n' "$1" >&2
  exit 1
}

help() {
  cat <<'HELP'
Install Wiqonn Audit Studio for Debian/Ubuntu/Pop!_OS x86_64 or Apple Silicon macOS.
Usage: sh install-audit-studio.sh [--version X.Y.Z] [--help]
The default release is 1.1.0. Downloads and exact-file SHA256 checksums use
HTTPS from Wiqonn/audit-studio-releases. Linux uses apt; macOS installs to
~/Applications/Wiqonn Audit Studio.app without sudo or changing user settings.
macOS requires Ventura 13.5 or newer for the bundled runtime.
Use AUDIT_STUDIO_TMPDIR (or TMPDIR) to choose an existing scratch directory.
AUDIT_STUDIO_APPLICATIONS_DIR may select another per-user macOS Applications directory.
HELP
}

cleanup() {
  if [ -n "$audit_previous_app" ] && [ -d "$audit_previous_app" ]; then
    if [ ! -e "$audit_destination" ] && [ ! -L "$audit_destination" ] &&
       mv "$audit_previous_app" "$audit_destination"; then
      audit_previous_app=
    else
      printf 'Wiqonn Audit Studio: Restore the previous app from this preserved backup: %s\n' "$audit_previous_app" >&2
      audit_stage_dir=
    fi
  fi
  if [ -n "$audit_stage_dir" ]; then
    rm -rf "$audit_stage_dir"
  fi
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

audit_os=$(uname -s)
audit_arch=$(uname -m)
audit_install_as_root=false
case "$audit_os" in
  Linux)
    case "$audit_arch" in
      x86_64|amd64) ;;
      *) fail 'Unsupported architecture; Linux requires x86_64 (amd64).' ;;
    esac
    audit_asset=wiqonn-audit-studio_${audit_version}_amd64.deb
    audit_commands='curl sha256sum cmp mktemp apt-get dpkg-deb'
    if [ "$(id -u)" = 0 ]; then
      audit_install_as_root=true
    else
      command -v sudo >/dev/null 2>&1 || fail 'sudo is required to install the verified package.'
    fi
    ;;
  Darwin)
    case "$audit_arch" in
      arm64) ;;
      x86_64)
        [ "$(sysctl -in sysctl.proc_translated 2>/dev/null || :)" = 1 ] ||
          fail 'This macOS release requires Apple Silicon; Intel Macs are not supported.'
        ;;
      *) fail 'Unsupported macOS architecture; this release requires Apple Silicon.' ;;
    esac
    command -v sw_vers >/dev/null 2>&1 || fail 'Missing required macOS utility: sw_vers.'
    audit_macos_version=$(sw_vers -productVersion) || fail 'Could not determine the macOS version.'
    case "$audit_macos_version" in
      ''|*[!0-9.]*|.*|*.|*..*) fail 'Could not determine the macOS version.' ;;
      *.*) ;;
      *) fail 'Could not determine the macOS version.' ;;
    esac
    audit_macos_major=${audit_macos_version%%.*}
    audit_macos_tail=${audit_macos_version#*.}
    audit_macos_minor=${audit_macos_tail%%.*}
    if [ "$audit_macos_major" -lt 13 ] ||
       { [ "$audit_macos_major" -eq 13 ] && [ "$audit_macos_minor" -lt 5 ]; }; then
      fail 'This release requires macOS Ventura 13.5 or newer for its bundled runtime.'
    fi
    [ "$(id -u)" != 0 ] || fail 'Run the macOS installer as your normal user, without sudo or root.'
    audit_asset=Wiqonn-Audit-Studio-${audit_version}-arm64.zip
    audit_commands='curl shasum cmp mktemp ditto plutil unzip awk mv'
    ;;
  *) fail 'This installer supports Linux and Apple Silicon macOS only.' ;;
esac

for audit_command in $audit_commands; do
  command -v "$audit_command" >/dev/null 2>&1 ||
    fail "Missing required installation utility: $audit_command."
done

audit_scratch_root=${AUDIT_STUDIO_TMPDIR:-${TMPDIR:-/tmp}}
case "$audit_scratch_root" in
  /*) ;;
  *) audit_scratch_root=$(pwd)/$audit_scratch_root ;;
esac
[ -d "$audit_scratch_root" ] || fail 'The configured scratch directory does not exist.'
umask 077
audit_work_dir=$(mktemp -d "$audit_scratch_root/wiqonn-audit-studio.XXXXXXXX") ||
  fail 'Could not create a private download directory.'

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

printf 'Downloading Wiqonn Audit Studio %s for %s (%s)...\n' "$audit_version" "$audit_os" "$audit_arch"
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
if [ "$audit_os" = Darwin ]; then
  audit_actual_digest=$(shasum -a 256 < "$audit_package")
else
  audit_actual_digest=$(sha256sum < "$audit_package")
fi
audit_actual_digest=${audit_actual_digest%% *}
[ "$audit_actual_digest" = "$audit_expected_digest" ] ||
  fail 'SHA256 checksum mismatch. Installation was not attempted.'

# @spec AI-003 — Verified macOS installation with per-user update rollback
if [ "$audit_os" = Darwin ]; then
  audit_app_name='Wiqonn Audit Studio.app'
  unzip -Z -1 "$audit_package" > "$audit_work_dir/entries" || fail 'Invalid macOS ZIP archive.'
  [ -s "$audit_work_dir/entries" ] || fail 'The macOS archive contains no application bundle.'
  while IFS= read -r audit_entry; do
    case "$audit_entry" in
      "$audit_app_name"|"$audit_app_name"/*|__MACOSX/|"__MACOSX/$audit_app_name/"*|"__MACOSX/._$audit_app_name") ;;
      *) fail 'Unexpected path in the macOS archive; expected only the application bundle.' ;;
    esac
    case "$audit_entry" in
      *\\*|*\**|*\?*|*\[*|*\]*|*/../*|*/..|*/./*|*/.|*//*) fail 'Unsafe path in the macOS archive.' ;;
    esac
  done < "$audit_work_dir/entries"

  # Inspect link targets before extraction, and forbid writes underneath links.
  # Normal framework and bundled Node links remain relative to this bundle.
  unzip -Z -l "$audit_package" > "$audit_work_dir/archive-details" || fail 'Invalid macOS ZIP archive metadata.'
  : > "$audit_work_dir/symlinks"
  while read -r audit_mode audit_format audit_origin audit_size audit_flags audit_compressed audit_method audit_date audit_time audit_entry; do
    case "$audit_mode" in
      l?????????)
        case "$audit_entry" in "$audit_app_name"/*) ;; *) fail 'Unsafe archive symlink.' ;; esac
        audit_target=$(unzip -p "$audit_package" "$audit_entry") || fail 'Could not inspect an archive symlink.'
        case "$audit_target" in ''|/*|*\\*) fail 'Unsafe archive symlink target.' ;; esac
        audit_link_path=${audit_entry%/*}/$audit_target
        audit_saved_ifs=$IFS
        IFS=/
        set -f
        set -- $audit_link_path
        set +f
        IFS=$audit_saved_ifs
        audit_depth=0
        for audit_segment do
          case "$audit_segment" in
            ''|.) ;;
            ..)
              [ "$audit_depth" -gt 1 ] || fail 'Archive symlink escapes the application bundle.'
              audit_depth=$((audit_depth - 1))
              ;;
            *) audit_depth=$((audit_depth + 1)) ;;
          esac
        done
        printf '%s\n' "$audit_entry" >> "$audit_work_dir/symlinks"
        ;;
    esac
  done < "$audit_work_dir/archive-details"
  while IFS= read -r audit_link; do
    awk -v link="$audit_link/" 'index($0, link) == 1 { exit 1 }' "$audit_work_dir/entries" ||
      fail 'The macOS archive writes underneath a symlink.'
  done < "$audit_work_dir/symlinks"

  audit_extracted=$audit_work_dir/extracted
  ditto -x -k "$audit_package" "$audit_extracted" || fail 'Could not extract the macOS archive.'
  audit_new_app=$audit_extracted/$audit_app_name
  [ -d "$audit_new_app" ] && [ ! -L "$audit_new_app" ] || fail 'The archive is missing the application bundle.'

  validate_mac_identity() {
    audit_plist=$1/Contents/Info.plist
    [ -f "$audit_plist" ] && [ ! -L "$audit_plist" ] || fail 'Invalid application plist metadata.'
    audit_bundle_id=$(plutil -extract CFBundleIdentifier raw -o - "$audit_plist" 2>/dev/null) || fail 'Invalid application identity metadata.'
    [ "$audit_bundle_id" = com.wiqonn.audit-studio ] || fail 'Unexpected application identity; an existing unrelated app will not be replaced.'
  }
  validate_mac_identity "$audit_new_app"
  audit_bundle_version=$(plutil -extract CFBundleShortVersionString raw -o - "$audit_plist" 2>/dev/null) || fail 'Invalid application version metadata.'
  [ "$audit_bundle_version" = "$audit_version" ] || fail 'The application version does not match the requested release.'

  audit_applications=${AUDIT_STUDIO_APPLICATIONS_DIR:-${HOME:?HOME must name your user home}/Applications}
  case "$audit_applications" in /*) ;; *) fail 'The Applications directory must be an absolute path.' ;; esac
  [ ! -L "$audit_applications" ] || fail 'The Applications directory must not be a symlink.'
  mkdir -p "$audit_applications" || fail 'Could not create your Applications directory.'
  audit_destination=$audit_applications/$audit_app_name
  if [ -e "$audit_destination" ] || [ -L "$audit_destination" ]; then
    [ -d "$audit_destination" ] && [ ! -L "$audit_destination" ] || fail 'The existing application path is not a regular app bundle.'
    validate_mac_identity "$audit_destination"
  fi
  audit_stage_dir=$(mktemp -d "$audit_applications/.wiqonn-audit-studio-install.XXXXXXXX") || fail 'Could not create a private application staging directory.'
  ditto "$audit_new_app" "$audit_stage_dir/new.app" || fail 'Could not stage the application copy; your existing app was preserved.'
  if [ -d "$audit_destination" ]; then
    # Assign the backup path before the move so signal cleanup can restore it.
    audit_previous_app=$audit_stage_dir/previous.app
    mv "$audit_destination" "$audit_previous_app" || fail 'Could not back up the existing app; installation stopped.'
  fi
  mv "$audit_stage_dir/new.app" "$audit_destination" || fail 'Could not replace the application; restoring the previous app.'
  audit_previous_app=
  printf 'Wiqonn Audit Studio installed successfully at %s. Open it from Finder.\n' "$audit_destination"
  exit 0
fi

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
