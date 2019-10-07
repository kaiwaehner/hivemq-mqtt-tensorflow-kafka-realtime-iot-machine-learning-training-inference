#!/usr/bin/env bash
set -e

echo "Delete Confluent Platform..."
helm delete --purge ksql
helm delete --purge controlcenter
# helm delete --purge connectors
# helm delete --purge replicator
helm delete --purge schemaregistry
helm delete --purge kafka
helm delete --purge zookeeper
helm delete --purge operator

kubectl -n operator delete sts/kafka
kubectl -n operator delete sts/zookeeper
kubectl -n operator delete service/zookeeper
kubectl -n operator delete service/zookeeper-0-internal
kubectl -n operator delete service/zookeeper-1-internal
kubectl -n operator delete service/zookeeper-2-internal

# gcloud --quiet container node-pools delete car-demo-node-pool --region europe-west1 --cluster car-demo-cluster
# gcloud --quiet container clusters delete car-demo-cluster --region europe-west1

echo "Check pods..."
kubectl get pods -n operator
