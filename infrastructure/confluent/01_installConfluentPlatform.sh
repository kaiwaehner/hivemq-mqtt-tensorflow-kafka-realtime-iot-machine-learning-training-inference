#!/usr/bin/env bash
set -e

# set current directory of script
MYDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

until gcloud container clusters list --region europe-west1 | grep 'RUNNING' >/dev/null 2>&1; do
    echo "kubeapi not available yet..."
    sleep 3
done

echo "Deploying prometheus..."
# Make sure the tiller change is rolled out
kubectl rollout status -n kube-system deployment tiller-deploy
# Commented next command, please do a helm repo update before executing terraform
# helm repo update

# Make upgrade idempotent by first deleting all the CRDs (the helm chart will error otherwise)
kubectl delete crd alertmanagers.monitoring.coreos.com podmonitors.monitoring.coreos.com prometheuses.monitoring.coreos.com prometheusrules.monitoring.coreos.com servicemonitors.monitoring.coreos.com 2>/dev/null || true
helm delete --purge prom 2>/dev/null || true
helm install --namespace monitoring --replace --name prom --version 6.8.1 stable/prometheus-operator --wait

echo "Deploying metrics server..."
helm upgrade --install metrics stable/metrics-server --version 2.8.4 --wait --force || true

echo "Deploying K8s dashboard..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.0.0-beta4/aio/deploy/recommended.yaml

echo "Kubernetes Dashboard token:"
gcloud config config-helper --format=json | jq -r '.credential.access_token'

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
  cp ${MYDIR}/gcp.yaml helm/providers/
fi

cd helm/

echo "Install Confluent Operator"
#helm delete --purge operator
helm install \
-f ../../gcp.yaml \
--name operator \
--namespace operator \
--set operator.enabled=true \
./confluent-operator || true
echo "After Operator Installation: Check all pods..."
kubectl get pods -n operator
kubectl rollout status deployment -n operator cc-operator
kubectl rollout status deployment -n operator cc-manager

echo "Patch the Service Account so it can pull Confluent Platform images"
kubectl -n operator patch serviceaccount default -p '{"imagePullSecrets": [{"name": "confluent-docker-registry" }]}'

echo "Install Confluent Zookeeper"
#helm delete --purge zookeeper
helm install \
-f ../../gcp.yaml \
--name zookeeper \
--namespace operator \
--set zookeeper.enabled=true \
./confluent-operator || true
echo "After Zookeeper Installation: Check all pods..."
kubectl get pods -n operator
sleep 10
kubectl rollout status sts -n operator zookeeper



echo "Install Confluent Kafka"
#helm delete --purge kafka
helm install \
-f ../../gcp.yaml \
--name kafka \
--namespace operator \
--set kafka.enabled=true \
./confluent-operator || true
echo "After Kafka Broker Installation: Check all pods..."
kubectl get pods -n operator
sleep 10
kubectl rollout status sts -n operator kafka


echo "Install Confluent Schema Registry"
#helm delete --purge schemaregistry
helm install \
-f ../../gcp.yaml \
--name schemaregistry \
--namespace operator \
--set schemaregistry.enabled=true \
./confluent-operator || true
echo "After Schema Registry Installation: Check all pods..."
kubectl get pods -n operator
sleep 10
kubectl rollout status sts -n operator schemaregistry


echo "Install Confluent KSQL"
# helm delete --purge ksql
helm install \
-f ../../gcp.yaml \
--name ksql \
--namespace operator \
--set ksql.enabled=true \
./confluent-operator || true
echo "After KSQL Installation: Check all pods..."
kubectl get pods -n operator
sleep 10
kubectl rollout status sts -n operator ksql

echo "Install Confluent Control Center"
# helm delete --purge controlcenter
helm install \
-f ../../gcp.yaml \
--name controlcenter \
--namespace operator \
--set controlcenter.enabled=true \
./confluent-operator || true
echo "After Control Center Installation: Check all pods..."
kubectl get pods -n operator
sleep 10
kubectl rollout status sts -n operator controlcenter

# TODO Build breaks if we don't wait here until all components are ready. Is there a better solution for a check?
sleep 200

