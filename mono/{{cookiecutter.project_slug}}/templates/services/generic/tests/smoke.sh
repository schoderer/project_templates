# shellcheck shell=bash
# HTTP smoke test for __NAME__: smoke.sh <base-url>
set -euo pipefail
base=$1

# Wait up to 5s for the server to accept connections.
for _ in $(seq 50); do
  curl -sf "$base/health" >/dev/null && break
  sleep 0.1
done

got=$(curl -sf "$base/health")
if [[ $got != "ok" ]]; then
  echo "FAIL: /health -> '$got'" >&2
  exit 1
fi
echo "ok: /health"

curl -sf "$base/" | grep -q "<h1>__NAME__</h1>"
echo "ok: /"
