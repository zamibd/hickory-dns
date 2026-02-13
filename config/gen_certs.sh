#!/usr/bin/env bash

set -euxo pipefail

OPENSSL=openssl

# Get the directory where the script is located
SCRIPT_DIR=$(dirname "$0")
CERTS_DIR="$SCRIPT_DIR/certs"

mkdir -p "$CERTS_DIR"
cd "$CERTS_DIR"

# Check if certificates already exist
for i in ca.key ca.pem cert_key.pem cert.csr cert.pem cert.p12 ; do
    [ -f $i ] && echo "$i exists" && exit 1;
done


echo 

cat <<-EOF > ca.conf
[req]
prompt = no
x509_extensions = v3_ca
distinguished_name = dn

[dn]
C = US
ST = California
L = San Francisco
O = Hickory DNS
CN = root.hickory-dns.org

[v3_ca]
basicConstraints = critical,CA:TRUE
keyUsage = critical, keyCertSign, cRLSign
subjectAltName = @alt_names
 
[alt_names]
DNS.1 = root.hickory-dns.org
EOF

# CA
echo "----> Generating CA <----"
${OPENSSL:?} req -x509 -new -nodes -newkey rsa:4096 -days 365 -keyout ca.key -out ca.pem -config ca.conf
${OPENSSL:?} x509 -in ca.pem -out ca.der -outform der  

cat <<-EOF > cert.conf
[req]
prompt = no
req_extensions = req_ext
distinguished_name = dn

[dn]

C = US
ST = California
L = San Francisco
O = Hickory DNS
CN = ns.hickory-dns.org

[req_ext]

basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
subjectAltName = @alt_names
 
[alt_names]
DNS.1 = ns.hickory-dns.org
DNS.2 = localhost
IP.1 = 127.0.0.1
IP.2 = ::1
EOF

# Cert
echo "----> Generating CERT  <----"
${OPENSSL:?} req -new -nodes -newkey rsa:4096 -keyout cert_key.pem -out cert.csr \
             -verify \
             -config cert.conf

${OPENSSL:?} pkcs8 -in cert_key.pem -inform pem -out cert-key.pk8 -topk8 -nocrypt

${OPENSSL:?} x509 -in ca.pem -inform pem -pubkey -noout > ca.pubkey

echo "----> Signing Cert <----"
${OPENSSL:?} x509 -req -days 365 -in cert.csr -CA ca.pem -CAkey ca.key  -set_serial 0x8771f7bdee982fa6 -out cert.pem -extfile cert.conf -extensions req_ext

echo "----> Verifying Cert <----"
${OPENSSL:?} verify -CAfile ca.pem cert.pem

echo "----> Creating PKCS12 <----"
${OPENSSL:?} pkcs12 -export -inkey cert_key.pem -in cert.pem -out cert.p12 -passout pass:mypass -name ns.hickory-dns.org -chain -CAfile ca.pem

# Clean up conf files
rm ca.conf cert.conf

echo "Certificates generated in $CERTS_DIR"
