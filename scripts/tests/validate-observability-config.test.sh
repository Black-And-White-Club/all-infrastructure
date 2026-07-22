#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=./lib.sh
source "$SCRIPT_DIR/lib.sh"

alloy_values="$REPO_ROOT/charts/alloy/values.yaml"
tempo_values="$REPO_ROOT/charts/tempo/values.yaml"
grafana_values="$REPO_ROOT/charts/grafana/values.yaml"
nats_values="$REPO_ROOT/charts/nats/values.yaml"
ops_deployment="$REPO_ROOT/kustomize/frolf-bot-ops/base/runtime/deployment.yaml"
dashboard_dir="$REPO_ROOT/cluster-resources/grafana-dashboards"
tempo_regression_script="$REPO_ROOT/scripts/verify-tempo-traceql.sh"

extract_dashboard_json() {
	local manifest="$1"
	sed -n '/\.json: |$/,$p' "$manifest" | sed '1d;s/^    //'
}

assert_dashboard_jq() {
	local manifest="$1"
	local expression="$2"
	local description="$3"

	if [[ ! -f "$manifest" ]]; then
		echo "expected dashboard manifest to exist: $manifest" >&2
		return 1
	fi
	if ! extract_dashboard_json "$manifest" | jq -e "$expression" >/dev/null; then
		echo "dashboard assertion failed ($description): $manifest" >&2
		return 1
	fi
}

assert_dashboard_variables() {
	local manifest="$1"
	local expected_json="$2"
	assert_dashboard_jq "$manifest" \
		"[.templating.list[].name] | sort == ($expected_json | sort)" \
		"variables must equal $expected_json"
}

test_alloy_splits_internal_and_browser_otlp() {
	assert_file_contains "$alloy_values" 'otelcol.receiver.otlp "internal"'
	assert_file_contains "$alloy_values" 'endpoint = "0.0.0.0:4317"'
	assert_file_contains "$alloy_values" 'endpoint = "0.0.0.0:4318"'
	assert_file_contains "$alloy_values" 'otelcol.processor.k8sattributes "internal"'
	assert_file_contains "$alloy_values" 'otelcol.receiver.otlp "browser"'
	assert_file_contains "$alloy_values" 'endpoint = "0.0.0.0:4319"'
	assert_file_contains "$alloy_values" 'name: otlp-http-web'
	assert_file_contains "$alloy_values" 'faroPort: 4319'
}

test_alloy_enriches_only_curated_dimensions() {
	for attribute in \
		'k8s.namespace.name' \
		'k8s.deployment.name' \
		'k8s.statefulset.name' \
		'k8s.pod.name' \
		'k8s.pod.uid' \
		'k8s.node.name'; do
		assert_file_contains "$alloy_values" "\"$attribute\""
	done
	assert_file_contains "$alloy_values" 'set(attributes[\"service.instance.id\"], attributes[\"k8s.pod.uid\"])'
	assert_file_contains "$alloy_values" 'set(attributes[\"k8s.workload.name\"], attributes[\"k8s.deployment.name\"])'
	assert_file_contains "$alloy_values" 'set(attributes[\"k8s.workload.name\"], attributes[\"k8s.statefulset.name\"])'
	assert_file_contains "$alloy_values" 'set(attributes[\"environment\"], attributes[\"deployment.environment.name\"])'
	assert_file_contains "$alloy_values" 'set(attributes[\"namespace\"], attributes[\"k8s.namespace.name\"])'
	assert_file_contains "$alloy_values" 'set(attributes[\"workload\"], attributes[\"k8s.workload.name\"])'
	assert_file_contains "$alloy_values" 'set(attributes[\"pod\"], attributes[\"k8s.pod.name\"])'
	assert_file_contains "$alloy_values" 'set(attributes[\"app_surface\"], resource.attributes[\"app.surface\"])'
	assert_file_contains "$alloy_values" 'value  = "service.name,environment,namespace,workload,pod,app.surface"'
	assert_file_contains "$alloy_values" 'value  = "level"'
}

test_alloy_scrapes_only_the_nats_exporter_pod_port() {
	assert_file_contains "$alloy_values" 'discovery.kubernetes "pods"'
	assert_file_contains "$alloy_values" 'prometheus.scrape "nats"'
	assert_file_contains "$alloy_values" 'job_name        = "nats"'
	assert_file_contains "$alloy_values" 'regex         = "prom-exporter"'
	assert_file_contains "$alloy_values" 'regex         = "7777"'
	assert_file_contains "$alloy_values" 'replacement   = "nats_stream_$1"'
	assert_file_contains "$alloy_values" 'replacement   = "nats_consumer_$1"'
}

