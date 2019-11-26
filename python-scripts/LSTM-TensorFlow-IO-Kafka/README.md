# Python Application deploying a LSTM using TensorFlow IO and Apache Kafka

The following contains an explanation of the Python application using TensorFlow IO to consume data from Kafka, train the model, do model inference and send the predictions back to a Kafka topic.

Please note that all of the below is already automated and included in the Terraform build of the quick start guide.

`WARNING:
This part (model training and inference with TensorFlow IO) works, but still has a few issues. We are working on a complete automated demo - target: End of October 2019.`

## Use Case: LSTM for Predictive Maintenance

We train a LSTM Neural Network from the car sensor data and use the model for predictions on new data in real time. The data is ingested via MQTT (HiveMQ) into a Kafka Topic (Confluent). TensorFlow (Python application) does model training and model inference in real time (without the need for another data store like S3 or HDFS).

## Technical Details

### Python Application

The Python application consumes from the Kafka topic `car-sensor`. We use TensorFlow IO for training and inference. The only dependency of tensorflow-io is TensorFlow (+ Kafka). This really simplified almost everything and is one of the biggest advantages of tenorflow-io.

See the Python application here: [cardata-v1.py](cardata-v1.py).

### Build the Docker Image for the Python Application

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

### Kubernetes Integration

As you could see the docker image could run standalone so it should be easy to just parameterize the docker image into kubernetes yamls.

The current procedure is training the model first, then deploying the prediction pods as a scalable Deployment onto Kubernetes.

Simply execute the [run.sh](run.sh) script to automatically perform these steps.

## ML Process for Streaming Model Training and Inference

Model training and model inference are separated processes. They can both run in the same application, or in separate applications. We will demonstrate both examples:

1. Use the Python application [cardata-v1.py](cardata-v1.py) to train the model and do inference on other events.
2. Save the model with the Python application and load the model into a Java application (TODO => e.g. Kafka Streams or KSQL) and do the model inference here - completelely separeated from the model training.

### Create Model for Streaming Data

There are quite a few ways to build a model for streaming data.

Since training in tf.keras requires a feature dataset, and a label dataset, we will need to come up with a way to get feature and label.

In normal situations, label could be done through alternative methods. For example, Car IoT device sensor data could be labels by human or ground truth.

In our example, the field `failure_occurred` in the data set classifies any data point as either „true“ or „false“ depending on whether any of the failure modes occurred for the given model. This field is used as label for training the LSTM. The field will be predicted in real time to predict potential failures in new car sensor events.

### Do Predictions

After model has been trained, a different set of data could be passed to model.predict for inference.

If you look into cardata-v1.py, we use the first 1000 records for training, and then use the next 200 records for inference. We could adjust these two values.

For example, if you run the demo with 100000 instead of 25 simulated cars, you should increase these values to use more events for training and inference.

### Write Predict Results back into another Kafka Topic

To show a complete pipeline: Essentially, tensorflow reads data from Apache Kafka, do either training or inference (or both), then write the inference back to Kafka. Other programs could just pull the inference results from Kafka and do additional processing (e.g. by a real time alerting system, mobile app, or another batch analytics tool).

In [cardata-v1.py](cardata-v1.py) we just concat the prediction results into a csv string. The string is written into a Kafka Topic.

TODO Ideally we could also serialize the prediction result with Avro schema, so that it will be even easier for Kafka to process.

## Details about Model Training and Inference with TensorFlow IO

In general, tensorflow-io is capable of providing either training or inference to tf.keras's high level API.

### Model training

Training is done through tf.keras' `model.fit` in a streaming fashion as well. At each epoch run, tensorflow-io will continue pulling data from Kafka stream from the beginning to end, and feed to `model.fit`. Since training might invoke multiple epoch runs, tensorflow-io will repeat the iteration at each epoch run.

Once the model has been trained, it could be saved for later use (predict). It also could be used directly for predict.

### Model Inference

Inference / predict is done through tf.keras' `model.predict()` in a streaming fashion. tensorflow-io will continue pulling data from Kafka stream and feed to model.predict() in a fashion similar to a pipeline.

tensorflow-io could also optionally write the predict result back in kafka (e.g., in another kafka topic). This is what we do in our example to show an end-to-end ML pipeline.

### Streaming vs. Batch Training and Inference

tf.keras's training or inference could always support batching. Batching serves multiple purposes:

1) to max the data flow to fit the GPU (if available)
2) to adjust input in neural network model.

tensorflow-io returns a `dataset` which you could easily adjust the batch by calling a method `dataset.batch(batch_size)`.

The returned dataset is always the variable to be passed to either model.fit or model.predict (prediction and training / fit requires slightly different dataset shape).
