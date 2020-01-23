FROM fedora:31
ENV PCP_REPO=https://github.com/performancecopilot/pcp.git
ENV PCP_VERSION=46a90c589c998df294b15929a9392867c57659d8
ENV GRAFANA_PCP_REPO=https://github.com/performancecopilot/grafana-pcp.git
ENV GRAFANA_PCP_VERSION=4d3b907ff453f2f6a09c26322a1b5439b4e5d6e8

RUN dnf -y install \
        pkg-config make gcc flex bison \
        which sudo hostname findutils bc git cppcheck \
        rpm-build redhat-rpm-config initscripts man procps \
        avahi-devel ncurses-devel readline-devel zlib-devel \
        perl perl-devel perl-generators perl-ExtUtils-MakeMaker \
        python2-devel python3 python3-devel pylint \
        bcc-tools bpftrace e2fsprogs xfsprogs libmicrohttpd-devel \
        libuv-devel openssl-devel python2 \
        nodejs-yarn

WORKDIR /pcp
RUN git clone ${PCP_REPO} . && git checkout ${PCP_VERSION}
RUN sed 's@/bin/hostname@hostname@g' -i ./build/rpm/pcp.spec.in
RUN ./Makepkgs --without-qt --without-qt3d --without-manager

WORKDIR /grafana-pcp
RUN git clone ${GRAFANA_PCP_REPO} . && git checkout ${GRAFANA_PCP_VERSION}
RUN nodejs-yarn install && nodejs-yarn build


FROM fedora:31
COPY --from=0 /pcp/pcp-*/build/rpm /pcp-rpms
COPY --from=0 /grafana-pcp/dist /var/lib/grafana/plugins/grafana-pcp
COPY grafana-configuration.service /etc/systemd/system

RUN dnf -y install dnf-plugins-core && \
    dnf -y copr enable agerstmayr/bpftrace && \
    dnf -y install \
        kmod procps redis grafana bcc-tools bpftrace \
        $(ls /pcp-rpms/*.{x86_64,noarch}.rpm) && \
    dnf clean all && \
    touch /var/lib/pcp/pmdas/{bcc,bpftrace}/.NeedInstall && \
    systemctl enable redis pmcd pmproxy grafana-server grafana-configuration

COPY grafana.ini /etc/grafana/grafana.ini
COPY datasource.yaml /usr/share/grafana/conf/provisioning/datasources/grafana-pcp.yaml
COPY bpftrace.conf /var/lib/pcp/pmdas/bpftrace/bpftrace.conf

CMD ["/usr/sbin/init"]
