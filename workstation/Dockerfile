FROM php:8.3-apache-bookworm

ENV DEBIAN_FRONTEND=noninteractive \
    COMPOSER_ALLOW_SUPERUSER=1 \
    COMPOSER_HOME=/opt/composer \
    PATH="/opt/ai-venv/bin:/opt/composer/vendor/bin:${PATH}" \
    NODE_VERSION=22.23.3

RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        git \
        unzip \
        zip \
        jq \
        ripgrep \
        openssh-client \
        python3 \
        python3-pip \
        python3-venv \
        libzip-dev \
        libicu-dev \
        libxml2-dev \
        pkg-config \
        xz-utils \
    && docker-php-ext-install -j"$(nproc)" pdo_mysql zip intl opcache \
    && a2enmod rewrite \
    && mkdir -p /etc/ssh/ssh_config.d /opt/ai \
    && rm -rf /var/lib/apt/lists/*

ARG TARGETARCH
RUN case "${TARGETARCH}" in \
        amd64) node_arch=x64 ;; \
        arm64) node_arch=arm64 ;; \
        *) echo "Arquitectura no soportada: ${TARGETARCH}" >&2; exit 1 ;; \
    esac \
    && curl -fsSL "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-${node_arch}.tar.xz" -o /tmp/node.tar.xz \
    && tar -xJf /tmp/node.tar.xz -C /usr/local --strip-components=1 \
    && rm /tmp/node.tar.xz \
    && npm install -g prettier eslint \
    && npm cache clean --force

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

RUN composer global require --no-interaction --prefer-dist \
        phpstan/phpstan:^2 \
        friendsofphp/php-cs-fixer:^3 \
    && python3 -m venv /opt/ai-venv \
    && /opt/ai-venv/bin/pip install --no-cache-dir --upgrade pip \
    && /opt/ai-venv/bin/pip install --no-cache-dir aider-chat oracledb

COPY apache-workspace.conf /etc/apache2/sites-available/000-default.conf
COPY ssh_config /etc/ssh/ssh_config.d/dev.conf
COPY dev.ini /usr/local/etc/php/conf.d/dev.ini
COPY phpstan.neon /opt/ai/phpstan.neon
COPY .prettierrc.json /opt/ai/.prettierrc.json
COPY CODING.md /opt/ai/CODING.md
COPY plsql.py /usr/local/bin/plsql
COPY ai.sh /usr/local/bin/ai
COPY entrypoint.sh /usr/local/bin/entrypoint.sh

RUN chmod 755 /usr/local/bin/plsql /usr/local/bin/ai /usr/local/bin/entrypoint.sh \
    && ln -sf /opt/ai-venv/bin/aider /usr/local/bin/aider \
    && ln -sf /opt/ai-venv/bin/python3 /usr/local/bin/python3 \
    && ln -sf /opt/ai-venv/bin/pip /usr/local/bin/pip \
    && ln -sf /opt/composer/vendor/bin/phpstan /usr/local/bin/phpstan \
    && ln -sf /opt/composer/vendor/bin/php-cs-fixer /usr/local/bin/php-cs-fixer \
    && mkdir -p /opt/ai /workspace /root/.ssh \
    && git config --global --add safe.directory /workspace \
    && git config --global init.defaultBranch main

WORKDIR /workspace
EXPOSE 80
ENTRYPOINT ["entrypoint.sh"]
CMD ["sleep", "infinity"]
