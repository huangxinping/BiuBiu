#!/bin/bash
# Creates the self-signed code signing certificate BiuBiu releases are signed with.
# Run once. Keep the .p12 and its password safe: every future release must use the same certificate,
# otherwise macOS treats the update as a different app and users lose granted permissions.
#
# Usage: scripts/create-signing-cert.sh <output-dir>
# Produces <output-dir>/biubiu-signing.p12 and prints the base64 value for the GitHub secret.
set -euo pipefail

OUT="${1:?usage: $0 <output-dir>}"
NAME="BiuBiu Self-Signed"
mkdir -p "$OUT"
cd "$OUT"

if [[ -e biubiu-signing.p12 ]]; then
  echo "biubiu-signing.p12 already exists in $OUT; refusing to overwrite it." >&2
  exit 1
fi

PASSWORD="${P12_PASSWORD:-$(openssl rand -base64 24)}"

cat > cert.cnf <<CNF
[req]
distinguished_name = dn
x509_extensions = ext
prompt = no
[dn]
CN = $NAME
[ext]
basicConstraints = critical, CA:false
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
CNF

openssl req -x509 -newkey rsa:2048 -nodes -days 3650 -config cert.cnf \
  -keyout key.pem -out cert.pem 2>/dev/null
openssl pkcs12 -export -legacy -inkey key.pem -in cert.pem -name "$NAME" \
  -passout "pass:$PASSWORD" -out biubiu-signing.p12
rm -f key.pem cert.cnf

echo "Created $OUT/biubiu-signing.p12 (certificate: $OUT/cert.pem)"
echo
echo "GitHub secret SIGNING_P12_PASSWORD:"
echo "$PASSWORD"
echo
echo "GitHub secret SIGNING_P12_BASE64:"
base64 -i biubiu-signing.p12
