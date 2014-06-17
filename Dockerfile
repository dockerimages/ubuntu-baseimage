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

# SYSLOG
ADD /config/syslog_ng_default /etc/default/syslog-ng
#SSH
ADD /config/sshd_config /etc/ssh/sshd_config 
ADD /00_regen_ssh_host_keys.sh /etc/my_init.d/
ADD /insecure_key.pub /etc/insecure_key.pub
ADD /insecure_key /etc/insecure_key
ADD /enable_insecure_key /usr/sbin/enable_insecure_key

#INIT
ADD /my_init /sbin/my_init
ADD /runit/sshd /etc/service/sshd/run 
ADD /runit/cron /etc/service/cron/run
ADD /runit/syslog-ng /etc/service/syslog-ng/run

# ubuntu-baseimage: This tool runs a command as another user and sets $HOME.
ADD /setuser /sbin/setuser

#### Executing all Transactions in Single Processes so they can be cached and replaced better with new packages
RUN chmod 644 /etc/insecure_key* 
RUN echo "ubuntu-baseimage: Temporarily disable dpkg fsync to make building faster." && \
    echo force-unsafe-io > /etc/dpkg/dpkg.cfg.d/02apt-speedup 66 \
    echo "ubuntu-baseimage: Fix some issues with APT packages. See https://github.com/dotcloud/docker/issues/1024" && \
    dpkg-divert --local --rename --add /sbin/initctl && \
    ln -sf /bin/true /sbin/initctl && \
    echo "ubuntu-baseimage: Prevent initramfs updates from trying to run grub and lilo." && \
    echo "ubuntu-baseimage: https://journal.paul.querna.org/articles/2013/10/15/docker-ubuntu-on-rackspace/" && \
    echo "ubuntu-baseimage: http://bugs.debian.org/cgi-bin/bugreport.cgi?bug=594189" && \
    mkdir -p /etc/container_environment && \
    echo -n no > /etc/container_environment/INITRD && \
    echo "ubuntu-baseimage: Replace the 'ischroot' tool to make it always return true." && \
    echo "ubuntu-baseimage: Prevent initscripts updates from breaking /dev/shm." && \
    echo "ubuntu-baseimage: https://journal.paul.querna.org/articles/2013/10/15/docker-ubuntu-on-rackspace/" && \
    echo "ubuntu-baseimage: https://bugs.launchpad.net/launchpad/+bug/974584" && \
    dpkg-divert --local --rename --add /usr/bin/ischroot && \
    ln -sf /bin/true /usr/bin/ischroot && \
    echo "ubuntu-baseimage: Upgrade sources.list to mirrors." && \
    echo "ubuntu-baseimage: Upgrade all packages." && \
    apt-get dist-upgrade -y && \
    apt-get --no-install-recommends install -y runit syslog-ng-core logrotate openssh-server cron curl less nano vim psmisc \
    git wget curl  apt-transport-https ca-certificates language-pack-en && \
    echo "Syslog-NG: Creating some needed dirs and files" && \
    mkdir -p /var/lib/syslog-ng && \
    echo "ubuntu-baseimage:# Replace the system() source because inside Docker we" && \
    echo "ubuntu-baseimage:# can't access /proc/kmsg." && \
    sed -i -E 's/^(\s*)system\(\);/\1unix-stream("\/dev\/log");/' /etc/syslog-ng/syslog-ng.conf && \
    echo "SSHD: Creating some needed dirs and files" && \
    mkdir /var/run/sshd && \
    mkdir -p /root/.ssh && \
    chmod 700 /root/.ssh && 
    echo "INIT: Install init process." && \
    mkdir -p /etc/my_init.d && \
    mkdir -p /etc/container_environment && \
    touch /etc/container_environment.sh && \
    touch /etc/container_environment.json && \
    echo "ENV-SYSTEM: Creating some needed dirs and files" && \
    chmod 700 /etc/container_environment && \
    chmod 600 /etc/container_environment.sh /etc/container_environment.json && \
    echo "ubuntu-baseimage: Setting Locale to en_US" && \
    locale-gen en_US && \
    echo "ubuntu-baseimage: ####################### Cleanup" && \
    apt-get clean && \
    rm -rf /build && \
    rm -rf /tmp/* /var/tmp/* && \
    rm -rf /var/lib/apt/lists/* && \
    rm -f /etc/dpkg/dpkg.cfg.d/02apt-speedup && \
    rm -f /etc/ssh/ssh_host_*
    echo "ubuntu-baseimage: ## Remove useless cron entries." && \
    echo "ubuntu-baseimage: # Checks for lost+found and scans for mtab." && \
    rm -f /etc/cron.daily/standard

CMD ["/sbin/my_init"]
