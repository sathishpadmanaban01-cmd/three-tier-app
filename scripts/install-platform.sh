#!/usr/bin/env bash
set -euo pipefail

create_ns() {
  local ns="$1"
  kubectl get namespace "$ns" >/dev/null 2>&1 || kubectl create namespace "$ns"
}

echo "Creating namespaces..."
create_ns argocd
create_ns app
create_ns monitoring
create_ns observability
create_ns logging
create_ns messaging

echo "Installing Argo CD..."
kubectl apply -n argocd --server-side --force-conflicts \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "Waiting for Argo CD core components..."
kubectl rollout status deployment/argocd-server -n argocd --timeout=600s
kubectl rollout status deployment/argocd-repo-server -n argocd --timeout=600s
kubectl rollout status deployment/argocd-applicationset-controller -n argocd --timeout=600s
kubectl rollout status statefulset/argocd-application-controller -n argocd --timeout=600s

echo "Adding Helm repos..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
helm repo add strimzi https://strimzi.io/charts/
helm repo add elastic https://helm.elastic.co
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

echo "Installing kube-prometheus-stack..."
helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  -n monitoring \
  --create-namespace \
  --set grafana.adminPassword=admin123

echo "Installing OpenTelemetry Collector..."
helm upgrade --install otel-collector open-telemetry/opentelemetry-collector \
  -n observability \
  --create-namespace \
  --set mode=deployment \
  --set image.repository=otel/opentelemetry-collector-contrib \
  --set config.receivers.otlp.protocols.http.endpoint=0.0.0.0:4318 \
  --set config.exporters.debug.verbosity=normal \
  --set config.service.pipelines.traces.receivers[0]=otlp \
  --set config.service.pipelines.traces.exporters[0]=debug

echo "Installing Redis..."
helm upgrade --install redis bitnami/redis \
  -n app \
  --create-namespace \
  --set auth.enabled=false

echo "Installing Strimzi Kafka Operator..."
helm upgrade --install strimzi-kafka-operator strimzi/strimzi-kafka-operator \
  -n messaging \
  --create-namespace

echo "Installing Elasticsearch..."
helm upgrade --install elasticsearch elastic/elasticsearch \
  -n logging \
  --create-namespace \
  --set replicas=1 \
  --set minimumMasterNodes=1

echo "Installing Kibana..."
helm upgrade --install kibana elastic/kibana \
  -n logging \
  --create-namespace \
  --set service.type=ClusterIP

echo "Platform installation completed."