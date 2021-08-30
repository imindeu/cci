FROM ubuntu:16.04

RUN apt-get -qq update && apt-get install -y \
  libicu55 libxml2 libbsd0 libcurl3 libatomic1 \
  libssl-dev pkg-config \
  && rm -r /var/lib/apt/lists/*

WORKDIR /app
COPY /build/bin/Run .
COPY /build/lib/* /usr/lib/

EXPOSE 8081

CMD ./Run --hostname 0.0.0.0 --port 8081
