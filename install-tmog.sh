#!/usr/bin/env bash

set -Eeuo pipefail

readonly APPIMAGE_URL="https://tmog.org/downloads/TMOG-Task-Manager-Linux-x86_64.AppImage"
readonly CHECKSUM_URL="${APPIMAGE_URL}.sha256"
readonly DESKTOP_ID="com.tmog.taskmanager.desktop"
readonly APP_NAME="TMOG Task Manager"

data_home="${XDG_DATA_HOME:-${HOME}/.local/share}"
bin_home="${XDG_BIN_HOME:-${HOME}/.local/bin}"
app_dir="${data_home}/tmog"
appimage_path="${app_dir}/TMOG-Task-Manager.AppImage"
launcher_path="${bin_home}/tmog-task-manager"
desktop_path="${data_home}/applications/${DESKTOP_ID}"
icon_root="${data_home}/icons/hicolor"
temp_dir=""

info() {
    printf '\033[1;34m==>\033[0m %s\n' "$*"
}

die() {
    printf '\033[1;31m错误：\033[0m %s\n' "$*" >&2
    exit 1
}

cleanup() {
    if [[ -n "${temp_dir}" && -d "${temp_dir}" ]]; then
        case "${temp_dir}" in
            "${TMPDIR:-/tmp}"/tmog-install.*)
                rm -rf -- "${temp_dir}"
                ;;
        esac
    fi
}

trap cleanup EXIT

usage() {
    cat <<'EOF'
用法：
  ./install-tmog.sh             下载、校验并安装/更新 TMOG
  ./install-tmog.sh --uninstall 卸载由本脚本安装的 TMOG
  ./install-tmog.sh --help      显示帮助

这是用户级安装，不需要 sudo。安装位置遵循 XDG 用户目录。
EOF
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || die "缺少命令：$1"
}

refresh_desktop_cache() {
    if command -v update-desktop-database >/dev/null 2>&1; then
        update-desktop-database "${data_home}/applications" >/dev/null 2>&1 || true
    fi

    if command -v gtk-update-icon-cache >/dev/null 2>&1; then
        gtk-update-icon-cache --force --ignore-theme-index "${icon_root}" >/dev/null 2>&1 || true
    fi
}

uninstall_tmog() {
    info "卸载 ${APP_NAME}"

    rm -f -- "${appimage_path}" "${launcher_path}" "${desktop_path}"

    for size in 32x32 48x48 64x64 128x128 256x256 512x512; do
        rm -f -- "${icon_root}/${size}/apps/tmog-task-manager.png"
    done

    rmdir -- "${app_dir}" 2>/dev/null || true
    refresh_desktop_cache
    info "卸载完成"
}

check_platform() {
    [[ "$(uname -s)" == "Linux" ]] || die "此脚本仅支持 Linux"

    case "$(uname -m)" in
        x86_64|amd64)
            ;;
        *)
            die "官方目前只提供 x86_64 Linux 包，当前架构为 $(uname -m)"
            ;;
    esac
}

download_file() {
    local url="$1"
    local destination="$2"

    curl \
        --fail \
        --location \
        --proto '=https' \
        --tlsv1.2 \
        --retry 5 \
        --retry-all-errors \
        --connect-timeout 20 \
        --output "${destination}" \
        "${url}"
}

verify_download() {
    local appimage_file="$1"
    local checksum_file="$2"
    local expected actual remainder

    read -r expected remainder < "${checksum_file}"
    [[ "${expected}" =~ ^[[:xdigit:]]{64}$ ]] || die "官网校验文件格式无效"

    read -r actual remainder < <(sha256sum "${appimage_file}")
    [[ "${actual,,}" == "${expected,,}" ]] || die "SHA-256 校验失败，已拒绝安装"

    info "SHA-256 校验通过"
}

install_icons() {
    local downloaded_appimage="$1"
    local extracted_root="${temp_dir}/squashfs-root"
    local source_icon size

    info "提取应用图标"
    (
        cd "${temp_dir}"
        "${downloaded_appimage}" \
            --appimage-extract 'usr/share/icons/hicolor/*/apps/tmog-task-manager.png' \
            >/dev/null
    )

    for size in 32x32 48x48 64x64 128x128 256x256 512x512; do
        source_icon="${extracted_root}/usr/share/icons/hicolor/${size}/apps/tmog-task-manager.png"
        if [[ -f "${source_icon}" ]]; then
            install -Dm0644 \
                "${source_icon}" \
                "${icon_root}/${size}/apps/tmog-task-manager.png"
        fi
    done
}

write_desktop_entry() {
    local staged_desktop="${temp_dir}/${DESKTOP_ID}"

    cat > "${staged_desktop}" <<EOF
[Desktop Entry]
Type=Application
Name=Task Manager TMOG
Comment=Native system monitor and task manager
Exec="${launcher_path}"
Icon=tmog-task-manager
Terminal=false
Categories=System;Monitor;
StartupNotify=true
EOF

    install -Dm0644 "${staged_desktop}" "${desktop_path}"

    if command -v desktop-file-validate >/dev/null 2>&1; then
        desktop-file-validate "${desktop_path}"
    fi
}

install_tmog() {
    local downloaded_appimage checksum_file staged_appimage

    check_platform
    require_command curl
    require_command install
    require_command mktemp
    require_command sha256sum

    temp_dir="$(mktemp -d "${TMPDIR:-/tmp}/tmog-install.XXXXXX")"
    downloaded_appimage="${temp_dir}/TMOG-Task-Manager-Linux-x86_64.AppImage"
    checksum_file="${temp_dir}/TMOG-Task-Manager-Linux-x86_64.AppImage.sha256"
    staged_appimage="${app_dir}/.TMOG-Task-Manager.AppImage.new"

    info "从 tmog.org 下载 ${APP_NAME}"
    download_file "${APPIMAGE_URL}" "${downloaded_appimage}"
    download_file "${CHECKSUM_URL}" "${checksum_file}"
    verify_download "${downloaded_appimage}" "${checksum_file}"
    chmod 0755 "${downloaded_appimage}"

    install_icons "${downloaded_appimage}"

    info "安装到 ${appimage_path}"
    mkdir -p -- "${app_dir}" "${bin_home}"
    install -m0755 "${downloaded_appimage}" "${staged_appimage}"
    mv -f -- "${staged_appimage}" "${appimage_path}"
    ln -sfn -- "${appimage_path}" "${launcher_path}"

    write_desktop_entry
    refresh_desktop_cache

    info "安装完成"
    printf '桌面菜单：Task Manager TMOG\n'
    printf '终端启动：%s\n' "${launcher_path}"
    if [[ ":${PATH}:" != *":${bin_home}:"* ]]; then
        printf '提示：%s 不在 PATH 中，但不影响从桌面菜单启动。\n' "${bin_home}"
    fi
}

case "${1:-}" in
    "")
        install_tmog
        ;;
    --uninstall)
        uninstall_tmog
        ;;
    --help|-h)
        usage
        ;;
    *)
        usage >&2
        exit 2
        ;;
esac
