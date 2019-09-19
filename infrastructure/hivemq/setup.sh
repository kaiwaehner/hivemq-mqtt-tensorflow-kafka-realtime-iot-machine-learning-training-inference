#!/usr/bin/env bash

set -euo pipefail

if ! hash kubectl 2>/dev/null; then
    echo "ERROR: You must install kubectl to use this script"
    exit 1
fi

kubectl create namespace hivemq || true
kubectl apply -f operator-rbac.yaml

echo "Deploying HiveMQ operator..."
# Warning: This is a really early development version of the operator. DO NOT USE IN PRODUCTION
kubectl run operator --namespace hivemq --serviceaccount=hivemq-operator --image=sbaier1/hivemq-operator:0.0.1 || true

kubectl apply -f hivemq-crd.yaml