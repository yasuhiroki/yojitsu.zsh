#!/usr/bin/env zsh
set -euo pipefail

# lib/report_cui.zsh - Formatted CUI summary table for yojitsu.zsh

# Ensure common utilities are sourced if not already loaded
if (( ! $+functions[yojitsu::common::log_info] )); then
  local script_dir="${0:A:h}"
  source "${script_dir}/common.zsh"
fi

yojitsu::report_cui::render_table() {
  local json_input="${1:-}"
  local json_content

  if [[ -n "${json_input}" && "${json_input}" != "-" ]]; then
    if [[ "${json_input}" =~ ^[[:space:]]*[\[\{] ]]; then
      json_content="${json_input}"
    elif [[ -f "${json_input}" ]]; then
      json_content="$(<"${json_input}")"
    else
      yojitsu::common::die "Report input file not found: ${json_input}"
    fi
  else
    json_content="$(cat)"
  fi

  if [[ -z "${json_content//[[:space:]]/}" ]]; then
    yojitsu::common::die "No JSON content provided to CUI report generator"
  fi

  # Extract delimited row data using jq with \u001f (Unit Separator)
  local row_data
  row_data="$(
    print -r -- "${json_content}" | jq -r '
      (if type == "array" then . else [.] end)
      | .[]
      | [
          ((.benchmark.title // .benchmark.id // "Untitled") | tostring | gsub("[\r\n\u001f]"; " ")),
          ((.metadata.agent // "unknown") | tostring | gsub("[\r\n\u001f]"; " ")),
          ((if (.benchmark.model // "") != "" then .benchmark.model else "default" end) | tostring),
          ((if (.benchmark.effort // "") != "" then .benchmark.effort else "default" end) | tostring),
          ((.benchmark.elapsed_sec // 0.0) | tostring),
          ((.tokens.total_tokens // 0) | tostring),
          ((.tokens.input.breakdown.cmd_tokens // .tokens.breakdown.cmd_tokens // 0) | tostring),
          ((.tokens.input.breakdown.base_context_tokens // .tokens.breakdown.base_context_tokens // 0) | tostring),
          ((.tokens.output.breakdown.thought_tokens // .tokens.breakdown.thought_tokens // 0) | tostring),
          ((.tokens.output.breakdown.response_tokens // .tokens.breakdown.response_tokens // 0) | tostring),
          ((.tool_calls_count // (.tools | length) // 0) | tostring),
          ((.cost.estimated_cost_usd // 0.0) | tostring)
        ]
      | join("\u001f")
    '
  )"

  if [[ -z "${row_data//[[:space:]]/}" ]]; then
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
  local delim=$'\x1f'

  local title agent model effort elapsed_sec tot_tokens cmd_tok base_tok th_tok resp_tok cmd_count cost_val
  while IFS="${delim}" read -r title agent model effort elapsed_sec tot_tokens cmd_tok base_tok th_tok resp_tok cmd_count cost_val; do
    [[ -z "${title}" && -z "${tot_tokens}" ]] && continue
    (( count++ )) || true

    local tot_formatted="$(yojitsu::common::format_number "${tot_tokens}")"
    local in_formatted="$(yojitsu::common::format_number "${cmd_tok}") / $(yojitsu::common::format_number "${base_tok}")"
    local out_formatted="$(yojitsu::common::format_number "${th_tok}") / $(yojitsu::common::format_number "${resp_tok}")"
    local time_str="${elapsed_sec}s"
    local cmds_desc="${cmd_count} cmds"

    # Truncate title if too long
    if (( ${#title} > 26 )); then
      title="${title[1,23]}..."
    fi

    if [[ "${elapsed_sec}" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
      total_elapsed="$(awk -v t1="${total_elapsed}" -v t2="${elapsed_sec}" 'BEGIN { printf "%.2f", t1 + t2 }')"
    fi

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
  done <<< "${row_data}"

  print -r -- "${YOJITSU_COLORS[gray]}${dash_line}${YOJITSU_COLORS[reset]}"
  print -r -- "${YOJITSU_COLORS[dim]}Total Runs: ${count} | Total Elapsed: ${total_elapsed}s${YOJITSU_COLORS[reset]}"
  print -r -- "${YOJITSU_COLORS[cyan]}${sep_line}${YOJITSU_COLORS[reset]}"
  print ""
}
