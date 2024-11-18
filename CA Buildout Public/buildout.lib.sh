#!/usr/bin/env bash

#   --- BUILDOUT FUNCTIONS ---
create_directories() {
	echo -e "Generating Directories...\n"
	mkdir -p "/certificates/certs" "/certificates/intermediate/certs" "/certificates/newcerts" "/certificates/private" "/certificates/intermediate/newcerts" "/certificates/intermediate/private" "./Generated Certificates/CA Certificates" "./Generated Keys/CA Keys" "./Generated Certificates/Server Certificates" "./Generated Certificates/Client Certificates" "./Generated Keys/Server Keys"
}
initialize_files() {
	echo -e "Creating index and serial files... \n"
	touch /certificates/index.txt /certificates/serial /certificates/intermediate/index.txt /certificates/intermediate/serial
	echo 1000 >/certificates/serial
	echo 1000 >/certificates/intermediate/serial
}
update_info() {
	read -p "Enter Country Code (Ex. US): " countryName
	read -p "Enter State or Province Name (Ex. WA): " stateName
	read -p "Enter Email Address: " emailAddress
	echo
	sed -i -e "43s/=.*/= $countryName/g" ./configs/openssl*
	sed -i -e "44s/=.*/= $stateName/" ./configs/openssl*
	sed -i -e "48s/=.*/= $emailAddress/" ./configs/openssl*
}

