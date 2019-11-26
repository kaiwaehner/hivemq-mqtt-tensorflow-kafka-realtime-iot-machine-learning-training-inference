# Python Application deploying a LSTM or Autoencoder using TensorFlow IO and Apache Kafka

The following contains an explanation of the Python application using TensorFlow IO to consume data from Kafka, train the model, do model inference and send the predictions back to a Kafka topic.

Model training and inference are separated by intention into two independent applications (i.e. Kubernetes pods). However, both processes use the same ingestion and pre-processing pipeline.

## Quickstart for Model Training and Model Inference

- Go to the folder [AUTOENCODER-TensorFlow-IO-Kafka](AUTOENCODER-TensorFlow-IO-Kafka)

- Start the model training with `kubectl apply -f model-training.yaml`. Training takes around 10min with default config and is executed only once. The model is stored as file model.h5 in GCS object store.

- Check if model training is finished (i.e. the pod execution complemeted), e.g. with `kubectl get pods -n default`.

- Start the model inference with `kubectl apply -f model-predictions.yaml`. The application (a Kubernetes Deployment which starts the pod `tf-model`) runs for some seconds to process the configured number of incoming events, does real time predictions, and then shuts down. Afterwards, it restarts and does the same again. (this is not an ideal architecture, and more the "Python batch style of data processing". We will also implement a more "real world streaming application" with Kafka Streams or ksqlDB which runs continuous in one or more pods)

- You can stop the model inference and continuous restarting of the pods with `kubectl delete deployment tf-model`. The model training just runs once, so no need to delete that pod.

- Using the ("hello world") LSTM Neural Network is very similar and implemented in the folder [LSTM-TensorFlow-IO-Kafka](LSTM-TensorFlow-IO-Kafka). We prefer the autoencoder and use it in our demos, though.

Below are more details about the implementation. The below is just for your information and if you want to change things. For running the demo, you just need to use the above two YAML files.

## Use Case: LSTM or Autoencoder for Predictive Maintenance

We train an supervised LSTM and via an unsupervised Autoencoder Neural Network from the car sensor data and use the model for predictions on new data in real time. The data is ingested via MQTT (HiveMQ) into a Kafka Topic (Confluent). TensorFlow (Python application) does model training and model inference in real time (without the need for another data store like S3 or HDFS).

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
