obs-ns.yaml
obs-prometheus-hrep.yaml
obs-grafana-hrep.yaml
obs-otel-hrep.yaml
obs-fluent-hrep.yaml
obs-prometheus-hrel.yaml (CRDs Create on install/upgrade)
obs-grafana-loki-hrel.yaml
obs-grafana-tempo-hrel.yaml
obs-otel-operator-hrel.yaml
obs-otel-collector.yaml
obs-otel-service.yaml
obs-fluent-bit-hrel.yaml
obs-grafana-hrel.yaml
obs-grafana-datasources.yaml
obs-otel-service-monitor.yaml (applied by the “monitors” Ks after CRDs exist)
####################################################################
#
####################################################################
NS=observability
curl -s https://fluxcd.io/install.sh | sudo FLUX_VERSION=2.0.0 bash

# 0 ---
k get all -n flux-system
k get all -n observability

# 1 ---
kubectl apply -f flux-kbot-bootstrap/observability/obs-ns.yaml
k get ns

# 2 ---
kubectl apply -f flux-kbot-bootstrap/observability/obs-prometheus-hrep.yaml
kubectl apply -f flux-kbot-bootstrap/observability/obs-grafana-hrep.yaml
kubectl apply -f flux-kbot-bootstrap/observability/obs-otel-hrep.yaml
kubectl apply -f flux-kbot-bootstrap/observability/obs-fluent-hrep.yaml
flux get sources helm -A

# 3 ---
kubectl apply -f flux-kbot-bootstrap/observability/obs-prometheus-hrel.yaml
flux reconcile hr kube-prometheus-stack -n $NS
flux get hr -n observability
kubectl wait --for=condition=Ready hr/kube-prometheus-stack -n $NS --timeout=15m
# ensure CRDs exist before any ServiceMonitor
kubectl wait --for=condition=Established crd/servicemonitors.monitoring.coreos.com --timeout=5m
kubectl wait --for=condition=Established crd/podmonitors.monitoring.coreos.com --timeout=5m

# 4 --- 
kubectl apply -f flux-kbot-bootstrap/observability/obs-grafana-loki-hrel.yaml
flux reconcile hr loki -n $NS
kubectl wait --for=condition=Ready hr/loki -n $NS --timeout=15m
flux get hr -n observability
k get all -n observability

kubectl apply -f flux-kbot-bootstrap/observability/obs-grafana-tempo-hrel.yaml
flux reconcile hr tempo -n $NS
kubectl wait --for=condition=Ready hr/tempo -n $NS --timeout=15m
flux get hr -n observability
k get all -n observability

# 5 ---
kubectl apply -f flux-kbot-bootstrap/observability/obs-otel-operator-hrel.yaml
flux reconcile hr opentelemetry-operator -n $NS
kubectl wait --for=condition=Ready hr/opentelemetry-operator -n $NS --timeout=10m
flux get hr -n observability
k get all -n observability

# 6 ---
# The Collector CR (spec.config: | … YAML block)
kubectl apply -f  flux-kbot-bootstrap/observability/obs-otel-collector.yaml
k get all -n observability
k describe pod/otel-gateway-collector-6b784d5d6f-pffkq -n $NS
k logs otel-gateway-collector-7d76577497-m2ttt --tail=60 -n $NS
# Service exposing OTLP/metrics endpoints
kubectl apply -f  flux-kbot-bootstrap/observability/obs-otel-service.yaml
k get all -n observability
kubectl -n observability get svc otel-gateway -o jsonpath='{.metadata.labels}{"\n"}{.spec.selector}{"\n"}'

# 7 ---
kubectl apply -f flux-kbot-bootstrap/observability/obs-fluent-bit-hrel.yaml
flux reconcile hr fluent-bit -n $NS
kubectl wait --for=condition=Ready hr/fluent-bit -n $NS --timeout=10m
flux get hr -n observability
k get all -n observability
flux -n observability logs --kind HelmRelease --name fluent-bit
k describe pod grafana-8b4b796f7-k77xx -n observability
k logs grafana-8b4b796f7-k77xx --tail=60 -n observability

