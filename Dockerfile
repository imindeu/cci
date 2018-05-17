FROM norionomura/swift:41

WORKDIR /app

COPY Package.swift ./
COPY Sources ./Sources
COPY Tests ./Tests

RUN swift package update
RUN swift build --product Run --configuration release
CMD .build/release/Run --hostname 0.0.0.0 --port 8081
