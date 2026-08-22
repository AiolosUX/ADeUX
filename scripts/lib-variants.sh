#!/usr/bin/env bash
# Shared MOD_VARIANTS parsing. Source this *after* REPO_ROOT and config.env
# are set, so there is exactly one place that understands the tuple format.
#
# config.env format, one entry per variant:
#
#   MOD_VARIANTS=(
#     "NAME:DTB[:LABEL[:DISPLAY]]"
#     ...
#   )
#
#   NAME     Variant identifier, matched case-insensitively against the
#            CLI arg / --variant flag (e.g. R36S, R46H), and used for the
#            consoles/<NAME>/ lookup directory.
#   DTB      Device tree blob filename for this variant.
#   LABEL    Optional. Used in place of NAME for output filenames.
#            Defaults to NAME. Use this when several devices share one
#            console/DTB and ship as a single combined build
#            (e.g. LABEL="R42Pro_R45H_R46H").
#   DISPLAY  Optional. Human-readable name(s) used in release-note tables
#            and descriptions. Defaults to LABEL with underscores turned
#            into " / " (e.g. "R42Pro_R45H_R46H" -> "R42Pro / R45H / R46H").
#            Set explicitly whenever the default spacing looks wrong, e.g.
#            DISPLAY="R36S Plus" or DISPLAY="R42 Pro / R45H / R46H".
#            Leave LABEL empty ("NAME:DTB::DISPLAY") to keep the default
#            LABEL while overriding just DISPLAY.
#
# All variants are console-dir variants: DTB and boot.ini are read from
# consoles/<NAME>/. They boot via boot.ini (not extlinux) and there is no
# U-Boot flash step.
#
# Adding a new variant is just adding a new entry + its consoles/<NAME>/
# folder (DTB, boot.ini, optional overlay/rootfs/ for device-specific
# files); no script changes needed for the common case.

resolve_variant() {
  local want="$1"
  want="${want^^}"
  local entry name dtb label display

  for entry in "${MOD_VARIANTS[@]}"; do
    IFS=':' read -r name dtb label display <<< "${entry}"
    if [[ "${name^^}" == "${want}" ]]; then
      VARIANT_NAME="${name}"
      VARIANT_DTB="${dtb}"
      VARIANT_LABEL="${label:-${name}}"
      VARIANT_DISPLAY="${display:-${VARIANT_LABEL//_/ \/ }}"
      VARIANT_CONSOLE_DIR="${REPO_ROOT}/consoles/${name}"

      [[ -d "${VARIANT_CONSOLE_DIR}" ]] || {
        echo "Error: missing consoles/${name}/ directory" >&2
        exit 1
      }

      return 0
    fi
  done

  echo "Error: unknown variant '${want}'. Valid: $(variants_list)" >&2
  exit 1
}

variants_list() {
  local entry name dtb label display out=""
  for entry in "${MOD_VARIANTS[@]}"; do
    IFS=':' read -r name dtb label display <<< "${entry}"
    out+="${name} "
  done
  echo "${out}"
}