# 8 ---
kubectl apply -f flux-kbot-bootstrap/observability/obs-grafana-hrel.yaml
flux reconcile hr grafana -n $NS
flux get hr -n observability
k get all -n observability
k describe pod fluent-bit-bgg47 -n observability
k logs fluent-bit-bgg47 --tail=60 -n observability
kubectl wait --for=condition=Ready hr/grafana -n $NS --timeout=10m
kubectl -n observability get cm grafana -o jsonpath='{.data.grafana\.ini}'
kubectl -n observability get pods -l app.kubernetes.io/name=grafana
kubectl -n observability get secret grafana -o jsonpath='{.data.admin-password}' | base64 -d; echo
kubectl -n observability port-forward svc/grafana 3001:80
# (if you keep datasources as a separate manifest)
kubectl apply -f flux-kbot-bootstrap/observability/obs-grafana-datasources.yaml
kubectl -n observability get cm grafana-datasources -o yaml | sed -n '1,60p'
kubectl -n observability logs deploy/grafana -c grafana-sc-datasources | tail -n 50

# 9 ---
kubectl apply -f flux-kbot-bootstrap/observability/obs-otel-service-monitor.yaml
kubectl -n $NS get servicemonitor
kubectl -n observability get servicemonitor otel-gateway -o yaml

# ---
kubectl -n observability get pods -l app.kubernetes.io/name=grafana
kubectl -n observability get secret grafana -o jsonpath='{.data.admin-password}' | base64 -d; echo
kubectl -n observability port-forward svc/grafana 3001:80


####################################################################
# HealthChecks
####################################################################
# Namespace shortcut
NS=observability

k get all -n observability

# --- OpenTelemetry Collector (gateway)
kubectl -n $NS logs deploy/otel-gateway-collector --tail=200 -f

# --- OpenTelemetry Operator (manager)
kubectl -n $NS logs deploy/opentelemetry-operator -c manager --tail=200 -f

# --- Fluent Bit (DaemonSet on all nodes)
kubectl -n $NS logs ds/fluent-bit -c fluent-bit --tail=200 -f --prefix --max-log-requests=20
kubectl -n $NS logs ds/fluent-bit -c fluent-bit --tail=200
# single pod (if needed)
kubectl -n $NS logs $(kubectl -n $NS get pod -l app.kubernetes.io/name=fluent-bit -o name | head -n1) -c fluent-bit --tail=200 -f

# --- Loki
kubectl -n observability logs -l app.kubernetes.io/name=loki --tail=200 -f

# --- Tempo
kubectl -n $NS logs -l app.kubernetes.io/name=tempo --tail=200 -f

# --- Prometheus (kube-prometheus-stack)
kubectl -n $NS logs sts/prometheus-kube-prometheus-stack-prometheus -c prometheus --tail=200 -f
kubectl -n $NS logs deploy/kube-prometheus-stack-operator --tail=200 -f

# --- Grafana
kubectl -n observability logs deploy/grafana -c grafana --tail=200 -f
kubectl -n $NS logs deploy/grafana -c grafana-sc-datasources --tail=200
kubectl -n $NS logs deploy/grafana -c grafana-sc-dashboard --tail=200 || true

# --- Flux controllers (when a HelmRelease misbehaves)
kubectl -n flux-system logs deploy/helm-controller -f | grep -Ei 'fluent-bit|loki|tempo|grafana|otel|prometheus'
kubectl -n flux-system logs deploy/source-controller -f | grep -Ei 'grafana|opentelemetry|prometheus'

# --- Quick status helpers
kubectl -n $NS get pods -o wide
kubectl -n $NS get events --sort-by=.lastTimestamp | tail -n 50


# -- ERRORS
kubectl -n $NS logs deploy/kube-prometheus-stack-operator --tail=200 -f
kubectl -n $NS logs deploy/grafana -c grafana --tail=200 -f | grep error

# ---------------------------------------------
# Vars (adjust if your namespaces differ)
# ---------------------------------------------
export FB_NS="${NS:-observability}"      # where fluent-bit DS runs
export OTEL_NS="observability"           # where your otel-gateway/collector runs
export OTEL_SVC="otel-gateway"           # Service name for the gateway
export OTEL_PORT="4318"                  # OTLP/HTTP
export OTEL_HEALTH_PORT="13133"          # otelcol health_check (if enabled)

# ---------------------------------------------
# 1) Basic inventory & status
# ---------------------------------------------
kubectl -n "$FB_NS" get ds,po -l 'app in (fluent-bit,fluentbit)' -o wide
kubectl -n "$OTEL_NS" get deploy,sts,po,svc -l 'app in (otel,otel-collector,otel-gateway,opentelemetry-collector)' -o wide

