#!/usr/bin/env bash
set -e

echo "Check if cluster is running"
gcloud container clusters list

# BEFORE running any deployments against GKE cluster, check if cluser is running
RESULT=$(bash gcloud container clusters list | grep RUNNING)
while [ -z "${RESULT}" ]
do
  echo "Cluster not running...wait 20 seconds...and check again..."
  RESULT=$(bash gcloud container clusters list | grep RUNNING)
  sleep 20
done

echo "Deploying prometheus..."
helm upgrade --install prom stable/prometheus-operator --wait

# BEFORE running any deployments against GKE cluster, check if cluser is running
RESULT=$(bash gcloud container clusters list | grep RUNNING)
while [ -z "${RESULT}" ]
do
  echo "Cluster not running...wait 20 seconds...and check again..."
  RESULT=$(bash gcloud container clusters list | grep RUNNING)
  sleep 20
done

echo "Deploying metrics server..."
helm upgrade --install metrics stable/metrics-server --wait --force || true

# BEFORE running any deployments against GKE cluster, check if cluser is running
RESULT=$(bash gcloud container clusters list | grep RUNNING)
while [ -z "${RESULT}" ]
do
  echo "Cluster not running...wait 20 seconds...and check again..."
  RESULT=$(bash gcloud container clusters list | grep RUNNING)
  sleep 20
done

echo "Deploying K8s dashboard..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.0.0-beta4/aio/deploy/recommended.yaml

# BEFORE running any deployments against GKE cluster, check if cluser is running
RESULT=$(bash gcloud container clusters list | grep RUNNING)
while [ -z "${RESULT}" ]
do
  echo "Cluster not running...wait 20 seconds...and check again..."
  RESULT=$(bash gcloud container clusters list | grep RUNNING)
  sleep 20
done

echo "Kubernetes Dashboard token:"
gcloud config config-helper --format=json | jq -r '.credential.access_token'

# BEFORE running any deployments against GKE cluster, check if cluser is running
RESULT=$(bash gcloud container clusters list | grep RUNNING)
while [ -z "${RESULT}" ]
do
  echo "Cluster not running...wait 20 seconds...and check again..."
  RESULT=$(bash gcloud container clusters list | grep RUNNING)
  sleep 20
done

echo "Download Confluent Operator"
# check if Confluent Operator still exist
DIR="confluent-operator/"
if [ -d "$DIR" ]; then
  # Take action if $DIR exists. #
  echo "Operator is installed..."
  cd confluent-operator/
else
  mkdir confluent-operator
  cd confluent-operator/
  wget https://platform-ops-bin.s3-us-west-1.amazonaws.com/operator/confluent-operator-20190912-v0.65.1.tar.gz
  tar -xvf confluent-operator-20190912-v0.65.1.tar.gz
  rm confluent-operator-20190912-v0.65.1.tar.gz
  cp ../gcp.yaml helm/providers/
fi
cd helm/

echo "Install Confluent Operator"
#helm delete --purge operator
helm install \
-f ./providers/gcp.yaml \
--name operator \
--namespace operator \
--set operator.enabled=true \
./confluent-operator
echo "After Operator Installation: Check all pods..."
kubectl get pods -n operator
echo "Wait 20 sec...."
sleep 20

echo "Patch the Service Account so it can pull Confluent Platform images"
kubectl -n operator patch serviceaccount default -p '{"imagePullSecrets": [{"name": "confluent-docker-registry" }]}'

# BEFORE running any deployments against GKE cluster, check if cluster is running
RESULT=$(bash gcloud container clusters list | grep RUNNING)
while [ -z "${RESULT}" ]
do
  echo "Cluster not running...wait 20 seconds...and check again..."
  RESULT=$(bash gcloud container clusters list | grep RUNNING)
  sleep 20
done

