ARG PCP_REPO=performancecopilot/pcp
ARG PCP_VERSION=5c76dea4cd20bbf92a1bfd3ec9505ea3eb32e98d
ARG GRAFANA_PCP_REPO=performancecopilot/grafana-pcp
ARG GRAFANA_PCP_VERSION=master

FROM fedora:30
RUN dnf -y install \
        pkg-config make gcc flex bison \
        which sudo hostname findutils bc git cppcheck \
        rpm-build redhat-rpm-config initscripts man procps \
        avahi-devel ncurses-devel readline-devel zlib-devel \
        perl perl-devel perl-generators perl-ExtUtils-MakeMaker \
        python2-devel python3 python3-devel pylint \
        bcc-tools e2fsprogs xfsprogs libmicrohttpd-devel \
        python2 nodejs-yarn

RUN git clone https://github.com/${PCP_REPO}.git /pcp
WORKDIR /pcp
RUN git checkout ${PCP_VERSION}
RUN ./Makepkgs --without-qt --without-qt3d --without-manager --with-pmdabpftrace

RUN git clone https://github.com/${GRAFANA_PCP_REPO}.git /grafana-pcp
WORKDIR /grafana-pcp
RUN git checkout ${GRAFANA_PCP_VERSION}
RUN nodejs-yarn install && \
    nodejs-yarn build


FROM fedora:30
RUN dnf -y install \
        kmod redis grafana bpftrace

COPY --from=0 /pcp/pcp-*/build/rpm /pcp-rpms
COPY --from=0 /grafana-pcp/dist /var/lib/grafana/plugins/grafana-pcp
COPY grafana.ini /etc/grafana/grafana.ini
COPY datasource.yaml /usr/share/grafana/conf/provisioning/datasources/grafana-pcp.yaml
COPY grafana-configuration.service /etc/systemd/system

RUN cd /pcp-rpms && \
    dnf -y install $(ls *.{x86_64,noarch}.rpm) && \
    touch /var/lib/pcp/pmdas/{bcc,bpftrace}/.NeedInstall && \
    systemctl enable redis pmwebd pmproxy grafana-server grafana-configuration

CMD ["/usr/sbin/init"]
