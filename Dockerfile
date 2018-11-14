# Build image
FROM norionomura/swift:42 as builder

#RUN apt-get -qq update && apt-get -q -y install libssl-dev pkg-config
WORKDIR /app

RUN mkdir -p /build/lib && cp -R /usr/lib/swift/linux/*.so /build/lib

COPY Package.swift ./
COPY Sources ./Sources
COPY Tests ./Tests

RUN swift package update
RUN swift build --product Run --configuration release && mv `swift build --product Run --configuration release --show-bin-path` /build/bin

# Production image
FROM ubuntu:16.04

RUN apt-get -qq update && apt-get install -y \
  libicu55 libxml2 libbsd0 libcurl3 libatomic1 \
  libssl-dev pkg-config \
  && rm -r /var/lib/apt/lists/*

WORKDIR /app
COPY --from=builder /build/bin/Run .
COPY --from=builder /build/lib/* /usr/lib/
CMD ./Run --hostname 0.0.0.0 --port 8081
