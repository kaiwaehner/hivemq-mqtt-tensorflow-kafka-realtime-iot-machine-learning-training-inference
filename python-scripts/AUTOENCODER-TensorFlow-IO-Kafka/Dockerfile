FROM tensorflow/tensorflow:2.0.0-py3

RUN python3 -m pip install tensorflow-io-nightly==0.10.0.dev2126 --no-deps

# For reading from the bucket
RUN python3 -m pip install google-cloud-storage tensorflow-datasets

ADD . /v

WORKDIR /v

