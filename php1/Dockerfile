FROM php:7.2-fpm

# Install curl, kubectl, and useful tools for container breakout
RUN apt-get update && apt-get install -y curl procps psmisc && \
    # Download and install kubectl
    KUBECTL_VERSION="v1.28.0" && \
    curl -L "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl" -o /usr/local/bin/kubectl && \
    chmod +x /usr/local/bin/kubectl && \
    # Verify kubectl installation
    kubectl version --client && \
    # Clean up
    rm -rf /var/lib/apt/lists/*

# Create kube directory structure
RUN mkdir -p /.kube && \
    chmod 755 /.kube

RUN mkdir /app
COPY hello.php /app
COPY test.php /app
COPY container-info.php /app
COPY 404.php /app
COPY flag-z3ybow20r3gms3dzdykitgzuxrandomstring.php /app
