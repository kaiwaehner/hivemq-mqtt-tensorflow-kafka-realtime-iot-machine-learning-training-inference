# Streaming Machine Learning from IoT Devices with HiveMQ, Apache Kafka and TensorFLow

WORK IN PROGRESS... NO FUNCTIONAL PROJECT YET...

This project implements a scenario where you can train new analytic models from streaming data - without the need for an additional data store like S3,HDFS or Spark.

We use HiveMQ as open source MQTT broker to ingest data from IoT devices, ingest the data in real time into an Apache Kafka cluster for preprocessing (using Kafka Streams / KSQL),and model training (using TensorFlow 2.0 and its Kafka IO plugin).

## Use Case and Architecture

TODO

## Streaming Ingestion and Model Training with Kafka and TensorFlow-IO

TODO

## Requirements and Installation

TODO

## Live Demo

TODO (via Docker container and run via single command)

- Start HiveMQ
- Start Confluent Platform
- Start TensorFlow Python script consuming data to train the model
- Create data stream (MQTT messages)
- Finish model training
- Use model for inference: 1) via TensorFlow-IO Python API and 2) exported to a Kafka Streams / KSQL microservice

