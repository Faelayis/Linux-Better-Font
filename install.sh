#!/usr/bin/env bash
set -Eeuo pipefail

readonly ACTION='install'
readonly RAW_BASE_URL="${LINUX_BETTER_FONT_RAW_BASE_URL:-https://raw.githubusercontent.com/faelayis/Linux-Better-Font/main}"

print_error() {
    local charmap
    local symbol='X'
    charmap=$(locale charmap 2>/dev/null) || charmap=''
    charmap=${charmap,,}
    [[ "$charmap" != 'utf-8' && "$charmap" != 'utf8' ]] || symbol='✗'
    if [[ -t 2 && -z "${NO_COLOR+x}" && "${TERM:-dumb}" != 'dumb' ]]; then
        printf '\033[31m%s\033[0m  \033[1mError\033[0m                %s\n' "$symbol" "$*" >&2
    else
        printf '%s  %-20s %s\n' "$symbol" 'Error' "$*" >&2
    fi
}

print_usage() {
    printf 'Usage: %s [--root]\n' "$(basename -- "$0")" >&2
}

case "$#" in
    0) ;;
    1) [[ "$1" == '--root' ]] || { print_usage; exit 2; } ;;
    *) print_usage; exit 2 ;;
esac

script_source="${BASH_SOURCE[0]:-}"
if [[ -n "$script_source" ]]; then
    script_dir=$(cd -- "$(dirname -- "$script_source")" 2>/dev/null && pwd -P) || script_dir=''
    if [[ -f "$script_dir/lib/dispatch.sh" ]]; then
        exec bash "$script_dir/lib/dispatch.sh" "$ACTION" "$@"
    fi
fi

command -v curl >/dev/null 2>&1 || { print_error 'curl is required'; exit 1; }
temporary_file=$(mktemp) || { print_error 'Could not create a temporary file'; exit 1; }
trap 'rm -f -- "${temporary_file:-}"' EXIT
curl -fsSL "$RAW_BASE_URL/lib/dispatch.sh" -o "$temporary_file"
LINUX_BETTER_FONT_RAW_BASE_URL="$RAW_BASE_URL" bash "$temporary_file" "$ACTION" "$@"
