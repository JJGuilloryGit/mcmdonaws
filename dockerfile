FROM jenkins/jenkins:lts

USER root

# Install sudo and required packages
RUN apt-get update && \
    apt-get install -y sudo python3 python3-pip && \
    rm -rf /var/lib/apt/lists/*

# Add Jenkins user to sudoers
RUN echo "jenkins ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

# Install Python packages
RUN python3 -m pip install --upgrade pip && \
    python3 -m pip install --no-cache-dir mlflow pandas numpy scikit-learn

USER jenkins
