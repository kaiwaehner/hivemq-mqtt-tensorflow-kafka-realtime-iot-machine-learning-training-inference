#!/usr/bin/env bash

set -euo pipefail

if ! hash kubectl 2>/dev/null; then
    echo "ERROR: You must install kubectl to use this script"
    exit 1
fi

# To make sure the Prometheus operator can discover the HiveMQ service monitor
kubectl patch prometheus prom-prometheus-operator-prometheus --type='json' -p='[{"op": "replace", "path": "/spec/serviceMonitorSelector", "value":{}}]'

kubectl create namespace hivemq || true
kubectl apply -f operator-rbac.yaml

kubectl create configmap hivemq-dashboard --from-file=hivemq.json || true
kubectl label configmap/hivemq-dashboard grafana_dashboard=1 || true

echo "Deploying HiveMQ operator..."
# Warning: This is a really early development version of the operator. DO NOT USE IN PRODUCTION
kubectl run operator --namespace hivemq --serviceaccount=hivemq-operator --image=sbaier1/hivemq-operator:0.0.1 || true
kubectl rollout -n hivemq status deployment operator
# Arbitrary sleep to wait until the operator creates the CRD
sleep 5

kubectl apply -f hivemq-crd.yaml
# Arbitrary sleep to wait until the operator creates the deployment
sleep 5
kubectl rollout -n hivemq status deployment hivemq-cluster1

kubectl apply -f hivemq-mqtt.yaml