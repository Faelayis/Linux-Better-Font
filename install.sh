#!/usr/bin/env bash
set -Eeuo pipefail

readonly ACTION='install'
readonly RAW_BASE_URL="${LINUX_BETTER_FONT_RAW_BASE_URL:-https://raw.githubusercontent.com/faelayis/Linux-Better-Font/main}"

case "$#" in
    0) ;;
    1) [[ "$1" == '--root' ]] || { printf 'Usage: %s [--root]\n' "$(basename -- "$0")" >&2; exit 2; } ;;
    *) printf 'Usage: %s [--root]\n' "$(basename -- "$0")" >&2; exit 2 ;;
esac

script_source="${BASH_SOURCE[0]:-}"
if [[ -n "$script_source" ]]; then
    script_dir=$(cd -- "$(dirname -- "$script_source")" 2>/dev/null && pwd -P) || script_dir=''
    if [[ -f "$script_dir/lib/dispatch.sh" ]]; then
        exec bash "$script_dir/lib/dispatch.sh" "$ACTION" "$@"
    fi
fi

command -v curl >/dev/null 2>&1 || { printf '%s\n' 'ERROR: curl is required' >&2; exit 1; }
temporary_file=$(mktemp) || { printf '%s\n' 'ERROR: Could not create a temporary file' >&2; exit 1; }
trap 'rm -f -- "${temporary_file:-}"' EXIT
curl -fsSL "$RAW_BASE_URL/lib/dispatch.sh" -o "$temporary_file"
LINUX_BETTER_FONT_RAW_BASE_URL="$RAW_BASE_URL" bash "$temporary_file" "$ACTION" "$@"
