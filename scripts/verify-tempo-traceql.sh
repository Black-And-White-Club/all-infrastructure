#!/usr/bin/env bash
set -euo pipefail

tempo_url="${1:-http://tempo-query-frontend.observability.svc.cluster.local:3200}"
query='{nestedSetParent<0 && true && resource.service.name != nil} | rate() by(resource.service.name)'
end_seconds="$(date +%s)"
start_seconds="$((end_seconds - 3600))"
response_file="$(mktemp)"

cleanup() {
	rm -f "$response_file"
}
trap cleanup EXIT

http_status="$({
	curl --silent --show-error --get \
		--output "$response_file" \
		--write-out '%{http_code}' \
		--data-urlencode "q=$query" \
		--data-urlencode "start=$start_seconds" \
		--data-urlencode "end=$end_seconds" \
		"${tempo_url%/}/api/metrics/query_range"
})"

if [[ "$http_status" != "200" ]]; then
	echo "Tempo TraceQL regression failed: expected HTTP 200, got $http_status" >&2
	cat "$response_file" >&2
	exit 1
fi

echo "Tempo TraceQL regression passed: HTTP 200"
jq -e . "$response_file" >/dev/null
