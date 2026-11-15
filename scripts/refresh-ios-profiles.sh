#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

if [[ ! -f .env.signing ]]; then
    echo "Missing .env.signing. Copy .env.signing.example to .env.signing and fill in the Bruce signing credentials." >&2
    exit 1
fi

set -a
source .env.signing
set +a

# An empty legacy assignment must not suppress Match’s Keychain lookup or secure prompt.
if [[ -z "${MATCH_PASSWORD:-}" ]]; then unset MATCH_PASSWORD; fi

missing=()
for name in DEVELOPMENT_TEAM ASC_KEY_ID ASC_ISSUER_ID MATCH_GIT_URL; do
    [[ -n "${!name:-}" ]] || missing+=("$name")
done
if [[ -z "${ASC_KEY_FILEPATH:-}" && -z "${ASC_KEY_CONTENT:-}" ]]; then
    missing+=("ASC_KEY_FILEPATH (or base64 ASC_KEY_CONTENT)")
fi
if [[ ${#missing[@]} -ne 0 ]]; then
    printf 'Missing signing configuration: %s\n' "${missing[@]}" >&2
    echo "Fill in .env.signing, then run just refresh-ios-profiles again." >&2
    exit 1
fi
if [[ -n "${ASC_KEY_FILEPATH:-}" && ! -r "$ASC_KEY_FILEPATH" ]]; then
    echo "ASC_KEY_FILEPATH must point to a readable .p8 file." >&2
    exit 1
fi

if ! bundle check >/dev/null 2>&1; then
    echo "Missing Ruby dependencies. Run bundle install, then retry just refresh-ios-profiles." >&2
    exit 1
fi

exec bundle exec fastlane ios force_certificates
