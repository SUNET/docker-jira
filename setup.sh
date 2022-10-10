#!/bin/bash

set -e
set -x

export DEBIAN_FRONTEND noninteractive

# Update the image and install the needed tools
apt-get update && \
    apt-get -y dist-upgrade && \
    apt-get install -y \
        ssl-cert\
    && apt-get -y autoremove \
    && apt-get autoclean

# Do some more cleanup to save space
rm -rf /var/lib/apt/lists/*

# Install Atlassian Jira and helper tools and setup initial home
# directory structure.
mkdir -p                                  "${JIRA_HOME}" \
    && chmod -R 700                       "${JIRA_HOME}" \
    && chown ${RUN_USER}:${RUN_GROUP}     "${JIRA_HOME}" \
    && mkdir -p                           "${JIRA_INSTALL}/conf" \
    && curl -Ls                           "${JIRA_DOWNLOAD_URL}" \
            -o /opt/jira-software.tar.gz

if [[ "${JIRA_SHA256_CHECKSUM}" != "$(sha256sum /opt/jira-software.tar.gz | cut -d' ' -f1)" ]]; then
    echo "ERROR: SHA256 checksum of downloaded Jira installation package does not match!"
    exit 1
fi

tar -xzf /opt/jira-software.tar.gz --directory "${JIRA_INSTALL}" --strip-components=1 --no-same-owner \
    && rm -f /opt/jira-software.tar.gz \
    && mv /opt/sunet/server.xml "${JIRA_INSTALL}/conf/server.xml"\
    && chmod -R 700                       "${JIRA_INSTALL}/conf" \
    && chmod -R 700                       "${JIRA_INSTALL}/temp" \
    && chmod -R 700                       "${JIRA_INSTALL}/logs" \
    && chmod -R 700                       "${JIRA_INSTALL}/work" \
    && chown -R ${RUN_USER}:${RUN_GROUP}  "${JIRA_INSTALL}/conf" \
    && chown -R ${RUN_USER}:${RUN_GROUP}  "${JIRA_INSTALL}/temp" \
    && chown -R ${RUN_USER}:${RUN_GROUP}  "${JIRA_INSTALL}/logs" \
    && chown -R ${RUN_USER}:${RUN_GROUP}  "${JIRA_INSTALL}/work" \
    && echo -e                            "jira.home=${JIRA_HOME}" > "${JIRA_INSTALL}/atlassian-jira/WEB-INF/classes/jira-init.properties" \
    && sed -i "s/-Xms\\\${JVM_MINIMUM_MEMORY}/-Xms\\\$\{HEAP_START\}/" ${JIRA_INSTALL}/bin/setenv.sh \
    && sed -i "s/-Xmx\\\${JVM_MAXIMUM_MEMORY}/-Xmx\\\$\{HEAP_MAX\}/" ${JIRA_INSTALL}/bin/setenv.sh

# Create the start up script for Confluence
cat>/opt/atlassian/atlassian_app.sh<<'EOF'
#!/bin/bash
SERVER_XML="$JIRA_INSTALL/conf/server.xml"
CURRENT_PROXY_NAME=$(xmlstarlet sel -t -v "Server/Service/Connector[@port="8080"]/@proxyName" "${SERVER_XML}")
if [ -w "${SERVER_XML}" ]
then
  if [[ ! -z "${PROXY_NAME}" ]] && [[ ! -z "${CURRENT_PROXY_NAME}" ]]; then
    xmlstarlet ed --inplace -u "Server/Service/Connector[@port='8080']/@proxyName" -v "${PROXY_NAME}" -u "Server/Service/Connector[@port='8080']/@proxyPort" -v "${PROXY_PORT}" -u "Server/Service/Connector[@port='8080']/@scheme" -v "${PROXY_SCHEME}" "${SERVER_XML}"
  elif [ -z "${PROXY_NAME}" ]; then
    xmlstarlet ed --inplace -d "Server/Service/Connector[@port='8080']/@scheme" -d "Server/Service/Connector[@port='8080']/@proxyName" -d "Server/Service/Connector[@port='8080']/@proxyPort" "${SERVER_XML}"
  elif [ -z "${CURRENT_PROXY_NAME}" ]; then
    xmlstarlet ed --inplace -a "Server/Service/Connector[@port='8080']" -t attr -n scheme -v "${PROXY_SCHEME}" -a "Server/Service/Connector[@port='8080']" -t attr -n proxyPort -v "${PROXY_PORT}" -a "Server/Service/Connector[@port='8080']" -t attr -n proxyName -v "${PROXY_NAME}" "${SERVER_XML}"
  fi
fi
"${JIRA_INSTALL}"/bin/catalina.sh run
EOF
chmod +x /opt/atlassian/atlassian_app.sh
