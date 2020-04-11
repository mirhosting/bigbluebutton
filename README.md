# bigbluebutton
Simple docker container build with BigBlueButton to be used with MIRhosting Container PaaS

Get your BigBlueButton installed within one-click and pay as low as 0.05 euro per hour real usage here: https://mirhosting.com/en/bbb

# IMPORTANT NOTE
Since we are using "automated build" to build docker container in Docker Hub, its advised to run command like:

```bash /bbb-install.sh -v xenial-220 -s ${env.domain} -e ${user.email}```

directly after you deploy your docker container to make sure everything installed correctly, updated and secured with Lets Encrypt certificate.

If you install it within MIRhosting Container PaaS, you can skip it since we have all necessary hooks already implemented during installation.
