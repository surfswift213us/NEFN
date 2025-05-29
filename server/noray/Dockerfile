FROM ubuntu:22.04 as builder

# Install build dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    git \
    libopus-dev \
    libssl-dev \
    pkg-config \
    && rm -rf /var/lib/apt/lists/*

# Copy the source code
COPY . /src
WORKDIR /src

# Build the server
RUN cmake . && make

FROM ubuntu:22.04

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    libopus0 \
    libssl3 \
    && rm -rf /var/lib/apt/lists/*

# Copy the built executable
COPY --from=builder /src/noray-server /usr/local/bin/

# Set up environment variables
ENV NORAY_PORT=7352
ENV NORAY_QUALITY=5

# Expose the port
EXPOSE ${NORAY_PORT}

# Run the server
CMD ["/usr/local/bin/noray-server"] 