test_tempo_enables_local_blocks_for_all_spans_and_storage() {
	assert_file_contains "$tempo_values" 'local_blocks:'
	assert_file_contains "$tempo_values" 'filter_server_spans: false'
	assert_file_contains "$tempo_values" 'flush_to_storage: true'
	assert_file_contains "$tempo_values" '- local-blocks'
}

test_grafana_uses_trace_to_logs_v2_with_curated_tags() {
	assert_file_contains "$grafana_values" 'tracesToLogsV2:'
	assert_file_contains "$grafana_values" 'filterByTraceID: true'
	assert_file_contains "$grafana_values" 'key: service.name'
	assert_file_contains "$grafana_values" 'value: service_name'
	assert_file_contains "$grafana_values" 'key: deployment.environment.name'
	assert_file_contains "$grafana_values" 'value: environment'
	assert_file_contains "$grafana_values" 'key: k8s.namespace.name'
	assert_file_contains "$grafana_values" 'value: namespace'
	assert_file_contains "$grafana_values" 'key: k8s.workload.name'
	assert_file_contains "$grafana_values" 'value: workload'
	assert_file_contains "$grafana_values" 'key: k8s.pod.name'
	assert_file_contains "$grafana_values" 'value: pod'
	assert_file_not_contains "$grafana_values" '          tracesToLogs:'
}

test_nats_exporter_collects_only_health_varz_and_jsz() {
	assert_file_contains "$nats_values" 'promExporter:'
	assert_file_contains "$nats_values" 'enabled: true'
	assert_file_contains "$nats_values" 'tag: 0.19.2'
	assert_file_contains "$nats_values" '- -healthz'
	assert_file_contains "$nats_values" '- -varz'
	assert_file_contains "$nats_values" '- -jsz=all'
	assert_file_not_contains "$nats_values" '- -connz'
	assert_file_not_contains "$nats_values" '- -subz'
	assert_file_not_contains "$nats_values" '- -routez'
	assert_file_contains "$nats_values" 'path: /metrics'
	assert_file_not_contains "$nats_values" 'path: /healthz'
	assert_file_contains "$nats_values" 'runAsNonRoot: true'
	assert_file_contains "$nats_values" 'readOnlyRootFilesystem: true'
}

test_ops_workload_sends_all_signals_to_internal_otlp() {
	for variable in \
		ENVIRONMENT \
		LOG_LEVEL \
		METRICS_ADDRESS \
		TEMPO_ENDPOINT \
		TEMPO_INSECURE \
		OTLP_ENDPOINT \
		OTLP_TRANSPORT \
		OTLP_INSECURE \
		OTLP_LOGS_ENABLED; do
		assert_file_contains "$ops_deployment" "name: $variable"
	done
	assert_file_contains "$ops_deployment" 'value: "alloy.observability.svc.cluster.local:4317"'
	for binding in 'OTLP_TRANSPORT=grpc' 'OTLP_INSECURE=true' 'OTLP_LOGS_ENABLED=true'; do
		name="${binding%%=*}"
		value="${binding#*=}"
		if ! yq -e ".spec.template.spec.containers[] | select(.name == \"frolf-bot-ops\") | .env[] | select(.name == \"$name\" and .value == \"$value\")" "$ops_deployment" >/dev/null; then
			echo "expected $name=$value in $ops_deployment" >&2
			return 1
		fi
	done
}

test_adopted_dashboards_keep_live_uids_and_filters() {
	local go_dashboard="$dashboard_dir/go-runtime-metrics.yaml"
	local logs_dashboard="$dashboard_dir/logs-app.yaml"
	local node_dashboard="$dashboard_dir/node-exporter-full.yaml"

	assert_dashboard_jq "$go_dashboard" '.uid == "go-runtime-metrics"' 'Go Runtime UID'
	assert_dashboard_variables "$go_dashboard" '["service","environment","namespace","workload","pod"]'
	assert_file_contains "$go_dashboard" 'job=~\"$service\"'
	assert_file_not_contains "$go_dashboard" 'service_name=~'

	assert_dashboard_jq "$logs_dashboard" '.uid == "sadlil-loki-apps-dashboard"' 'Logs/App UID'
	assert_dashboard_variables "$logs_dashboard" '["service","environment","namespace","workload","pod","level","search"]'
	assert_file_contains "$logs_dashboard" '"uid": "loki"'

	assert_dashboard_jq "$node_dashboard" '.uid == "rYdddlPWk"' 'Node Exporter Full UID'
	assert_dashboard_variables "$node_dashboard" '["node","device","mountpoint"]'
	assert_file_contains "$node_dashboard" '"uid": "mimir"'
}

