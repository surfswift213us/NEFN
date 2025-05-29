FROM ubuntu:22.04

# Install required dependencies
RUN apt-get update && apt-get install -y \
    ca-certificates \
    curl \
    wget \
    git \
    build-essential \
    pkg-config \
    libssl-dev \
    supervisor \
    && rm -rf /var/lib/apt/lists/*

# Install Nakama
RUN curl -L -o nakama.tar.gz https://github.com/heroiclabs/nakama/releases/download/v3.17.0/nakama-3.17.0-linux-amd64.tar.gz \
    && tar xvzf nakama.tar.gz \
    && mv nakama /usr/local/bin \
    && rm nakama.tar.gz

# Create necessary directories
RUN mkdir -p /nakama/data /nakama/modules /etc/nakama

# Copy configuration files
COPY config/nakama.yml /etc/nakama/
COPY config/modules /nakama/modules/

# Set up supervisord configuration
COPY config/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Expose ports
# Nakama API
EXPOSE 7350
# Nakama gRPC
EXPOSE 7349
# ENet
EXPOSE 7351
# Noray VOIP
EXPOSE 7352

# Create a directory for the server
WORKDIR /app

# Copy the server files
COPY server/ .

# Set up environment variables
ENV NAKAMA_PORT=7350
ENV ENET_PORT=7351
ENV NORAY_PORT=7352

# Start supervisor which will manage all our processes
CMD ["/usr/bin/supervisord"] 