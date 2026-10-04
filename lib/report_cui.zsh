#!/usr/bin/env zsh
set -euo pipefail

# lib/report_cui.zsh - Formatted CUI summary table for yojitsu.zsh

# Ensure common utilities are sourced if not already loaded
if (( ! $+functions[yojitsu::common::log_info] )); then
  local script_dir="${0:A:h}"
  source "${script_dir}/common.zsh"
fi

__yojitsu::report_cui::format_cell() {
  local str="$1"
  local width="$2"
  printf "%-${width}s" "${str[1,$width]}"
}

yojitsu::report_cui::render_table() {
  local json_input="${1:-}"
  local json_content

  if [[ -n "${json_input}" && "${json_input}" != "-" ]]; then
    if [[ ! -f "${json_input}" ]]; then
      yojitsu::common::die "Report input file not found: ${json_input}"
    fi
    json_content="$(<"${json_input}")"
  else
    json_content="$(cat)"
  fi

  if [[ -z "${json_content//[[:space:]]/}" ]]; then
    yojitsu::common::die "No JSON content provided to CUI report generator"
  fi

  # Extract TSV row data using jq
  local tsv_data
  tsv_data="$(
    print -r -- "${json_content}" | jq -r '
      (if type == "array" then . else [.] end)
      | .[]
      | [
          ((.benchmark.title // .benchmark.id // "Untitled") | gsub("\t|\n"; " ")),
          ((.metadata.agent // "unknown") | gsub("\t|\n"; " ")),
          ((.benchmark.model // "default") | gsub("\t|\n"; " ")),
          ((.benchmark.effort // "default") | gsub("\t|\n"; " ")),
          (
            if .benchmark.elapsed_sec then
              (.benchmark.elapsed_sec | tostring) + "s"
            else
              "0.0s"
            end
          ),
          ((.tokens.total_tokens // 0) | tostring),
          (
            ((.tokens.breakdown.cmd_tokens // 0) | tostring)
            + " / "
            + ((.tokens.breakdown.base_context_tokens // 0) | tostring)
          ),
          (
            ((.tokens.breakdown.thought_tokens // 0) | tostring)
            + " / "
            + ((.tokens.breakdown.response_tokens // 0) | tostring)
          ),
          (
            ((.tool_calls_count // (.tools | length) // 0) | tostring) + " cmds"
          ),
          ((.cost.estimated_cost_usd // 0.0) | tostring)
        ]
      | @tsv
    '
  )"

  if [[ -z "${tsv_data//[[:space:]]/}" ]]; then
    yojitsu::common::log_warn "No valid benchmark runs found in JSON."
    return 0
  fi

  local term_width=124
  local sep_line
  sep_line="$(printf '=%.0s' {1..${term_width}})"
  local dash_line
  dash_line="$(printf -- '-%.0s' {1..${term_width}})"

  print ""
  print -r -- "${YOJITSU_COLORS[cyan]}${sep_line}${YOJITSU_COLORS[reset]}"
  print -r -- "${YOJITSU_COLORS[bold]}${YOJITSU_COLORS[white]}Execution Summary${YOJITSU_COLORS[reset]}"
  print -r -- "${YOJITSU_COLORS[cyan]}${sep_line}${YOJITSU_COLORS[reset]}"

  # Header
  printf "${YOJITSU_COLORS[bold]}%-26s | %-7s | %-16s | %-6s | %-7s | %-8s | %-16s | %-16s | %s${YOJITSU_COLORS[reset]}\n" \
    "Variant / Title" "Agent" "Model" "Effort" "Time" "Total" "In (Cmd/Base)" "Out (Think/Resp)" "Commands"
  print -r -- "${YOJITSU_COLORS[gray]}${dash_line}${YOJITSU_COLORS[reset]}"

  local count=0
  local total_elapsed=0.0
  local total_cost=0.0

  local title agent model effort time_str tot_str in_desc out_desc cmds_desc cost_val
  while IFS=$'\t' read -r title agent model effort time_str tot_str in_desc out_desc cmds_desc cost_val; do
    (( count++ )) || true

    local tot_formatted
    tot_formatted="$(yojitsu::common::format_number "${tot_str}")"

    # Truncate title if too long
    if (( ${#title} > 26 )); then
      title="${title[1,23]}..."
    fi

    local raw_time="${time_str%s}"
    if [[ "${raw_time}" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
      total_elapsed="$(awk -v t1="${total_elapsed}" -v t2="${raw_time}" 'BEGIN { printf "%.2f", t1 + t2 }')"
    fi
    if [[ "${cost_val}" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
      total_cost="$(awk -v c1="${total_cost}" -v c2="${cost_val}" 'BEGIN { printf "%.4f", c1 + c2 }')"
    fi

    local cmd_val="${in_desc% / *}"
    local base_val="${in_desc#* / }"
    local th_val="${out_desc% / *}"
    local resp_val="${out_desc#* / }"

    local in_formatted="$(yojitsu::common::format_number "${cmd_val}") / $(yojitsu::common::format_number "${base_val}")"
    local out_formatted="$(yojitsu::common::format_number "${th_val}") / $(yojitsu::common::format_number "${resp_val}")"

    printf "%-26s | %-7s | %-16s | %-6s | %-7s | %-8s | %-16s | %-16s | %s\n" \
      "${title}" \
      "${agent}" \
      "${model}" \
      "${effort}" \
      "${time_str}" \
      "${tot_formatted}" \
      "${in_formatted}" \
      "${out_formatted}" \
      "${cmds_desc}"
  done <<< "${tsv_data}"

  print -r -- "${YOJITSU_COLORS[gray]}${dash_line}${YOJITSU_COLORS[reset]}"
  print -r -- "${YOJITSU_COLORS[dim]}Total Runs: ${count} | Total Elapsed: ${total_elapsed}s | Estimated Cost: \$${total_cost}${YOJITSU_COLORS[reset]}"
  print -r -- "${YOJITSU_COLORS[cyan]}${sep_line}${YOJITSU_COLORS[reset]}"
  print ""
}
