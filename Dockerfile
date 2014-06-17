FROM ubuntu:14.04
MAINTAINER Frank Lemanschik <info@dspeed.eu>

ENV HOME /root
ENV LC_ALL C
ENV DEBIAN_FRONTEND noninteractive
ENV APT_OPT '-y --no-install-recommends'
ENV INITRD=no

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
RUN dpkg-divert --local --rename --add /sbin/initctl
RUN ln -sf /bin/true /sbin/initctl

## Prevent initramfs updates from trying to run grub and lilo.
## https://journal.paul.querna.org/articles/2013/10/15/docker-ubuntu-on-rackspace/
## http://bugs.debian.org/cgi-bin/bugreport.cgi?bug=594189
RUN mkdir -p /etc/container_environment
RUN echo -n no > /etc/container_environment/INITRD

## Replace the 'ischroot' tool to make it always return true.
## Prevent initscripts updates from breaking /dev/shm.
## https://journal.paul.querna.org/articles/2013/10/15/docker-ubuntu-on-rackspace/
## https://bugs.launchpad.net/launchpad/+bug/974584
dpkg-divert --local --rename --add /usr/bin/ischroot
ln -sf /bin/true /usr/bin/ischroot

## Enable Ubuntu Universe and Multiverse.
RUN sed -i 's/^#\s*\(deb.*universe\)$/\1/g' /etc/apt/sources.list
RUN sed -i 's/^#\s*\(deb.*multiverse\)$/\1/g' /etc/apt/sources.list
RUN apt-get update -y

## Install HTTPS support for APT.
RUN apt-get install $APT_OPT  apt-transport-https ca-certificates

## Fix locale.
apt-get install $APT_OPT language-pack-en
locale-gen en_US

## Upgrade all packages.
RUN apt-get dist-upgrade $APT_OPT


################## System Services


RUN /build/prepare.sh && \
	/build/system_services.sh && \
	/build/utilities.sh && \
	/build/cleanup.sh

CMD ["/sbin/my_init"]
