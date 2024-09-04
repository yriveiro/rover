# syntax = docker/dockerfile:1

# Prep base stage
ARG TF_VERSION=1.9.5

# Build ui
FROM node:20-alpine AS ui

WORKDIR /src

# Copy specific package files
COPY ./ui/package-lock.json ./
COPY ./ui/package.json ./
COPY ./ui/babel.config.js ./

# Set Progress, Config and install
RUN npm set progress=false && npm config set depth 0 && npm install

# Copy source
# Copy Specific Directories
COPY ./ui/public ./public
COPY ./ui/src ./src

RUN NODE_OPTIONS='--openssl-legacy-provider' npm run build

# Build rover
FROM golang:1.23 AS rover

WORKDIR /src

# Copy full source
COPY . .
# Copy ui/dist from ui stage as it needs to embedded
COPY --from=ui ./src/dist ./ui/dist

# Build rover
RUN <<EOF
  go get -v golang.org/x/net/html
  CGO_ENABLED=0 GOOS=linux go build -o rover .
EOF

# Release stage
FROM hashicorp/terraform:$TF_VERSION AS release

# Copy terraform binary to the rover's default terraform path
RUN cp /bin/terraform /usr/local/bin/terraform

# Copy rover binary
COPY --from=rover /src/rover /bin/rover

RUN <<EOF
  chmod +x /bin/rover

  # Install Google Chrome
  apk --no-cache add chromium
EOF


WORKDIR /src

ENTRYPOINT [ "/bin/rover" ]
