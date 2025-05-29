FROM ubuntu:22.04 as builder

# Install build dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    git \
    libenet-dev \
    && rm -rf /var/lib/apt/lists/*

# Copy the source code
COPY . /src
WORKDIR /src

# Build the server
RUN cmake . && make

FROM ubuntu:22.04

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    libenet7 \
    && rm -rf /var/lib/apt/lists/*

# Copy the built executable
COPY --from=builder /src/enet-server /usr/local/bin/

# Set up environment variables
ENV ENET_PORT=7351

# Expose the port
EXPOSE ${ENET_PORT}

# Run the server
CMD ["/usr/local/bin/enet-server"] 