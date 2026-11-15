#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
scratch="$(mktemp -d)"
trap 'rm -rf "$scratch"' EXIT
mkdir -p "$scratch/scripts" "$scratch/bin"
cp "$REPO_ROOT/scripts/refresh-ios-profiles.sh" "$scratch/scripts/"

cat > "$scratch/bin/bundle" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
if [[ "$*" == check ]]; then exit "${BUNDLE_CHECK_STATUS:-0}"; fi
[[ "$*" == 'exec fastlane ios force_certificates' ]]
[[ "$DEVELOPMENT_TEAM" == test-team ]]
[[ "$ASC_KEY_ID" == test-key ]]
[[ "$ASC_ISSUER_ID" == test-issuer ]]
[[ "$MATCH_GIT_URL" == git@example.test:bruce-signing.git ]]
[[ "${MATCH_PASSWORD:-keychain}" == "${EXPECTED_MATCH_PASSWORD:-keychain}" ]]
if [[ -z "${MATCH_PASSWORD:-}" ]]; then [[ -z "${MATCH_PASSWORD+x}" ]]; fi
[[ -n "${ASC_KEY_CONTENT:-}${ASC_KEY_FILEPATH:-}" ]]
echo 'Profile refresh invoked with exported configuration.'
SH
chmod +x "$scratch/bin/bundle"
export PATH="$scratch/bin:$PATH"
unset DEVELOPMENT_TEAM ASC_KEY_ID ASC_ISSUER_ID ASC_KEY_FILEPATH ASC_KEY_CONTENT
unset MATCH_GIT_URL MATCH_PASSWORD MATCH_GIT_BASIC_AUTHORIZATION

run_refresh() { bash "$scratch/scripts/refresh-ios-profiles.sh" > "$scratch/output" 2>&1; }
expect_failure() {
    if run_refresh; then
        echo 'Expected profile refresh to fail before invoking Fastlane.' >&2
        exit 1
    fi
    grep -Eq "$1" "$scratch/output"
}

expect_failure 'Missing .env.signing'
echo "ASC_KEY_ID='test-key'" > "$scratch/.env.signing"
expect_failure 'ASC_ISSUER_ID'
grep -Eq 'MATCH_GIT_URL' "$scratch/output"
if grep -Eq 'MATCH_PASSWORD' "$scratch/output"; then
    echo 'The Match password must not be required in local configuration.' >&2
    exit 1
fi
grep -Eq 'ASC_KEY_FILEPATH' "$scratch/output"

cat > "$scratch/.env.signing" <<'SH'
DEVELOPMENT_TEAM='test-team'
ASC_KEY_ID='test-key'
ASC_ISSUER_ID='test-issuer'
ASC_KEY_CONTENT='private-key-content'
MATCH_GIT_URL='git@example.test:bruce-signing.git'
SH
run_refresh
grep -Eq 'Profile refresh invoked' "$scratch/output"

# Legacy blank values must still allow Keychain lookup.
echo "MATCH_PASSWORD=''" >> "$scratch/.env.signing"
run_refresh
grep -Eq 'Profile refresh invoked' "$scratch/output"
sed -i.bak '/^MATCH_PASSWORD=/d' "$scratch/.env.signing"
export MATCH_PASSWORD='external-secret' EXPECTED_MATCH_PASSWORD='external-secret'
run_refresh
grep -Eq 'Profile refresh invoked' "$scratch/output"
unset MATCH_PASSWORD EXPECTED_MATCH_PASSWORD

echo "ASC_KEY_FILEPATH='missing.p8'" >> "$scratch/.env.signing"
expect_failure 'readable .p8 file'
touch "$scratch/key.p8"
echo "ASC_KEY_FILEPATH='key.p8'" >> "$scratch/.env.signing"
echo "ASC_KEY_CONTENT=''" >> "$scratch/.env.signing"
run_refresh
grep -Eq 'Profile refresh invoked' "$scratch/output"

export BUNDLE_CHECK_STATUS=1
expect_failure 'Run bundle install'
if grep -Eq 'private-key-content|external-secret' "$scratch/output"; then
    echo 'Signing values appeared in diagnostic output.' >&2
    exit 1
fi
echo 'Profile refresh tests passed.'
