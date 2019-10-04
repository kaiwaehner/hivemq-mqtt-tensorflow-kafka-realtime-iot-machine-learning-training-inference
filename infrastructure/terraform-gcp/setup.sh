#!/usr/bin/env bash

CNAME=${1}
REGION=${2}
PROJECT=${3}
REPLICAS=${4}
ZONE1=${5}

set -e

echo "Provisioning K8s cluster..."

gcloud container clusters get-credentials ${1} --zone ${5}
# gcloud container clusters get-credentials car-demo-cluster --zone europe-west1

# Context should be set automatically
#kubectl use-context gke_${3}_${2}_${1}

# _idempotent_ setup

# Make tiller a cluster-admin so it can do whatever it wants
kubectl apply -f tiller-rbac.yaml

helm init --wait --service-account tiller
# Apparently tiller is sometimes not ready after init even with --wait
sleep 5

echo "Deploying prometheus..."
helm upgrade --install prom stable/prometheus-operator --wait

echo "Deploying metrics server..."
helm upgrade --install metrics stable/metrics-server --wait --force || true

echo "Deploying K8s dashboard..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.0.0-beta4/aio/deploy/recommended.yaml

echo "Kubernetes Dashboard token:"
gcloud config config-helper --format=json | jq -r '.credential.access_token'

echo "Download Confluent Operator"
# check if Confluent Operator still exist
DIR="conluent-operator/"
if [ -d "$DIR" ]; then
  # Take action if $DIR exists. #
  echo "Operator is installed..."
else
  mkdir confluent-operator
  cd confluent-operator/
  wget https://platform-ops-bin.s3-us-west-1.amazonaws.com/operator/confluent-operator-20190912-v0.65.1.tar.gz
  tar -xvf confluent-operator-20190912-v0.65.1.tar.gz
  rm confluent-operator-20190912-v0.65.1.tar.gz
  cp ../gcp.yaml helm/providers/
  cd helm/
fi

#echo "Install Confluent Operator"
#helm delete --purge operator
helm install \
-f ./providers/gcp.yaml \
--name operator \
--namespace operator \
--set operator.enabled=true \
./confluent-operator
sleep 5
kubectl get pods -n operator

echo "Install Confluent Zookeeper"
#helm delete --purge zookeeper
helm install \
-f ./providers/gcp.yaml \
--name zookeeper \
--namespace operator \
--set zookeeper.enabled=true \
./confluent-operator
sleep 50
kubectl get pods -n operator

echo "Install Confluent Kafka"
#helm delete --purge kafka
helm install \
-f ./providers/gcp.yaml \
--name kafka \
--namespace operator \
--set kafka.enabled=true \
./confluent-operator
sleep 50
kubectl get pods -n operator

echo "Install Confluent Schema Registry"
#helm delete --purge schemaregistry
helm install \
-f ./providers/gcp.yaml \
--name schemaregistry \
--namespace operator \
--set schemaregistry.enabled=true \
./confluent-operator
Sleep 50
kubectl get pods -n operator

echo "Install Confluent KSQL"
# helm delete --purge ksql
helm install \
-f ./providers/gcp.yaml \
--name ksql \
--namespace operator \
--set ksql.enabled=true \
./confluent-operator
Sleep 50
kubectl get pods -n operator

echo "Install Confluent Control Center"
# helm delete --purge controlcenter
helm install \
-f ./providers/gcp.yaml \
--name controlcenter \
--namespace operator \
--set controlcenter.enabled=true \
./confluent-operator
Sleep 50
kubectl get pods -n operator

echo "Create LB for Control Center"
helm upgrade -f ./providers/gcp.yaml \
 --set controlcenter.enabled=true \
 --set controlcenter.loadBalancer.enabled=true \
 --set controlcenter.loadBalancer.domain=axvy.aa.de controlcenter \
 ./confluent-operator
Sleep 50
kubectl get services -n operator
