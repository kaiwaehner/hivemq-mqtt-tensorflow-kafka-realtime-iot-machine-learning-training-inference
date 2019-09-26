#!/usr/bin/env bash

set -e

echo "Provisioning K8s cluster..."

gcloud container clusters get-credentials ${1} --zone ${2}

# Context should be set automatically
#kubectl use-context gke_${3}_${2}_${1}

# _idempotent_ setup

# Make tiller a cluster-admin so it can do whatever it wants
kubectl apply -f tiller-rbac.yaml

helm init --wait --service-account tiller
# Apparently tiller is sometimes not ready after init even with --wait
sleep 5

echo "Deploying prometheus..."
helm upgrade --install prom stable/prometheus-operator --wait

echo "Deploying metrics server..."
helm upgrade --install metrics stable/metrics-server --wait --force || true

echo "Deploying K8s dashboard..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.0.0-beta4/aio/deploy/recommended.yaml

echo "Kubernetes Dashboard token:"
gcloud config config-helper --format=json | jq -r '.credential.access_token'