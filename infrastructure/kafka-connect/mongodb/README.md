# MongoDB Integration with Kafka Connect

This section describes the integration of MongoDB using Kafka Connect.

The example creates a *MongoDB sink to ingest sensor data into a MongoDB database for further monitoring, aggregations and analytics*. This is one example of building a *digital twin architecture*.

## Digital Twin with Kafka and MongoDB

Check out [IoT Architectures for Digital Twin with Apache Kafka](https://www.kai-waehner.de/blog/2020/03/25/architectures-digital-twin-digital-thread-apache-kafka-iot-platforms-machine-learning/) for more thoughts on this. Similarly to the MongoDB integration, you can easily create other source and sink integrations.

If you want to learn more about the Kafka / MongoDB integration leveraging Kafka Connect, then the following blog post gets you started: [Getting Started with the MongoDB Connector for Apache Kafka and MongoDB](https://www.confluent.io/blog/getting-started-mongodb-connector-for-apache-kafka-and-mongodb/).

## Build Kafka Connect Docker Image for MongoDB

Please note that you need to *build your own Kafka Connect Docker Image* if your Connector is not included in the Kafka Connect base image from Confluent Operator. You can skip this step if you want to use one of included connectors.

The Kafka Connect Docker Image from Confluent comes with a few connectors preinstalled. However, most connectors (including MongoDB) are not included to keep the base image small and lightweight.

The [documentation of Confluent Operator](https://docs.confluent.io/current/tutorials/examples/kubernetes/gke-base/docs/index.html#connector-deployments) explains how to build your own Docker image.

We use the following Docker file:

```bash
FROM confluentinc/cp-server-connect-operator:5.4.0.0
ENV CONNECT_PLUGIN_PATH="/usr/share/java,/usr/share/confluent-hub-components"
RUN confluent-hub install --no-prompt mongodb/kafka-connect-mongodb:1.0.1
```

For other source and sink connectors, check out [Confluent Hub](https://www.confluent.io/hub/). There you can find many open source and commercial connectors.

The following commands build the Docker Image and push it to Dockerhub so that the Terraform script can load it during deployment:

```bash
docker build --tag connect-with-mongodb-connector:1.0 .
docker login --username=megachucky
docker images
docker tag f0cb744350ed megachucky/connect-with-mongodb-connector:1.0
docker push megachucky/connect-with-mongodb-connector
```

## Kafka Connect Cluster

Configure the Helm Charts to use your Kafka Connect Docker Image with your MongoDB connector libraries, then deploy the Kafka Connect cluster.

### Point Helm Charts to your MongoDB Kafka Connect Docker Image

The following step is only required if you built your own Docker image with your own connectors.

This is required because the base image does not contain all libraries for all Kafka Connect connectors. In this case, you need to update to values.yaml file (in our project: gcp.yaml) and point to your own repository and Docker Image:

```bash
connect:
  image:
    repository: megachucky/connect-with-mongodb-connector
    tag: 1.0
  name: connect
```

A [full example](https://github.com/confluentinc/examples/blob/5.3.1-post/kubernetes/gke-base/cfg/values.yaml#L53) can be found in the Confluent Operator documentation.

### Deploy Kafka Connect with the MongoDB Connector Library included

The Kafka Connect cluster can be installed and maintained using Confluent Operator:

```bash
connect:
  name: connect
  replicas: 2
  tls:
    enabled: false
    ## "" for none, "tls" for mutual auth
    authentication:
      type: ""
    fullchain: |-
    privkey: |-
    cacerts: |-
  loadBalancer:
    enabled: false
    domain: ""
  dependencies:
    kafka:
      bootstrapEndpoint: kafka:9071
      brokerCount: 3
    schemaRegistry:
      enabled: true
      url: http://schemaregistry:8081
```

The script '01_installConfluentPlatform.sh' uses Helm to set up the Kafka Connect cluster in distributed mode with two pods:

```bash
helm upgrade --install \
connect \
./confluent-operator -f \
${MYDIR}/gcp.yaml \
--namespace operator \
--set connect.enabled=true

echo "After Kafka Connect Installation: Check all pods..."
kubectl get pods -n operator
sleep 10
kubectl rollout status sts -n operator connect
```

## MongoDB

This demo uses MongoDB Atlas, i.e. MongoDB as a fully managed service. Of course, you could also deploy MongoDB within the Kubernetes cluster or connect to any other location.

### MongoDB Cluster Setup

This demo uses a [MongoDB Atlas database for free](https://cloud.mongodb.com/). Please create your own one and replace the connection-uri with yours.

```bash
mongodb+srv://admin:helloABC!@confluent-kafka-digital-twin.gcp.mongodb.net/test?retryWrites=true&w=majority
```

Don't forget to whitelist your IP address. This is pretty straighforward in the Atlas cloud UI. Or you can make it accessible from everywhere with one single click (only for testing and with test data, obviously).

As otehr option, you can connect to any other MongoDB cluster, of course.

### Creation and Deployment of the MongoDB Connector

THe two Kafka Connct instances are 'connect-0' and 'connect-1'. We use the Load Balancer 'connect-bootstrap-lb' to set up the MongoDB connector:

```bash
➜  terraform-gcp git:(master) ✗ kubectl get services -n operator connect-bootstrap-lb
NAME                   TYPE           CLUSTER-IP      EXTERNAL-IP     PORT(S)        AGE
connect-bootstrap-lb   LoadBalancer   10.31.243.186   34.76.164.249   80:31942/TCP   20m
```

#### Testing with CURL and Kafka Connect REST API

For testing, you can use the REST API of Kafka Connect directly for deployment, status check and deletion of the MongoDB connector:

```bash
curl -s "http://35.205.152.69:80/connectors"

curl -s "http://35.205.152.69:80/connectors/sink-mongodb/status"

curl -s -X DELETE 35.205.152.69:80/connectors/sink-mongodb

curl -X PUT http://35.205.152.69/connectors/sink-mongodb/config -H "Content-Type: application/json" -d ' {
      "connector.class":"com.mongodb.kafka.connect.MongoSinkConnector",
      "tasks.max":"1",
      "topics":"sensor-data",
      "connection.uri":"mongodb+srv://admin:helloABC!@confluent-kafka-digital-twin.gcp.mongodb.net/test?retryWrites=true&w=majority",
      "database":"confluent-kafka-digital-twin",
      "collection":"sensor-data",
      "key.converter":"org.apache.kafka.connect.storage.StringConverter",
      "key.converter.schemas.enable":false,
      "value.converter":"org.apache.kafka.connect.storage.StringConverter",
      "value.converter.schemas.enable":false,
      "transforms":"WrapKey",
      "transforms.WrapKey.type":"org.apache.kafka.connect.transforms.HoistField$Key",
      "transforms.WrapKey.field":"_id"

}'
```

MongoDB Sink does not support Strings. It requires JSON for the key and value of the Kafka message. As the key from the car-sensor Kafka topic is a String, we need to transform it so that it can be ingested into the MongoDB collection.

We use [SMT (Single Message Transformations)](https://docs.confluent.io/current/connect/transforms/index.html), a simple but powerful Kafka Connect feature to do "ETL on the fly", for this transformation.

#### Deployment with Kubernetes Concepts - YAML, Kubectl, ConfigMap and Job

The ConfigMap contains the configuration for the MongoDB connector:

```bash
kubectl -n operator apply -f connector-configmap-mongodb.yaml
```

The Job executes a CURL command to deploy the MongoDB connector:

```bash
kubectl -n operator apply -f connector-deployments-mongodb.yaml
```