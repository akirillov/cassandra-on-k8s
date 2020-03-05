FROM ubuntu:18.04

ENV JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64 \
    CASSANDRA_HOME=/opt/cassandra \
    CASSANDRA_DATA=/cassandra_data

ENV CASSANDRA_CONF=${CASSANDRA_HOME}/conf \
    CASSANDRA_LOGS=${CASSANDRA_HOME}/logs \
    PATH=$JAVA_HOME/bin:${CASSANDRA_HOME}/bin:$PATH

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      bash \
      curl \
      openjdk-8-jdk \
      python && \
    mkdir -p ${CASSANDRA_HOME} && \
    curl -L https://downloads.apache.org/cassandra/3.11.6/apache-cassandra-3.11.6-bin.tar.gz | tar xz -C ${CASSANDRA_HOME} --strip-components=1  && \
    mkdir -p  ${CASSANDRA_LOGS} && \
    useradd --no-create-home --shell /bin/bash --no-user-group cassandra && \
    rm -rf /var/cache/apt/* /root/.cache

RUN chown -R cassandra ${CASSANDRA_HOME}

ADD files /

RUN chown cassandra /ready-probe.sh /run.sh && chmod +x /ready-probe.sh /run.sh

VOLUME ["/$CASSANDRA_DATA"]

# 7000: intra-node communication
# 7001: TLS intra-node communication
# 7199: JMX
# 9042: CQL
# 9160: thrift service
EXPOSE 7000 7001 7199 9042 9160

CMD ["/bin/bash", "/run.sh"]
