# Part 2: KafkaDataset
# $ pip3 install tensorflow==2.0.0b1
# $ pip3 install tensorflow-io-2.0-preview
import tensorflow as tf
import tensorflow_io.kafka as kafka_io

# NOTE: From original model
nb_epoch = 5
batch_size = 32

# Autoencoder: 30 => 14 => 7 => 7 => 14 => 30 dimensions
input_dim = 30 # train_x.shape[1] #num of columns, 30
encoding_dim = 14
hidden_dim = int(encoding_dim / 2) #i.e. 7
learning_rate = 1e-7

# Dense = fully connected layer
input_layer = tf.keras.layers.Input(shape=(input_dim, ))
# First parameter is output units (14 then 7 then 7 then 30) :
encoder = tf.keras.layers.Dense(encoding_dim, activation="tanh", activity_regularizer=tf.keras.regularizers.l1(learning_rate))(input_layer)
encoder = tf.keras.layers.Dense(hidden_dim, activation="relu")(encoder)
decoder = tf.keras.layers.Dense(hidden_dim, activation='tanh')(encoder)
decoder = tf.keras.layers.Dense(input_dim, activation='relu')(decoder)
autoencoder = tf.keras.models.Model(inputs=input_layer, outputs=decoder)


autoencoder.compile(metrics=['accuracy'],
                    loss='mean_squared_error',
                    optimizer='adam')

# NOTE: KafkaDataset processing
def process_csv(entry):
  # "Time","V1","V2","V3","V4","V5","V6","V7","V8","V9","V10","V11","V12","V13","V14","V15","V16","V17","V18","V19","V20","V21","V22","V23","V24","V25","V26","V27","V28","Amount","Class"
  return tf.io.decode_csv(entry, [[0.0], *[[0.0] for i in range(28)], [0.0], [""]])

creditcard_dataset = kafka_io.KafkaDataset(['creditcard:0'], group='creditcard', eof=True).batch(batch_size).map(process_csv)

def process_x_y(*entry):
  return (tf.stack(entry[0:30], 1), tf.strings.to_number(entry[30], out_type=tf.int32))

train_dataset = creditcard_dataset.map(process_x_y)
print(train_dataset)

# NOTE: model.fit()
# NOTE: "Time" and "Amount" are not transformed with the following yet
# df_norm['Time'] = StandardScaler().fit_transform(df_norm['Time'].values.reshape(-1, 1))
# df_norm['Amount'] = StandardScaler().fit_transform(df_norm['Amount'].values.reshape(-1, 1))
# Runtime transformation of the above, may require all data available which may defeat the purpose of "streaming" data
autoencoder.fit(train_dataset, epochs=nb_epoch)
