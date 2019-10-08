#!/usr/bin/env bash

# BEFORE running any deployments against GKE cluster, check if cluser is running
RESULT=$(gcloud container clusters list | grep RUNNING)
while [[ -z "${RESULT}" ]];
do
  echo "Cluster not running...wait 20 seconds...and check again..."
  RESULT=$(gcloud container clusters list | grep RUNNING)
  sleep 20
done