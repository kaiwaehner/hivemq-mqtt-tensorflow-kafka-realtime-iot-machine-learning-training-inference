# Create GCP K8s

Applying this terraform deployment will create a K8s cluster with the following deployed:

* Prometheus
* K2s Deasboard
* Confluent Platform
* HiveMQ

## Requirements

The following components are required:

* jq: e.g. 'brew install jq'
* [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/): e.g. brew install kubernetes-cli (tested with 1.16.0)
* helm 3: e.g. `brew reinstall helm` (tested with 3.0.2)
  see [Migrate from Helm 2 to 3](https://helm.sh/blog/migrate-from-helm-v2-to-helm-v3/), [install helm 3.0.2](https://helm.sh/docs/intro/install/) and [Helm 2 to Helm 3 Upgrade](https://runkiss.blogspot.com/2019/12/helm-2-to-helm-3-updates.html). In most cases, you just need to install Helm 3 and then add the stable Helm Repo: `helm repo add stable https://kubernetes-charts.storage.googleapis.com/`
* [terraform (0.12.19)](https://www.terraform.io/downloads.html): e.g. brew install terraform
* [GCloud CLI v. 277.0.0](https://cloud.google.com/sdk/docs/quickstart-macos) (run `gcloud init` first)

The setup is tested on Mac OS X.

Make sure to have updated versions, e.g. an older version of helm did not work.

## Quick Start

1. Ensure account.json is in this folder. You will have to [create a service account](https://cloud.google.com/iam/docs/creating-managing-service-account-keys) on GCP first. Choose the right roles and enable google API. If something is missing terraform let you know.
My service Account has the following roles

* Compute Admin
* Compute Network Admin
* Compute Storage Admin
* Kubernetes Engine Admin
* Kubernetes Engine Cluster Admin
* Kubernetes Engine Developer
* Create Service Accounts
* Delete Service Accounts
* Service Account Key Admin
* Service Account User
* Storage Admin

2. Choose a GCP project or create a new one on your cloud console. Terraform will prompt you to specify your project name when applying.

3. Before starting terraform: change the file [variables.tf](variables.tf). Here you will find entries which have to fit with your environment. You have to set the right region, the node count and preemptible_nodes.

4. First Step: Create the environment in Google Cloud: Create the GKE Cluster (you have to enter the project name)
```bash
# set the right project
gcloud init
# create the GKE Cluster
terraform init
terraform plan
terraform apply
```

## Destroy Infrastructure

* Run 'terraform destroy' to stop and remove the created Kubernetes infrastructure
```bash
# destroy the GKE Cluster, enter the project name
terraform destroy
```
HINT:
* Double check in Google Cloud Console if everything is destroyed: 
  Kubernetes Engine, Compute Engine and under Compute Engine please check also Disks and Instance Groups.
* It seems to be that the ssd Disk from Confluent will not be deleted, so please delete manually in your google console UI.
* If the destroy takes more than 10 minutes then terraform is throwing an error. 
  Then you have to destory manually via Google Cloud Console.
  * delete Service accounts
    gcloud iam service-accounts delete car-demo-storage-account@projectname.iam.gserviceaccount.com
  * delete storage bucket in console car-demo-tensorflow-models_projectname
  * delete services in Kubernetes Engibe Console under Service [check 02_deleteConfluentPlatform.sh](../confluent/02_deleteConfluentPlatform.sh)
  * delete instance groups in Compute Engine
  * delete not attached Disks in Compute Engine
  * Delete cluster in Kubernetes Engine
