#!/usr/bin/env bash

echo "Removing dashboard"
kubectl delete -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.0.0-beta4/aio/deploy/recommended.yaml

echo "Removing Prometheus"
helm delete --purge prom

helm delete --purge metrics

../confluent/02_deleteConfluentPlatform.sh || true


echo "Purging namespaces..."
kubectl delete --grace-period=0 --force --all pods --namespace=operator || true
kubectl delete --grace-period=0 --force --all pods --namespace=hivemq || true
kubectl delete --grace-period=0 --force --all pods --namespace=monitoring || true
kubectl delete namespaces hivemq operator monitoring || true
