# Infrastructure deployment

Components (in order of deployment):
- [terraform-gcp](terraform-gcp): A terraform script for setting up a basic Kubernetes Cluster on GKE and provisioning it with Tiller and the Prometheus operator.
- TODO confluent operator and platform, this should be set up first
- [hivemq](hivemq): Scripting for creating the HiveMQ operator on K8s and deploying a basic cluster with the Kafka extension installed as well as a monitoring dashboard for use with the Prometheus operator.
- [test-generator](test-generator): Scripting for running the load generator which will simulate the car clients, publishing sensor data.