#!/usr/bin/env zsh
set -euo pipefail

# lib/common.zsh - Shared utility functions for yojitsu.zsh

# --- Color Definitions ---
typeset -gA YOJITSU_COLORS
if [[ -t 1 ]]; then
  YOJITSU_COLORS=(
    reset     $'\e[0m'
    bold      $'\e[1m'
    dim       $'\e[2m'
    red       $'\e[31m'
    green     $'\e[32m'
    yellow    $'\e[33m'
    blue      $'\e[34m'
    magenta   $'\e[35m'
    cyan      $'\e[36m'
    white     $'\e[37m'
    gray      $'\e[90m'
  )
else
  YOJITSU_COLORS=(
    reset     ""
    bold      ""
    dim       ""
    red       ""
    green     ""
    yellow    ""
    blue      ""
    magenta   ""
    cyan      ""
    white     ""
    gray      ""
  )
fi

# --- Logging Functions ---
yojitsu::common::log_info() {
  local msg="$*"
  print -r -- "${YOJITSU_COLORS[cyan]}[INFO]${YOJITSU_COLORS[reset]} ${msg}" >&2
}

yojitsu::common::log_success() {
  local msg="$*"
  print -r -- "${YOJITSU_COLORS[green]}[SUCCESS]${YOJITSU_COLORS[reset]} ${msg}" >&2
}

yojitsu::common::log_warn() {
  local msg="$*"
  print -r -- "${YOJITSU_COLORS[yellow]}[WARN]${YOJITSU_COLORS[reset]} ${msg}" >&2
}

yojitsu::common::log_error() {
  local msg="$*"
  print -r -- "${YOJITSU_COLORS[red]}[ERROR]${YOJITSU_COLORS[reset]} ${msg}" >&2
}

yojitsu::common::die() {
  local msg="$*"
  yojitsu::common::log_error "${msg}"
  exit 1
}

# --- Environment & Dependency Checks ---
yojitsu::common::check_dependencies() {
  local missing=()
  if ! command -v jq >/dev/null 2>&1; then
    missing+=("jq")
  fi

  if (( ${#missing[@]} > 0 )); then
    yojitsu::common::die "Missing required command(s): ${missing[*]} (Please install them first)"
  fi
}

# --- Path & Directory Helpers ---
yojitsu::common::resolve_dir() {
  local path_arg="$1"
  local abs_path
  abs_path="$(cd "$(dirname "${path_arg}")" 2>/dev/null && pwd)" || return 1
  print -r -- "${abs_path}/$(basename "${path_arg}")"
}

yojitsu::common::ensure_dir() {
  local dir_path="$1"
  if [[ ! -d "${dir_path}" ]]; then
    mkdir -p "${dir_path}"
  fi
}

# Resolve sequential output directory (e.g., ./benchmark_results_01)
yojitsu::common::resolve_next_output_dir() {
  local base_path="$1"
  local parent_dir
  local base_name
  parent_dir="$(dirname "${base_path}")"
  base_name="$(basename "${base_path}")"

  local parent_abs
  parent_abs="$(cd "${parent_dir}" 2>/dev/null && pwd || pwd)"
  
  local clean_name="${base_name%_[0-9]*}"
  local existing_max=0
  local dir_entry
  local num

  if [[ -d "${parent_abs}" ]]; then
    for dir_entry in "${parent_abs}/${clean_name}"_*(N); do
      if [[ -d "${dir_entry}" ]]; then
        num="${dir_entry##*_}"
        if [[ "${num}" =~ ^[0-9]+$ ]]; then
          if (( 10#${num} > existing_max )); then
            existing_max=$(( 10#${num} ))
          fi
        fi
      fi
    done
  fi

  local next_num=$(( existing_max + 1 ))
  local next_dir
  printf -v next_dir "%s/%s_%02d" "${parent_abs}" "${clean_name}" "${next_num}"
  print -r -- "${next_dir}"
}

# --- Formatting Helpers ---
yojitsu::common::format_number() {
  local num="$1"
  print -r -- "${num}" | awk '{
    len = length($0)
    res = ""
    for (i = 0; i < len; i++) {
      if (i > 0 && i % 3 == 0) res = "," res
      res = substr($0, len - i, 1) res
    }
    print res
  }'
}
