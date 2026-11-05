#!/usr/bin/env bash
# Runs the test files for each variant of VARIANTS (and each NodeJS version of NODE_VERSIONS for variant-node.sh),
# TEST_JOBS test files at the same time, with one log per test file in LOG_DIR.
# TEST_SCOPE=reduced only runs the test files where their result can differ (see TESTS.md).
# Usage: PHP_VERSION=8.4 VARIANTS="apache cli fpm" NODE_VERSIONS="22 24 26" [TEST_JOBS=2] [TEST_SCOPE=full|reduced] ./tests-suite/run_tests.sh
set -u
cd "$(dirname "$0")"

export TEST_JOBS="${TEST_JOBS:-2}"
TEST_SCOPE="${TEST_SCOPE:-full}"
if [[ "${TEST_SCOPE}" != "full" ]] && [[ "${TEST_SCOPE}" != "reduced" ]]; then
  >&2 echo "Invalid TEST_SCOPE: '${TEST_SCOPE}' (supported: 'full' or 'reduced')"
  exit 1
fi
LATEST_PHP_VERSION=$(ls ../extensions | grep -xE '[0-9]+\.[0-9]+' | sort -V | tail -n 1)
export LOG_DIR="${LOG_DIR:-$(mktemp -d)}"
mkdir -p "${LOG_DIR}"
# Started first so that the longest test files are spread over the parallel jobs instead of ending on a single one
SLOW_TEST_FILES="tool-supercronic.sh onbuild.sh variant-fpm.sh tool-daemon.sh php-extensions.sh"

# Whether the test file runs for the variant and PHP_VERSION, according to the table of TESTS.md
in_scope() {
  local file=$1 variant=$2 variants versions
  if [[ "${TEST_SCOPE}" == "full" ]]; then return 0; fi
  IFS='|' read -r _ _ _ variants versions _ < <(grep -F "| \`${file}\`" TESTS.md) || return 0
  read -r variants <<< "${variants}"
  read -r versions <<< "${versions}"
  [[ "${variants}" == "all" || "${variants}" == "${variant}" ]] || return 1
  [[ "${versions}" == "all" || ( "${versions}" == "latest" && "${PHP_VERSION}" == "${LATEST_PHP_VERSION}" ) ]]
}

test_units() {
  local file variant node
  for file in ${SLOW_TEST_FILES} $(ls *.sh | grep -vxF -f <(tr ' ' '\n' <<< "${SLOW_TEST_FILES} run_tests.sh")); do
    for variant in ${VARIANTS}; do
      in_scope "${file}" "${variant}" || continue
      if [[ "${file}" == "variant-node.sh" ]]; then
        for node in ${NODE_VERSIONS:-}; do echo "${variant} ${file} ${node}"; done
      else
        echo "${variant} ${file}"
      fi
    done
  done
}

run_test_unit() {
  local variant=$1 file=$2 node=${3:-} name start status
  name="${variant}${node:+-node${node}}-${file%.sh}"
  start=${SECONDS}
  if (export VARIANT="${variant}"; if [[ -n "${node}" ]]; then export NODE="${node}"; fi; ./bash_unit -f tap "${file}") > "${LOG_DIR}/${name}.log" 2>&1; then
    status=ok
  else
    status=FAILED
  fi
  echo "${status} ${name} $((SECONDS - start))s"
}
export -f run_test_unit

test_units | xargs -P "${TEST_JOBS}" -L 1 bash -c 'run_test_unit "$@"' _ | tee "${LOG_DIR}/summary"

FAILED=0
for log in "${LOG_DIR}"/*.log; do
  name=$(basename "${log}" .log)
  if grep -q "^FAILED ${name} " "${LOG_DIR}/summary"; then
    FAILED=1
    echo "::group::FAILED ${name}"
  else
    echo "::group::${name}"
  fi
  cat "${log}"
  echo "::endgroup::"
done
if [[ "${FAILED}" == "1" ]]; then
  echo "Failed test files:"
  grep "^FAILED" "${LOG_DIR}/summary"
fi
exit "${FAILED}"
