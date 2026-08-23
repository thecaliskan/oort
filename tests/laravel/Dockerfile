ARG OORT_IMAGE=thecaliskan/oort:8.5
FROM ${OORT_IMAGE}

ARG LARAVEL_VERSION=13.0
ENV LARAVEL_VERSION=${LARAVEL_VERSION}

USER root
RUN apk add --no-cache git unzip
COPY --chown=oort:oort setup.sh /tmp/setup.sh
COPY --chown=oort:oort files/ /tmp/files/

USER oort
WORKDIR /var/www
RUN sh /tmp/setup.sh && rm -rf /tmp/setup.sh /tmp/files
