FROM    ubuntu:16.04
LABEL   maintainer="MIRhosting Devs"

RUN     apt-get update
RUN     apt-get install wget lsb-release apt-utils net-tools sudo -y

RUN     wget -qO- https://ubuntu.bigbluebutton.org/bbb-install.sh | bash -s -- -v xenial-220

EXPOSE  80 443
