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

echo " GKE cluster created"