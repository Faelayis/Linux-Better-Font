#!/usr/bin/env bash
set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"

# shellcheck source=common.sh
. "$SCRIPT_DIR/common.sh"

configure_scope "$@"
ui_header 'Uninstall'
ui_scope
check_fedora
require_command fc-cache
uninstall_fix