echo "Create LB for KSQL"
helm upgrade -f ../../gcp.yaml \
 --set ksql.enabled=true \
 --set ksql.loadBalancer.enabled=true \
 --set ksql.loadBalancer.domain=mydevplatform.gcp.cloud ksql \
 ./confluent-operator
 kubectl rollout status sts -n operator ksql

echo "Create LB for Kafka"
helm upgrade -f ../../gcp.yaml \
 --set kafka.enabled=true \
 --set kafka.loadBalancer.enabled=true \
 --set kafka.loadBalancer.domain=mydevplatform.gcp.cloud kafka \
 ./confluent-operator
 kubectl rollout status sts -n operator kafka

echo "Create LB for Schemaregistry"
helm upgrade -f ../../gcp.yaml \
 --set schemaregistry.enabled=true \
 --set schemaregistry.loadBalancer.enabled=true \
 --set schemaregistry.loadBalancer.domain=mydevplatform.gcp.cloud schemaregistry \
 ./confluent-operator
 kubectl rollout status sts -n operator schemaregistry

echo "Create LB for Control Center"
helm upgrade -f ../../gcp.yaml \
 --set controlcenter.enabled=true \
 --set controlcenter.loadBalancer.enabled=true \
 --set controlcenter.loadBalancer.domain=mydevplatform.gcp.cloud controlcenter \
 ./confluent-operator
kubectl rollout status sts -n operator controlcenter

echo " Loadbalancers are created please wait a couple of minutes..."
sleep 60
kubectl get services -n operator | grep LoadBalancer
echo " After all external IP Adresses are seen, add your local /etc/hosts via "
echo "sudo /etc/hosts"
echo "EXTERNAL-IP  ksql.mydevplatform.gcp.cloud ksql-bootstrap-lb ksql"
echo "EXTERNAL-IP  schemaregistry.mydevplatform.gcp.cloud schemaregistry-bootstrap-lb schemaregistry"
echo "EXTERNAL-IP  controlcenter.mydevplatform.gcp.cloud controlcenter controlcenter-bootstrap-lb"
echo "EXTERNAL-IP  b0.mydevplatform.gcp.cloud kafka-0-lb kafka-0 b0"
echo "EXTERNAL-IP  b1.mydevplatform.gcp.cloud kafka-1-lb kafka-1 b1"
echo "EXTERNAL-IP  b2.mydevplatform.gcp.cloud kafka-2-lb kafka-2 b2"
echo "EXTERNAL-IP  kafka.mydevplatform.gcp.cloud kafka-bootstrap-lb kafka"
kubectl get services -n operator | grep LoadBalancer
sleep 10

echo "After Load balancer Deployments: Check all Confluent Services..."
kubectl get services -n operator
kubectl get pods -n operator
echo "Confluent Platform into GKE cluster is finished."

echo "Create Topics on Confluent Platform for Test Generator"
# Create Kafka Property file in all pods
kubectl rollout status sts -n operator kafka
echo "deploy kafka.property file into all brokers"
kubectl -n operator exec -it kafka-0 -- bash -c "printf \"bootstrap.servers=kafka:9071\nsasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule required username=\"test\" password=\"test123\";\nsasl.mechanism=PLAIN\nsecurity.protocol=SASL_PLAINTEXT\" > /opt/kafka.properties"
kubectl -n operator exec -it kafka-1 -- bash -c "printf \"bootstrap.servers=kafka:9071\nsasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule required username=\"test\" password=\"test123\";\nsasl.mechanism=PLAIN\nsecurity.protocol=SASL_PLAINTEXT\" > /opt/kafka.properties"
kubectl -n operator exec -it kafka-2 -- bash -c "printf \"bootstrap.servers=kafka:9071\nsasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule required username=\"test\" password=\"test123\";\nsasl.mechanism=PLAIN\nsecurity.protocol=SASL_PLAINTEXT\" > /opt/kafka.properties"

