# Infrastructure deployment

Components (in order of deployment):
- [terraform-gcp](terraform-gcp): A terraform script for setting up a basic Kubernetes Cluster on GKE and provisioning it with Tiller .
- [confluent](confluent): The Prometheus operator and confluent operator. A small Confluent Cluster is setup, 3 Zookeeper, 3 Kafka Broker, 1 Schema Registry, 1 KSQL-Server, 1 Control Center
- [hivemq](hivemq): Scripting for creating the HiveMQ operator on K8s and deploying a basic cluster with the Kafka extension installed as well as a monitoring dashboard for use with the Prometheus operator.
- [test-generator](test-generator): Scripting for running the load generator which will simulate the car clients, publishing sensor data.