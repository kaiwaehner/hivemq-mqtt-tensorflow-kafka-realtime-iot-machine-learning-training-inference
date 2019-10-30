import numpy as np
import tensorflow as tf
import tensorflow_io.kafka as kafka_io

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


def kafka_dataset(servers, topic, offset, schema, eof=True):
    print("Create: ", "{}:0:{}".format(topic, offset))
    dataset = kafka_io.KafkaDataset(["{}:0:{}".format(topic, offset, offset)], servers=servers, group="cardata-v1",
                                    eof=eof, config_global=kafka_config)

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
        tire_pressure_1_1,
        tire_pressure_1_2,
        tire_pressure_2_1,
        tire_pressure_2_2,
        accelerometer_1_1_value,
        accelerometer_1_2_value,
        accelerometer_2_1_value,
        accelerometer_2_2_value,
        control_unit_firmware,
        failure_occurred):
    tire_pressure_1_1 = tf.cast(tire_pressure_1_1, tf.float64)
    tire_pressure_1_2 = tf.cast(tire_pressure_1_2, tf.float64)
    tire_pressure_2_1 = tf.cast(tire_pressure_2_1, tf.float64)
    tire_pressure_2_2 = tf.cast(tire_pressure_2_2, tf.float64)

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
    tire_pressure_1_1 = scale_fn(tire_pressure_1_1, 20.0, 35.0)
    tire_pressure_1_2 = scale_fn(tire_pressure_1_2, 20.0, 35.0)
    tire_pressure_2_1 = scale_fn(tire_pressure_2_1, 20.0, 35.0)
    tire_pressure_2_2 = scale_fn(tire_pressure_2_2, 20.0, 35.0)

    # accelerometer (0, 7) => (-1.0, 1.0)
    accelerometer_1_1_value = scale_fn(accelerometer_1_1_value, 0.0, 7.0)
    accelerometer_1_2_value = scale_fn(accelerometer_1_2_value, 0.0, 7.0)
    accelerometer_2_1_value = scale_fn(accelerometer_2_1_value, 0.0, 7.0)
    accelerometer_2_2_value = scale_fn(accelerometer_2_2_value, 0.0, 7.0)

    # control_unit_firmware [1000|2000] => (-1.0, 1.0)
    control_unit_firmware = scale_fn(control_unit_firmware, 1000.0, 2000.0)

    failure_occurred = tf.cast(1 if failure_occurred is "true" else 0, tf.float64)
    # failure_occurred = tf.cast(failure_occurred, tf.string)
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
        tire_pressure_1_1,
        tire_pressure_1_2,
        tire_pressure_2_1,
        tire_pressure_2_2,
        accelerometer_1_1_value,
        accelerometer_1_2_value,
        accelerometer_2_1_value,
        accelerometer_2_2_value,
        control_unit_firmware
    ])


import sys

print("Options: ", sys.argv)

if len(sys.argv) != 4 and len(sys.argv) != 5:
    print("Usage: python3 cardata-v1.py <servers> <topic> <offset> [result_topic]")
    sys.exit(1)

servers = sys.argv[1]
topic = sys.argv[2]
offset = sys.argv[3]
result_topic = None if len(sys.argv) != 5 else sys.argv[4]

# create data for training
dataset = kafka_dataset(servers, topic, offset, schema)

# normalize data
dataset = dataset.map(normalize_fn)

features = 18
look_back = 1
batch_size = 1

# create and fit the LSTM network
model = tf.keras.models.Sequential()
model.add(tf.keras.layers.LSTM(32, activation='relu', input_shape=(look_back, features), return_sequences=True))
model.add(tf.keras.layers.LSTM(16, activation='relu', return_sequences=False))
model.add(tf.keras.layers.RepeatVector(look_back))
model.add(tf.keras.layers.LSTM(16, activation='relu', return_sequences=True))
model.add(tf.keras.layers.LSTM(32, activation='relu', return_sequences=True))
model.add(tf.keras.layers.TimeDistributed(tf.keras.layers.Dense(features)))

model.compile(metrics=['accuracy'], loss='mean_squared_error', optimizer='adam')

model.summary()

# dataset x: look_back x features (batch x look_back x features eventually)
# dataset x: window(look_back)
dataset_x = dataset.window(look_back, shift=1, drop_remainder=True)
dataset_x = dataset_x.flat_map(lambda window: window.batch(look_back))

# dataset x: 1 * features (batch x 1 x features eventually)
# dataset y: skip(look_back)
dataset_y = dataset.skip(look_back).map(lambda e: tf.expand_dims(e, 0))

dataset = tf.data.Dataset.zip((dataset_x, dataset_y)).batch(batch_size).take(1000)
print("DATASET: ", dataset)

model.fit(dataset, epochs=5, verbose=2).history

print("Training complete")

# Create predict dataset (with 200 data points)
# Note: skip the first 1000 data points which have been used for training
dataset_predict = dataset_x.batch(batch_size).skip(1000).take(200)


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


# Use same batch_size, but result_topic
output = OutputCallback(batch_size, topic=result_topic, servers=servers)

predict = model.predict(dataset_predict, callbacks=[output])

output.flush()

print("Predict complete")

# Note: usage example for training+inference
# docker build -t tensorflow-io .
# docker run -i -t --net=host tensorflow-io python3 cardata-v1.py localhost:9092 cardata-v1 0 cardata-v1-result
#
# The inference result is available:
# from kafka import KafkaConsumer
# consumer = KafkaConsumer('cardata-v1-result', auto_offset_reset='earliest', enable_auto_commit=False, bootstrap_servers=['localhost:9092'])
# for message in consumer:
#   print("MESSAGE: ", message)
