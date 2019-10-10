#!/usr/bin/env bash

set -e

CNAME=${1}
REGION=${2}
PROJECT=${3}

echo "Provisioning K8s cluster..."
gcloud container clusters get-credentials ${CNAME} --region ${REGION}

# Context should be set automatically
#kubectl use-context gke_${3}_${2}_${1}

# _idempotent_ setup

until kubectl cluster-info >/dev/null 2>&1; do
    echo "kubeapi not available yet..."
    sleep 3
done
# Make tiller a cluster-admin so it can do whatever it wants
kubectl apply -f tiller-rbac.yaml

helm init --wait --service-account tiller
# Apparently tiller is sometimes not ready after init even with --wait
sleep 5

echo " GKE cluster created"
gcloud container clusters list