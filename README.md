# Streaming Machine Learning from IoT Devices with HiveMQ, Apache Kafka and TensorFLow

WORK IN PROGRESS... NO FUNCTIONAL PROJECT YET...

This project implements a scenario where you can *train new analytic models from streaming data - without the need for an additional data store* like S3,HDFS or Spark.

We use HiveMQ as open source MQTT broker to ingest data from IoT devices, ingest the data in real time into an Apache Kafka cluster for preprocessing (using Kafka Streams / KSQL),and model training (using TensorFlow 2.0 and its Kafka IO plugin).

## Use Case and Architecture

TODO

## Streaming Ingestion and Model Training with Kafka and TensorFlow-IO

Typically, analytic models are trained in batch mode where you first ingest all historical data in a data store like HDFS, AWS S3 or GCS. Then you train the model using a framework like Spark MLlib, TensorFlow or Google ML. 

[TensorFlow I/O](https://github.com/tensorflow/io) is a component of the TensorFlow framework which allows native integration with different technologies.

One of these integrations is tensorflow_io.kafka which allows streaming ingestion into TensorFlow from Kafka WITHOUT the need for a data store! This *significantly simplifies the architecture  and reduces operation and development costs*.

You can pick and choose the right components from the Apache Kafka and TensorFlow ecosystems for your use case:

![Machine Learning Workflow with TensorFlow and Apache Kafka Ecosystem](images/TensorFlow_Apache_Kafka_Streaming_Workflow.png)

This demo will do the following steps:

- Consume streaming data from MQTT via a Kafka Consumer
- Preprocess the data with KSQL (filter, transform)
- Ingest the data into TensorFlow  (tf.data and tensorflow-io)
- Build, train and save the model  (TensorFlow 2.0 API)
- Deploy the model within a Kafka Streams application for embedded real time scoring

Optional steps (nice to have and implemented later)

- Deploy the model via TensorFlow Serving
- Some kind of A/B testing
- Re-train the model and updating the Kafka Streams application (via sending the new model to a Kafka topic)
- Monitoring of model training (via TensorBoard) and model deployment / inference (via some kind of Kafka integration + dashboard technology)

## Requirements and Installation

TODO

## Live Demo

Until the demo is ready, you can already checkout a working [Python example of streaming ingestion of MNIST data into TensorFlow via Kafka](confluent-tensorflow-io-kafka.py).


TODO IMPLEMENT DEMO

(via Docker container and run via single command)

- Start HiveMQ
- Start Confluent Platform
- Start TensorFlow Python script consuming data to train the model
- Create data stream (MQTT messages)
- Finish model training
- Use model for inference: 1) via TensorFlow-IO Python API and 2) exported to a Kafka Streams / KSQL microservice

