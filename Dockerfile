# The tags that are recommended to be used for
# the base image are: latest, staging, stable
FROM docker.sunet.se/eduix/eduix-base:stable
MAINTAINER Jarkko Leponiemi "jarkko.leponiemi@eduix.fi"

# Setup useful environment variables
ENV JIRA_HOME     /var/atlassian/application-data/jira
ENV JIRA_INSTALL  /opt/atlassian/jira
ENV HEAP_START          2048m
ENV HEAP_MAX            2048m
ARG CONF_VERSION=8.13.3
ARG JIRA_SHA256_CHECKSUM=ce2bc5dbc2d5f09aee607d1857121e8f6852e515598d1a175cee5dc64daa28c1

LABEL Description="This image is used to start Atlassian Jira" Vendor="Atlassian" Version="${CONF_VERSION}"

ENV JIRA_DOWNLOAD_URL http://www.atlassian.com/software/jira/downloads/binary/atlassian-jira-software-${CONF_VERSION}.tar.gz

ENV RUN_USER            atlassian
ENV RUN_GROUP           atlassian

# Copying the Dockerfile to the image as documentation
COPY Dockerfile /
COPY server.xml /opt/sunet/server.xml
COPY setup.sh /opt/sunet/setup.sh
RUN /opt/sunet/setup.sh

USER atlassian

# Expose default HTTP connector port.
EXPOSE 8080

# Set volume mount points for installation and home directory. Changes to the
# home directory needs to be persisted as well as parts of the installation
# directory due to eg. logs.
VOLUME ["${JIRA_INSTALL}", "${JIRA_HOME}"]

# Set the default working directory as the Confluence installation directory.
WORKDIR ${JIRA_INSTALL}

# Run Atlassian Confluence as a foreground process by default.
CMD ["/opt/atlassian/atlassian_app.sh"]