# Full buildout input
full_buildout() {
    create_directories
    initialize_files
	echo -e "\nEnter information for Trust Anchor Certificate...\n"
	read -p "Enter Orginization Name: " orgName
	#	Ex. KTS-Office
	read -p "Enter Orginization Unit (Orginization Name-Location): " rorgUName
	read -p "Enter Trust Anchor Name: " rootName
	read -p "Enter $rootName CA password: " rootPass
	#	Generate CA
	generate_ca_cert $rootName $rootPass
    echo -e "\nEnter information for Intermediate Certificate(s)...\n"
	read -p "Enter # of Intermediate Certificates: " intCount
	echo
	for i in $(seq $intCount); do
		echo -e "Enter information for Intermediate Certificate ($i)...\n"
		read -p "Enter Orginization Unit (Enter for same as Root): " iorgUName
		if [[ "$iorgUName" = "" ]]; then iorgUName="$rorgUName"; fi
		read -p "Enter Intermediate CA $i Name: " intName
		read -p "Enter intermediate CA $intName password: " intPass
		#	Generate Intermediate certs
		generate_intermediate_certs
        server_input
	done
}
# Intermediate (independent) input
intermediate_buildout() {
    echo -e "\nEnter Information for the Trust Anchor Certificate You Wish to Sign too...\n"
    read -p "Enter Orginization Name: " orgName
    read -p "Enter Trust Anchor Name: " rootName
    if [[ -f "/certificates/certs/$rootName.cert.pem" ]]; then
        read -p "Enter Trust Anchor $rootName Password: " rootPass
        echo -e "\nEnter Information for the Intermediate Certificate...\n"
        read -p "Enter Orginization Unit (Orginization Name-Location): " iorgUName
        read -p "Enter # of previous Intermediate Certificates: " p
        read -p "Enter # of Intermediate Certificates you wish to sign to $rootName: " intCount
        for n in $(seq $intCount); do
            i=$(($n+$p))
            echo -e "\nEnter Information for Intermediate Certificate $c\n"
            read -p "Enter Intermediate Certificate #$n Name: " intName
            read -p "Enter Intermediate Certificate clientName password: " intPass
            generate_intermediate_certs $rootName $rootPass $orgName $i
        done
        # Create server certs after intermediate generation
        read -p "Would you like to create server certificates for $intName? (y/n): " serverInput
        if [[ "$serverInput" == 'y' || "$serverInput" == 'Y' ]]; then server_input $i $intName $intPass $iorgUName $orgName; fi
		read -p "Would you like to generate Client certificates for $intName? (y/n): " clientInput
		if [[ "$clientInput" == 'y' || "$clientInput" == 'Y' ]]; then client_input; fi
    fi
}
# Server (independent) input
server_buildout() {
    echo -e "\nEnter Information for the Intermediate CA Certificate You Wish to Sign too...\n"
    read -p "Enter Orginization Name: " orgName
	#	Ex. KTS-Office
	read -p "Enter Orginization Unit (Orginization Name-Location): " sorgUName
	#	Required for chain verification
    read -p "Enter Intermediate CA Chain #: " i
    read -p "Enter Intermediate CA Name: " intName
    if [[ -f "/certificates/intermediate/certs/$intName.cert.pem" ]]; then
        read -p "Enter Intermediate CA $intName Password: " intPass
        echo -e "\nEnter Information for the Server Certificate...\n"
        echo
        read -p "Enter # of Server Certificates you wish to sign to $intName: " serverCount
        for s in $(seq $serverCount); do
            echo -e "\nEnter Information for Server Certificate $s\n"
            read -p "Enter Server Certificate #$s Name: " serverName
            read -p "Enter Server Certificate $serverName password: " serverPass
            #	IP Input
			read -p "Enter # of IPs for $serverName: " serverIPCount
			for l in $(seq $serverIPCount); do
				read -p "Enter IP #$l for $serverName: " serverIP[$l]
			done
			#	DNS Input
			read -p "Enter # of DNS servers for $serverName: " serverDNSCount
			for k in $(seq $serverDNSCount); do
				read -p "Enter DNS server #$k for $serverName: " serverDNS[$k]
			done
            generate_server_certs
        done
        echo
        read -p "Would you like $serverName to be a PFX file? (y/n): " pfxInput
			if [[ "$pfxInput" == 'y' || "$pfxInput" == 'Y' ]]; then
				pfx_gen $serverName $serverPass
                cp "/certificates/intermediate/certs/$serverName.pfx" "Generated Certificates/Server Certificates"
			fi
		echo
    fi
}
#	Server input
server_input() {
    echo -e "\nEnter information for Server Certificate(s)...\n"
    read -p "Enter # of Server Certificates: " serverCount
    echo
    for j in $(seq $serverCount); do
        echo -e "Enter information for Server Certificate ($j) that will sign to Intermediate CA $intName...\n"
        read -p "Enter Orginization Unit (Press enter for same as Intermediate): " sorgUName
        if [[ "$sorgUName" = "" ]]; then sorgUName="$iorgUName"; fi
        read -p "Enter server Certificate $j Name: " serverName
        read -p "Enter server Certificate $serverName password: " serverPass
        #	IP Input
        read -p "Enter # of IPs for $serverName: " serverIPCount
        for l in $(seq $serverIPCount); do
            read -p "Enter IP #$l for $serverName: " serverIP[$l]
        done
        #	DNS Input
        read -p "Enter # of DNS servers for $serverName: " serverDNSCount
        for k in $(seq $serverDNSCount); do
            read -p "Enter DNS server #$k for $serverName: " serverDNS[$k]
        done
        #	Generate server certs
        generate_server_certs #$intName $intPass $orgName $i
        #	PFX Input Logic
        read -p "Would you like $serverName to be a PFX file? (y/n): " pfxInput
        if [[ "$pfxInput" == 'y' || "$pfxInput" == 'Y' ]]; then
            pfx_gen $serverName $serverPass
            cp "/certificates/intermediate/certs/$serverName.pfx" "Generated Certificates/Server Certificates"
        fi
        echo
    done
	read -p "Would you like to generate Client certificates for $intName? (y/n): " clientInput
	if [[ "$clientInput" == 'y' || "$clientInput" == 'Y' ]]; then
		client_input
	fi
	read -p "Would you like to generate Client certificates for $intName? (y/n): " clientInput
		if [[ "$clientInput" == 'y' || "$clientInput" == 'Y' ]]; then client_input; fi
}
# Client (independent) input
client_buildout() {
    echo -e "\nEnter Information for the Intermediate CA Certificate You Wish to Sign too...\n"
    read -p "Enter Orginization Name: " orgName
	read -p "Enter Orginization Unit (Orginization Name-Location): " corgUName
    read -p "Enter Intermediate CA Chain #: " i
    read -p "Enter Intermediate CA Name: " intName
    if [[ -f "/certificates/intermediate/certs/$intName.cert.pem" ]]; then
        read -p "Enter Intermediate CA $intName Password: " intPass
        echo -e "\nEnter Information for the Client Certificate...\n"
        read -p "Enter # of Client Certificates you wish to sign to $intName: " clientCount
        for c in $(seq $clientCount); do
            echo -e "\nEnter Information for Client Certificate $c\n"
            read -p "Enter Client Certificate #$c Name: " clientName
            read -p "Enter Client Certificate $clientName password: " clientPass
            generate_client_certs
        done
    fi
}

