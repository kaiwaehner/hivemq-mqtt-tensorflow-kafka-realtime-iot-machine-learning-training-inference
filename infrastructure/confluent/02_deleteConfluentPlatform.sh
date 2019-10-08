#!/usr/bin/env bash
set -e

echo "Delete Confluent Platform and Operator from K8s GKE..."

# Cleanup
helm delete --purge controlcenter
helm delete --purge schemaregistry
helm delete --purge ksql

helm delete --purge kafka
# Force kafka broker container delete in case they get stuck
kubectl -n operator delete pod kafka-0 --grace-period=0 --force --wait=false
kubectl -n operator delete pod kafka-1 --grace-period=0 --force --wait=false
kubectl -n operator delete pod kafka-2 --grace-period=0 --force --wait=false

helm delete --purge zookeeper
# Force zookeeper container delete in case they get stuck
kubectl -n operator delete pod zookeeper-0 --grace-period=0 --force --wait=false
kubectl -n operator delete pod zookeeper-1 --grace-period=0 --force --wait=false
kubectl -n operator delete pod zookeeper-2 --grace-period=0 --force --wait=false

helm delete --purge operator
# Delete the namespace and all it's content
kubectl delete all --all -n operator --wait=false
kubectl delete namespace operator --wait=false


# Only for doublecheck
#kubectl -n operator delete sts/kafka
#kubectl -n operator delete sts/zookeeper
#kubectl -n operator delete service/zookeeper
#kubectl -n operator delete service/zookeeper-0-internal
#kubectl -n operator delete service/zookeeper-1-internal
#kubectl -n operator delete service/zookeeper-2-internal

# gcloud --quiet container node-pools delete car-demo-node-pool --region europe-west1 --cluster car-demo-cluster
# gcloud --quiet container clusters delete car-demo-cluster --region europe-west1

echo "Check pods..."
kubectl get pods -n operator
