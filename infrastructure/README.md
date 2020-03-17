# Quick Start Guide

Let's first understand the used components in this demo. Then install the required CLI tools. Finally setup the demo with just two commands.

## Installed Components

The following components will be installed (deployment in this order):

1) [terraform-gcp](terraform-gcp): A terraform script for setting up and provisioning a basic Kubernetes Cluster on GKE. This terraform setup will also run the [01_installConfluentPlatform.sh](confluent/01_installConfluentPlatform.sh) from 2) and afterwards run the [setup_evaluation.sh](hivemq/setup_evaluation.sh). So after successful execution of `terraform apply`, a GKE cluster with Confluent Platform, HiveMQ and monitoring (Prometheus, Grafana) is running.
2) [confluent](confluent): Script for deploying Confluent Operator and Prometheus operator into GKE. A Confluent Cluster is setup with 3 ZooKeeper, 3 Kafka Broker, 2 Schema Registry, 2 KSQL-Server, 1 Control Center.
3) [hivemq](hivemq): Script for deploying the HiveMQ Operator on GKE and deploying a basic cluster with the HiveMQ Kafka extension installed as well as a monitoring dashboard for use with the Prometheus operator.
4) [test-generator](test-generator): Script for running the load generator which will simulate the car clients, publishing sensor data.
5) [Python Application for Streaming ML](../python-scripts/README.md): Deployment of a container which does streaming model training and inference using Kafka and TensorFlow IO.  

## Requirements

The following components are required on your laptop to provison and install the demo (ideally in the tested versions, otherwise, you might have to fix errors):

* [jq](https://stedolan.github.io/jq/): Lightweight and flexible command-line JSON processor,  e.g. `brew install jq`
* [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/): Kubernetes CLI to deploy applications, inspect and manage cluster resources,  e.g. `brew install kubernetes-cli` (tested with 1.16.0)
* [Helm](https://helm.sh/): Helps you manage Kubernetes applications - Helm Charts help you define, install, and upgrade even the most complex Kubernetes application, e.g. `brew install kubernetes-helm` (tested with 3.0.1). Please note that we already use Helm 3 (no Tiller!) instead of the painful Helm 2.x with Tiller.
* [terraform (0.12)](https://www.terraform.io/downloads.html): Enables you to safely and predictably create, change, and improve infrastructure (infrastructure independent, but currently only implemented GCP setup), e.g. `brew install terraform`
* [gcloud](https://cloud.google.com/sdk/docs/quickstart-macos): Tool that provides the primary CLI to Google Cloud Platform, e.g.  (always run `gcloud init` first)
* `wget`

Make sure to have up-to-date versions (see the tested versions above). For instance, an older version of helm or kubectl CLI did not work well and threw (sometimes confusing) exceptions.

The setup is tested on Mac OS X. We used HiveMQ 4.2.2 and Confluent Platform 5.4 (with Apache Kafka 2.4).

## Configure GCP Account and Project

1) Create account.json in `terraform-gcp` directory. You will have to create a [service account on GCP](https://cloud.google.com/iam/docs/creating-managing-service-account-keys) first if you don't have one. Choose the right roles and enable google API. If something is missing terraform let you know. If you already have a Service Account, you can go to your `GCP Console in the web browser --> IAM & admin --> Service Accounts --> Create or Select Key --> Download .json file --> Rename to account.json --> Copy to terraform-gcp directory`
2) Choose a `GCP project` or create a new one on your cloud console. Terraform will prompt you to specify your project name when applying.
3) Change the file `variables.tf` in terraform-gcp folder. Here you will find entries which have to fit with your environment. You have to set the right region, the node count and preemptible_nodes (cheaper). Mandatory change is `project`: Add your GCP project name or enter the correct GCP project name after terraform apply (it will ask). The others can stay default.

## Usage

1. Go to `terraform-gcp` directory
    * Run `helm repo update` to refresh the repo of Helm first.
    * Run `terraform init` (initializes the setup - only needed to be executed once on your laptop, not every time you want to re-create the infrastructure)
    * Configure `gcloud` with the project you wish to use:
      * `gcloud config set project <name>`
    * Add the `helm` stable repository
      * `helm repo add stable https://kubernetes-charts.storage.googleapis.com`
    * Run `terraform plan` (plans the setup)
    * Run `terraform apply` (sets up all required infrastructure on GCP - can take 10-20 minutes) - NOTE: If you get any "weird error messages" while the build is running, just execute the command again. This sometimes happens if the connectivity to GCP is bad or if any other cloud issues happen.
    * For a Confluent Control Center, KSQL, Schem Registry, REST Proxy and Kafka we use Google Load Balancers. Please change your /etc/hosts file as mentioned in the documentation [go to confluent](confluent/README.md)
2. Go to `test-generator` directory
    * Run `./run_scenario_evaluation.sh` (currently configured to send a fixed amount of messages - restart to produce more messages). You have to be placed in the correct folder `test-generator`
3. Monitoring and interactive queries
    * Go to [confluent](confluent) directory
    * Use the hints to connect Confluent Control Center, Grafana, Prometheus for monitoring or working with KSQL CLI for interactive queries
4. You can also connect to Grafana and observe Cluster and application-level metrics for HiveMQ and the Device Simulator: `kubectl port-forward -n monitoring service/prom-grafana 3000:service`
5. Streaming Model Training and Inference with Kafka and TensorFlow IO: This includes seperated steps which are explained here: [python-scripts/README.md](../python-scripts/README.md).

For more details about the demo, UIs, customization of the setup, monitoring, etc., please go to the subfolders of the components: [terraform-gcp](terraform-gcp), [confluent](confluent), [hivemq](hivemq), [test-generator](test-generator), [tensorflow-io](python-scripts/README.md).

## Deletion of Demo Infrastructure

When done with the demo, go to `terraform-gcp` directory and run `terraform destroy` to stop and remove the created Kubernetes infrastructure. 

`Doublecheck the 'disks' in your GCP console`. If you had some errors, the script might not be able to delete all SDDs!

### Open Source and License Requirements

The *default configuration runs without any need for additional licenses*. We use open source Apache Kafka and open source HiveMQ. We use additional Enterprise components which are included as trial version.

Confluent components automatically include a 30 day trial license (not allowed for production usage). This license can be used without any limitations regarding scalability. You can see in Confluent Control Center how many days you have left. After 30 days, you need to contact a Confluent person.

HiveMQ does not require a test license. However, be aware that the open source version is limited to 25 device connections. If you wish to run the test at large scale (e.g. 100k MQTT clients), please go to [hivemq](hivemq) to get a license, add the license as described there, and run `./setup.sh` to update the cluster to use the license.

If you have any questions about licensing, please contact the main contributors of this Github project or an account manager of Confluent respectively HiveMQ.
