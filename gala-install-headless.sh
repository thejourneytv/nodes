#!/bin/bash

ISUPDATE=false
UPDATE_WARNING="Updating your node can cause daily progress to be lost. Please ensure you have already completed the minimum time, or have enough time to reach 100% today."

UPDATEPARAM=$1

displayhelp () {
    echo ""
    echo "install-headless.sh installs or updates the Headless Node"
    echo "   use install-healdess.sh to create an initial installation"
    echo "   use install-headless.sh --update to update an existing installation"
    echo ""
    exit
}

if [[ -n $1 ]] ; then
  if [[ $1 == "--update" || $1 == "-u" ]]; then
    ISUPDATE=true
  elif [[ $1 == "--help" || $1 == "-h" ]]; then
    displayhelp
  else
    displayhelp
  fi
fi

USER_NAME=`whoami`
if [[ $USER_NAME != 'root' ]]; then
  echo "The install-headless.sh script MUST be run with sudo. Use: 'sudo ./install-headless.sh'"
  exit
fi

INSTALL_PROMPT="You are now INSTALLING the Linux Headless version of the Gala Node. Choose Yes to continue."
if [[ $ISUPDATE == true ]]; then
  INSTALL_PROMPT="You are now UPDATING the Linux Headless version of the Gala Node. Choose Yes to continue."
fi

if (whiptail --title "Gala Node Setup" --yesno "${INSTALL_PROMPT}" 10 60) then
    if [[ $ISUPDATE == true ]]; then
      if (whiptail --title "Gala Node Update" --yesno "${UPDATE_WARNING}" 10 60) then
        echo "updating..."
        rm /usr/local/bin/gala-node/gala-node
      else 
        echo "Bye"
        exit
      fi
    else
      rm -rf /usr/local/bin/gala-node
    fi

    apt-get install -qq -y expect
    rm -r gala-node.tar.gz

    # manage old installs
    systemctl stop gala-node.service
    systemctl stop linux-headless-beta.service
    systemctl disable linux-headless-beta.service

   	wget https://static.gala.games/node/gala-node.tar.gz

    if [[ $ISUPDATE == false ]]; then
  	  mkdir -p /usr/local/bin/gala-node
      rm -rf /opt/gala-headless-node
    	mkdir -p /opt/gala-headless-node
    fi

	tar -xzf gala-node.tar.gz --directory /usr/local/bin/gala-node
	{
    mkdir -p /etc/systemd/system
    echo '[Unit]' > /etc/systemd/system/gala-node.service
    echo 'Description=Gala Node' >> /etc/systemd/system/gala-node.service
    echo 'After=network.target' >> /etc/systemd/system/gala-node.service
    echo '[Service]' >> /etc/systemd/system/gala-node.service
    sudo sh -c "echo User=$SUDO_USER >> /etc/systemd/system/gala-node.service"
    sudo sh -c "echo Group=$SUDO_USER >> /etc/systemd/system/gala-node.service"
    echo 'ExecStart=/usr/local/bin/gala-node/gala-node daemon' >> /etc/systemd/system/gala-node.service
    echo 'StandardOutput=true' >> /etc/systemd/system/gala-node.service
    echo '[Install]' >> /etc/systemd/system/gala-node.service
    echo 'WantedBy=multi-user.target' >> /etc/systemd/system/gala-node.service
    for ((i = 0 ; i <= 100 ; i+=20)); do
        sleep 0.5
        echo $i
    done
	} | whiptail --gauge "Please wait while installing..." --title "Gala Node Setup" 6 60 0

  if [[ $ISUPDATE == false ]]; then
    # clean up leftover bits if they exist
    if [[ -d "/opt/gala-headless-node/.ipfs" ]]; then
      rm -rf "/opt/gala-headless-node/.ipfs"
    fi
  fi

  chown -R ${SUDO_USER}:${SUDO_USER} /usr/local/bin/gala-node
  chown -R ${SUDO_USER}:${SUDO_USER} /opt/gala-headless-node

  if [[ $ISUPDATE == false ]]; then
    # run as the non-root user so that the log files end up owned by that user
    su ${SUDO_USER} -c "/usr/local/bin/gala-node/gala-node config device"
    su ${SUDO_USER} -c "/usr/local/bin/gala-node/gala-node config workloads"
  fi
	systemctl daemon-reload
	systemctl restart systemd-journald
	systemctl enable gala-node.service
	systemctl start gala-node.service
	systemctl --no-pager status gala-node.service

  # symlink for adding node binary call to path
  sudo ln -s /usr/local/bin/gala-node/gala-node /usr/bin/gala-node
	whiptail --msgbox "Installation finished." --title "Done." 10 60
else
    echo "Bye."
    exit 1
fi