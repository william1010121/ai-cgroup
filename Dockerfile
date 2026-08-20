FROM node:22-bookworm

# uv (user rule: always uv, never pip)
RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH="/root/.local/bin:${PATH}"

# Common build tooling. node:22-bookworm already ships node/npm/python3/gcc/git.
RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential ca-certificates curl ripgrep \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /work
