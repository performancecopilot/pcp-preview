FROM fedora:30
ENV PCP_REPO=https://github.com/performancecopilot/pcp.git
ENV PCP_VERSION=a8873f7b52fb5bc67d1690d04b0c6e96ae69d83d
ENV GRAFANA_PCP_REPO=https://github.com/performancecopilot/grafana-pcp.git
ENV GRAFANA_PCP_VERSION=9b70df041624b988b2c519172498185520c4677d

RUN dnf -y install \
        pkg-config make gcc flex bison \
        which sudo hostname findutils bc git cppcheck \
        rpm-build redhat-rpm-config initscripts man procps \
        avahi-devel ncurses-devel readline-devel zlib-devel \
        perl perl-devel perl-generators perl-ExtUtils-MakeMaker \
        python2-devel python3 python3-devel pylint \
        bcc-tools e2fsprogs xfsprogs libmicrohttpd-devel \
        libuv-devel openssl-devel \
        python2 nodejs-yarn

RUN git clone ${PCP_REPO} /pcp
WORKDIR /pcp
RUN git checkout ${PCP_VERSION}
RUN ./Makepkgs --without-qt --without-qt3d --without-manager --with-pmdabpftrace

RUN git clone ${GRAFANA_PCP_REPO} /grafana-pcp
WORKDIR /grafana-pcp
RUN git checkout ${GRAFANA_PCP_VERSION}
RUN nodejs-yarn install && \
    nodejs-yarn build


FROM fedora:30
COPY --from=0 /pcp/pcp-*/build/rpm /pcp-rpms
COPY --from=0 /grafana-pcp/dist /var/lib/grafana/plugins/grafana-pcp
COPY grafana.ini /etc/grafana/grafana.ini
COPY datasource.yaml /usr/share/grafana/conf/provisioning/datasources/grafana-pcp.yaml
COPY grafana-configuration.service /etc/systemd/system

RUN dnf -y install \
        kmod procps redis grafana bpftrace \
        $(ls /pcp-rpms/*.{x86_64,noarch}.rpm) && \
    dnf clean all && \
    touch /var/lib/pcp/pmdas/{bcc,bpftrace}/.NeedInstall && \
    systemctl enable redis pmcd pmproxy grafana-server grafana-configuration

COPY bpftrace.conf /var/lib/pcp/pmdas/bpftrace/bpftrace.conf
CMD ["/usr/sbin/init"]
