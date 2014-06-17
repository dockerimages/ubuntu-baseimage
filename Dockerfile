FROM ubuntu:14.04
MAINTAINER Frank Lemanschik <info@dspeed.eu>

ENV HOME /root
ENV LC_ALL C
ENV DEBIAN_FRONTEND noninteractive
ENV APT_OPT '-y --no-install-recommends'
ENV INITRD no

RUN mkdir /build
ADD . /build
################## Modify Base Ubuntu Image 

#RUN 	set -e && \
#	export LC_ALL=C && \
#	export DEBIAN_FRONTEND=noninteractive && \
#	minimal_apt_get_install='apt-get install -y --no-install-recommends' && \
#	set -x

## Temporarily disable dpkg fsync to make building faster.
RUN echo force-unsafe-io > /etc/dpkg/dpkg.cfg.d/02apt-speedup

## Fix some issues with APT packages.
## See https://github.com/dotcloud/docker/issues/1024
RUN dpkg-divert --local --rename --add /sbin/initctl && \
    ln -sf /bin/true /sbin/initctl

## Prevent initramfs updates from trying to run grub and lilo.
## https://journal.paul.querna.org/articles/2013/10/15/docker-ubuntu-on-rackspace/
## http://bugs.debian.org/cgi-bin/bugreport.cgi?bug=594189
RUN mkdir -p /etc/container_environment && \
    echo -n no > /etc/container_environment/INITRD

## Replace the 'ischroot' tool to make it always return true.
## Prevent initscripts updates from breaking /dev/shm.
## https://journal.paul.querna.org/articles/2013/10/15/docker-ubuntu-on-rackspace/
## https://bugs.launchpad.net/launchpad/+bug/974584
RUN dpkg-divert --local --rename --add /usr/bin/ischroot && \
    ln -sf /bin/true /usr/bin/ischroot

## Enable Ubuntu Universe and Multiverse.
#RUN sed -i 's/^#\s*\(deb.*universe\)$/\1/g' /etc/apt/sources.list && \
#    sed -i 's/^#\s*\(deb.*multiverse\)$/\1/g' /etc/apt/sources.list && \
#    apt-get update -y

## Install HTTPS support for APT.
RUN apt-get install $APT_OPT  apt-transport-https ca-certificates

## Fix locale.
RUN apt-get install $APT_OPT language-pack-en && \
    locale-gen en_US

## Upgrade all packages.
RUN apt-get dist-upgrade $APT_OPT

################## System Services

## Install init process.
ADD /my_init /sbin/my_init

RUN mkdir -p /etc/my_init.d && \
    mkdir -p /etc/container_environment && \
    touch /etc/container_environment.sh && \
    touch /etc/container_environment.json && \
    chmod 700 /etc/container_environment && \
    chmod 600 /etc/container_environment.sh /etc/container_environment.json

## Install runit.
RUN apt-get install $APT_OPT runit

## Install a syslog daemon.
RUN apt-get install $APT_OPT syslog-ng-core && \
    mkdir /etc/service/syslog-ng && \
    cp /build/runit/syslog-ng /etc/service/syslog-ng/run && \
    mkdir -p /var/lib/syslog-ng && \
    cp /build/config/syslog_ng_default /etc/default/syslog-ng && \

# Replace the system() source because inside Docker we
# can't access /proc/kmsg.
RUN sed -i -E 's/^(\s*)system\(\);/\1unix-stream("\/dev\/log");/' /etc/syslog-ng/syslog-ng.conf

## Install logrotate.
RUN apt-get install $APT_OPT logrotate

## Install the SSH server.
RUN apt-get install $APT_OPT openssh-server && \
    mkdir /var/run/sshd
    mkdir /etc/service/sshd
    cp /build/runit/sshd /etc/service/sshd/run
    cp /build/config/sshd_config /etc/ssh/sshd_config
    cp /build/00_regen_ssh_host_keys.sh /etc/my_init.d/

## Install default SSH key for root and app.
RUN mkdir -p /root/.ssh && \
    chmod 700 /root/.ssh && \
    chown root:root /root/.ssh && \
    cp /build/insecure_key.pub /etc/insecure_key.pub && \
    cp /build/insecure_key /etc/insecure_key && \
    chmod 644 /etc/insecure_key* && \
    chown root:root /etc/insecure_key* && \
    cp /build/enable_insecure_key /usr/sbin/

## Install cron daemon.
RUN apt-get install $APT_OPT cron && \
    mkdir /etc/service/cron && \
    cp /build/runit/cron /etc/service/cron/run


####################### Utils 
## Often used tools.
RUN apt-get install $APT_OPT curl less nano vim psmisc git wget curl

## This tool runs a command as another user and sets $HOME.
ADD /setuser /sbin/setuser

####################### Cleanup
## Remove useless cron entries.
# Checks for lost+found and scans for mtab.
RUN rm -f /etc/cron.daily/standard 

RUN apt-get clean && \
rm -rf /build && \
rm -rf /tmp/* /var/tmp/* && \
rm -rf /var/lib/apt/lists/* && \
rm -f /etc/dpkg/dpkg.cfg.d/02apt-speedup && \
rm -f /etc/ssh/ssh_host_*

CMD ["/sbin/my_init"]
