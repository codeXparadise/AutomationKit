FROM n8nio/runners:latest

USER root

# Install required external Python libraries into the Python runner environment.
# The official n8n task runner docs use `uv pip install` for extending n8nio/runners.
RUN cd /opt/runners/task-runner-python && uv pip install \
    numpy \
    pandas \
    redis \
    yt-dlp \
    requests \
    pydantic

# Copy custom task runners configuration
COPY n8n-task-runners.json /etc/n8n-task-runners.json

USER runner
