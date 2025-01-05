FROM docker.io/node:alpine AS builder
WORKDIR /frontend/
COPY ./frontend/ .
RUN npm install
RUN npm run build

FROM docker.io/nginx:alpine
COPY ../config/nginx.prod.conf /etc/nginx/nginx.conf
COPY --from=builder /frontend/build/ /usr/share/nginx/html
