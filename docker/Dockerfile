FROM python:3.12-slim

ENV DEBIAN_FRONTEND=noninteractive
ENV VIRTUAL_ENV=/opt/venv
ENV PATH="$VIRTUAL_ENV/bin:/home/user/.bun/bin:/home/user/.local/bin:$PATH"
ENV HOME=/home/user
ENV PLAYWRIGHT_BROWSERS_PATH=/ms-playwright

RUN apt-get update && apt-get install -y \
    curl wget git unzip jq build-essential \
    libglib2.0-0 libnss3 libnspr4 libatk1.0-0 libatk-bridge2.0-0 \
    libcups2 libdrm2 libdbus-1-3 libxcb1 libxkbcommon0 libx11-6 \
    libxcomposite1 libxdamage1 libxext6 libxfixes3 libxrandr2 libgbm1 \
    libpango-1.0-0 libcairo2 libasound2 \
    libwoff1 libharfbuzz-icu0 libvpx9 \
    xclip xsel wl-clipboard gosu \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://bun.sh/install | bash

RUN curl -LsSf https://astral.sh/uv/install.sh | sh

RUN npm install -g \
    opencode-ai \
    gitnexus@1.6.12 \
    @upstash/context7-mcp \
    @playwright/cli@latest

RUN mkdir -p /home/user/.local /home/user/.bun \
    /home/user/.config/opencode /home/user/.config/macrodata \
    && chown -R 1000:1000 /home/user

RUN python3 -m venv $VIRTUAL_ENV

COPY docker/requirements.txt /tmp/requirements.txt
RUN pip install --no-cache-dir -U pip \
    && pip install --no-cache-dir -r /tmp/requirements.txt

RUN playwright install --with-deps chromium && chmod -R 755 /ms-playwright

RUN git config --system --add safe.directory '*'

RUN mkdir -p /workspace && chown 1000:1000 /workspace

WORKDIR /workspace

COPY docker/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

RUN chown -R 1000:1000 /home/user

USER 1000:1000

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["opencode"]
