#!/usr/bin/env bash
set -euo pipefail

kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace app --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace observability --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace logging --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace messaging --dry-run=client -o yaml | kubectl apply -f -

kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
helm repo add strimzi https://strimzi.io/charts/
helm repo add elastic https://helm.elastic.co
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  -n monitoring \
  --set grafana.adminPassword=admin123

helm upgrade --install otel-collector open-telemetry/opentelemetry-collector \
  -n observability \
  --set mode=deployment \
  --set config.receivers.otlp.protocols.http.endpoint=0.0.0.0:4318 \
  --set config.exporters.debug.verbosity=normal \
  --set config.service.pipelines.traces.receivers[0]=otlp \
  --set config.service.pipelines.traces.exporters[0]=debug

helm upgrade --install redis bitnami/redis -n app --set auth.enabled=false
helm upgrade --install strimzi-kafka-operator strimzi/strimzi-kafka-operator -n messaging
helm upgrade --install elasticsearch elastic/elasticsearch -n logging --set replicas=1 --set minimumMasterNodes=1
helm upgrade --install kibana elastic/kibana -n logging
