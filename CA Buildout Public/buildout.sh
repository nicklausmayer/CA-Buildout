#!/usr/bin/env bash
#  ________  ________                                                           
# |\   ____\|\   __  \                                                          
# \ \  \___|\ \  \|\  \                                                         
#  \ \  \    \ \   __  \                                                        
#   \ \  \____\ \  \ \  \                                                       
#    \ \_______\ \__\ \__\                                                      
#  ___\|_______|\|__|\|__|  ___       ________  ________  ___  ___  _________   
# |\   __  \|\  \|\  \|\  \|\  \     |\   ___ \|\   __  \|\  \|\  \|\___   ___\ 
# \ \  \|\ /\ \  \\\  \ \  \ \  \    \ \  \_|\ \ \  \|\  \ \  \\\  \|___ \  \_| 
#  \ \   __  \ \  \\\  \ \  \ \  \    \ \  \ \\ \ \  \\\  \ \  \\\  \   \ \  \  
#   \ \  \|\  \ \  \\\  \ \  \ \  \____\ \  \_\\ \ \  \\\  \ \  \\\  \   \ \  \ 
#    \ \_______\ \_______\ \__\ \_______\ \_______\ \_______\ \_______\   \ \__\
#     \|_______|\|_______|\|__|\|_______|\|_______|\|_______|\|_______|    \|__|

clear
source ./buildout.lib.sh

echo -e "CA Buildout Script v1.0 by Nick M.
If you have not created any certificates on the device you are on, start with Full Buildout (1).
The certificates will be generated within the certificates directory found in the root directory.
If you do not change the name of the certificates directory and attempt to run a full buildout,
you will encounter errors due to the creation of new serial indexes.\n
!!! THIS SCRIPT CAN BE DESTRUCTIVE TO OLD CERTS IF THE SAME NAME FOR THE CERTIFICATE IS USED !!!
For example, a newly created root (trust anchor) with the name root,
will overwrite an old root certificate with the name root.\n"

if [[ $(id -u) != 0 ]]; then 
    echo -e "Elevated permissions are required to run this script."
    exit
fi

read -p "First time running script? (Y/n): " upinfo
if [[ "$upinfo" == 'y' || "$upinfo" == 'Y' ]]; then
	update_info
fi

buildout() {
    PS3="Select a buildout option: "
    select bld in "Full Buildout" "Intermediate Buildout" "Server Buildout" "Client Buildout" "Exit"
    do
        case $bld in 
            "Full Buildout")
                full_buildout
                buildout;;
            "Intermediate Buildout")
                intermediate_buildout
                buildout;;
            "Server Buildout")
                server_buildout
                buildout;;
            "Client Buildout")
                client_buildout
                buildout;;
            "Exit")
                exit;;
            *)
                echo "Out of bounds"
        esac
    done
}
buildout