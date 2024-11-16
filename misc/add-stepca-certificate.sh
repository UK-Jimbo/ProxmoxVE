# Your CA administrative password is: ls7COdtSQgwqwLwxCqq9BQfCNuBQIbVzxyCXGj8J
# Your password is: FKHmIpn9zabzJjGhtzz4UFKniBuoRRCRZCo9wFIa
# Your CA fingerprint is : 3c71803de1271802174c5975ee1d05f499af3972689d832ecb57c19c42952a6e

wget https://dl.smallstep.com/cli/docs-cli-install/latest/step-cli_amd64.deb
sudo dpkg -i step-cli_amd64.deb

step ca bootstrap --ca-url https://step-ca.lan:9000 --fingerprint 3c71803de1271802174c5975ee1d05f499af3972689d832ecb57c19c42952a6e --install

echo "ls7COdtSQgwqwLwxCqq9BQfCNuBQIbVzxyCXGj8J" > password.txt
step ca certificate --provisioner-password-file=password.txt test.lan test.lan.crt test.lan.key
rm password.txt


# step-ca.lan is specficed in STEPCA_INIT_DNS_NAMES in step ca creation
# Basically... if you create a ct named step-ca, step-ca.lan will be added to the trusted DNS names
# In turn you need a step-ca.lan DNS record
# step ca bootstrap --ca-url https://step-ca.lan:9000 --fingerprint 3c71803de1271802174c5975ee1d05f499af3972689d832ecb57c19c42952a6e --install