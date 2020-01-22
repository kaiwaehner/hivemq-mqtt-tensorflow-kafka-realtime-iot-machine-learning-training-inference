#!/usr/bin/env bash

set -e

CNAME=${1}
REGION=${2}
PROJECT=${3}

echo "Provisioning K8s cluster..."
gcloud container clusters get-credentials ${CNAME} --zone ${REGION}

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
# This supposedly helps with flaky "lost connection to pod" errors and the like when installing a chart
kubectl set resources -n kube-system deployment tiller-deploy --limits=memory=200Mi

echo " GKE cluster created"
gcloud container clusters list