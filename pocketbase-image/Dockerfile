FROM alpine:3.20
RUN apk add --no-cache unzip ca-certificates curl
ARG PB_VERSION=0.22.13
RUN curl -fsSL -o /tmp/pb.zip "https://github.com/pocketbase/pocketbase/releases/download/v${PB_VERSION}/pocketbase_${PB_VERSION}_linux_arm64.zip" \
    && unzip /tmp/pb.zip -d /usr/local/bin \
    && rm /tmp/pb.zip \
    && chmod +x /usr/local/bin/pocketbase
WORKDIR /pb
VOLUME ["/pb/pb_data"]
EXPOSE 8090
ENTRYPOINT ["/usr/local/bin/pocketbase"]
CMD ["serve","--http=0.0.0.0:8090","--dir=/pb/pb_data"]