echo "Install Confluent Zookeeper"
#helm delete --purge zookeeper
helm install \
-f ./providers/gcp.yaml \
--name zookeeper \
--namespace operator \
--set zookeeper.enabled=true \
./confluent-operator
echo "After Zookeeper Installation: Check all pods..."
kubectl get pods -n operator
echo "Wait 120 sec...."
sleep 120

# BEFORE running any deployments against GKE cluster, check if cluser is running
RESULT=$(bash gcloud container clusters list | grep RUNNING)
while [ -z "${RESULT}" ]
do
  echo "Cluster not running...wait 20 seconds...and check again..."
  RESULT=$(bash gcloud container clusters list | grep RUNNING)
  sleep 20
done

echo "Install Confluent Kafka"
#helm delete --purge kafka
helm install \
-f ./providers/gcp.yaml \
--name kafka \
--namespace operator \
--set kafka.enabled=true \
./confluent-operator
echo "After Kafka Broker Installation: Check all pods..."
kubectl get pods -n operator
echo "Wait 240 sec...."
sleep 240

# BEFORE running any deployments against GKE cluster, check if cluser is running
RESULT=$(bash gcloud container clusters list | grep RUNNING)
while [ -z "${RESULT}" ]
do
  echo "Cluster not running...wait 20 seconds...and check again..."
  RESULT=$(bash gcloud container clusters list | grep RUNNING)
  sleep 20
done

echo "Install Confluent Schema Registry"
#helm delete --purge schemaregistry
helm install \
-f ./providers/gcp.yaml \
--name schemaregistry \
--namespace operator \
--set schemaregistry.enabled=true \
./confluent-operator
echo "After Schema Registry Installation: Check all pods..."
kubectl get pods -n operator
echo "Wait 50 sec...."
Sleep 50

# BEFORE running any deployments against GKE cluster, check if cluser is running
RESULT=$(bash gcloud container clusters list | grep RUNNING)
while [ -z "${RESULT}" ]
do
  echo "Cluster not running...wait 20 seconds...and check again..."
  RESULT=$(bash gcloud container clusters list | grep RUNNING)
  sleep 20
done

echo "Install Confluent KSQL"
# helm delete --purge ksql
helm install \
-f ./providers/gcp.yaml \
--name ksql \
--namespace operator \
--set ksql.enabled=true \
./confluent-operator
echo "After KSQL Installation: Check all pods..."
kubectl get pods -n operator
echo "Wait 50 sec...."
Sleep 50

# BEFORE running any deployments against GKE cluster, check if cluser is running
RESULT=$(bash gcloud container clusters list | grep RUNNING)
while [ -z "${RESULT}" ]
do
  echo "Cluster not running...wait 20 seconds...and check again..."
  RESULT=$(bash gcloud container clusters list | grep RUNNING)
  sleep 20
done

echo "Install Confluent Control Center"
# helm delete --purge controlcenter
helm install \
-f ./providers/gcp.yaml \
--name controlcenter \
--namespace operator \
--set controlcenter.enabled=true \
./confluent-operator
echo "After Control Center Installation: Check all pods..."
kubectl get pods -n operator
echo "Wait 50 sec...."
Sleep 50

# BEFORE running any deployments against GKE cluster, check if cluser is running
RESULT=$(bash gcloud container clusters list | grep RUNNING)
while [ -z "${RESULT}" ]
do
  echo "Cluster not running...wait 20 seconds...and check again..."
  RESULT=$(bash gcloud container clusters list | grep RUNNING)
  sleep 20
done

echo "Create LB for Control Center"
helm upgrade -f ./providers/gcp.yaml \
 --set controlcenter.enabled=true \
 --set controlcenter.loadBalancer.enabled=true \
 --set controlcenter.loadBalancer.domain=axvy.aa.de controlcenter \
 ./confluent-operator
echo "After Load balancer Deployment for Control Center: Check all Service..."
kubectl get services -n operator
kubectl get pods -n operator
echo "Confluent Platform into GKE cluster is finished."