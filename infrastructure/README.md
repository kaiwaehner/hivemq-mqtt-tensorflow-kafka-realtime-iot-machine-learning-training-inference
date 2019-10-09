# Quick Start Guide

Let's first understand the used components in this demo. Then install the required CLI tools. Finally setup the demo with just two commands.

## Installed Components

The following components will be installed (deployment in this order):

1) [terraform-gcp](terraform-gcp): A terraform script for setting up a basic Kubernetes Cluster on GKE and provisioning it with Tiller.
2) [confluent](confluent): The Prometheus operator and confluent operator. A small Confluent Cluster is setup, 3 Zookeeper, 3 Kafka Broker, 1 Schema Registry, 1 KSQL-Server, 1 Control Center
3) [hivemq](hivemq): Scripting for creating the HiveMQ operator on K8s and deploying a basic cluster with the Kafka extension installed as well as a monitoring dashboard for use with the Prometheus operator.
4) [test-generator](test-generator): Scripting for running the load generator which will simulate the car clients, publishing sensor data.

## Requirements

The following components are required on your laptop to provison and install the demo:

* [jq](https://stedolan.github.io/jq/): Lightweight and flexible command-line JSON processor,  e.g. `brew install jq`
* [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/): Kubernetes CLI to deploy applications, inspect and manage cluster resources,  e.g. `brew install kubernetes-cli` (tested with 1.16.0)
* Helm: Helps you manage Kubernetes applications - Helm Charts help you define, install, and upgrade even the most complex Kubernetes application, e.g. `brew install kubernetes-helm` (tested with 2.14.3)
* [terraform (0.12)](https://www.terraform.io/downloads.html): Enables you to safely and predictably create, change, and improve infrastructure (infrastructure independent, but currently only implemented GCP setup), e.g. `brew install terraform`
* [gcloud](https://cloud.google.com/sdk/docs/quickstart-macos): Tool that provides the primary CLI to Google Cloud Platform, e.g.  (always run `gcloud init` first)

The setup is tested on Mac OS X.

Make sure to have updated versions, e.g. an older version of helm did not work well. Also see the tested version above.

## Configure GCP Account and Project

1) Create account.json in `terraform-gcp` directory. You will have to create a [service account on GCP](https://cloud.google.com/iam/docs/creating-managing-service-account-keys) first if you don't have one. Choose the right roles and enable google API. If something is missing terraform let you know. If you already have a Service Account, you can go to your `GCP Console in the web browser --> IAM & admin --> Service Accounts --> Create or Select Key --> Download .json file --> Rename to account.json --> Copy to terraform-gcp directory`
2) Choose a GCP project or create a new one on your cloud console. Terraform will prompt you to specify your project name when applying.
3) Change the file `variables.tf`. Here you will find entries which have to fit with your environment. You have to set the right region, the node count and preemptible_nodes. Mandatory change is `project`: Add your GCP project name. The others can stay default.

## Usage

1. Go to `terraform-gcp` directory
2. Run `terraform plan` (plans the setup)
3. Run `terraform apply` (sets up all required infrastructure on GCP)
4. Go to `test-generator` directory
5. Run `./run_scenario_evaluation.sh` (currently configured to send a fixed amount of messages - restart to produce more messages)
6. When done with the demo, go to `terraform-gcp` directory and run `terraform destroy` to stop and remove the created Kubernetes infrastructure

For more details about the demo, UIs, customization, etc., please go to the subfolders of the components: [terraform-gcp](terraform-gcp), [confluent](confluent), [hivemq](hivemq), [test-generator](test-generator).

### Open Source and License Requirements

The default configuration runs without any need for additional licenses. We use open source Apache Kafka, open source HiveMQ, and additional Enterprise components which are included as trial version.

Confluent components automatically include a 30 day trial license (not allowed for production usage). This license can be used without any limitations regarding scalability. You can see in Confluent Control Center how many days you have left. After 30 days, you also need to contact a Confluent person.

HiveMQ does not require a test license. However, be aware that the open source version is limited to 25 parallel connections. If you wish to run the test at large scale (e.g. 100k MQTT clients),please go to [hivemq](hivemq) to get a license, add the license as described there, and run `./setup.sh` to update the cluster to use the license.

If you have any questions about licensing, please contact the main contributors of this Github project or an account manager of Hive MQ or Confluent.

## TODOs - Not implemented in MVP

Planned until end of October 2019:

    2a) TODO KSQL Client (for preprocessing)
    2b) TODO TensorFlow I/O Clinet (for model training)
    2c) TODO Kafka Client (for model predictions)
