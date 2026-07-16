#!/usr/bin/env bash
set -Eeuo pipefail

readonly RAW_BASE_URL="${LINUX_BETTER_FONT_RAW_BASE_URL:-https://raw.githubusercontent.com/faelayis/Linux-Better-Font/main}"
TEMPORARY_DIR=''

cleanup() {
    [[ -z "$TEMPORARY_DIR" ]] || rm -rf -- "$TEMPORARY_DIR"
}

trap cleanup EXIT

color_enabled() {
    [[ -t "$1" && -z "${NO_COLOR+x}" && "${TERM:-dumb}" != 'dumb' ]]
}

die() {
    local charmap
    local symbol='X'
    charmap=$(locale charmap 2>/dev/null) || charmap=''
    charmap=${charmap,,}
    [[ "$charmap" != 'utf-8' && "$charmap" != 'utf8' ]] || symbol='✗'
    if color_enabled 2; then
        printf '\033[31m%s\033[0m  \033[1mError\033[0m                %s\n' "$symbol" "$*" >&2
    else
        printf '%s  %-20s %s\n' "$symbol" 'Error' "$*" >&2
    fi
    exit 1
}

print_info() {
    local charmap
    local symbol='*'
    charmap=$(locale charmap 2>/dev/null) || charmap=''
    charmap=${charmap,,}
    [[ "$charmap" != 'utf-8' && "$charmap" != 'utf8' ]] || symbol='●'
    if color_enabled 1; then
        printf '\033[36m%s\033[0m  \033[1m%-20s\033[0m %s\n' "$symbol" "$1" "$2"
    else
        printf '%s  %-20s %s\n' "$symbol" "$1" "$2"
    fi
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"
}

detect_distro() {
    [[ -r /etc/os-release ]] || die "Cannot read /etc/os-release"

    (
        set +u
        . /etc/os-release
        printf '%s\n' "${ID:-}"
    )
}

run_action() {
    local distro="$1"
    local action="$2"
    shift 2
    local relative_dir="distros/$distro"
    local script_source="${BASH_SOURCE[0]:-}"
    local script_dir repo_dir distro_dir

    if [[ -n "$script_source" ]]; then
        script_dir=$(cd -- "$(dirname -- "$script_source")" 2>/dev/null && pwd -P) || script_dir=''
        repo_dir=$(cd -- "$script_dir/.." 2>/dev/null && pwd -P) || repo_dir=''
        distro_dir="$repo_dir/$relative_dir"
        if [[ -f "$distro_dir/common.sh" && -f "$distro_dir/$action.sh" ]]; then
            exec bash "$distro_dir/$action.sh" "$@"
        fi
    fi

    require_command curl
    require_command mktemp
    TEMPORARY_DIR=$(mktemp -d) || die "Could not create a temporary directory"

    print_info 'Loading scripts' "$distro $action"
    curl -fsSL "$RAW_BASE_URL/$relative_dir/common.sh" -o "$TEMPORARY_DIR/common.sh"
    curl -fsSL "$RAW_BASE_URL/$relative_dir/$action.sh" -o "$TEMPORARY_DIR/$action.sh"
    bash "$TEMPORARY_DIR/$action.sh" "$@"
}

main() {
    local action="${1:-}"
    local distro

    (( $# == 1 || $# == 2 )) || die "Usage: dispatch.sh ACTION [--root]"
    case "$action" in
        install|status|uninstall) ;;
        *) die "Unsupported action: $action" ;;
    esac
    if (( $# == 2 )) && [[ "$2" != '--root' ]]; then
        die "Unsupported option: $2"
    fi

    distro=$(detect_distro)
    case "$distro" in
        fedora) run_action fedora "$action" "${@:2}" ;;
        '') die "Could not detect the Linux distribution" ;;
        *) die "Unsupported Linux distribution: $distro" ;;
    esac
}

main "$@"
