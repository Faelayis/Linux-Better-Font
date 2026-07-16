#!/usr/bin/env bash
set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"

# shellcheck source=common.sh
. "$SCRIPT_DIR/common.sh"

configure_scope "$@"
ui_header 'Status'
ui_scope
check_fedora
require_command fc-match
require_command fc-list
require_command rpm
show_status
