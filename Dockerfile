FROM --platform=linux/amd64 redhat/ubi9:latest

RUN dnf swap -y curl-minimal curl 

RUN dnf install -y rrdtool httpd wget pcre make gcc gcc-c++ tar pcre-devel openssl-devel \
    zlib-devel procps-ng nmap-ncat net-tools git hostname vim \
    && dnf clean all

RUN cd /tmp \
    && curl https://rpmfind.net/linux/centos-stream/9-stream/BaseOS/x86_64/os/Packages/libtirpc-1.3.3-6.el9.x86_64.rpm \
    -o libtirpc-1.3.3-6.el9.x86_64.rpm \
    && curl https://rpmfind.net/linux/centos-stream/9-stream/CRB/x86_64/os/Packages/libtirpc-devel-1.3.3-6.el9.x86_64.rpm \
    -o libtirpc-devel-1.3.3-6.el9.x86_64.rpm \
    && dnf install -y ./libtirpc-1.3.3-6.el9.x86_64.rpm \
            ./libtirpc-devel-1.3.3-6.el9.x86_64.rpm \
    && rm -rf libtirpc*


RUN cd /tmp \
    && wget https://rpmfind.net/linux/centos-stream/9-stream/CRB/x86_64/os/Packages/rrdtool-devel-1.7.2-21.el9.x86_64.rpm \
    && dnf -y install rrdtool-devel-1.7.2-21.el9.x86_64.rpm && rm -rf rrdtool-devel-1.7.2-21.el9.x86_64.rpm


RUN useradd -s /bin/bash -M xymon && mkdir /home/xymon && chown -R xymon:xymon /home/xymon

# cache control
ENV TEST=3

RUN mkdir /home/build && cd /home/build && git clone https://github.com/bizmonx/xymon.git \
    && cd /home/build/xymon

ADD Makefile /home/build/xymon/Makefile

ENV LD_LIBRARY_PATH=/usr/local/lib

RUN cd /home/build/xymon && chmod +rx /home/xymon -R && make && make install

RUN cp /home/xymon/server/etc/xymon-apache.conf /etc/httpd/conf.d/ 

RUN sed -i 's/Listen 80/Listen 8080/' /etc/httpd/conf/httpd.conf

RUN echo "Mutex posixsem" >> /etc/httpd/conf/httpd.conf
RUN echo "ServerName localhost" >> /etc/httpd/conf/httpd.conf

RUN chown -R xymon:xymon /var/run/httpd /var/www \
    /run/httpd /etc/httpd /var/log/httpd

ENV TEST=0


RUN chown xymon:xymon /home/xymon -R && chmod +w /home/xymon -R


EXPOSE 8080
EXPOSE 1984
EXPOSE 1976

USER xymon
WORKDIR /home/xymon


ENV XYMON_HOST=127.0.0.1 XYMON_PORT=1984

ENV TZ=Europe/Brussels
# CMD ["/home/xymon/scripts/startup-ubi.sh"]

 

