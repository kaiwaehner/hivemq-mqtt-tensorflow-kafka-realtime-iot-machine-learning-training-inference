#!/usr/bin/env bash

CNAME=${1}
REGION=${2}
PROJECT=${3}

set -e

echo "Provisioning K8s cluster..."
gcloud container clusters get-credentials ${CNAME} --region ${REGION}
echo "Check if cluster is running..."
gcloud container clusters list

# BEFORE running any deployments against GKE cluster, check if cluser is running
RESULT=$(bash gcloud container clusters list | grep RUNNING)
while [ -z "${RESULT}" ]
do
  echo "Cluster not running...wait 20 seconds...and check again..."
  RESULT=$(bash gcloud container clusters list | grep RUNNING)
  sleep 20
done

# Context should be set automatically
#kubectl use-context gke_${3}_${2}_${1}

# _idempotent_ setup

# Make tiller a cluster-admin so it can do whatever it wants
kubectl apply -f tiller-rbac.yaml

helm init --wait --service-account tiller
# Apparently tiller is sometimes not ready after init even with --wait
sleep 5

echo " GKE cluster created"
gcloud container clusters list