# fake some events needed for correct startup other services

description "In-Container Upstart Fake Events"

start on startup

script
rm -rf /var/run/*.pid
rm -rf /var/run/network/*
/sbin/initctl emit stopped JOB=udevtrigger --no-wait
/sbin/initctl emit started JOB=udev --no-wait
/sbin/initctl emit runlevel RUNLEVEL=3 --no-wait
end script
