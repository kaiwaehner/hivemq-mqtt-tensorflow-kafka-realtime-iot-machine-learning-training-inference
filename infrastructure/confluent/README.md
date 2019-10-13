# Install Confluent Operator and setup a Confluent Platform Cluster

If you did run already `terraform apply` in [terraform-gcp](../terraform-gcp/) then you do not need to install Confluent Platform anymore. Please [Go to Test Confluent Platform on GKE](#test-confluent-platform-on-gke)

If you run your own cluster, please continue:
Applying this  deployment will create in your existing K8s cluster (see [Create GKE](../terraform-gcp/README.md)) the following objects:

* Prometheus Operator
* metrics-server for Kubernetes metrics in dashboard
* K8s dashboard (use `gcloud config config-helper --format=json | jq -r ‘.credential.access_token’` for login)
* Confluent Operator
* Confluent Cluster running in Multi-Zone with with replica of 3 for Zookeeper and Kafka Broker

It will also set your kubectl context to the gcp cluster automatically. (To undo this, see `kubectl config get-contexts` and switch to your preferred context)

## Quick Start

1. Ensure your GKE cluster is running:

```bash
gcloud container clusters list
```

2. During the script execution the Confluent Operator (Version v0.65.1) will be downloaded ([The logic is in 01_installConfluentPlatform.sh](01_installConfluentPlatform.sh)). If there is newer Confluent Operator version please update the link in 01_installConfluentPlatform.sh.
We use Google Cloud Confluent Operator template [gcp.yaml](gcp.yaml) for installing the Confluent Platform into GKE created K8s cluster. The template is copied into the new downloaded Confluent Operator Helm-Chart-Producer directory(see confluent-operator/helm/provider on your local disk). Please change this file [gcp.yaml](gcp.yaml) for your setup. We use Cloud Region=europe-west1 and Zones=europe-west1-b, europe-west1-c, europe-west1-d. The replicas for Kafka Broker and Zookeeper are set to 3 all other replicas=1.
The following setup will be provisioned:
![GKE cluster deployed pods](images/gke_cluster.png)
If the GKE cluster is up and running execute the script [01_installConfluentPlatform.sh](01_installConfluentPlatform.sh) manually.
3. Iinstall the Prometheus and Confluent Operator and setup the Confluent Platform in GKE 
It is really important that the GKE cluster is up and running. Sometimes it takes a while, because GKE doing automatic upgrades. First you create your own GKE cluster or used our terraform (see [Create GKE](../terraform-gcp/README.md)): Please execute this script only if you deployed your own cluster, if your execute our terraform then you do not need to execute the following script.
Install Confluent Platform in a second step:
```bash
# Deploy prometheus and Confluent Operator and install Confluent Platform
./01_installConfluentPlatform.sh
```

### Test Confluent Cluster

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
#### Access the Pods directly
Access the pod into broker kafka-0:

```bash
kubectl -n operator exec -it kafka-0 bash
```
All Kafka brokers should have a config file like the following:
```bash
cat kafka.properties
bootstrap.servers=kafka:9071
sasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule required username="test" password="test123";
sasl.mechanism=PLAIN
security.protocol=SASL_PLAINTEXT
```
Query the bootstrap server
```bash
kafka-broker-api-versions --command-config kafka.properties --bootstrap-server kafka:9071
```

#### Test KSQL (Data Analysis and Processing)

Go into the KSQL Server and play around with KSQL CLI:

```bash
kubectl -n operator exec -it ksql-0 bash
$ ksql
ksql> list topics;
ksql> PRINT 'sensor-data' FROM BEGINNING;
ksql> list streams;
ksql> list tables;
```
### external Access to the Confluent Platform running in GKE
  Two possibilities to configure external access:
    1. do port forwarding to your local machine
    2. create external loadbalancers
The `terraform apply (with 01_installConfluentPlatform.sh` created a couple of Google Loadbalancers already, so 2. is already implemented. If you do want to save money, then please go with 1.

#### 1. Prot Forwarding
First check ports where your confluent components listining to:
```
# control center
kubectl get pods controlcenter-0 -n operator --template='{{(index (index .spec.containers 0).ports 0).containerPort}}{{"\n"}}'
# ksql
kubectl get pods ksql-0 -n operator --template='{{(index (index .spec.containers 0).ports 0).containerPort}}{{"\n"}}'
# Schema Registry
kubectl get pods schema-registry-0 -n operator --template='{{(index (index .spec.containers 0).ports 0).containerPort}}{{"\n"}}'
# Kafka
kubectl get pods kafka-0 -n operator --template='{{(index (index .spec.containers 0).ports 0).containerPort}}{{"\n"}}'
```
You can do for each Confluent component create one port-fowarding, e.g. Control Center:
```
# Port Forward Control Center
kubectl port-forward controlcenter-0 -n operator 7000:9021
```
Now, you can open your brower and run the control center locally on Port 7000 [Control Center](http://localhost:7000)). Please enter Username=admin and Password=Developer1

If you want to forward multiple ports locally then use an utility. E.g. kubefwd;
```
# make sure context is set
kubectl config current-context
# install kubefwd on macos
brew install txn2/tap/kubefwd
brew upgrade kubefwd
# foward all services for -n operator
sudo kubefwd svc -n operator
```
kubefwd is generating for all k8s services an Port forwarding and add in /etc/hosts the correct hostname.

#### 2. External Loadblancer
The second possibiliy is to create for each Confluent Component an external Loadbalancer in GKE. What we did with the `terraform apply`.
For this we can use the Confluent Operator and tell k8s to add a loadbalancer
```
cd infrastructure/terraform-gcp/confluent-operator/helm/
echo "Create LB for Kafka"
helm upgrade -f ./providers/gcp.yaml \
 --set kafka.enabled=true \
 --set kafka.loadBalancer.enabled=true \
 --set kafka.loadBalancer.domain=mydevplatform.gcp.cloud kafka \
 ./confluent-operator
echo "Create LB for KSQL"
helm upgrade -f ./providers/gcp.yaml \
 --set ksql.enabled=true \
 --set ksql.loadBalancer.enabled=true \
 --set ksql.loadBalancer.domain=mydevplatform.gcp.cloud ksql \
 ./confluent-operator
echo "Create LB for SchemaRegistry"
helm upgrade -f ./providers/gcp.yaml \
 --set schemaregistry.enabled=true \
 --set schemaregistry.loadBalancer.enabled=true \
 --set schemaregistry.loadBalancer.domain=mydevplatform.gcp.cloud schemaregistry \
 ./confluent-operator
echo "Create LB for Control Center"
helm upgrade -f ./providers/gcp.yaml \
 --set controlcenter.enabled=true \
 --set controlcenter.loadBalancer.enabled=true \
 --set controlcenter.loadBalancer.domain=mydevplatform.gcp.cloud controlcenter \
 ./confluent-operator
```
Because we do not want to buy a domain `mydevplatform.gcp.cloud`we have to add the IPs into our /etc/hosts file, so that we can reach the components.
First get the external IP adresses of the load balancer:
```
kubectl get services -n operator | grep LoadBalancer
```
Then edit the /etc/hosts file and add the new IPs with hostnames:
```
sudo vi /etc/hosts
# add with your IPs
EXTERNALIP-OF-KSQL    ksql.mydevplatform.gcp.cloud ksql-bootstrap-lb ksql
EXTERNALIP-OF-SR      schemaregistry.mydevplatform.gcp.cloud schemaregistry-bootstrap-lb schemaregistry
EXTERNALIP-OF-C3      controlcenter.mydevplatform.gcp.cloud controlcenter controlcenter-bootstrap-lb
EXTERNALIP-OF-KB0     b0.mydevplatform.gcp.cloud kafka-0-lb kafka-0 b0
EXTERNALIP-OF-KB1     b1.mydevplatform.gcp.cloud kafka-1-lb kafka-1 b1
EXTERNALIP-OF-KB2     b2.mydevplatform.gcp.cloud kafka-2-lb kafka-2 b2
EXTERNALIP-OF-KB      kafka.mydevplatform.gcp.cloud kafka-bootstrap-lb kafka

### Test Control Center (Monitoring) with external access

Use your browser and go to [http://controlcenter:9021](http://controlcenter:9021) enter the Username=admin and Password=Developer1.

Please note that https (default by most web browers) is not configured, explicity type http://URL:port.
(Here you can use also KSQL)

### External Access to your Confluent Plaform

Please follow the Confluent documentation [External Access](https://docs.confluent.io/current/installation/operator/co-endpoints.html#co-loadbalancer-kafka). At the end you have to enable the loadblancer settings in gcp.yaml file.

## Kubernetes Dashboard

* Run `kubectl proxy &`
* Go to [K8s dashboard](http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/)
* Login to K8s dashboard using The token from `gcloud config config-helper --format=json | jq -r '.credential.access_token'`

## Grafana Dashboards

* Forward local port to Grafana service: `kubectl -n monitoring port-forward service/prom-grafana 3000:service`
* Go to [localhost:3000](http://localhost:3000) (login: admin, prom-operator)
* Dashboards will be deployed automatically (if they are not visible, bounce the deployment by deleting the current Grafana pod. It will reload the ConfigMaps after it restarts.)

## Confluent Platform on Kubernetes

Follow the examples of how to use and play with Confluent Platform on GCP K8s on [Confluent docs](https://docs.confluent.io/current/installation/operator/co-deployment.html)

## Destroy Confluent Platform from GKE

* Run the script 02_deleteConfluentPlatform.sh to delete the Confluent Platform from GKE

```bash
./02_deleteConfluentPlatform.sh
#check if everything is deleted
kubectl get services -n operator
kubectl get pods -n operator
```

If you want to destroy the complete GKE cluster including Confluent Platform then please [go to terraform destroy](../terraform-gcp/)

Please also check the GCP Disks (if errors occur during Terraform scripts, it sometimes does not delete all SSDs successfully).
