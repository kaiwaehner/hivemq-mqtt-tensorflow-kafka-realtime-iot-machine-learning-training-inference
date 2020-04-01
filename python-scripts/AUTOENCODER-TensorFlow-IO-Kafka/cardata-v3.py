import numpy as np
import tensorflow as tf
import tensorflow_io.kafka as kafka_io
import tensorflow_datasets as tfds
from google.cloud import storage

kafka_config = [
    "broker.version.fallback=0.10.0.0",
    "security.protocol=sasl_plaintext",
    "sasl.username=test",
    "sasl.password=test123",
    "sasl.mechanisms=PLAIN"
    # Tried to force kafka library to use the correct address
    # "bootstrap.servers=kafka.operator.svc.cluster.local:9071"
]

with open('cardata-v1.avsc') as f:
    schema = f.read()

import sys

print("Options: ", sys.argv)

if len(sys.argv) != 8:
    print("Usage: python3 cardata-v1.py <servers> <topic> <offset> <result_topic> <mode> <model-file> <project>")
    sys.exit(1)

servers = sys.argv[1]
topic = sys.argv[2]
offset = sys.argv[3]
result_topic = sys.argv[4]
mode = sys.argv[5].strip().lower()
if mode != "predict" and mode != "train":
    print("Mode is invalid, must be either 'train' or 'predict':", mode)
    sys.exit(1)
model_file = sys.argv[6]
bucket_suffix = sys.argv[7]

# Configure google storage bucket access
client = storage.Client.from_service_account_json('/credentials/credentials.json')
bucket = client.get_bucket("tf-models_" + bucket_suffix)


def kafka_dataset(servers, topic, offset, schema, eof=True):
    print("Create: ", "{}:0:{}".format(topic, offset))
    dataset = kafka_io.KafkaDataset(["{}:0:{}".format(topic, offset, offset)], servers=servers,
                                    group="cardata-autoencoder", eof=eof, config_global=kafka_config)

    # remove kafka framing
    dataset = dataset.map(lambda e: tf.strings.substr(e, 5, -1))

    # deserialize avro
    dataset = dataset.map(
        lambda e: kafka_io.decode_avro(
            e, schema=schema, dtype=[
                tf.float64,
                tf.float64,
                tf.float64,
                tf.float64,
                tf.float64,
                tf.float64,
                tf.float64,
                tf.float64,
                tf.float64,
                tf.int32,
                tf.int32,
                tf.int32,
                tf.int32,
                tf.float64,
                tf.float64,
                tf.float64,
                tf.float64,
                tf.int32,
                tf.string]))
    return dataset


def normalize_fn(
        coolant_temp,
        intake_air_temp,
        intake_air_flow_speed,
        battery_percentage,
        battery_voltage,
        current_draw,
        speed,
        engine_vibration_amplitude,
        throttle_pos,
        tire_pressure_11,
        tire_pressure_12,
        tire_pressure_21,
        tire_pressure_22,
        accelerometer_11_value,
        accelerometer_12_value,
        accelerometer_21_value,
        accelerometer_22_value,
        control_unit_firmware,
        failure_occurred):
    tire_pressure_11 = tf.cast(tire_pressure_11, tf.float64)
    tire_pressure_12 = tf.cast(tire_pressure_12, tf.float64)
    tire_pressure_21 = tf.cast(tire_pressure_21, tf.float64)
    tire_pressure_22 = tf.cast(tire_pressure_22, tf.float64)

    control_unit_firmware = tf.cast(control_unit_firmware, tf.float64)

    def scale_fn(value, value_min, value_max):
        return (value - value_min) / (value_max - value_min) * 2.0 - 1.0

    # coolant_temp ?????????? TODO
    coolant_temp = 0.0

    # intake_air_temp (15, 40) => (-1.0, 1.0)
    intake_air_temp = scale_fn(intake_air_temp, 15.0, 40.0)

    # intake_air_flow_speed ?????????? TODO
    intake_air_flow_speed = 0.0

    # battery_percentage ?????????? (0, 100) => (-1.0, 1.0)
    battery_percentage = scale_fn(battery_percentage, 0.0, 100.0)

    # battery_voltage ?????????? TODO
    battery_voltage = 0.0

    # current_draw ?????????? TODO
    current_draw = 0.0

    # speed ?????????? (0, 50) => (-1.0, 1.0)
    speed = scale_fn(speed, 0.0, 50.0)

    # engine_vibration_amplitude ???? [speed * 150 or speed * 100] (0, 7500) => (-1.0. 1.0)
    engine_vibration_amplitude = scale_fn(engine_vibration_amplitude, 0.0, 7500.0)

    # throttle_pos (0, 1) => (-1.0, 1.0)
    throttle_pos = scale_fn(throttle_pos, 0.0, 1.0)

    # tire pressure (20, 35) => (-1.0, 1.0)
    tire_pressure_11 = scale_fn(tire_pressure_11, 20.0, 35.0)
    tire_pressure_12 = scale_fn(tire_pressure_12, 20.0, 35.0)
    tire_pressure_21 = scale_fn(tire_pressure_21, 20.0, 35.0)
    tire_pressure_22 = scale_fn(tire_pressure_22, 20.0, 35.0)

    # accelerometer (0, 7) => (-1.0, 1.0)
    accelerometer_11_value = scale_fn(accelerometer_11_value, 0.0, 7.0)
    accelerometer_12_value = scale_fn(accelerometer_12_value, 0.0, 7.0)
    accelerometer_21_value = scale_fn(accelerometer_21_value, 0.0, 7.0)
    accelerometer_22_value = scale_fn(accelerometer_22_value, 0.0, 7.0)

    # control_unit_firmware [1000|2000] => (-1.0, 1.0)
    control_unit_firmware = scale_fn(control_unit_firmware, 1000.0, 2000.0)

    return tf.stack([
        coolant_temp,
        intake_air_temp,
        intake_air_flow_speed,
        battery_percentage,
        battery_voltage,
        current_draw,
        speed,
        engine_vibration_amplitude,
        throttle_pos,
        tire_pressure_11,
        tire_pressure_12,
        tire_pressure_21,
        tire_pressure_22,
        accelerometer_11_value,
        accelerometer_12_value,
        accelerometer_21_value,
        accelerometer_22_value,
        control_unit_firmware]), failure_occurred


