ARG OORT_IMAGE=thecaliskan/oort:8.5
FROM ${OORT_IMAGE}

ARG SYMFONY_VERSION=8.1
ENV SYMFONY_VERSION=${SYMFONY_VERSION}

USER root
RUN apk add --no-cache git unzip
COPY --chown=oort:oort setup.sh /tmp/setup.sh
COPY --chown=oort:oort files/ /tmp/files/

USER oort
WORKDIR /var/www
RUN sh /tmp/setup.sh && rm -rf /tmp/setup.sh /tmp/files
