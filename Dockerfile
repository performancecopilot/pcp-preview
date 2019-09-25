FROM fedora:30
ENV PCP_REPO=https://github.com/performancecopilot/pcp.git
ENV PCP_VERSION=6ef5c5f6b18a78b072378a3d14e5d95c9003f43b
ENV GRAFANA_PCP_REPO=https://github.com/performancecopilot/grafana-pcp.git
ENV GRAFANA_PCP_VERSION=d5d0d5c8bfb943f366e20326d2900dc3b3f7986d

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
        kmod redis grafana bpftrace \
        $(ls /pcp-rpms/*.{x86_64,noarch}.rpm) && \
    dnf clean all && \
    touch /var/lib/pcp/pmdas/{bcc,bpftrace}/.NeedInstall && \
    systemctl enable redis pmwebd pmproxy grafana-server grafana-configuration

CMD ["/usr/sbin/init"]
