# GCP K8s with HiveMQ operator

Applying this terraform deployment will create a K8s cluster with the following deployed:

* Tiller
* Prometheus Operator & Prometheus
* metrics-server for Kubernetes metrics in dashboard
* K8s dashboard (use `gcloud config config-helper --format=json | jq -r ‘.credential.access_token’` for login)
* Confluent Operator
* Confluent Cluster running in one Zone with only one replica of each component

It will also set your kubectl context to the gcp cluster automatically. (To undo this, see `kubectl config get-contexts` and switch to your preferred context)

# Requirements
The following components are required:

* jq: e.g. 'brew install jq'
* [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/): e.g. brew install kubernetes-cli (tested with 1.16.0)
* helm: e.g. `brew install kubernetes-helm` (tested with 2.14.3)
* [terraform (0.12)](https://www.terraform.io/downloads.html): e.g. brew install terraform
* [GCloud CLI](https://cloud.google.com/sdk/docs/quickstart-macos) (run `gcloud init` first)

The setup is tested on Mac OS X.

Make sure to have updated versions, e.g. an older version of helm did not work.

# Quick Start

1. Ensure account.json is in this folder. You will have to [create a service account](https://cloud.google.com/iam/docs/creating-managing-service-account-keys) on GCP first. Choose the right roles and enable google API. If something is missing terraform let you know.

2. Choose a GCP project or create a new one on your cloud console. Terraform will prompt you to specify your project name when applying.

3. Before starting terraform: update the file [variables.tf](variables.tf). Here you will find entries which have to fit with your environment.
During the terraform deployment the Confluent Operator (Version v0.65.1) will be downloaded ([The logic is in setup.sh](setup.sh)). If there is newer version please update the link in setup.sh.
We use Google Cloud Confluent Operator template [gcp.yaml](gcp.yaml) for installing the Confluent Platform into GKE created K8s cluster. The template is copied into the new downloaded Confluent Operator Helm-Chart-Producer directory. Please change this file for your setup. We use Cloud Region=europe-west1 and Zone=europe-west1-b and replicas=1.
The script [setup.sh](setup.sh) will create all components into GKE cluster.

4. Create the environment in Google Cloud
```bash
terraform init
terraform apply
```

# Kubernetes Dashboard

* Run `kubectl proxy &`
* Go to [K8s dashboard](http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/)
* Login to K8s dashboard using The token from `gcloud config config-helper --format=json | jq -r '.credential.access_token'`

# Grafana Dashboards

* Forward local port to Grafana service: `kubectl port-forward service/prom-grafana 3000:service`
* Go to [localhost:3000](http://localhost:3000) (login: admin, prom-operator)
* Dashboards will be deployed automatically (if they are not visible, bounce the deployment by deleting the current Grafana pod. It will reload the ConfigMaps after it restarts.)

# Confluent Platform
Follow the examples of how to use and play with Confluent Platform on GCP K8s on [Confluent docs](https://docs.confluent.io/current/installation/operator/co-deployment.html)

# Destroy Infrastructure

* Run 'terraform destroy' to stop and remove the created Kubernetes infrastructure