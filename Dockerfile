FROM    ubuntu:16.04
LABEL   maintainer="MIRhosting Devs"
LABEL   version="0.3"

RUN     apt-get update
RUN     apt-get install wget lsb-release apt-utils net-tools sudo nano fail2ban software-properties-common -y

RUN     wget https://github.com/bigbluebutton/bbb-install/raw/master/bbb-install.sh
RUN     sed -i 's/3940/1024/g' bbb-install.sh
RUN     bash bbb-install.sh -v xenial-220

COPY    freeswitch.local /etc/fail2ban/jail.d/freeswitch.local

EXPOSE  80 443
