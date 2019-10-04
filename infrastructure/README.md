# Infrastructure deployment

Components (in order of deployment):
- [terraform-gcp](terraform-gcp): A terraform script for setting up a basic Kubernetes Cluster on GKE and provisioning it with Tiller and the Prometheus operator.
- And confluent operator and platform, a small Confluent Cluster is setup, 1 Zookeeper, 1 Kafka Broker, 1 Schema Registry, 1 KSQL-Server, 1 Control Center
- [hivemq](hivemq): Scripting for creating the HiveMQ operator on K8s and deploying a basic cluster with the Kafka extension installed as well as a monitoring dashboard for use with the Prometheus operator.
- [test-generator](test-generator): Scripting for running the load generator which will simulate the car clients, publishing sensor data.