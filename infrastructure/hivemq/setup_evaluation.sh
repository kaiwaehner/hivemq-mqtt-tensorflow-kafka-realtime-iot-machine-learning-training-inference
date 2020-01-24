#!/usr/bin/env bash

set -euo pipefail

cd ../hivemq/

if ! hash kubectl 2>/dev/null; then
    echo "ERROR: You must install kubectl to use this script"
    exit 1
fi

# To make sure the Prometheus operator can discover the HiveMQ service monitor
kubectl patch -n monitoring prometheus prometheus-prometheus-oper-prometheus --type='json' -p='[{"op": "replace", "path": "/spec/serviceMonitorSelector", "value":{}}]'

kubectl create namespace hivemq || true
kubectl apply -f operator-rbac.yaml

kubectl create -n monitoring configmap hivemq-dashboard --from-file=hivemq.json || true
kubectl label -n monitoring configmap/hivemq-dashboard grafana_dashboard=1 || true

echo "Deploying HiveMQ operator..."
# Warning: This is a really early development version of the operator. DO NOT USE IN PRODUCTION
kubectl run operator --namespace hivemq --serviceaccount=hivemq-operator --image=sbaier1/hivemq-operator:0.0.5 || true
kubectl rollout -n hivemq status deployment operator
# Arbitrary sleep to wait until the operator creates the CRD
sleep 5

kubectl apply -f kafka-config.yaml

kubectl apply -f hivemq-crd-evaluation.yaml
until kubectl get -n hivemq deployments | grep hivemq-cluster1; do
    echo "Deployment not available yet"
    sleep 5
done
kubectl rollout -n hivemq status --timeout=10m deployment hivemq-cluster1 || true

kubectl apply -f hivemq-mqtt.yaml -f hivemq-control-center.yaml

echo "${SA_KEY}" | base64 -D > credentials.json

kubectl create secret generic --from-file credentials.json google-application-credentials || true

rm -f credentials.json || true