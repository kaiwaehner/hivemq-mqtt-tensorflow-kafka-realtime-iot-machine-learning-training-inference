#!/usr/bin/env bash

set -o xtrace
export PROJECT_ID=$1
export REGION=$2
export CLUSTER=$3
gcloud container --project ${PROJECT_ID} clusters delete "${CLUSTER}" --region "${REGION}" --async --quiet
yes Y | gcloud compute disks list | grep gke-car-demo-cluster | awk '{printf "gcloud compute disks delete %s --zone %s; ", $1, $2}' | bash

