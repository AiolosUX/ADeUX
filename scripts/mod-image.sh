#!/usr/bin/env bash
# Patch one dArkOS image copy for a console-dir variant.
# Expected layout: BOOT_PART is FAT/vfat; ROOTFS_PART is ext4 or btrfs.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# shellcheck source=config.env
source "${REPO_ROOT}/config.env"
# shellcheck source=lib-variants.sh
source "${SCRIPT_DIR}/lib-variants.sh"

# Cleanup state lives at script level so the EXIT trap can always see it,
# even when set -e aborts the script from inside a function.
loop_dev=""
boot_mnt=""
root_mnt=""

cleanup() {
  set +e
  sync

  if [[ -n "${boot_mnt:-}" ]]; then
    if mountpoint -q "${boot_mnt}"; then
      umount "${boot_mnt}" 2>/dev/null || umount -l "${boot_mnt}"
    fi
    rmdir "${boot_mnt}" 2>/dev/null
  fi

  if [[ -n "${root_mnt:-}" ]]; then
    if mountpoint -q "${root_mnt}"; then
      umount "${root_mnt}" 2>/dev/null || umount -l "${root_mnt}"
    fi
    rmdir "${root_mnt}" 2>/dev/null
  fi

  if [[ -n "${loop_dev:-}" ]]; then
    losetup -d "${loop_dev}" 2>/dev/null
  fi
}
trap cleanup EXIT

part_path() {
  local disk="$1" part="$2"

  if [[ "${disk}" == /dev/loop* ]]; then
    echo "${disk}p${part}"
  elif [[ -b "${disk}p${part}" ]]; then
    echo "${disk}p${part}"
  elif [[ -b "${disk}${part}" ]]; then
    echo "${disk}${part}"
  else
    echo "${disk}p${part}"
  fi
}

wait_for_block() {
  local dev="$1" disk="${2:-}"
  local i

  for ((i = 1; i <= 50; i++)); do
    [[ -b "${dev}" ]] && return 0

    if [[ -n "${disk}" ]] && command -v partprobe >/dev/null 2>&1; then
      partprobe "${disk}" 2>/dev/null || true
    fi

    udevadm settle 2>/dev/null || true
    sleep 0.2
  done

  echo "Error: block device not ready: ${dev}" >&2
  return 1
}

setup_loop_image() {
  local image="$1"
  local dev

  dev="$(losetup --find --show --partscan "${image}")"
  partprobe "${dev}" 2>/dev/null || true
  udevadm settle 2>/dev/null || true
  echo "${dev}"
}

usage() {
  cat <<EOF
Usage: $(basename "$0") <variant> <input.img> <output.img>

  variant  Variant defined in config.env MOD_VARIANTS
  input    Upstream raw image
  output   Modified image path
EOF
}

require_root() {
  [[ "$(id -u)" -eq 0 ]] || {
    echo "Error: run as root (sudo) for loop mounts and image modification." >&2
    exit 1
  }
}

mount_rootfs() {
  local dev="$1" mnt="$2"
  local fstype

  fstype="$(blkid -o value -s TYPE "${dev}" 2>/dev/null || true)"

  case "${fstype}" in
    btrfs)
      mount -t btrfs -o subvol=/ "${dev}" "${mnt}"
      ;;
    ext4)
      mount "${dev}" "${mnt}"
      ;;
    "")
      echo "Error: could not detect filesystem on ${dev}" >&2
      blkid "${dev}" 2>/dev/null || true
      exit 1
      ;;
    *)
      echo "Error: unsupported rootfs type '${fstype}' on ${dev}" >&2
      exit 1
      ;;
  esac
}

patch_boot_console_ini() {
  local boot_mnt="$1"
  local kernel_path="${REPO_ROOT}/${KERNEL_IMAGE}"
  local dtb_path="${VARIANT_CONSOLE_DIR}/${VARIANT_DTB}"
  local boot_ini_path="${VARIANT_CONSOLE_DIR}/boot.ini"
  local uboot_dtb_path="${REPO_ROOT}/rg351mp-uboot.dtb"

  echo "[mod] replacing kernel Image"
  cp -f "${kernel_path}" "${boot_mnt}/Image"

  echo "[mod] installing ${VARIANT_DTB}"
  cp -f "${dtb_path}" "${boot_mnt}/${VARIANT_DTB}"

  echo "[mod] installing rg351mp-uboot.dtb"
  cp -f "${uboot_dtb_path}" "${boot_mnt}/rg351mp-uboot.dtb"

  echo "[mod] replacing boot.ini"
  cp -f "${boot_ini_path}" "${boot_mnt}/boot.ini"

  local screenfiles_path="${VARIANT_CONSOLE_DIR}/ScreenFiles"
  if [[ -d "${screenfiles_path}" ]]; then
    echo "[mod] installing ScreenFiles"
    mkdir -p "${boot_mnt}/ScreenFiles"
    # FAT has no Unix ownership/permissions, so copy without preserving them.
    cp -rT --no-preserve=mode,ownership,timestamps \
      "${screenfiles_path}" "${boot_mnt}/ScreenFiles"
  fi

  if [[ -n "${UPSTREAM_DTB:-}" \
    && "${UPSTREAM_DTB}" != "${VARIANT_DTB}" \
    && "${UPSTREAM_DTB}" != "rg351mp-uboot.dtb" \
    && -f "${boot_mnt}/${UPSTREAM_DTB}" ]]; then
    echo "[mod] removing upstream ${UPSTREAM_DTB}"
    rm -f "${boot_mnt}/${UPSTREAM_DTB}"
  fi
}