# Create Topic sensor-data
echo "Create Topic sensor-data"
kubectl -n operator exec -it kafka-0 -- bash -c "kafka-topics --bootstrap-server kafka:9071 --command-config kafka.properties --create --topic sensor-data --replication-factor 3 --partitions 10 --config retention.ms=7200000"
echo "Create Topic model-predictions"
kubectl -n operator exec -it kafka-0 -- bash -c "kafka-topics --bootstrap-server kafka:9071 --command-config kafka.properties --create --topic model-predictions --replication-factor 3 --partitions 10 --config retention.ms=7200000"
# list Topics
kubectl -n operator exec -it kafka-0 -- bash -c "kafka-topics --bootstrap-server kafka:9071 --list --command-config kafka.properties"
# Create STREAMS
# CURL CREATE
echo "CREATE STREAM SENSOR_DATA_S"
kubectl -n operator exec -it ksql-0 -- bash -c "curl -X \"POST\" \"http://ksql:8088/ksql\" \
     -H \"Content-Type: application/vnd.ksql.v1+json; charset=utf-8\" \
     -d $'{
  \"ksql\": \"CREATE STREAM SENSOR_DATA_S (coolant_temp DOUBLE, intake_air_temp DOUBLE, intake_air_flow_speed DOUBLE, battery_percentage DOUBLE, battery_voltage DOUBLE, current_draw DOUBLE, speed DOUBLE, engine_vibration_amplitude DOUBLE, throttle_pos DOUBLE, tire_pressure_1_1 BIGINT, tire_pressure_1_2 BIGINT, tire_pressure_2_1 BIGINT, tire_pressure_2_2 BIGINT, accelerometer_1_1_value DOUBLE, accelerometer_1_2_value DOUBLE, accelerometer_2_1_value DOUBLE, accelerometer_2_2_value DOUBLE, control_unit_firmware BIGINT, coolantTemp DOUBLE, intakeAirTemp DOUBLE, intakeAirFlowSpeed DOUBLE, batteryPercentage DOUBLE, batteryVoltage DOUBLE, currentDraw DOUBLE, engineVibrationAmplitude DOUBLE, throttlePos DOUBLE, tirePressure11 BIGINT, tirePressure12 BIGINT, tirePressure21 BIGINT, tirePressure22 BIGINT, accelerometer11Value DOUBLE, accelerometer12Value DOUBLE, accelerometer21Value DOUBLE, accelerometer22Value DOUBLE, controlUnitFirmware BIGINT) WITH (kafka_topic=\'sensor-data\', value_format=\'JSON\');\",
  \"streamsProperties\": {}
}'"
echo "CREATE STREAM SENSOR_DATA_S_AVRO"
kubectl -n operator exec -it ksql-0 -- bash -c "curl -X \"POST\" \"http://ksql:8088/ksql\" \
     -H \"Content-Type: application/vnd.ksql.v1+json; charset=utf-8\" \
     -d $'{
  \"ksql\": \"CREATE STREAM SENSOR_DATA_S_AVRO WITH (VALUE_FORMAT=\'AVRO\') AS SELECT * FROM SENSOR_DATA_S;\",
  \"streamsProperties\": {}
}'"
echo "CREATE STREAM SENSOR_DATA_S_AVRO_REKEY"
kubectl -n operator exec -it ksql-0 -- bash -c "curl -X \"POST\" \"http://ksql:8088/ksql\" \
     -H \"Content-Type: application/vnd.ksql.v1+json; charset=utf-8\" \
     -d $'{
  \"ksql\": \"CREATE STREAM SENSOR_DATA_S_AVRO_REKEY AS SELECT ROWKEY as CAR, * FROM SENSOR_DATA_S_AVRO PARTITION BY CAR;\",
  \"streamsProperties\": {}
}'"
echo "CREATE TABLE SENSOR_DATA_EVENTS_PER_5MIN_T"
kubectl -n operator exec -it ksql-0 -- bash -c "curl -X \"POST\" \"http://ksql:8088/ksql\" \
     -H \"Content-Type: application/vnd.ksql.v1+json; charset=utf-8\" \
     -d $'{
  \"ksql\": \"CREATE TABLE SENSOR_DATA_EVENTS_PER_5MIN_T AS SELECT car, count(*) as event_count FROM SENSOR_DATA_S_AVRO_REKEY WINDOW TUMBLING (SIZE 5 MINUTE) GROUP BY car;\",
  \"streamsProperties\": {}
}'"
echo "####################################"
echo "## Confluent Deployment finshed ####"
echo "####################################"
