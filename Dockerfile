FROM vscojfrogrhel.vsazure.com/rhel-ubi-images/ubi8:latest

## Define some args that get passed at build time.
##
ARG TIME_STAMP

## Security Team Requirements
##
# start code here

## Infra Team Tuneables
##
# Point the rhel ubi public repos to artifactory's proxied repos
RUN sed -i 's/https\:\/\/cdn-ubi\.redhat\.com\/content\/public\/ubi/https\:\/\/vscojfrogrhel\.vsazure\.com\/artifactory\/rhel-ubi-base/g' /etc/yum.repos.d/ubi.repo

# Copy to image more repos to be included.
COPY ./rhel_8_repos/*.repo /etc/yum.repos.d/

# Make sure packages are up-to-date, patch system
# Add timestamp file for extra image tagging
RUN touch /tmp/${TIME_STAMP} && \
    yum --disableplugin=subscription-manager update -y

RUN yum --disableplugin=subscription-manager install iputils bind-utils telnet -y --nobest

ARG GF_UID="472"
ARG GF_GID="0"

ENV PATH="/usr/share/grafana/bin:$PATH" \
    GF_PATHS_CONFIG="/etc/grafana/grafana.ini" \
    GF_PATHS_DATA="/var/lib/grafana" \
    GF_PATHS_HOME="/usr/share/grafana" \
    GF_PATHS_LOGS="/var/log/grafana" \
    GF_PATHS_PLUGINS="/var/lib/grafana/plugins" \
    GF_SECURITY_ADMIN_PASSWORD="P1(kl3s4u" \
    GF_PATHS_PROVISIONING="/etc/grafana/provisioning" 

WORKDIR $GF_PATHS_HOME

COPY ./grafana-8.3.4/conf ./conf
COPY  ./grafana.ini /etc/grafana/grafana.ini
COPY  ./ldap.toml /etc/grafana/ldap.toml

RUN if [ ! `getent group "$GF_GID"` ]; then \
      addgroup -g $GF_GID grafana; \
    fi

RUN export GF_GID_NAME=`getent group $GF_GID | cut -d':' -f1` && \
    mkdir -p "$GF_PATHS_HOME/.aws" && \
    adduser -u $GF_UID -G "$GF_GID_NAME" grafana && \
    mkdir -p "$GF_PATHS_PROVISIONING/datasources" \
             "$GF_PATHS_PROVISIONING/dashboards" \
             "$GF_PATHS_PROVISIONING/notifiers" \
             "$GF_PATHS_PROVISIONING/plugins" \
             "$GF_PATHS_PROVISIONING/access-control" \
             "$GF_PATHS_LOGS" \
             "$GF_PATHS_PLUGINS" \
             "$GF_PATHS_DATA" && \
    # cp "$GF_PATHS_HOME/conf/ldap.toml" /etc/grafana/ldap.toml && \
    chown -R "grafana:$GF_GID_NAME" "$GF_PATHS_DATA" "$GF_PATHS_HOME/.aws" "$GF_PATHS_LOGS" "$GF_PATHS_PLUGINS" "$GF_PATHS_PROVISIONING" && \
    chmod -R 777 "$GF_PATHS_DATA" "$GF_PATHS_PLUGINS"&& \
    chmod -R 777 "$GF_PATHS_LOGS" && \
    chmod -R 777 "$GF_PATHS_HOME/.aws" "$GF_PATHS_PROVISIONING"

COPY ./grafana-8.3.4/bin/grafana-server ./bin/
COPY ./grafana-8.3.4/bin/grafana-cli ./bin/
COPY ./grafana-8.3.4/public ./public
COPY ./grafana-8.3.4/plugins-bundled ./plugins-bundled
COPY ./grafana-worldmap-panel /var/lib/grafana/plugins/

EXPOSE 3000
VOLUME     [ "/var/lib/grafana" ]

COPY ./run.sh /run.sh

USER grafana
ENTRYPOINT [ "/run.sh" ]
