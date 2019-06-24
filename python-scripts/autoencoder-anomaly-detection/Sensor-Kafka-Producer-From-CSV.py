# Part 1: Produce data into Kafka (optional)
# $ pip3 install kafka-python
import kafka

producer = kafka.KafkaProducer(bootstrap_servers=['localhost:9092'])

# NOTE: Data from https://www.kaggle.com/mlg-ulb/creditcardfraud/data
with open('creditcard.csv', 'r') as f:
  next(f) # skip header line
  count = 0
  for line in f:
    producer.send('creditcard', line.rstrip().encode())
    count += 1
  print(count, "records has been produced in 'creditcard'")
producer.flush()
