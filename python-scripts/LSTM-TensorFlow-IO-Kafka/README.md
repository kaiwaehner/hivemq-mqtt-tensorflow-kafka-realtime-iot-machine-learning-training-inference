# Python Application deploying a LSTM using TensorFlow IO and Apache Kafka

We train a LSTM Neural Network from the car sensor data and use the model for predictions on new data in real time. The data is ingested via MQTT (HiveMQ) into a Kafka Topic (Confluent). TensorFlow (Python application) does model training and model inference in real time (without the need for another data store like S3 or HDFS).

`WARNING:
This part (deployment of the Python application) is not scripted yet. You have to deploy the application (via Docker) manually. Target for automated scripting: End of October 2019.`

## Python application

The Python application consumes from the Kafka topic `car-sensor`. We use TensorFlow IO for training and inference. The only dependency of tensorflow-io is TensorFlow (+ Kafka). This really simplified almost everything and is one of the biggest advantages of tenorflow-io.

See the Python application here: [cardata-v1.py](LSTM-TensorFlow-IO-Kafka/cardata-v1.py).

## Build the Docker Image for the Python Application

There is a Dockerfile which could be used for building a docker image and deploy locally or on Kuberentes clusters.

To build docker image, you could run with

```bash
docker build -t tensorflow-io .
```

Once the Docker image is build, you could run with the following command:

```bash
docker run -i -t --net=host tensorflow-io python3 cardata-v1.py localhost:9092 cardata-v1 0 cardata-v1-result
```

Some explanation about each args in localhost:9092 cardata-v1 0 cardata-v1-result (you will need to adjust to fit your environment):

1) localhost:9092: This needs to be replaced with the kafka bootstrap servers in your environment.
2) cardata-v1: This needs to be replaced with the topic name you create in the Kafka (for data feed)
3) 0: This is the offset to start with. Note this value has to be absolute (not relative to the end of the stream, etc).
4) cardata-v1-result: This is the topic to send back the prediction result to Kafka. You can create an empty topic for this purpose (no Avro support yet).

The docker image has schema (cardata-v1.avsc) embedded. If you change the schema you will need to rebuild the docker image with file included.

## Kubernetes Integration

As you could see the docker image could run standalone so it should be easy to just parameterize the docker image into kubernetes yams.

TensorFlow does support distributed training (e.g., through MirrorStrategy). I haven't had this part in place yet. But we could add distributed training in next phase.

Note distributed training will requires special kubernetes settings (than simply launching the container). We could get it in place later.

## Details about Model Training with TensorFlow IO

In general, tensorflow-io is capable of providing either training or inference to tf.keras's high level API.

### For Model Inference

- Inference/predict is done through tf.keras' `model.predict()` in a streaming fashion. tensorflow-io will continue pulling data from Kafka stream and feed to model.predict() in a fashion similar to a pipeline.

- tensorflow-io could also optionally write the predict result back in kafka (e.g., in another kafka topic).

### For Model training

- Training is done through tf.keras' `model.fit` in a streaming fashion as well. At each epoch run, tensorflow-io will continue pulling data from Kafka stream from the beginning to end, and feed to `model.fit`. Since training might invoke multiple epoch runs, tensorflow-io will repeat the iteration at each epoch run.

### Batch

- tf.keras's training or inference could always support batching. Batching serves multiple purposes: 1) to max the data flow to fit the GPU (if available), 2) to adjust input in neural network model.

- tensorflow-io returns a `dataset` which you could easily adjust the batch by calling a method `dataset.batch(batch_size)`.

- The returned dataset is always the variable to be passed to either model.fit or model.predict (prediction and training/fit requires slightly different dataset shape).

### Model for streaming data

There are quite a few ways to build a model for streaming data.

Since training in tf.keras requires a feature dataset, and a label dataset, we will need to come up with a way to get feature and label.

- In normal situations, label could be done through alternative methods. For example, I assume Car IoT device sensor data could be labels by human or ground truth. In the data set I receive, I couldn't find the label field though.

- We could also create label based on history. For example, let's say we have history data from past month. We could assume past month most of the time the data is "normal". Then we could create a sliding window of, say, each day. We could use every data as the feature dataset, and the immediate next hour/min as the label data. If we have one month of data, then the feature set will be the sliding window of 1day from day 0 to day 29, and the label set will be from day 1+0hour to day 30+0hour.

 Ideally the first case (with ground truth labeling) would be better. But since I don't see label in the data I am using second case.

In [cardata-v1.py](LSTM-TensorFlow-IO-Kafka/cardata-v1.py), you could see we are creating a `look_back` which is the window size, for feature dataset (dataset_x). I am also `skip(look_back)` for label dataset (dataset_y) because the first `look_back` we could only use it for feature. (the next 1 will be the label corresponding to the feature in first `look_back`).

### Model.fit

Model.fit will train the model. Once the model has been trained, it could be saved for later use (predict). It also could be used directly for predict.

### Predict

After model has been trained, a different set of data could be passed to model.predict for inference.

If you look into cardata-v1.py, I use the first 1000 records for training, and then use the next 200 records for inference. We could adjust these two values.

### Write predict results back into Kafka

To show a complete pipeline: Essentially, tensorflow reads data from Apache Kafka, do either training or inference (or both), then write the inference back to Kafka. Other programs could just pull the inference results from Kafka and do additional processing if needed.

In cardata-v1.py we just concat the prediction results into a csv string. The string is written into Kafka. Ideally we could also serialize the prediction result with Avro schema, so that it will be even easier for Kafka to process. We may need some discussion on what schema might be needed.

## Open TODOs

1. Add this Python container and usage to the quick start guide including automated scripting.

2. Test with larger scale IoT data and see how much we can scale without breaking the Python code -> to find out what we can show in a demo without further changes

3. Save the model to also allow the usage from another application (like a Kafka Streams or KSQLs app deployed in another container

4. Depending on 1), implement the distributed training. I dont think this is urgent, but of course this overall demo has the right setup to show an impressive use case.
