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

echo " GKE cluster created"
gcloud container clusters list