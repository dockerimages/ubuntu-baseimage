FROM ubuntu:14.04
MAINTAINER Frank Lemanschik <info@dspeed.eu>

ENV HOME /root
ENV LC_ALL C
ENV DEBIAN_FRONTEND noninteractive
ENV INITRD no

################## Modify Base Ubuntu Image 

#RUN 	set -e && \
#	export LC_ALL=C && \
#	export DEBIAN_FRONTEND=noninteractive && \
#	minimal_apt_get_install='apt-get install -y --no-install-recommends' && \
#	set -x

### Adding files at Start 
ADD adduser /usr/sbin/adduser
chmod +x /usr/sbin/adduser
#### Executing all Transactions in Single Processes so they can be cached and replaced better with new packages
#RUN chmod 644 /etc/insecure_key*
ADD sources.list /etc/apt/sources.list
RUN apt-get update -y
RUN cat /etc/apt/sources.list
RUN echo "ubuntu-baseimage: Temporarily disable dpkg fsync to make building faster."
RUN echo force-unsafe-io > /etc/dpkg/dpkg.cfg.d/02apt-speedup 
RUN echo "ubuntu-baseimage: Fix some issues with APT packages. See https://github.com/dotcloud/docker/issues/1024"
RUN dpkg-divert --local --rename --add /sbin/initctl
RUN ln -sf /bin/true /sbin/initctl && \
    echo "ubuntu-baseimage: Prevent initramfs updates from trying to run grub and lilo." && \
    echo "ubuntu-baseimage: https://journal.paul.querna.org/articles/2013/10/15/docker-ubuntu-on-rackspace/" && \
    echo "ubuntu-baseimage: http://bugs.debian.org/cgi-bin/bugreport.cgi?bug=594189"
#RUN mkdir -p /etc/container_environment && \
#    echo -n no > /etc/container_environment/INITRD && \
    echo "ubuntu-baseimage: Replace the 'ischroot' tool to make it always return true." && \
    echo "ubuntu-baseimage: Prevent initscripts updates from breaking /dev/shm." && \
    echo "ubuntu-baseimage: https://journal.paul.querna.org/articles/2013/10/15/docker-ubuntu-on-rackspace/" && \
    echo "ubuntu-baseimage: https://bugs.launchpad.net/launchpad/+bug/974584" && \
    dpkg-divert --local --rename --add /usr/bin/ischroot && \
    ln -sf /bin/true /usr/bin/ischroot && \
    echo "ubuntu-baseimage: Upgrade sources.list to mirrors."
RUN apt-get --no-install-recommends install -y curl wget sudo net-tools pwgen unzip \
            language-pack-en software-properties-common \
            logrotate openssh-server cron less nano psmisc git apt-transport-https ca-certificates language-pack-en language-pack-de && \
    echo "ubuntu-baseimage: Setting Locale to en_US" && \
    locale-gen en_US && \
    echo "ubuntu-baseimage: ####################### Cleanup" && \
    echo "ubuntu-baseimage: Upgrade all packages."
RUN apt-get dist-upgrade -y && \
    apt-get clean && \
    rm -rf /build && \
    rm -rf /tmp/* /var/tmp/* && \
    rm -rf /var/lib/apt/lists/* && \
    rm -f /etc/dpkg/dpkg.cfg.d/02apt-speedup && \
    rm -f /etc/ssh/ssh_host_*
    echo "ubuntu-baseimage: ## Remove useless cron entries." && \
    echo "ubuntu-baseimage: # Checks for lost+found and scans for mtab." && \
    rm -f /etc/cron.daily/standard

### Adding files at Start 




# ubuntu-baseimage: This tool runs a command as another user and sets $HOME.

#### super visor related


#### runit related
#CMD ["/sbin/my_init"]
