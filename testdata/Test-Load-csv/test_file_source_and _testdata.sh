#!/bin/bash
# some links 
# Schema registry tutorial: https://docs.confluent.io/current/schema-registry/schema_registry_tutorial.html
# KSQL: changing data formats: https://www.confluent.io/stream-processing-cookbook/ksql-recipes/changing-data-serialization-format-json-avro
# filestream connector: https://docs.confluent.io/current/connect/filestream_connector.html
# Using schema registry with connect: https://docs.confluent.io/current/schema-registry/connect.html#schemaregistry-kafka-connect
# Kafka Connect worker config: https://docs.confluent.io/current/connect/references/allconfigs.html#common-worker-configs
# Schema AVRO Tutorial: https://aseigneurin.github.io/2018/08/02/kafka-tutorial-4-avro-and-schema-registry.html
# Kafka Connect deep dive: https://www.confluent.io/blog/kafka-connect-deep-dive-converters-serialization-explained
# 

confluent local start
confluent local list connectors

kafka-topics --create --topic car-data-csv --partitions 1 --replication-factor 1 --zookeeper 127.0.0.1:2181
kafka-topics --create --topic cardata --partitions 1 --replication-factor 1 --zookeeper 127.0.0.1:2181
# kafka-topics --zookeeper localhost:2181 --delete --topic users
# kafka-topics --zookeeper localhost:2181 --list

# check subjects in schema registry for schema registry
curl http://localhost:8081/subjects/

# register schema  <schema registry REST> <topic> <avro schema file>
# or use C3 https://docs.confluent.io/current/control-center/topics/schema.html
# works only in this format
#"fields": [
#    {
#      "name": "coolant_temp", "type": "float"},
python3 register_schema.py http://localhost:8081 cardata /Users/cmutzlitz/Confluent/hiveMQ/cardata-v1.avsc

# check
curl http://localhost:8081/subjects/cardata-value/versions/
# get schema
curl http://localhost:8081/subjects/cardata-value/versions/1

# check current properties
cat file_stream_demo_standalone.properties
cat worker.properties

# start the standa alone connector
connect-standalone worker.properties file_stream_demo_standalone.properties
# stop with control+c

# check data
kafka-console-consumer --topic users --from-beginning --bootstrap-server 127.0.0.1:9092
kafkacat -b localhost:9092 -t car-data-csv -C

# transform to AVRO
KSQL> SET 'auto.offset.reset'='earliest';
KSQL> PRINT 'car-data-csv' FROM BEGINNING;
KSQL> create stream car_stream (created varchar, carid varchar, coolant_temp double, intake_air_temp double, intake_air_flow_speed double, 
battery_percentage double, battery_voltage double, current_draw double, Speed double, engine_vibration_amplitude double, throttle_pos double, 
tire_pressure_1_1 int, tire_pressure_1_2 int, tire_pressure_2_1 int, tire_pressure_2_2 int, accelerometer_1_1_value double, accelerometer_1_2_value double,
 accelerometer_2_1_value double,  accelerometer_2_2_value double, control_unit_firmware int) 
 WITH (KAFKA_TOPIC='car-data-csv', VALUE_FORMAT='DELIMITED'); 
KSQL> describe car_stream;
KSQL> SET 'auto.offset.reset' = 'earliest';
KSQL> select * from car_stream;
KSQL> CREATE STREAM car_stream_avro WITH (VALUE_FORMAT='AVRO') AS SELECT * FROM car_stream;
KSQL> describe car_stream_avro;
KSQL> select * from car_stream_avro;

# check automatically created schema
curl http://localhost:8081/subjects/kcmi-CAR_STREAM_AVRO-value/versions/
# get schema
curl http://localhost:8081/subjects/kcmi-CAR_STREAM_AVRO-value/versions/1

# clean
rm standalone.offsets