# ---------------------------------------------
# 2) Service wiring: DNS, Service, Endpoints
# ---------------------------------------------
kubectl -n "$OTEL_NS" get svc "$OTEL_SVC" -o wide
kubectl -n "$OTEL_NS" describe svc "$OTEL_SVC"

# Endpoints / EndpointSlices must NOT be empty and should list READY backends
kubectl -n "$OTEL_NS" get endpoints "$OTEL_SVC" -o yaml
kubectl -n "$OTEL_NS" get endpointslice -l 'kubernetes.io/service-name='"$OTEL_SVC" -o yaml

# ---------------------------------------------
# 3) Collector/gateway pods: readiness & logs
# ---------------------------------------------
# Show events that often reveal port/selector mismatches
kubectl -n "$OTEL_NS" get po -l app="$OTEL_SVC" -o name | xargs -r kubectl -n "$OTEL_NS" describe
# Recent logs of all containers in the gateway/collector
kubectl -n "$OTEL_NS" logs deploy/"$OTEL_SVC" --all-containers --tail=200 || true
kubectl -n "$OTEL_NS" logs -l 'app in (otel-collector,opentelemetry-collector)' --all-containers --tail=200

# ---------------------------------------------
# 4) Verify the Collector is listening on 4318 (HTTP)
#    The OTLP receiver should have both http: 4318 and/or grpc: 4317 configured.
#    If inbound is only on 127.0.0.1, ClusterIP connections will be refused.
# ---------------------------------------------
# Show relevant config (search for otlp receiver and endpoint bindings)
kubectl -n "$OTEL_NS" get cm -o name | grep -i otel | xargs -r kubectl -n "$OTEL_NS" get -o yaml | \
  sed -n '1,2000p' | grep -nE 'receivers:|otlp:|protocols:|http:|grpc:|endpoint:|4318|4317'

# Example expected snippet in your otel config:
# receivers:
#   otlp:
#     protocols:
#       http:
#         endpoint: 0.0.0.0:4318
#       grpc:
#         endpoint: 0.0.0.0:4317


# ---------------------------------------------
# 6) Check for NetworkPolicies that could block egress/ingress
# ---------------------------------------------
kubectl -n "$FB_NS" get netpol -o yaml
kubectl -n "$OTEL_NS" get netpol -o yaml

# (If needed) Temporarily allow egress from Fluent Bit to the gateway:
# cat <<'EOF' | kubectl apply -f -
# apiVersion: networking.k8s.io/v1
# kind: NetworkPolicy
# metadata:
#   name: allow-egress-to-otel
#   namespace: '"$FB_NS"'
# spec:
#   podSelector:
#     matchLabels:
#       app: fluent-bit
#   policyTypes: ["Egress"]
#   egress:
#   - to:
#     - namespaceSelector:
#         matchLabels:
#           kubernetes.io/metadata.name: '"$OTEL_NS"'
#     - podSelector: {}
#     ports:
#     - protocol: TCP
#       port: '"$OTEL_PORT"'
# EOF

# ---------------------------------------------
# 7) (Optional) Health check if extension is enabled on the Collector
#    port-forward and hit health endpoint (defaults to 13133)
# ---------------------------------------------
kubectl -n "$OTEL_NS" get deploy -o name | grep -E "(otel|collector)" | head -n1 | \
  xargs -I{} kubectl -n "$OTEL_NS" port-forward {} '"$OTEL_HEALTH_PORT"':'"$OTEL_HEALTH_PORT"' >/tmp/otel-hpf.log 2>&1 &
sleep 1
curl -sS http://127.0.0.1:"$OTEL_HEALTH_PORT"/ || true
pkill -f "port-forward .* $OTEL_HEALTH_PORT:$OTEL_HEALTH_PORT" || true

# ---------------------------------------------
# 8) Fluent Bit: show current output config (to verify host/port/TLS)
#    Confirm it targets http://otel-gateway:4318 (and not gRPC/4317).
# ---------------------------------------------
kubectl -n "$FB_NS" get cm -o name | grep -i fluent | xargs -r kubectl -n "$FB_NS" get -o yaml | \
  sed -n '1,2000p' | grep -nE '^\s*\[OUTPUT\]|name\s+opentelemetry|host\s+|port\s+|uri\s+|tls\s+|http_' || true

# If you hardcoded an external IP (e.g., 34.118.231.214:4318), remove it and use the ClusterIP Service DNS.


