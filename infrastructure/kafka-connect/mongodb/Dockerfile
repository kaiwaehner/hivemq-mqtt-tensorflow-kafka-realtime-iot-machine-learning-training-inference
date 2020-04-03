FROM confluentinc/cp-server-connect-operator:5.4.0.0
ENV CONNECT_PLUGIN_PATH="/usr/share/java,/usr/share/confluent-hub-components"
RUN confluent-hub install --no-prompt mongodb/kafka-connect-mongodb:1.0.1