#!/usr/bin/env bash
set -Eeuo pipefail

CONFIG_DIR=''
CONFIG_FILE=''
TEMPORARY_CONFIG_FILE=''
DESKTOP_HOME=''
DESKTOP_CONFIG_HOME=''
DESKTOP_STATE_HOME=''
USER_CONFIG_DIR=''
FLATPAK_BRIDGE_FILE=''
FLATPAK_STATE_DIR=''
FLATPAK_OVERRIDE_MARKER=''
readonly MANAGED_MARKER='  <!-- Managed by Linux-Better-Font -->'
declare -a NOTO_SANS_FAMILIES=()
declare -a NOTO_SERIF_FAMILIES=()
declare -a NOTO_MONO_FAMILIES=()
declare -a NOTO_OTHER_FAMILIES=()

UI_BOLD=''
UI_DIM=''
UI_CYAN=''
UI_GREEN=''
UI_YELLOW=''
UI_RED=''
UI_RESET=''
UI_BULLET='-'
UI_INFO='*'
UI_OK='+'
UI_SKIP='-'
UI_FAIL='X'

unicode_enabled() {
    local charmap
    charmap=$(locale charmap 2>/dev/null) || return 1
    charmap=${charmap,,}
    [[ "$charmap" == 'utf-8' || "$charmap" == 'utf8' ]]
}

if unicode_enabled; then
    UI_BULLET='•'
    UI_INFO='●'
    UI_OK='✓'
    UI_SKIP='−'
    UI_FAIL='✗'
fi

color_enabled() {
    [[ -t "$1" && -z "${NO_COLOR+x}" && "${TERM:-dumb}" != 'dumb' ]]
}

if color_enabled 1; then
    UI_BOLD=$'\033[1m'
    UI_DIM=$'\033[2m'
    UI_CYAN=$'\033[36m'
    UI_GREEN=$'\033[32m'
    UI_YELLOW=$'\033[33m'
    UI_RED=$'\033[31m'
    UI_RESET=$'\033[0m'
fi

ui_header() {
    printf '\n%bLinux Better Font%b  %b%s%b  %b%s%b\n' \
        "$UI_BOLD" "$UI_RESET" "$UI_DIM" "$UI_BULLET" "$UI_RESET" "$UI_BOLD" "$1" "$UI_RESET"
}

ui_scope() {
    local scope='Current user'
    [[ "$CONFIG_DIR" != '/etc/fonts/conf.d' ]] || scope='System-wide'
    printf '%b%-23s%b %s\n' "$UI_DIM" 'Scope' "$UI_RESET" "$scope"
}

ui_section() {
    printf '\n%b%s%b\n' "$UI_BOLD" "$1" "$UI_RESET"
}

ui_status() {
    local symbol="$1"
    local color="$2"
    local label="$3"
    local detail="$4"
    local padded_label

    printf -v padded_label '%-20s' "$label"
    printf '%b%s%b  %b%s%b %s\n' \
        "$color" "$symbol" "$UI_RESET" "$UI_BOLD" "$padded_label" "$UI_RESET" "$detail"
}

ui_info() { ui_status "$UI_INFO" "$UI_CYAN" "$1" "${2:-}"; }
ui_ok() { ui_status "$UI_OK" "$UI_GREEN" "$1" "${2:-}"; }
ui_warn() { ui_status '!' "$UI_YELLOW" "$1" "${2:-}"; }
ui_skip() { ui_status "$UI_SKIP" "$UI_YELLOW" "$1" "${2:-}"; }
ui_fail() { ui_status "$UI_FAIL" "$UI_RED" "$1" "${2:-}"; }

ui_detail() {
    printf '   %b%s%b\n' "$UI_DIM" "$1" "$UI_RESET"
}

die() {
    if color_enabled 2; then
        printf '\033[31m%s\033[0m  \033[1mError\033[0m                %s\n' "$UI_FAIL" "$*" >&2
    else
        printf '%s  %-20s %s\n' "$UI_FAIL" 'Error' "$*" >&2
    fi
    exit 1
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"
}

