# GCS Integration with Kafka Connect

This section describes the integration of GCP's Google Cloud Storage (GCS) using Kafka Connect.

## Installation of the GCS Connector

The Kafka Connect Docker Image form Confluent Operator 5.4 ships the GCS library out-of-the-box. No need for additional installation setup.

## Configuration

The configuration of the [Google Cloud Storage Sink Connector for Confluent Platform](https://docs.confluent.io/current/connect/kafka-connect-gcs/index.html) is documented in detail on the Confluent website.

The following shows how to get the connector running in the car-demo example. We configure the connector to store the data in AVRO format in GCS. Parquet, JSON or Raw data could be stored by just changing the related parameters.

```bash

# List deployed connectors
curl -s "http://35.205.63.174:80/connectors"

# Deploy GCS connector instance
curl -X PUT http://35.205.63.174/connectors/sink-gcs/config -H "Content-Type: application/json" -d ' {
	"connector.class":"io.confluent.connect.gcs.GcsSinkConnector",
	"tasks.max":"1",
	"topics":"SENSOR_DATA_S_AVRO",
	"gcs.bucket.name":"car-demo-sensor-data-avro",
	"gcs.part.size":"5242880",
	"flush.size":"3",
	"gcs.credentials.json":"{\"type\": \"service_account\", \"project_id\": \"TODO\", \"private_key_id\": \"TODO\\n\", \"client_email\": \"administrator@kai-waehner-project.iam.gserviceaccount.com\", \"client_id\": \"104520591841340402330\", \"auth_uri\": \"https://accounts.google.com/o/oauth2/auth\", \"token_uri\": \"https://oauth2.googleapis.com/token\", \"auth_provider_x509_cert_url\": \"https://www.googleapis.com/oauth2/v1/certs\", \"client_x509_cert_url\": \"https://www.googleapis.com/robot/v1/metadata/x509/administrator%40kai-waehner-project.iam.gserviceaccount.com\"}",
	"storage.class":"io.confluent.connect.gcs.storage.GcsStorage",
	"format.class":"io.confluent.connect.gcs.format.avro.AvroFormat",
      	"key.converter":"org.apache.kafka.connect.storage.StringConverter",
      	"value.converter":"io.confluent.connect.avro.AvroConverter",
	"value.converter.schema.registry.url":"http://schemaregistry:8081",
	"partitioner.class":"io.confluent.connect.storage.partitioner.DefaultPartitioner",
	"schema.compatibility":"NONE",
	"confluent.topic.replication.factor":"1",
	"name":"sink-gcs",
	"confluent.topic.bootstrap.servers":"kafka:9071",
	"confluent.topic.security.protocol": "SASL_PLAINTEXT",
	"confluent.topic.sasl.mechanism": "PLAIN",
	"confluent.topic.sasl.jaas.config":"org.apache.kafka.common.security.plain.PlainLoginModule required username=\"test\" password=\"test123\";"

}'

# Show status of the deployed GCS connector instance
curl -s "http://35.205.63.174:80/connectors/sink-gcs/status"

# Delete the GCS connector instance
curl -s -X DELETE 35.205.63.174:80/connectors/sink-gcs
```

## Hints

A few things to point out:

- The Avro Converter only works because we consume data from a Kafka Topic which stores Avro data. For other data formats, the Kafka Topics needs to use the right serialization format, too.

- The key of our messages is a String. You need to enforce Connect to use StringConverter

- The above example embedded the whole GCS security information into the CURL command. This is not recommended. The docs also describe how to add a JSON config file. This file needs to be accessible from the Connect pod (not your laptop where you run the CURL command).

- If you need to convert the GCP JSON security file to String, you can use this nice Python script specifically built for the GCS Sink connector to "[stringify the GCP credentials](https://github.com/NathanNam/stringify-gcp-credentials)" - or use a general tool like [JSON to String Online Converter](https://tools.knowledgewalls.com/jsontostring)

- If you want to deploy and automate the connector configuration adn deployment using Kubernetes-native tooling, check out the [MongoDB YAML files of this project](https://github.com/kaiwaehner/hivemq-mqtt-tensorflow-kafka-realtime-iot-machine-learning-training-inference/tree/master/infrastructure/kafka-connect/mongodb).

- Don't forget to delete the Bucket (or configure a short retention time when creating the bucket) if you just use it for a demo or POC. The GCS example is not part of the Terraform script, so DESTROY does NOT include this bucket.
