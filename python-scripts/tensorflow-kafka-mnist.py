import numpy as np
import tensorflow as tf
import kafka

# 1. MNIST Kafka Producer, run separately
(x_train, y_train), (x_test, y_test) = tf.keras.datasets.mnist.load_data()
print("train: ", (x_train.shape, y_train.shape))

producer = kafka.KafkaProducer(bootstrap_servers=['localhost:9092'])
count = 0
for (x, y) in zip(x_train, y_train):
  producer.send('xx', x.tobytes())
  producer.send('yy', y.tobytes())
  count += 1
print("count(x, y): ", count)
producer.flush()

import numpy as np
import tensorflow as tf
import tensorflow_io.kafka as kafka_io

# 2. KafkaDataset with map function
def func_x(x):
  # Decode image to (28, 28)
  x = tf.io.decode_raw(x, out_type=tf.uint8)
  x = tf.reshape(x, [28, 28])
  # Convert to float32 for tf.keras
  x = tf.image.convert_image_dtype(x, tf.float32)
  return x
def func_y(y):
  # Decode image to (,)
  y = tf.io.decode_raw(y, out_type=tf.uint8)
  y = tf.reshape(y, [])
  return y
train_images = kafka_io.KafkaDataset(['xx:0'], group='xx', eof=True).map(func_x)
train_labels = kafka_io.KafkaDataset(['yy:0'], group='yy', eof=True).map(func_y)
train_kafka = tf.data.Dataset.zip((train_images, train_labels)).batch(1)
print(train_kafka)

# 3. Keras model
model = tf.keras.Sequential([
    tf.keras.layers.Flatten(input_shape=(28, 28)),
    tf.keras.layers.Dense(128, activation=tf.nn.relu),
    tf.keras.layers.Dense(10, activation=tf.nn.softmax)
])
model.compile(optimizer='adam',
              loss='sparse_categorical_crossentropy',
              metrics=['accuracy'])
model.fit(train_kafka, epochs=5, steps_per_epoch=12000)