test_gitops_dashboards_expose_canonical_filters() {
	assert_dashboard_variables "$dashboard_dir/application-service-overview.yaml" '["service","environment","namespace","workload","pod","surface"]'
	assert_dashboard_variables "$dashboard_dir/kubernetes-resources.yaml" '["namespace","node","pod","container"]'
	assert_dashboard_variables "$dashboard_dir/nats.yaml" '["server","stream","consumer"]'
	assert_dashboard_variables "$dashboard_dir/frolf-bot-eventbus.yaml" '["service","stream","consumer"]'
	assert_dashboard_variables "$dashboard_dir/frolf-bot-service-health.yaml" '["service","environment","route","status"]'
	assert_dashboard_variables "$dashboard_dir/frolf-bot-db.yaml" '["service","operation","table"]'
	assert_dashboard_variables "$dashboard_dir/finops.yaml" '["club_id","namespace","workload"]'
	assert_dashboard_variables "$dashboard_dir/frolf-bot-business.yaml" '["club_id"]'

	assert_file_contains "$dashboard_dir/application-service-overview.yaml" 'Trace Drilldown'
	assert_file_contains "$dashboard_dir/application-service-overview.yaml" 'Logs Drilldown'
	assert_file_contains "$dashboard_dir/kubernetes-resources.yaml" 'Workload Health'
	assert_file_contains "$dashboard_dir/nats.yaml" 'nats_varz_'
	assert_file_contains "$dashboard_dir/nats.yaml" 'nats_stream_'
	assert_file_contains "$dashboard_dir/nats.yaml" 'nats_consumer_'
}

test_broken_k8s_uid_is_provisioned_as_a_redirect() {
	local deprecated_dashboard="$dashboard_dir/k8s-dashboard-deprecated.yaml"
	assert_dashboard_jq "$deprecated_dashboard" '.uid == "f0bc58e1-e352-48ee-a588-3d9688cd08ec"' 'deprecated K8S UID'
	assert_file_contains "$deprecated_dashboard" '/d/k8s-resources/'
	assert_file_contains "$deprecated_dashboard" 'Kubernetes — Resource Usage & Health'
}

test_traceql_regression_check_replays_the_original_failure() {
	assert_file_contains "$tempo_regression_script" '{nestedSetParent<0 && true && resource.service.name != nil} | rate() by(resource.service.name)'
	assert_file_contains "$tempo_regression_script" 'expected HTTP 200'
}

test_all_dashboard_json_is_valid_and_has_no_stale_datasources() {
	local manifest
	for manifest in "$dashboard_dir"/*.yaml; do
		extract_dashboard_json "$manifest" | jq -e . >/dev/null
	done
	if grep -R -E -q 'PAE45454D0EDB9216|WAYOn0FGz|P8E80F9AEF21F6940' "$dashboard_dir"; then
		echo "stale UI datasource UID found in Git-managed dashboards" >&2
		return 1
	fi
}

tests=(
	test_alloy_splits_internal_and_browser_otlp
	test_alloy_enriches_only_curated_dimensions
	test_alloy_scrapes_only_the_nats_exporter_pod_port
	test_tempo_enables_local_blocks_for_all_spans_and_storage
	test_grafana_uses_trace_to_logs_v2_with_curated_tags
	test_nats_exporter_collects_only_health_varz_and_jsz
	test_ops_workload_sends_all_signals_to_internal_otlp
	test_adopted_dashboards_keep_live_uids_and_filters
	test_gitops_dashboards_expose_canonical_filters
	test_broken_k8s_uid_is_provisioned_as_a_redirect
	test_traceql_regression_check_replays_the_original_failure
	test_all_dashboard_json_is_valid_and_has_no_stale_datasources
)

for test_name in "${tests[@]}"; do
	echo "running $test_name"
	"$test_name"
done