#	Generate Certificates
generate_ca_cert() {
	echo -e "Generating Trust Anchor Certificate...\n"
	#   Edit root CNF, root key and root cert directory locations, subject and alt names
	cp configs/openssl-rt.cnf "/certificates/intermediate/openssl-rt.cnf"
	sed -i -e "19s|private/\([^/]*\)|private/$rootName.key.pem|g" "/certificates/intermediate/openssl-rt.cnf"
	sed -i -e "20s|certs/\([^/]*\)|certs/$rootName.cert.pem|g" "/certificates/intermediate/openssl-rt.cnf"
	sed -i -e "45s|= organization|= $orgName|g" "/certificates/intermediate/openssl-rt.cnf"
	sed -i -e "46s|= organizationUnit|= $rorgUName|g" "/certificates/intermediate/openssl-rt.cnf"
	sed -i -e "47s/= root/= $rootName/g" "/certificates/intermediate/openssl-rt.cnf"
	# 	Generate root certificate private key
	openssl genrsa -aes256 -passout pass:$rootPass -out /certificates/private/$rootName.key.pem 4096
	#	Generate root certificate
	openssl req -config "/certificates/intermediate/openssl-rt.cnf" -passin pass:$rootPass -key /certificates/private/$rootName.key.pem -new -x509 -days 1825 -sha512 -extensions v3_ca -out /certificates/certs/$rootName.cert.pem
	#	Output certificate details
	openssl x509 -noout -text -in /certificates/certs/$rootName.cert.pem
	cp "/certificates/certs/$rootName.cert.pem" "Generated Certificates/CA Certificates"
	cp "/certificates/private/$rootName.key.pem" "Generated Keys/CA Keys"
	#	Root config not removed so config file can be used for signing certs
	echo
}
generate_intermediate_certs() {
	echo -e "Generating Intermediate Certificate..."
	#	Create INTERMEDIATE config files, edit root key and root cert directory locations, subject, and alt names
	cp configs/openssl-int.cnf "/certificates/intermediate/openssl-int.$i.cnf"
	sed -i -e "19s|private/\([^/]*\)|private/$rootName.key.pem|g" "/certificates/intermediate/openssl-int.$i.cnf"
	sed -i -e "20s|certs/\([^/]*\)|certs/$rootName.cert.pem|g" "/certificates/intermediate/openssl-int.$i.cnf"
	sed -i -e "45s|= organization|= $orgName|g" "/certificates/intermediate/openssl-int.$i.cnf"
	sed -i -e "46s|= organizationUnit|= $iorgUName|g" "/certificates/intermediate/openssl-int.$i.cnf"
	sed -i -e "47s/intermediate/$intName/g" "/certificates/intermediate/openssl-int.$i.cnf"
	#	Generate intermediate private key
	openssl genrsa -aes256 -passout pass:$intPass -out "/certificates/intermediate/private/$intName.key.pem" 1648
	#	Generate intermediate certificate signing request
	openssl req -config "/certificates/intermediate/openssl-int.$i.cnf" -new -sha512 -passin pass:"$intPass" -key "/certificates/intermediate/private/$intName.key.pem" -out "/certificates/intermediate/certs/$intName.csr.pem"
	#	Signing intermediate certificate from root certificate
	openssl ca -batch -passin pass:$intPass -config "/certificates/intermediate/openssl-int.$i.cnf" -extensions v3_intermediate_ca -days 1824 -notext -in "/certificates/intermediate/certs/$intName.csr.pem" -out "/certificates/intermediate/certs/$intName.cert.pem"
	#	Output certificate details
	openssl x509 -noout -text -in "/certificates/intermediate/certs/$intName.cert.pem"
	#	Verify certificate against root
	openssl verify -CAfile "/certificates/certs/$rootName.cert.pem" "/certificates/intermediate/certs/$intName.cert.pem"
	echo -e "Generating certificate chain...\n"
	cat "/certificates/intermediate/certs/$intName.cert.pem" /certificates/certs/$rootName.cert.pem >"Generated Certificates/CA Certificates/ca-chain$i.cert.pem"
	openssl crl2pkcs7 -nocrl -certfile "Generated Certificates/CA Certificates/ca-chain$i.cert.pem" -out "Generated Certificates/CA Certificates/ca-chain$i.p7b"
	cp "Generated Certificates/CA Certificates/ca-chain$i.cert.pem" "/certificates/intermediate/certs/ca-chain$i.cert.pem"
	cp "Generated Certificates/CA Certificates/ca-chain$i.p7b" "/certificates/intermediate/certs/ca-chain$i.p7b"
	cp "/certificates/intermediate/certs/$intName.cert.pem" "Generated Certificates/CA Certificates"
	cp "/certificates/intermediate/private/$intName.key.pem" "Generated Keys/CA Keys"
	#	Intermediate config not removed so config file can be used for signing certs
}
pfx_gen() {
    input=$1
    pass=$2
    openssl pkcs12 -passout pass:"$pass" -export -out "/certificates/intermediate/certs/$input.pfx" -passin pass:"$pass" -inkey "/certificates/intermediate/private/$input.key.pem" -in "/certificates/intermediate/certs/$input.cert.pem"
	openssl pkcs12 -info -in "/certificates/intermediate/certs/$input.pfx" -passin pass:"$pass" -passout pass:"$pass"
}
generate_server_certs() {
	echo -e "Generating Server Certificate...\n"
	#	Create SERVER config files, edit root key and root cert directory locations, subject, and alt names
	cp configs/openssl-server.cnf "/certificates/intermediate/openssl-server.cnf"
	sed -i -e "19s|private/\([^/]*\)|private/$intName.key.pem|g" "/certificates/intermediate/openssl-server.cnf"
	sed -i -e "20s|certs/\([^/]*\)|certs/$intName.cert.pem|g" "/certificates/intermediate/openssl-server.cnf"
	sed -i -e "45s|= organization|= $orgName|g" "/certificates/intermediate/openssl-server.cnf"
	sed -i -e "46s|= organizationUnit|= $sorgUName|g" "/certificates/intermediate/openssl-server.cnf"
	sed -i -e "47s/= server/= $serverName/g" "/certificates/intermediate/openssl-server.cnf"
	#	IP Loop
	for l in $(seq $serverIPCount); do
		sed -i -e "62iIP.$l = ${serverIP[$l]}" "/certificates/intermediate/openssl-server.cnf"
	done
	#	DNS Loop
	for k in $(seq $serverDNSCount); do
		sed -i -e "62iDNS.$k = ${serverDNS[$k]}" "/certificates/intermediate/openssl-server.cnf"
	done
	#	Generate SERVER cert
	openssl genrsa -aes256 -passout pass:"$serverPass" -out "/certificates/intermediate/private/$serverName.key.pem" 1648
	openssl req -config "/certificates/intermediate/openssl-server.cnf" -new -sha512 -passin pass:"$serverPass" -key "/certificates/intermediate/private/$serverName.key.pem" -out "/certificates/intermediate/certs/$serverName.csr.pem"
	openssl ca -batch -passin pass:"$intPass" -config "/certificates/intermediate/openssl-server.cnf" -extensions server_cert -days 1824 -notext -in "/certificates/intermediate/certs/$serverName.csr.pem" -out "/certificates/intermediate/certs/$serverName.cert.pem"
	openssl x509 -noout -text -in "/certificates/intermediate/certs/$serverName.cert.pem"
    openssl verify -CAfile "/certificates/intermediate/certs/ca-chain$i.cert.pem" "/certificates/intermediate/certs/$serverName.cert.pem"
    echo -e "\nCopying Files to home directories...\n"
	cp "/certificates/intermediate/certs/$serverName.cert.pem" "Generated Certificates/Server Certificates"
	cp "/certificates/intermediate/private/$serverName.key.pem" "Generated Keys/Server Keys"
	rm "/certificates/intermediate/openssl-server.cnf"
}
generate_client_certs() {
	#	Create CLIENT config files, edit root key and root cert directory locations, subject, and DNS name
	cp configs/openssl-client.cnf "/certificates/intermediate/openssl-client.cnf"
	sed -i -e "19s|private/\([^/]*\)|private/$intName.key.pem|g" "/certificates/intermediate/openssl-client.cnf"
	sed -i -e "20s|certs/\([^/]*\)|certs/$intName.cert.pem|g" "/certificates/intermediate/openssl-client.cnf"
    sed -i -e "45s|= organization|= $orgName|g" "/certificates/intermediate/openssl-client.cnf"
	sed -i -e "46s|= organizationUnit|= $corgUName|g" "/certificates/intermediate/openssl-client.cnf"
	sed -i -e "47s/client/$clientName/g" "/certificates/intermediate/openssl-client.cnf"

	#	Generate CLIENT cert
	openssl genrsa -aes256 -passout pass:$clientPass -out "/certificates/intermediate/private/$clientName.key.pem" 1648
	openssl req -config "/certificates/intermediate/openssl-client.cnf" -new -sha512 -passin pass:$clientPass -key "/certificates/intermediate/private/$clientName.key.pem" -out "/certificates/intermediate/certs/$clientName.csr.pem"
	openssl ca -batch -passin pass:$intPass -config "/certificates/intermediate/openssl-client.cnf" -extensions usr_cert -days 1824 -notext -md sha256 -in "/certificates/intermediate/certs/$clientName.csr.pem" -out "/certificates/intermediate/certs/$clientName.cert.pem"
	openssl x509 -noout -text -in "/certificates/intermediate/certs/$clientName.cert.pem"
    openssl verify -CAfile "/certificates/intermediate/certs/ca-chain$i.cert.pem" "/certificates/intermediate/certs/$clientName.cert.pem"
    openssl pkcs12 -passout pass:"$clientPass" -export -out "/certificates/intermediate/certs/$clientName.pfx" -passin pass:"$clientPass" -inkey "/certificates/intermediate/private/$clientName.key.pem" -in "/certificates/intermediate/certs/$clientName.cert.pem"
    openssl pkcs12 -info -in "/certificates/intermediate/certs/$clientName.pfx" -passin pass:"$clientPass" -passout pass:"$clientPass"
    echo -e "\nCopying Files to home directories..."
    cp "/certificates/intermediate/certs/$clientName.pfx" "Generated Certificates/Client Certificates"
    rm "/certificates/intermediate/openssl-client.cnf"
}