#!/usr/bin/env zsh
set -euo pipefail

# lib/report_html.zsh - Static HTML/CSS packaging for yojitsu.zsh

# Ensure common utilities are sourced if not already loaded
if (( ! $+functions[yojitsu::common::log_info] )); then
  local script_dir="${0:A:h}"
  source "${script_dir}/common.zsh"
fi

typeset -g _YOJITSU_HTML_LIB_DIR="${${(%):-%x}:A:h}"
typeset -g _YOJITSU_ROOT_DIR="${_YOJITSU_HTML_LIB_DIR:h}"

yojitsu::report_html::generate() {
  local json_input="${1:-}"
  local out_dir="${2:-./report_out}"
  local report_title="${3:-yojitsu Benchmark Dashboard}"
  local target_desc="${4:-}"

  local json_content
  if [[ -n "${json_input}" && "${json_input}" != "-" ]]; then
    if [[ "${json_input}" =~ ^[[:space:]]*[\[\{] ]]; then
      json_content="${json_input}"
    elif [[ -f "${json_input}" ]]; then
      json_content="$(<"${json_input}")"
    else
      yojitsu::common::die "HTML report input file not found: ${json_input}"
    fi
  else
    json_content="$(cat)"
  fi

  if [[ -z "${json_content//[[:space:]]/}" ]]; then
    yojitsu::common::die "No JSON content provided to HTML report generator"
  fi

  # Validate JSON and ensure array
  local normalized_json
  normalized_json="$(print -r -- "${json_content}" | jq 'if type == "array" then . else [.] end')"

  # Resolve templates directory
  local templates_dir="${_YOJITSU_ROOT_DIR}/templates"
  if [[ ! -d "${templates_dir}" ]]; then
    # Fallback to current working directory templates if not found
    if [[ -d "./templates" ]]; then
      templates_dir="./templates"
    else
      yojitsu::common::die "Templates directory not found: ${templates_dir}"
    fi
  fi

  yojitsu::common::ensure_dir "${out_dir}"

  # 1. Save benchmark_data.json
  local data_json_path="${out_dir}/benchmark_data.json"
  print -r -- "${normalized_json}" > "${data_json_path}"

  # 2. Copy static assets (style.css, app.js)
  cp "${templates_dir}/style.css" "${out_dir}/style.css"
  cp "${templates_dir}/app.js" "${out_dir}/app.js"

  # 3. Create standalone index.html with inline JSON data
  local template_html_path="${templates_dir}/index.html"
  local dest_html_path="${out_dir}/index.html"

  local html_content
  html_content="$(<"${template_html_path}")"

  # Replace title
  html_content="${html_content//<h1 id=\"reportTitle\">yojitsu Benchmark Dashboard<\/h1>/<h1 id=\"reportTitle\">${report_title}<\/h1>}"
  if [[ -n "${target_desc}" ]]; then
    local subtitle_text="Target: ${target_desc} | Generated: $(date '+%Y-%m-%d %H:%M:%S')"
    html_content="${html_content//<div class=\"subtitle\" id=\"reportSubtitle\">LLM Cost-Performance & Token Consumption Analyzer<\/div>/<div class=\"subtitle\" id=\"reportSubtitle\">${subtitle_text}<\/div>}"
  fi

  # Inject JSON data into script tag using temporary file replacement to avoid sed escaping issues
  local marker="<script id=\"benchmark-data\" type=\"application/json\">"
  local pre_part="${html_content%%${marker}*}"
  local post_part="${html_content#*${marker}}"
  # Strip the original placeholder content until </script>
  local after_script="${post_part#*<\/script>}"

  {
    print -r -- "${pre_part}${marker}"
    print -r -- "${normalized_json}"
    print -r -- "</script>${after_script}"
  } > "${dest_html_path}"

  yojitsu::common::log_success "HTML report generated: file://${dest_html_path}"
}
