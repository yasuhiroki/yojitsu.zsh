#!/usr/bin/env zsh
set -euo pipefail

# test/test_run.zsh - Smoke tests for yojitsu.zsh pipeline

SCRIPT_DIR="${${(%):-%x}:A:h}"
REPO_ROOT="${SCRIPT_DIR:h}"

print -r -- "=== Running yojitsu tests ==="

# 1. Normalization validation
print -n "Testing agy normalizer... "
SAMPLE_JSON="${REPO_ROOT}/agy-sample.json"
if [[ -f "${SAMPLE_JSON}" ]]; then
  NORM_OUT="$(jq -n -f "${REPO_ROOT}/lib/normalize/agy.jq" --arg prompt "test prompt" "${SAMPLE_JSON}")"
  VER="$(print -r -- "${NORM_OUT}" | jq -r '.version')"
  AGENT="$(print -r -- "${NORM_OUT}" | jq -r '.metadata.agent')"
  IN_TOK="$(print -r -- "${NORM_OUT}" | jq -r '.tokens.input.input_tokens // .tokens.input_tokens')"

  if [[ "${VER}" != "1.1.0" || "${AGENT}" != "agy" || "${IN_TOK}" -le 0 ]]; then
    print "FAILED: unexpected normalization output"
    exit 1
  fi
  print "OK"
else
  print "SKIPPED (agy-sample.json not present)"
fi

# 2. CLI Single prompt test (dry-run)
print -n "Testing 'yojitsu run --prompt' (dry-run)... "
TEST_OUT_DIR="${REPO_ROOT}/test_out_single"
"${REPO_ROOT}/bin/yojitsu" run --agent agy --prompt "Hello test" --dry-run -o "${TEST_OUT_DIR}" >/dev/null

CREATED_DIRS=("${TEST_OUT_DIR}"/*_*(N))
if (( ${#CREATED_DIRS[@]} == 0 )) || [[ ! -f "${CREATED_DIRS[1]}/index.html" || ! -f "${CREATED_DIRS[1]}/benchmark_data.json" ]]; then
  print "FAILED: expected files not created in ${TEST_OUT_DIR}"
  exit 1
fi

# Clean up
for d in "${TEST_OUT_DIR}"/*(N); do rm "${d}"/*(N) 2>/dev/null; rmdir "${d}" 2>/dev/null; done
rmdir "${TEST_OUT_DIR}" 2>/dev/null
print "OK"

# 3. CLI Prompts JSON test (dry-run)
print -n "Testing 'yojitsu run --prompts-json' (dry-run)... "
TEST_PROMPTS_FILE="${REPO_ROOT}/test_temp_prompts.json"
cat << 'EOF' > "${TEST_PROMPTS_FILE}"
[
  {"id": "P1", "title": "Test 1", "prompt": "Prompt 1"},
  {"id": "P2", "title": "Test 2", "prompt": "Prompt 2"}
]
EOF

TEST_OUT_DIR_MULTI="${REPO_ROOT}/test_out_multi"
"${REPO_ROOT}/bin/yojitsu" run --prompts-json "${TEST_PROMPTS_FILE}" --dry-run -o "${TEST_OUT_DIR_MULTI}" >/dev/null

CREATED_MULTI_DIRS=("${TEST_OUT_DIR_MULTI}"/*_*(N))
if (( ${#CREATED_MULTI_DIRS[@]} == 0 )) || [[ ! -f "${CREATED_MULTI_DIRS[1]}/index.html" || ! -f "${CREATED_MULTI_DIRS[1]}/benchmark_data.json" ]]; then
  print "FAILED: expected multi files not created in ${TEST_OUT_DIR_MULTI}"
  rm "${TEST_PROMPTS_FILE}"
  exit 1
fi

RUNS_COUNT="$(jq 'length' "${CREATED_MULTI_DIRS[1]}/benchmark_data.json")"
if (( RUNS_COUNT != 2 )); then
  print "FAILED: expected 2 runs in benchmark_data.json, got ${RUNS_COUNT}"
  rm "${TEST_PROMPTS_FILE}"
  exit 1
fi

# Clean up
rm "${TEST_PROMPTS_FILE}"
for d in "${TEST_OUT_DIR_MULTI}"/*(N); do rm "${d}"/*(N) 2>/dev/null; rmdir "${d}" 2>/dev/null; done
rmdir "${TEST_OUT_DIR_MULTI}" 2>/dev/null
print "OK"

print -r -- "=== All tests passed successfully! ==="
