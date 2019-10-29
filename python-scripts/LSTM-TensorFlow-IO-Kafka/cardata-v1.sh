curl -s https://raw.githubusercontent.com/kaiwaehner/hivemq-mqtt-tensorflow-kafka-realtime-iot-machine-learning-training-inference/master/testdata/cardata-v1.avsc | awk -v ORS= -v OFS= '{$1=$1}1' > cardata-v1.avsc

VERSION=5.3.1
docker run -i --rm -v $PWD:/v -w /v --net=host confluentinc/cp-kafka:$VERSION bash -c '/usr/bin/kafka-topics --create --zookeeper localhost:2181 --replication-factor 1 --partitions 1 --topic cardata-v1'

docker run -i --rm -v $PWD:/v -w /v --net=host confluentinc/cp-schema-registry:$VERSION bash -c '/usr/bin/kafka-avro-console-producer --broker-list localhost:9092 --topic cardata-v1 --property value.schema=`cat cardata-v1.avsc` < cardata-v1.json'

docker run -i --rm -v $PWD:/v -w /v --net=host confluentinc/cp-kafka:$VERSION bash -c '/usr/bin/kafka-topics --create --zookeeper localhost:2181 --replication-factor 1 --partitions 1 --topic cardata-v1-result'
