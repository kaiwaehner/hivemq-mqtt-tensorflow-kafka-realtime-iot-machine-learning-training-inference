#!/usr/bin/env bash

set -o xtrace

echo "Deleting services first..."
kubectl delete --grace-period=10 svc --all --namespace=operator || true
kubectl delete --grace-period=10 svc --all --namespace=monitoring || true
kubectl delete --grace-period=10 svc --all --namespace=hivemq || true

echo "Deleting Stateful sets..."
kubectl delete --grace-period=10 sts --all --namespace=operator || true
kubectl delete --grace-period=10 sts --all --namespace=monitoring || true
kubectl delete --grace-period=10 sts --all --namespace=hivemq || true

echo "Deleting Pods..."
kubectl delete --grace-period=0 --force pod --all --namespace=operator || true
kubectl delete --grace-period=0 --force pod --all --namespace=monitoring || true
kubectl delete --grace-period=0 --force pod --all --namespace=hivemq || true


echo "Deleting PVCs"
kubectl delete --grace-period=5 --all pvc --namespace=operator || true
kubectl delete --grace-period=5 --all pvc --namespace=monitoring || true
kubectl delete --grace-period=5 --all pvc --namespace=hivemq || true

echo "Purging namespaces..."
kubectl delete --grace-period=0 --force --all all --namespace=operator || true
kubectl delete --grace-period=0 --force --all all --namespace=monitoring || true
kubectl delete --grace-period=0 --force --all all --namespace=hivemq || true
