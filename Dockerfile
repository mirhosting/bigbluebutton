FROM    ubuntu:18.04
LABEL   maintainer="MIRhosting Devs"
LABEL   version="0.6"

RUN     apt-get update
RUN     apt-get install wget lsb-release apt-utils net-tools sudo nano fail2ban software-properties-common openssh-server logrotate gawk -y

RUN     wget https://github.com/bigbluebutton/bbb-install/raw/master/bbb-install.sh
RUN     sed -i 's/3940/1024/g' bbb-install.sh
RUN     bash bbb-install.sh -v bionic-23; exit 0

COPY    freeswitch.local /etc/fail2ban/jail.d/freeswitch.local
COPY    install-greenlight.sh /root/install-greenlight.sh
COPY    update-ssl.sh /root/update-ssl.sh

EXPOSE  80 443 5090 5066 8888 5080 8021 1935 9999 5070 8081 8082 7443 3000
