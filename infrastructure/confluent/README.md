# Install Confluent Operator and setup a Confluent Platform Cluster

Applying this  deployment will create in the existing K8s cluster (see [Create GKE](../terraform-gcp/README.md)) with the following deployed:

* Prometheus Operator & Prometheus
* metrics-server for Kubernetes metrics in dashboard
* K8s dashboard (use `gcloud config config-helper --format=json | jq -r ‘.credential.access_token’` for login)
* Confluent Operator
* Confluent Cluster running in Multi-Zone with with replica of 3 for Zookeeper and Kafka Broker

It will also set your kubectl context to the gcp cluster automatically. (To undo this, see `kubectl config get-contexts` and switch to your preferred context)

# Requirements
The following components are required:

* jq: e.g. 'brew install jq'
* [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/): e.g. brew install kubernetes-cli (tested with 1.16.0)
* helm: e.g. `brew install kubernetes-helm` (tested with 2.14.3)
* [GCloud CLI](https://cloud.google.com/sdk/docs/quickstart-macos) (run `gcloud init` first)

The setup is tested on Mac OS X.

Make sure to have updated versions, e.g. an older version of helm did not work.

# Quick Start

1. Ensure your GKE cluster is running:
```bash
gcloud container clusters list
```
2. During the script execution the Confluent Operator (Version v0.65.1) will be downloaded ([The logic is in 01_installConfluentPlatform.sh](01_installConfluentPlatform.sh)). If there is newer version please update the link in 01_installConfluentPlatform.sh.
We use Google Cloud Confluent Operator template [gcp.yaml](gcp.yaml) for installing the Confluent Platform into GKE created K8s cluster. The template is copied into the new downloaded Confluent Operator Helm-Chart-Producer directory(see confluent-operator/helm/provider on your local disk). Please change this file [gcp.yaml](gcp.yaml) for your setup. We use Cloud Region=europe-west1 and Zones=europe-west1-b, europe-west1-c, europe-west1-d. The replicas for Kafka Broker and Zookeeper are set to 3 all other replicas=1.
The following setup will be provisioned:
![GKE cluster deployed pods](images/gke_cluster.png)
If the GKE cluster is up and running execute the script [01_installConfluentPlatform.sh](01_installConfluentPlatform.sh) manually.
3. Install the Prometheus and Confluent Operator and setup the Confluent Platform in GKE 
It is really important that the GKE cluster is up and running. Sometimes it takes a while, because GKE doing automatic upgrades. First you create the GKE cluster with terraform (see [Create GKE](../terraform-gcp/README.md)) and then execute the deployment of the Confluent Platform in a second step:
```bash
# Deploy prometheus and Confluent Operator and install Confluent Platform
./01_installConfluentPlatform.sh
```
After the script execution please check again if Confluent Platform cluster is running:
```bash
kubectl get pods -n operator
# Output should look like this
NAME                          READY   STATUS    RESTARTS   AGE
cc-manager-5c8894687d-j6lms   1/1     Running   1          11m
cc-operator-9648c4f8d-w48v8   1/1     Running   0          11m
controlcenter-0               1/1     Running   0          3m10s
kafka-0                       1/1     Running   0          8m53s
kafka-1                       1/1     Running   0          7m31s
kafka-2                       1/1     Running   0          6m6s
ksql-0                        1/1     Running   0          6m
schemaregistry-0              1/1     Running   1          6m53s
zookeeper-0                   1/1     Running   0          10m
zookeeper-1                   1/1     Running   0          10m
zookeeper-2                   1/1     Running   0          10m
```
# Test Confluent Platform on GKE
Login into kafka-0 Broker:
```bash
kubectl -n operator exec -it kafka-0 bash
```
Generate Config file:
```bash
cat << EOF > kafka.properties
bootstrap.servers=kafka:9071
sasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule required username="test" password="test123";
sasl.mechanism=PLAIN
security.protocol=SASL_PLAINTEXT
EOF
```
Query the bootstrap server
```bash
kafka-broker-api-versions --command-config kafka.properties --bootstrap-server kafka:9071
```
Playing with KSQL cli go into the KSQL Server:
```bash
kubectl -n operator exec -it ksql-0 bash
ksql
ksql> list topics;
```
To get Access to Control Conter check the EXTERNAL-IP and use your browser:
```bash
kubectl get services -n operator
# output
NAME                         TYPE           CLUSTER-IP      EXTERNAL-IP      PORT(S)                                     
...
controlcenter-bootstrap-lb   LoadBalancer   10.39.252.125   35.195.132.239   9021:30878/TCP 
```
Use your browser and go to http://35.195.132.239:9021 enter the Username=admin and Password=Developer1
Here you can use also KSQL.

## external Access to your Confluent Plaform
Please follow the Confluent documentation [External Access](https://docs.confluent.io/current/installation/operator/co-endpoints.html#co-loadbalancer-kafka). At the end you have to enable the loadblancer settings in gcp.yaml file.

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

# Destroy Confluent Platform from GKE

* Run the script 02_deleteConfluentPlatform.sh to delete the Confluent Platform from GKE
```bash
./02_deleteConfluentPlatform.sh
#check if everything is deleted
kubectl get services -n operator
kubectl get pods -n operator
```
