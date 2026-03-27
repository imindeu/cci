FROM ubuntu:24.04

RUN apt-get -qq update && apt-get install -y \
  libicu74 libxml2 libbsd0 libcurl4 libatomic1 \
  libssl-dev pkg-config ca-certificates \
  && update-ca-certificates \
  && rm -r /var/lib/apt/lists/*

WORKDIR /app
COPY /bin/cci .
COPY /lib/* /usr/lib/

EXPOSE 80

CMD ./cci serve --hostname 0.0.0.0 --port 80