# Note: same autoencoder, except:
# Autoencoder: 30 => 14 => 7 => 7 => 14 => 30 dimensions
# replaced by
# Autoencoder: 18 => 14 => 7 => 7 => 14 => 18 dimensions

nb_epoch = 20
batch_size = 100

# Autoencoder: 18 => 14 => 7 => 7 => 14 => 18 dimensions
input_dim = 18  # num of columns, 18
encoding_dim = 14
hidden_dim = int(encoding_dim / 2)  # i.e. 7
learning_rate = 1e-7

# Dense = fully connected layer
# Dense = fully connected layer
input_layer = tf.keras.layers.Input(shape=(input_dim,))
# First parameter is output units (14 then 7 then 7 then 30) :
encoder = tf.keras.layers.Dense(encoding_dim, activation="tanh",
                                activity_regularizer=tf.keras.regularizers.l1(learning_rate))(input_layer)
encoder = tf.keras.layers.Dense(hidden_dim, activation="relu")(encoder)
decoder = tf.keras.layers.Dense(hidden_dim, activation='tanh')(encoder)
decoder = tf.keras.layers.Dense(input_dim, activation='relu')(decoder)
autoencoder = tf.keras.models.Model(inputs=input_layer, outputs=decoder)

# create data for training
dataset = kafka_dataset(servers, topic, offset, schema)

# normalize data
dataset = dataset.map(normalize_fn)

if mode == "train":
    autoencoder.compile(metrics=['accuracy'],
                        loss='mean_squared_error',
                        optimizer='adam')

    autoencoder.summary()

    # Let's keep a copy for later usage, and use dataset_training instead for training only

    # only take data from failure_occurred == false for normal case for training
    dataset_training = dataset.filter(lambda x, y: y == "false")

    # autoencoder is x => x so no y
    dataset_training = dataset_training.map(lambda x, y: x)

    # Autoencoder => Input == Output
    dataset_training = tf.data.Dataset.zip((dataset_training, dataset_training)).batch(batch_size).take(100)

    history = autoencoder.fit(dataset_training,  # Autoencoder => Input == Output dimensions!
                              epochs=nb_epoch,
                              verbose=2).history

    print("Training complete")

    # Save the model
    autoencoder.save("/" + model_file)

    # Store model into file:
    blob = bucket.blob("/" + model_file)
    blob.upload_from_filename("/" + model_file)
    print("Model stored successfully", model_file)


class OutputCallback(tf.keras.callbacks.Callback):
    """KafkaOutputCallback"""

    def __init__(self, batch_size, topic, servers):
        self._sequence = kafka_io.KafkaOutputSequence(
            topic=topic, servers=servers, configuration=kafka_config)
        self._batch_size = batch_size

    def on_predict_batch_end(self, batch, logs=None):
        index = batch * self._batch_size
        for outputs in logs['outputs']:
            for output in outputs:
                message = np.array2string(output)
                self._sequence.setitem(index, message)
                index += 1

    def flush(self):
        self._sequence.flush()


if mode == "predict":
    print("Downloading model", model_file)
    blob = bucket.blob("/" + model_file)
    blob.download_to_filename("/" + model_file)
    print("Loading model")
    # Recreate the exact same model purely from the file
    new_autoencoder = tf.keras.models.load_model("/" + model_file)

    # Create predict dataset (with 200 data points)
    # Note: we don't need to  use `filter(lambda x, y: y == "false")` anymore
    # as we will do predict for everything

    # drop y field (could be `true`, `false`, or no value ``)
    dataset_predict = dataset.map(lambda x, y: x)
    data_offset = 100

    # Use same batch_size, but result_topic
    output = OutputCallback(batch_size, result_topic, servers)

    dataset_predict = dataset_predict.batch(batch_size).skip(data_offset).take(100)

    predict_out = new_autoencoder.predict(dataset_predict, callbacks=[output])

    print("predict %s, dataset: %s", predict_out, dataset_predict)
    output.flush()
    print("Predict complete")
    # while True:
    #    dataset_predict = dataset_predict.batch(batch_size).skip(data_offset).take(100)
    #    predict = new_autoencoder.predict(dataset_predict, callbacks=[output])
    #
    #    output.flush()
    #    data_offset += 100
    #    print("Predict complete")

    # Note: usage example for training+inference
    # docker build -t tensorflow-io .
    # docker run -i -t --net=host tensorflow-io python3 cardata-v1.py localhost:9092 cardata-v1 0 cardata-v1-result
    #
    # The inference result is available:
    # from kafka import KafkaConsumer
    # consumer = KafkaConsumer('cardata-v1-result', auto_offset_reset='earliest', enable_auto_commit=False, bootstrap_servers=['localhost:9092'])
    # for message in consumer:
    #   print("MESSAGE: ", message)
