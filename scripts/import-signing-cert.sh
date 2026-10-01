#!/bin/bash
# Imports the signing .p12 into a dedicated keychain so codesign can use it without prompts.
# Usage: scripts/import-signing-cert.sh <p12-file> <p12-password> <keychain-path>
set -euo pipefail

P12="${1:?p12 file}"
P12_PASSWORD="${2:?p12 password}"
KEYCHAIN="${3:?keychain path}"
KEYCHAIN_PASSWORD="$(openssl rand -base64 18)"

rm -f "$KEYCHAIN"
security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN"
security set-keychain-settings "$KEYCHAIN"
security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN"
security import "$P12" -k "$KEYCHAIN" -P "$P12_PASSWORD" -T /usr/bin/codesign
security set-key-partition-list -S apple-tool:,apple: -s -k "$KEYCHAIN_PASSWORD" "$KEYCHAIN" >/dev/null
echo "Imported into $KEYCHAIN"