apply_rootfs_overlay() {
  local root_mnt="$1"
  local shared_overlay="${REPO_ROOT}/overlay/rootfs"
  local console_overlay="${VARIANT_CONSOLE_DIR}/overlay/rootfs"

  if [[ -d "${shared_overlay}" ]]; then
    echo "[mod] applying shared rootfs overlay"
    cp -a "${shared_overlay}/." "${root_mnt}/"
  fi

  if [[ -d "${console_overlay}" ]]; then
    echo "[mod] applying console overlay"
    cp -a "${console_overlay}/." "${root_mnt}/"
  fi
}

verify_rootfs_overlay() {
  local root_mnt="$1"
  # Add device-specific verification rules here when needed.
  : "${root_mnt}"
}

main() {
  local variant="${1:-}"
  local input="${2:-}"
  local output="${3:-}"

  if [[ -z "${variant}" || -z "${input}" || -z "${output}" ]]; then
    usage >&2
    exit 1
  fi

  resolve_variant "${variant}"

  [[ -f "${input}" ]] || {
    echo "Error: input image not found: ${input}" >&2
    exit 1
  }

  require_root

  local kernel_path="${REPO_ROOT}/${KERNEL_IMAGE}"
  local uboot_dtb_path="${REPO_ROOT}/rg351mp-uboot.dtb"
  local dtb_path="${VARIANT_CONSOLE_DIR}/${VARIANT_DTB}"
  local boot_ini_path="${VARIANT_CONSOLE_DIR}/boot.ini"

  [[ -f "${kernel_path}" ]] || {
    echo "Error: missing kernel: ${kernel_path}" >&2
    exit 1
  }
  [[ -f "${uboot_dtb_path}" ]] || {
    echo "Error: missing U-Boot DTB: ${uboot_dtb_path}" >&2
    exit 1
  }
  [[ -f "${dtb_path}" ]] || {
    echo "Error: missing DTB: ${dtb_path}" >&2
    exit 1
  }
  [[ -f "${boot_ini_path}" ]] || {
    echo "Error: missing boot.ini: ${boot_ini_path}" >&2
    exit 1
  }

  echo "[mod] variant=${VARIANT_NAME} dtb=${VARIANT_DTB}"
  echo "[mod] source: consoles/${VARIANT_NAME}/"
  echo "[mod] ${input} -> ${output}"

  mkdir -p "$(dirname "${output}")"
  cp --reflink=auto "${input}" "${output}" 2>/dev/null || cp "${input}" "${output}"

  local boot_dev=""
  local root_dev=""

  loop_dev="$(setup_loop_image "${output}")"
  boot_dev="$(part_path "${loop_dev}" "${BOOT_PART}")"
  root_dev="$(part_path "${loop_dev}" "${ROOTFS_PART}")"

  echo "[debug] loop device: ${loop_dev}"
  echo "[debug] expected boot: ${boot_dev}"
  echo "[debug] expected rootfs: ${root_dev}"
  lsblk -o NAME,PATH,SIZE,FSTYPE,LABEL,TYPE "${loop_dev}" || true
  parted -s "${loop_dev}" unit MiB print || true

  wait_for_block "${boot_dev}" "${loop_dev}"
  wait_for_block "${root_dev}" "${loop_dev}"

  echo "[debug] boot filesystem: $(blkid -o value -s TYPE "${boot_dev}" 2>/dev/null || echo unknown)"
  echo "[debug] rootfs filesystem: $(blkid -o value -s TYPE "${root_dev}" 2>/dev/null || echo unknown)"

  boot_mnt="$(mktemp -d)"
  root_mnt="$(mktemp -d)"

  mount "${boot_dev}" "${boot_mnt}"
  mount_rootfs "${root_dev}" "${root_mnt}"

  patch_boot_console_ini "${boot_mnt}"
  apply_rootfs_overlay "${root_mnt}"
  verify_rootfs_overlay "${root_mnt}"

  sync
  umount "${boot_mnt}"
  umount "${root_mnt}"
  rmdir "${boot_mnt}"
  rmdir "${root_mnt}"
  boot_mnt=""
  root_mnt=""

  losetup -d "${loop_dev}"
  loop_dev=""
  trap - EXIT

  sync
  echo "[mod] done: ${output}"
}

main "$@"
