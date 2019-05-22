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