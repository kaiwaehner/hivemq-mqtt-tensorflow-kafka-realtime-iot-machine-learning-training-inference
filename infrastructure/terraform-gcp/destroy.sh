#!/usr/bin/env bash

set -o xtrace

echo "Purging namespaces..."
kubectl delete --grace-period=0 --force --all all --namespace=operator || true
kubectl delete --grace-period=0 --force --all all --namespace=monitoring || true
kubectl delete --grace-period=0 --force --all all --namespace=hivemq || true