discover_noto_families() {
    local families

    families=$(run_fontconfig fc-list -f '%{family[0]}\n' | LC_ALL=C sort -u)
    mapfile -t NOTO_MONO_FAMILIES < <(printf '%s\n' "$families" | awk '/^Noto Sans Mono($| )/')
    mapfile -t NOTO_SANS_FAMILIES < <(printf '%s\n' "$families" | awk '/^Noto Sans($| )/ && !/^Noto Sans Mono($| )/')
    mapfile -t NOTO_SERIF_FAMILIES < <(printf '%s\n' "$families" | awk '/^Noto Serif($| )/')
    mapfile -t NOTO_OTHER_FAMILIES < <(printf '%s\n' "$families" | awk '/^Noto($| )/ && !/^Noto Sans($| )/ && !/^Noto Serif($| )/')

    (( ${#NOTO_SANS_FAMILIES[@]} > 0 )) || die "No Noto Sans families were found"
    (( ${#NOTO_SERIF_FAMILIES[@]} > 0 )) || die "No Noto Serif families were found"
    (( ${#NOTO_MONO_FAMILIES[@]} > 0 )) || die "No Noto Sans Mono families were found"
}

emit_family_elements() {
    local family

    for family in "$@"; do
        [[ "$family" != *['&<>']* ]] || die "Unsupported XML character in font family: $family"
        printf '      <family>%s</family>\n' "$family"
    done
}

generate_fontconfig_xml() {
    cat <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
<fontconfig>
  <description>Complete Noto fallback and Ubuntu-style rendering for Fedora</description>
  <!-- Managed by Linux-Better-Font -->
  <!-- Prefer every installed Noto family before non-Noto fallbacks. -->
  <alias binding="strong">
    <family>sans-serif</family>
    <prefer>
EOF
    emit_family_elements "${NOTO_SANS_FAMILIES[@]}" "${NOTO_SERIF_FAMILIES[@]}" "${NOTO_MONO_FAMILIES[@]}" "${NOTO_OTHER_FAMILIES[@]}"
    cat <<'EOF'
    </prefer>
  </alias>
  <alias binding="strong">
    <family>serif</family>
    <prefer>
EOF
    emit_family_elements "${NOTO_SERIF_FAMILIES[@]}" "${NOTO_SANS_FAMILIES[@]}" "${NOTO_MONO_FAMILIES[@]}" "${NOTO_OTHER_FAMILIES[@]}"
    cat <<'EOF'
    </prefer>
  </alias>
  <alias binding="strong">
    <family>monospace</family>
    <prefer>
EOF
    emit_family_elements "${NOTO_MONO_FAMILIES[@]}" "${NOTO_SANS_FAMILIES[@]}" "${NOTO_SERIF_FAMILIES[@]}" "${NOTO_OTHER_FAMILIES[@]}"
    cat <<'EOF'
    </prefer>
  </alias>

  <!-- Match Ubuntu desktop rendering at 100% scale. -->
  <match target="font">
    <edit name="antialias" mode="assign"><bool>true</bool></edit>
    <edit name="hinting" mode="assign"><bool>true</bool></edit>
    <edit name="hintstyle" mode="assign"><const>hintslight</const></edit>
    <edit name="rgba" mode="assign"><const>rgb</const></edit>
    <edit name="lcdfilter" mode="assign"><const>lcddefault</const></edit>
  </match>

  <!-- Reject non-scalable bitmap fonts; scalable color emoji remains. -->
  <selectfont>
    <rejectfont>
      <pattern>
        <patelt name="outline"><bool>false</bool></patelt>
        <patelt name="scalable"><bool>false</bool></patelt>
      </pattern>
    </rejectfont>
  </selectfont>
</fontconfig>
EOF
}

cleanup_config() {
    [[ -z "$TEMPORARY_CONFIG_FILE" ]] || rm -f -- "$TEMPORARY_CONFIG_FILE"
}

trap cleanup_config EXIT

configure_scope() {
    local passwd_entry

    (( $# <= 1 )) || die "Expected no options or --root"

    DESKTOP_HOME="$HOME"
    if (( EUID == 0 )) && [[ -n "${SUDO_USER:-}" && "$SUDO_USER" != 'root' ]]; then
        require_command getent
        passwd_entry=$(getent passwd "$SUDO_USER") || die "Cannot find invoking user: $SUDO_USER"
        DESKTOP_HOME=$(printf '%s\n' "$passwd_entry" | cut -d: -f6)
        DESKTOP_CONFIG_HOME="$DESKTOP_HOME/.config"
        DESKTOP_STATE_HOME="$DESKTOP_HOME/.local/state"
    else
        DESKTOP_CONFIG_HOME="${XDG_CONFIG_HOME:-$DESKTOP_HOME/.config}"
        DESKTOP_STATE_HOME="${XDG_STATE_HOME:-$DESKTOP_HOME/.local/state}"
    fi

    USER_CONFIG_DIR="$DESKTOP_CONFIG_HOME/fontconfig/conf.d"
    FLATPAK_BRIDGE_FILE="$USER_CONFIG_DIR/98-noto-base-flatpak.conf"
    FLATPAK_STATE_DIR="$DESKTOP_STATE_HOME/linux-better-font"
    FLATPAK_OVERRIDE_MARKER="$FLATPAK_STATE_DIR/flatpak-fontconfig-override"

    case "${1:-}" in
        '') CONFIG_DIR="$USER_CONFIG_DIR" ;;
        --root) CONFIG_DIR='/etc/fonts/conf.d' ;;
        *) die "Unsupported option: $1" ;;
    esac
    CONFIG_FILE="$CONFIG_DIR/99-noto-base.conf"
}

check_fedora() {
    [[ -r /etc/os-release ]] || die "Cannot read /etc/os-release"
    grep -q '^ID=fedora$' /etc/os-release || die "This script supports Fedora only"
}

run_as_root() {
    if (( EUID == 0 )); then
        "$@"
    else
        require_command sudo
        sudo "$@"
    fi
}

run_as_desktop_user() {
    if (( EUID == 0 )) && [[ -n "${SUDO_USER:-}" && "$SUDO_USER" != 'root' ]]; then
        require_command sudo
        sudo -u "$SUDO_USER" env HOME="$DESKTOP_HOME" XDG_CONFIG_HOME="$DESKTOP_CONFIG_HOME" XDG_STATE_HOME="$DESKTOP_STATE_HOME" "$@"
    else
        "$@"
    fi
}

remove_user_state_dir_if_empty() {
    [[ -d "$1" ]] || return 0
    run_as_desktop_user rmdir --ignore-fail-on-non-empty "$1"
}

run_fontconfig() {
    if [[ "$CONFIG_DIR" == '/etc/fonts/conf.d' ]]; then
        require_command env
        env -u FONTCONFIG_FILE -u FONTCONFIG_PATH HOME=/nonexistent XDG_CONFIG_HOME=/nonexistent "$@"
    else
        run_as_desktop_user "$@"
    fi
}

refresh_font_cache() {
    if [[ "$CONFIG_DIR" == '/etc/fonts/conf.d' ]]; then
        run_as_root fc-cache -f
    else
        run_as_desktop_user fc-cache -f
    fi
}

ensure_noto_fonts() {
    local package='google-noto-fonts-all'

    require_command rpm
    if ! rpm -q "$package" >/dev/null 2>&1; then
        require_command dnf
        ui_info 'Required package' "Installing $package"
        run_as_root dnf install -y "$package"
    else
        ui_ok 'Required package' "$package is installed"
    fi
}

is_managed_config() {
    is_managed_file "$CONFIG_FILE"
}

is_managed_file() {
    [[ -f "$1" ]] && grep -Fxq "$MANAGED_MARKER" "$1"
}

verify_generated_config() {
    local file="$1"
    local label="$2"
    local actual expected

    actual=$(<"$file")
    expected=$(generate_fontconfig_xml)
    if [[ "$actual" == "$expected" ]]; then
        ui_ok "$label" 'Current'
        ui_detail "$file"
        return 0
    fi

    ui_fail "$label" 'Stale or incomplete'
    ui_detail "$file"
    return 1
}

preflight_managed_file() {
    local file="$1"

    [[ ! -e "$file" ]] && return
    is_managed_file "$file" || die "Refusing to modify unmanaged file: $file"
}

preflight_install_files() {
    preflight_managed_file "$CONFIG_FILE"
    if [[ "$CONFIG_DIR" == '/etc/fonts/conf.d' ]]; then
        preflight_managed_file "$FLATPAK_BRIDGE_FILE"
    fi
}

write_config() {
    if [[ -e "$CONFIG_FILE" ]] && ! is_managed_config; then
        die "Refusing to overwrite unmanaged file: $CONFIG_FILE"
    fi

    require_command mktemp
    if [[ "$CONFIG_DIR" == '/etc/fonts/conf.d' ]]; then
        require_command install
        TEMPORARY_CONFIG_FILE=$(mktemp) || die "Could not create a temporary file"
        generate_fontconfig_xml > "$TEMPORARY_CONFIG_FILE"
        run_as_root install -D -m 0644 "$TEMPORARY_CONFIG_FILE" "$CONFIG_FILE"
    else
        require_command tee
        run_as_desktop_user mkdir -p -- "$CONFIG_DIR"
        TEMPORARY_CONFIG_FILE=$(run_as_desktop_user mktemp --tmpdir="$CONFIG_DIR" '.99-noto-base.conf.XXXXXX') || die "Could not create a temporary file"
        generate_fontconfig_xml | run_as_desktop_user tee "$TEMPORARY_CONFIG_FILE" >/dev/null
        run_as_desktop_user chmod 0644 "$TEMPORARY_CONFIG_FILE"
        run_as_desktop_user mv -f -- "$TEMPORARY_CONFIG_FILE" "$CONFIG_FILE"
    fi
    rm -f -- "$TEMPORARY_CONFIG_FILE"
    TEMPORARY_CONFIG_FILE=''
}

write_flatpak_bridge() {
    if [[ -e "$FLATPAK_BRIDGE_FILE" ]] && ! is_managed_file "$FLATPAK_BRIDGE_FILE"; then
        die "Refusing to overwrite unmanaged file: $FLATPAK_BRIDGE_FILE"
    fi

    require_command mktemp
    require_command tee
    run_as_desktop_user mkdir -p -- "$USER_CONFIG_DIR"
    TEMPORARY_CONFIG_FILE=$(run_as_desktop_user mktemp --tmpdir="$USER_CONFIG_DIR" '.98-noto-base-flatpak.conf.XXXXXX') || die "Could not create a temporary Flatpak bridge"
    generate_fontconfig_xml | run_as_desktop_user tee "$TEMPORARY_CONFIG_FILE" >/dev/null
    run_as_desktop_user chmod 0644 "$TEMPORARY_CONFIG_FILE"
    run_as_desktop_user mv -f -- "$TEMPORARY_CONFIG_FILE" "$FLATPAK_BRIDGE_FILE"
    TEMPORARY_CONFIG_FILE=''
}

flatpak_override_has_fontconfig() {
    local overrides

    overrides=$(run_as_desktop_user flatpak override --user --show 2>/dev/null) || return 2
    grep -Eq '(^|[=;])xdg-config/fontconfig(:ro|:create)?(;|$)' <<< "$overrides"
}

install_flatpak_override() {
    local marker_created=0 override_status

    if ! command -v flatpak >/dev/null 2>&1; then
        ui_skip 'Flatpak integration' 'Flatpak is not installed'
        return
    fi

    if flatpak_override_has_fontconfig; then
        ui_ok 'Flatpak access' 'Already enabled'
        return
    else
        override_status=$?
        (( override_status == 1 )) || die "Could not inspect Flatpak overrides"
    fi

    if [[ ! -e "$FLATPAK_OVERRIDE_MARKER" ]]; then
        run_as_desktop_user mkdir -p -- "$FLATPAK_STATE_DIR"
        run_as_desktop_user touch -- "$FLATPAK_OVERRIDE_MARKER"
        marker_created=1
    fi
    if ! run_as_desktop_user flatpak override --user --filesystem=xdg-config/fontconfig:ro; then
        if (( marker_created == 1 )); then
            run_as_desktop_user rm -f -- "$FLATPAK_OVERRIDE_MARKER"
            remove_user_state_dir_if_empty "$FLATPAK_STATE_DIR"
        fi
        die "Could not enable Flatpak Fontconfig access"
    fi
    ui_ok 'Flatpak access' 'Enabled read-only Fontconfig access'
}

remove_flatpak_override_if_unused() {
    if [[ ! -e "$FLATPAK_OVERRIDE_MARKER" ]]; then
        return
    fi
    if is_managed_file "$USER_CONFIG_DIR/99-noto-base.conf" ||
       is_managed_file "$FLATPAK_BRIDGE_FILE"; then
        return
    fi
    if ! command -v flatpak >/dev/null 2>&1; then
        ui_warn 'Flatpak access' 'Command unavailable; override was not removed'
        return
    fi

    run_as_desktop_user flatpak override --user --nofilesystem=xdg-config/fontconfig
    run_as_desktop_user rm -f -- "$FLATPAK_OVERRIDE_MARKER"
    remove_user_state_dir_if_empty "$FLATPAK_STATE_DIR"
    ui_ok 'Flatpak access' 'Removed Fontconfig access'
}

verify_flatpak() {
    local -a apps=()
    local app app_list arabic_match cjk_match devanagari_match mono_match override_status sans_match serif_match
    local failed=0

    if ! command -v flatpak >/dev/null 2>&1; then
        ui_skip 'Flatpak' 'Not installed'
        return
    fi
    if [[ "$CONFIG_DIR" == '/etc/fonts/conf.d' ]]; then
        if is_managed_file "$FLATPAK_BRIDGE_FILE"; then
            verify_generated_config "$FLATPAK_BRIDGE_FILE" 'Flatpak bridge' || failed=1
        else
            ui_fail 'Flatpak bridge' 'Missing'
            ui_detail "$FLATPAK_BRIDGE_FILE"
            failed=1
        fi
    fi
    if flatpak_override_has_fontconfig; then
        ui_ok 'Flatpak access' 'xdg-config/fontconfig enabled'
    else
        override_status=$?
        if (( override_status == 1 )); then
            ui_fail 'Flatpak access' 'Missing'
        else
            ui_fail 'Flatpak access' 'Query failed'
        fi
        failed=1
    fi

    if ! app_list=$(run_as_desktop_user flatpak list --app --columns=application 2>/dev/null); then
        ui_fail 'Flatpak sandbox' 'Application query failed'
        failed=1
    elif [[ -z "$app_list" ]]; then
        ui_skip 'Flatpak sandbox' 'Not tested; no applications installed'
    else
        mapfile -t apps <<< "$app_list"
        app=${apps[0]}
        if sans_match=$(run_as_desktop_user flatpak run --command=fc-match "$app" -f '%{family[0]}|%{file}\n' 'sans-serif' 2>/dev/null) &&
           serif_match=$(run_as_desktop_user flatpak run --command=fc-match "$app" -f '%{family[0]}|%{file}\n' 'serif' 2>/dev/null) &&
           mono_match=$(run_as_desktop_user flatpak run --command=fc-match "$app" -f '%{family[0]}|%{file}\n' 'monospace' 2>/dev/null) &&
           arabic_match=$(run_as_desktop_user flatpak run --command=fc-match "$app" -f '%{family[0]}|%{file}\n' 'sans-serif:charset=0627' 2>/dev/null) &&
            devanagari_match=$(run_as_desktop_user flatpak run --command=fc-match "$app" -f '%{family[0]}|%{file}\n' 'sans-serif:charset=0905' 2>/dev/null) &&
            cjk_match=$(run_as_desktop_user flatpak run --command=fc-match "$app" -f '%{family[0]}|%{file}\n' 'sans-serif:charset=4e2d' 2>/dev/null); then
            if [[ "$sans_match" == Noto\ Sans\|* &&
                  "$serif_match" == Noto\ Serif\|* &&
                  "$mono_match" == Noto\ Sans\ Mono\|* ]]; then
                ui_ok 'Flatpak sandbox' "$app"
            else
                ui_fail 'Flatpak sandbox' "$app"
                failed=1
            fi
            ui_detail "sans-serif: $sans_match"
            ui_detail "serif: $serif_match"
            ui_detail "monospace: $mono_match"
            if [[ "$arabic_match" == Noto\ * && "$devanagari_match" == Noto\ * && "$cjk_match" == Noto\ * ]]; then
                ui_ok 'Flatpak scripts' "$arabic_match | $devanagari_match | $cjk_match"
            else
                ui_fail 'Flatpak scripts' "$arabic_match | $devanagari_match | $cjk_match"
                failed=1
            fi
        else
            ui_fail 'Flatpak sandbox' "Verification failed ($app)"
            failed=1
        fi
    fi

    (( failed == 0 ))
}

first_match() {
    run_fontconfig fc-match -f '%{family[0]} | %{style[0]} | %{file}\n' "$1"
}

verify_match() {
    local label="$1"
    local pattern="$2"
    local expected_family="$3"
    local actual_family match

    actual_family=$(run_fontconfig fc-match -f '%{family[0]}\n' "$pattern")
    match=$(first_match "$pattern")
    if [[ "$actual_family" == "$expected_family" ]]; then
        ui_ok "$label" "$match"
        return
    fi

    ui_fail "$label" "$match"
    ui_detail "Expected: $expected_family"
    return 1
}

verify_noto_match() {
    local label="$1"
    local pattern="$2"
    local actual_family match

    actual_family=$(run_fontconfig fc-match -f '%{family[0]}\n' "$pattern")
    match=$(first_match "$pattern")
    if [[ "$actual_family" == Noto\ * ]]; then
        ui_ok "$label" "$match"
        return
    fi

    ui_fail "$label" "$match"
    ui_detail 'Expected: a Noto family'
    return 1
}

verify_noto_inventory() {
    local family_count

    family_count=$(( ${#NOTO_SANS_FAMILIES[@]} + ${#NOTO_SERIF_FAMILIES[@]} + ${#NOTO_MONO_FAMILIES[@]} + ${#NOTO_OTHER_FAMILIES[@]} ))
    if (( family_count > 0 )); then
        ui_ok 'Noto families' "$family_count installed"
        return
    fi

    ui_fail 'Noto families' 'None installed'
    return 1
}

verify_rendering() {
    local actual

    actual=$(run_fontconfig fc-match -f '%{antialias}|%{hinting}|%{hintstyle}|%{rgba}|%{lcdfilter}\n' 'sans-serif')
    if [[ "$actual" == 'True|True|1|1|1' ]]; then
        ui_ok 'Rendering' "$actual"
        ui_detail 'antialias | hinting | hintstyle | rgba | lcdfilter'
        return
    fi

    ui_fail 'Rendering' "$actual"
    ui_detail 'Expected: True | True | 1 | 1 | 1'
    return 1
}

verify_emoji() {
    local family properties

    family=$(run_fontconfig fc-match -f '%{family[0]}\n' 'emoji:charset=1f600')
    properties=$(run_fontconfig fc-match -f '%{color}|%{scalable}|%{file}\n' 'emoji:charset=1f600')
    if [[ "$family" == 'Noto Color Emoji' && "$properties" == True\|True\|* ]]; then
        ui_ok 'Emoji' "$family | $properties"
        return
    fi

    ui_fail 'Emoji' "$family | $properties"
    ui_detail 'Expected: Noto Color Emoji with color and scalable enabled'
    return 1
}

verify_bitmaps_hidden() {
    local matches

    matches=$(run_fontconfig fc-list ':outline=false:scalable=false' -f '%{file}\n')
    if [[ -z "$matches" ]]; then
        ui_ok 'Bitmap fonts' 'Hidden'
        return 0
    fi

    ui_fail 'Bitmap fonts' 'Visible'
    ui_detail "$matches"
    return 1
}

show_status() {
    local failed=0

    discover_noto_families

    ui_section 'Configuration'
    if is_managed_config; then
        verify_generated_config "$CONFIG_FILE" 'Config' || failed=1
    elif [[ -e "$CONFIG_FILE" ]]; then
        ui_fail 'Config' 'Unmanaged file exists'
        ui_detail "$CONFIG_FILE"
        failed=1
    else
        ui_fail 'Config' 'Not installed'
        ui_detail "$CONFIG_FILE"
        failed=1
    fi
    if rpm -q google-noto-fonts-all >/dev/null 2>&1; then
        ui_ok 'Noto package' 'google-noto-fonts-all installed'
    else
        ui_fail 'Noto package' 'google-noto-fonts-all missing'
        failed=1
    fi

    ui_section 'Generic fonts'
    verify_match 'sans-serif' 'sans-serif' 'Noto Sans' || failed=1
    verify_match 'serif' 'serif' 'Noto Serif' || failed=1
    verify_match 'monospace' 'monospace' 'Noto Sans Mono' || failed=1

    ui_section 'Script coverage'
    verify_noto_inventory || failed=1
    verify_noto_match 'Arabic' 'sans-serif:charset=0627' || failed=1
    verify_noto_match 'Devanagari' 'sans-serif:charset=0905' || failed=1
    verify_noto_match 'CJK' 'sans-serif:charset=4e2d' || failed=1

    ui_section 'Policy and rendering'
    verify_bitmaps_hidden || failed=1
    verify_rendering || failed=1
    verify_emoji || failed=1

    ui_section 'Flatpak integration'
    verify_flatpak || failed=1

    printf '\n'
    if (( failed == 0 )); then
        ui_ok 'Verification' 'All checks passed'
        return
    fi

    ui_fail 'Verification' 'Completed with issues'
    return 1
}

install_fix() {
    preflight_install_files
    ensure_noto_fonts
    discover_noto_families
    write_config
    ui_ok 'Fontconfig file' 'Written'
    ui_detail "$CONFIG_FILE"
    if [[ "$CONFIG_DIR" == '/etc/fonts/conf.d' ]]; then
        write_flatpak_bridge
        ui_ok 'Flatpak bridge' 'Written'
        ui_detail "$FLATPAK_BRIDGE_FILE"
    fi
    install_flatpak_override
    ui_info 'Font cache' 'Refreshing'
    refresh_font_cache
    ui_section 'Verification'
    show_status
    printf '\n'
    ui_ok 'Installation' 'Complete'
    ui_detail 'Restart open applications to apply the new fonts.'
}

uninstall_fix() {
    preflight_install_files

    if [[ -e "$CONFIG_FILE" ]]; then
        if [[ "$CONFIG_DIR" == '/etc/fonts/conf.d' ]]; then
            run_as_root rm -f -- "$CONFIG_FILE"
        else
            run_as_desktop_user rm -f -- "$CONFIG_FILE"
        fi
        ui_ok 'Removed config' "$CONFIG_FILE"
    else
        ui_skip 'Config' 'Already absent'
        ui_detail "$CONFIG_FILE"
    fi

    if [[ "$CONFIG_DIR" == '/etc/fonts/conf.d' && -e "$FLATPAK_BRIDGE_FILE" ]]; then
        run_as_desktop_user rm -f -- "$FLATPAK_BRIDGE_FILE"
        ui_ok 'Removed bridge' "$FLATPAK_BRIDGE_FILE"
    fi

    remove_flatpak_override_if_unused
    ui_info 'Font cache' 'Refreshing'
    refresh_font_cache
    printf '\n'
    ui_ok 'Uninstall' 'Complete'
    ui_detail 'Installed Noto font packages were kept.'
}