####################################################################
# FIX
#
# Option A (zero-downtime, change Service only — recommended)
# Point svc/otel-gateway at the otel-gateway-collector pods.
####################################################################
# 0) Inspect current labels on the collector pods so we know what to select
kubectl -n observability get po -l app.kubernetes.io/instance=observability.otel-gateway -o jsonpath='{range .items[*]}{.metadata.name}{"  inst="}{.metadata.labels.app\.kubernetes\.io/instance}{"  name="}{.metadata.labels.app\.kubernetes\.io/name}{"\n"}{end}'
kubectl -n observability get po otel-gateway-collector-5d8b9fd749-kfbnz -o jsonpath='{range .items[*]}{.metadata.name}{"  inst="}{.metadata.labels.app\.kubernetes\.io/instance}{"  name="}{.metadata.labels.app\.kubernetes\.io/name}{"\n"}{end}'
kubectl -n observability describe po otel-gateway-collector-5d8b9fd749-kfbnz

# See current (empty) selector and endpoints of the broken Service
kubectl -n observability get svc otel-gateway -o jsonpath='{.spec.selector}{"\n"}'
kubectl -n observability get endpoints otel-gateway -o wide

# Patch the Service selector to match the running collector pods
kubectl -n observability patch svc otel-gateway \
  --type=merge \
  -p '{"spec":{"selector":{"app.kubernetes.io/instance":"observability.otel-gateway","app.kubernetes.io/name":"otel-gateway-collector"}}}'

# Confirm Endpoints get populated (addresses must appear)
kubectl -n observability get endpoints otel-gateway -o wide
kubectl -n observability get endpointslice -l kubernetes.io/service-name=otel-gateway -o jsonpath='{range .items[*].endpoints[*]}{.addresses}{"\n"}{end}'

# Sanity probe (expect HTTP 400/405 for empty payload, which is fine = port reachable)
kubectl -n observability run netshoot --rm -it --restart=Never --image=ghcr.io/nicolaka/netshoot:latest -- \
  sh -lc 'curl -s -o /dev/null -w "HTTP:%{http_code}\n" -X POST -H "Content-Type: application/json" --data "{}" \
  http://otel-gateway.observability.svc.cluster.local:4318/v1/logs'

# Watch Fluent Bit recover
kubectl -n observability logs ds/fluent-bit -c fluent-bit --tail=200 -f


####################################################################
# FIX
#
# Grafana origin not allowed
####################################################################
gcloud compute addresses create grafana-ip --global
gcloud compute addresses describe grafana-ip --global --format='get(address)'
# ---
kubectl apply -f flux-kbot-bootstrap/observability/obs-grafana-ing.yaml
kubectl -n observability get ingress grafana -o wide
kubectl apply -f flux-kbot-bootstrap/observability/obs-grafana-backendconfig.yaml
kubectl -n observability get bc grafana-backendconfig -o wide
# ---
kubectl apply -f flux-kbot-bootstrap/observability/obs-grafana-hrel.yaml
flux reconcile hr grafana -n $NS
kubectl -n observability get cm grafana -o jsonpath='{.data.grafana\.ini}'
# ---
kubectl -n observability get ingress grafana -o wide
kubectl -n observability describe ingress grafana
# wait until ADDRESS is set
# then watch the LB turn healthy:
gcloud compute backend-services list --global | grep grafana
gcloud compute backend-services get-health grafana-backendconfig --global
# ---
kubectl -n observability get netpol loki-namespace-only -o yaml
# ---
kubectl apply -f flux-kbot-bootstrap/observability/obs-allow-gclb-to-grafana.yaml

# --- Resources clean-up
gcloud compute addresses delete grafana-ip --global --quiet
gcloud compute addresses delete grafana-ip --global --quiet

gcloud compute forwarding-rules list --global | grep -i grafana || true
gcloud compute target-http-proxies list --global | grep -i grafana || true
gcloud compute url-maps list --global | grep -i grafana || true
gcloud compute backend-services list --global | grep -i grafana || true
gcloud compute health-checks list --global | grep -i k8s || true

gcloud compute backend-services delete <NAME> --global --quiet
gcloud compute url-maps delete <NAME> --global --quiet
gcloud compute target-http-proxies delete <NAME> --global --quiet
gcloud compute forwarding-rules delete <NAME> --global --quiet
gcloud compute health-checks delete <NAME> --global --quiet

kubectl -n observability exec deploy/grafana -c grafana -- \
  curl -s 'http://loki.observability.svc.cluster.local:3100/loki/api/v1/labels?since=10m' \
  | jq -r '.data[]' | sort | egrep 'k8s_|service_name|host_name' 