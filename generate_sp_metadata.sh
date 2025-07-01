#!/bin/bash
# Script to generate SP metadata for mod_auth_mellon

# Create SP metadata XML
cat > mellon-config/sp-metadata.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<md:EntityDescriptor xmlns:md="urn:oasis:names:tc:SAML:2.0:metadata" 
                     entityID="https://pssid-metrics.miserver.it.umich.edu">
  <md:SPSSODescriptor protocolSupportEnumeration="urn:oasis:names:tc:SAML:2.0:protocol">
    
    <md:AssertionConsumerService Binding="urn:oasis:names:tc:SAML:2.0:bindings:HTTP-POST" 
                                 Location="https://pssid-metrics.miserver.it.umich.edu/mellon/postResponse" 
                                 index="0"/>
    <md:AssertionConsumerService Binding="urn:oasis:names:tc:SAML:2.0:bindings:HTTP-Redirect" 
                                 Location="https://pssid-metrics.miserver.it.umich.edu/mellon/redirectResponse" 
                                 index="1"/>
                                 
    <md:SingleLogoutService Binding="urn:oasis:names:tc:SAML:2.0:bindings:HTTP-Redirect" 
                            Location="https://pssid-metrics.miserver.it.umich.edu/mellon/logout"/>
    <md:SingleLogoutService Binding="urn:oasis:names:tc:SAML:2.0:bindings:HTTP-POST" 
                            Location="https://pssid-metrics.miserver.it.umich.edu/mellon/logout"/>
  </md:SPSSODescriptor>
</md:EntityDescriptor>
EOF

echo "SP metadata generated at mellon-config/sp-metadata.xml"
echo "You'll need to provide this metadata to University of Michigan IT for registration."
echo ""
echo "Also make sure you have these files in mellon-config/:"
echo "- idp-metadata.xml (downloaded from U-M)"
echo "- sp-private-key.pem (generated with openssl)"
echo "- sp-certificate.pem (generated with openssl)"
echo ""
echo "If you haven't generated the certificate files yet, run:"
echo "cd mellon-config"
echo "openssl genrsa -out sp-private-key.pem 2048"
echo "openssl req -new -x509 -key sp-private-key.pem -out sp-certificate.pem -days 365 -subj '/CN=pssid-metrics.miserver.it.umich.edu'"