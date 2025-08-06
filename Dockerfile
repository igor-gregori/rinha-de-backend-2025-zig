FROM alpine:3.20

RUN apk add --no-cache ca-certificates

WORKDIR /app

COPY zig-out/bin/rinha_de_backend_2025_zig ./payment_proxy

CMD ["./payment_proxy"]