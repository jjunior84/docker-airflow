# VERSION 1.10.10
# AUTHOR: Jonatas Junior
# DESCRIPTION: Image for Airflow 1.10.10
# BUILD: docker build --rm -t buzz84/docker-airflow .
# SOURCE: https://github.com/jjunior84/docker-airflow
# REFERENCE SOURCE: https://hub.docker.com/r/apache/airflow & https://hub.docker.com/r/puckel/docker-airflow

FROM python:3.7-slim

# Never prompts the user for choices on installation/configuration of packages
ENV DEBIAN_FRONTEND noninteractive
ENV TERM linux

# Airflow arguments
ARG AIRFLOW_VERSION=1.10.10
ARG AIRFLOW_CONSTRAINT_BASE="https://raw.githubusercontent.com/apache/airflow/"
ARG AIRFLOW_USER_HOME=/opt/airflow
ARG AIRFLOW_EXTRAS="crypto,celery,postgres,hive,jdbc,mysql,ssh,slack,redis"
ARG AIRFLOW_DEPS=""
ENV AIRFLOW_GPL_UNIDECODE yes
ENV AIRFLOW_HOME=${AIRFLOW_USER_HOME}

# Python arguments
ARG PYTHON_MAJOR_MINOR_VERSION="3.6"
ARG PYTHON_DEPS=""

# Make sure debian install is used language variables set
ENV LANGUAGE en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LC_ALL en_US.UTF-8
ENV LC_CTYPE en_US.UTF-8
ENV LC_MESSAGES en_US.UTF-8

RUN set -ex \
    && buildDeps=' \
        freetds-dev \
        libkrb5-dev \
        libsasl2-dev \
        libssl-dev \
        libffi-dev \
        libpq-dev \
        git \
    ' \
    && apt-get update -yqq \
    && apt-get upgrade -yqq \
    && apt-get install -yqq --no-install-recommends \
        $buildDeps \
        freetds-bin \
        build-essential \
        default-libmysqlclient-dev \
        apt-utils \
        curl \
        rsync \
        netcat \
        locales \
        dos2unix \
        gnupg \
        nano \
        python2 \
        jq \
    && sed -i 's/^# en_US.UTF-8 UTF-8$/en_US.UTF-8 UTF-8/g' /etc/locale.gen \
    && locale-gen \
    && update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 \
    && useradd -ms /bin/bash -d ${AIRFLOW_USER_HOME} airflow \
    && pip install -U pip setuptools wheel \
    && pip install pytz \
    && pip install pyOpenSSL \
    && pip install ndg-httpsclient \
    && pip install pyasn1 

# Install MySQL client from Oracle repositories (Debian installs mariadb)
RUN KEY="A4A9406876FCBD3C456770C88C718D3B5072E1F5" \
    && GNUPGHOME="$(mktemp -d)" \
    && export GNUPGHOME \
    && for KEYSERVER in $(shuf -e \
            ha.pool.sks-keyservers.net \
            hkp://p80.pool.sks-keyservers.net:80 \
            keyserver.ubuntu.com \
            hkp://keyserver.ubuntu.com:80 \
            pgp.mit.edu) ; do \
          gpg --keyserver "${KEYSERVER}" --recv-keys "${KEY}" && break || true ; \
       done \
    && gpg --export "${KEY}" | apt-key add - \
    && gpgconf --kill all \
    rm -rf "${GNUPGHOME}"; \
    apt-key list > /dev/null \
    && echo "deb http://repo.mysql.com/apt/debian/ stretch mysql-5.7" | tee -a /etc/apt/sources.list.d/mysql.list \
    && apt-get update \
    && apt-get install --no-install-recommends -y \
        libmysqlclient-dev \
        mysql-client \
    && apt-get autoremove -yqq --purge \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*    

# Preparing and copying requirment.txt
# It will copy your own requiment.txt or download the one keep by apache-airflow (too much requirements)
###
ENV CONSTRAINT_REQUIREMENTS="${AIRFLOW_CONSTRAINT_BASE}${AIRFLOW_VERSION}/requirements/requirements-python${PYTHON_MAJOR_MINOR_VERSION}.txt"
WORKDIR /opt/airflow
ADD "${CONSTRAINT_REQUIREMENTS}" /requirements_build.txt

# Install Airflow considering Extra and Deps
RUN pip install apache-airflow[${AIRFLOW_EXTRAS}${AIRFLOW_DEPS:+,}${AIRFLOW_DEPS}]==${AIRFLOW_VERSION} \
    --constraint /requirements_build.txt \
    && if [ -n "${PYTHON_DEPS}" ]; then pip install ${PYTHON_DEPS}; fi \
    && apt-get purge --auto-remove -yqq $buildDeps \
    && apt-get autoremove -yqq --purge \
    && apt-get clean \
    && rm -rf \
        /var/lib/apt/lists/* \
        /tmp/* \
        /var/tmp/* \
        /usr/share/man \
        /usr/share/doc \
        /usr/share/doc-base

# Set RBAC user interface if the version of airflow installed have it
RUN \
    AIRFLOW_SITE_PACKAGE="/root/.local/lib/python${PYTHON_MAJOR_MINOR_VERSION}/site-packages/airflow"; \
    if [[ -f "${AIRFLOW_SITE_PACKAGE}/www_rbac/package.json" ]]; then \
        WWW_DIR="${AIRFLOW_SITE_PACKAGE}/www_rbac"; \
    elif [[ -f "${AIRFLOW_SITE_PACKAGE}/www/package.json" ]]; then \
        WWW_DIR="${AIRFLOW_SITE_PACKAGE}/www"; \
    fi; \
    if [[ ${WWW_DIR:=} != "" ]]; then \
        yarn --cwd "${WWW_DIR}" install --frozen-lockfile --no-cache; \
        yarn --cwd "${WWW_DIR}" run prod; \
        rm -rf "${WWW_DIR}/node_modules"; \
    fi        

COPY ./entrypoint.sh /entrypoint.sh
COPY ./airflow.cfg ${AIRFLOW_USER_HOME}/airflow.cfg
#COPY script/*  ${AIRFLOW_USER_HOME}/

RUN chown -R airflow: ${AIRFLOW_USER_HOME}

EXPOSE 8080 5555 8793 8081

RUN curl -sSL https://sdk.cloud.google.com | bash -s -- --install-dir '/usr/local'
ENV PATH $PATH:/usr/local/google-cloud-sdk/bin

RUN dos2unix /entrypoint.sh 
RUN chmod +x /entrypoint.sh

USER airflow
WORKDIR ${AIRFLOW_USER_HOME}
ENTRYPOINT ["/entrypoint.sh"]
CMD ["webserver"] # set default arg for entrypoint
