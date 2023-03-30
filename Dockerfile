FROM openjdk:8 as build-env

ENV SBT_VERSION "1.5.8"

ARG THEHIVE_VERSION=4.1.24-1

RUN apt-get update \
  && apt-get install -y apt-transport-https \
  && apt-get install -y nodejs \
			npm \
                        git \
                        libpng-dev \
                        sudo \
                        \
  && npm install -g grunt-cli \
                    bower \
  && apt-get update

RUN \
  mkdir /working/ && \
  cd /working/ && \
  curl -L -o sbt-$SBT_VERSION.deb https://repo.scala-sbt.org/scalasbt/debian/sbt-$SBT_VERSION.deb && \
  dpkg -i sbt-$SBT_VERSION.deb && \
  rm sbt-$SBT_VERSION.deb && \
  apt-get update && \
  apt-get install sbt && \
  cd && \
  rm -r /working/ && \
  sbt sbtVersion

RUN mkdir TheHive

COPY . TheHive/

WORKDIR TheHive
RUN sbt stage
#-Dsbt.rootdir=true
  #&& /opt/4.1.14/sbt clean stage \
RUN mv ./target/universal/stage /opt/thehive \
  && mv ./package/docker/entrypoint /opt/thehive/entrypoint \
  && echo "play.http.secret.key=$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 49)" >> /opt/thehive/conf/application.sample.conf \
  && mkdir /var/log/thehive \
  && apt-get purge -y git \
                      nodejs \
                      libpng-dev \
  && rm -rf /TheHive \
            /root/* \
            /root/.m2 \
            /root/.ivy2 \
            /root/.sbt \
            /var/lib/apt/lists/*

FROM openjdk:8
COPY --from=build-env /opt/thehive /opt/thehive
COPY --from=build-env /var/log/thehive /var/log/thehive

RUN useradd thehive \
  && chown -R thehive /opt/thehive \
                      /var/log/thehive \
  && mkdir /etc/thehive \
  && cp /opt/thehive/conf/application.sample.conf /etc/thehive/application.sample.conf \
  && cp /opt/thehive/conf/logback.xml /etc/thehive/logback.xml \
  && echo 'search.host = ["localhost:9200"]\n\
cortex.url = ${?CORTEX_URL}\n\
cortex.key = ${?CORTEX_KEY}\n\
play.http.secret.key = ${?PLAY_SECRET}' >> /etc/thehive/application.sample.conf \
  && chmod +x /opt/thehive/entrypoint

USER thehive

EXPOSE 9000

RUN chmod -R 777 /opt/thehive

RUN chmod -R 777 /data

WORKDIR /opt/thehive

ENTRYPOINT ["./entrypoint"]
