#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

usage() {
  cat <<'USAGE'
Usage:
  scripts/install_ios_release.sh [device-id]

Installs a release build onto a USB-connected iPhone/iPad through Flutter/Xcode.

Arguments:
  device-id   Optional Flutter device id. Defaults to the first detected iOS device.

Environment:
  DART_DEFINES_FILE   Defaults to env/dart_defines.local.json
  DRY_RUN=1           Print commands without executing them
  FLUTTER_DEVICES_OUTPUT
                      Optional pre-captured "flutter devices" output for tests
  SKIP_PUB_GET=1      Skip "flutter pub get"

Examples:
  scripts/install_ios_release.sh
  scripts/install_ios_release.sh 00008110-001234567890801E
  DRY_RUN=1 scripts/install_ios_release.sh
USAGE
}

die() {
  echo "error: $*" >&2
  exit 1
}

run() {
  echo "+ $*"
  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    return 0
  fi
  "$@"
}

detect_ios_device_id() {
  local devices_output
  devices_output="${FLUTTER_DEVICES_OUTPUT:-}"
  if [[ -z "$devices_output" ]]; then
    devices_output="$(flutter devices)"
  fi

  local device_id
  device_id="$(
    printf '%s\n' "$devices_output" |
      awk -F ' • ' '
        NF >= 4 {
          platform = $3
          gsub(/^[ \t]+|[ \t]+$/, "", platform)
          if (platform == "ios") {
            id = $2
            gsub(/^[ \t]+|[ \t]+$/, "", id)
            print id
            exit
          }
        }
      '
  )"

  if [[ -z "$device_id" ]]; then
    printf '%s\n' "$devices_output" >&2
    die "No connected iOS device found. Connect and unlock your iPhone, trust this Mac, then run again."
  fi

  printf '%s\n' "$device_id"
}

print_signing_help() {
  cat >&2 <<'HELP'

iOS release install failed. If the error mentions signing, open Xcode and set up
free Apple ID signing:

  open ios/Runner.xcworkspace

Then in Xcode:
  Runner -> Signing & Capabilities
  Enable "Automatically manage signing"
  Select your Personal Team
  Use a unique Bundle Identifier

On the iPhone, enable Developer Mode and trust this Mac/developer if prompted.
After that, run this script again.
HELP
}

main() {
  cd "$REPO_ROOT"

  if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
  fi
  if (($# > 1)); then
    usage >&2
    exit 64
  fi

  command -v flutter >/dev/null 2>&1 || die "flutter is not on PATH"

  local dart_defines_file="${DART_DEFINES_FILE:-env/dart_defines.local.json}"
  [[ -f "$dart_defines_file" ]] || die "$dart_defines_file not found. Copy env/dart_defines.example.json to $dart_defines_file and fill local values."
  [[ -d ios ]] || die "ios/ directory not found"
  [[ -d ios/Runner.xcworkspace ]] || die "ios/Runner.xcworkspace not found. Run flutter pub get first if iOS files are incomplete."

  local device_id="${1:-}"
  if [[ -z "$device_id" ]]; then
    device_id="$(detect_ios_device_id)"
    echo "Using iOS device: $device_id"
  fi

  if [[ "${SKIP_PUB_GET:-0}" != "1" ]]; then
    run flutter pub get
  fi

  if ! run flutter run --release -d "$device_id" --dart-define-from-file="$dart_defines_file"; then
    print_signing_help
    exit 1
  fi
}

main "$@"
