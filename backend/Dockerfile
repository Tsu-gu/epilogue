FROM docker.io/golang:alpine AS backend-builder
WORKDIR /backend/
ENV MODE=Release
COPY ./backend/ .
RUN go build -o epilogue cmd/main.go

FROM docker.io/alpine:latest
ENV MODE=Release
ARG UNAME=epilogue
ARG UID=1000
ARG GID=1000
RUN addgroup -g $UID $UNAME && adduser -D -u $GID -G $UNAME $UNAME
USER $UNAME
WORKDIR /app
COPY --chown=$UID:$GID --from=backend-builder /backend/epilogue /app/
ENTRYPOINT /app/epilogue

