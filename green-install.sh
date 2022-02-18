#/usr/bin/env bash

green="green-linux-headless-node"
green_dir="/usr/local/bin/$green"
green_exp="$green_dir/launch-$green.exp"
green_systemd="/etc/systemd/system/$green@.service"
green_config="/usr/local/etc/config.yaml"

expect_script() {
	cat >"$green_exp" <<EOL
spawn $green_dir/green-linux-headless-node cfg=$green_config specifier=1
set timeout -1
expect eof
EOL
}

config_file() {
	cat >"$green_config" <<EOL
email: "$green_email"
password: "$green_password"
nodeName: "$node_name"
EOL
}

systemd_script() {
	cat >"$green_systemd" <<EOL
[Unit]
Description=Green Node %i
After=network.target

[Service]
ExecStart=/usr/bin/expect $green_exp cfg=$green_config
StandardOutput=null

[Install]
WantedBy=multi-user.target
EOL
}

auth_script() {
	green_email=$(whiptail --inputbox "Please enter the E-mail for your Green account?" 8 78 --title "Login Credentials - E-mail" 3>&1 1>&2 2>&3)
	green_password=$(whiptail --passwordbox "Please enter your password" 8 78 --title "Login Credentials - Password" 3>&1 1>&2 2>&3)
	auth_url="https://www.googleapis.com/identitytoolkit/v3/relyingparty/verifyPassword?key=AIzaSyB4yFCX1P6Vs553OO4KyI5lkD5JBLIbHro"
}

install_dependencies() {
	for arg in "$@"; do
		if ! command -v "$arg" &>/dev/null; then
			if ! apt-get install "$arg"; then
				printf "Failed to install %s\n" "$arg"
				exit 1
			fi
		fi
	done
}

install_dependencies "curl" "wget" "expect" "whiptail"

if (whiptail --title "Smart Node Setup" --yesno "You are now installing the Linux Headless version of the green Smart Node. Choose Yes to continue." 10 60); then

	auth_script
	while [ "$status" != "200" ]; do
		# Prompt for creds (whiptail)
		status=$(curl "$auth_url" \
			--request POST \
			--output /dev/null -s -w "%{http_code}\n" \
			--header 'Content-Type: application/json' \
			--header 'Origin: https://app.share.green' \
			--data-raw '{"email":"'"$green_email"'","password":"'"$green_password"'","returnSecureToken":true}')

		if [[ "$status" = 2* ]]; then
			# Got it!
			node_name=$(whiptail --inputbox "Please name this Node." 8 78 --title "Node Name" 3>&1 1>&2 2>&3)
			mkdir -p "$green_dir"
			mkdir -p /etc/systemd/system
			systemd_script
			expect_script
			config_file
			apt-get install -qq -y expect
			rm -r ./green-linux-headless-node
			wget https://static.share.green/softnode/green-linux-headless-node.tar.gz
			tar -xzf green-linux-headless-node.tar.gz --directory "$green_dir"
			break
		elif [[ "$status" == 4* ]]; then
			whiptail --msgbox "Username and/or password incorrect, please try again." 8 78
			sleep 2
			auth_script
		elif [[ "$status" == 5* ]]; then
			whiptail --msgbox "Internal Server Error, please try again." 8 78
			sleep 2
			auth_script
		fi

		# Notify that the password is wrong, and let it loop away (could switch/if off of the status, for 500/400, for additional errors)

	done

	#Part 1 - Query for the user's email
	if [ $? = 0 ]; then
		echo "E-mail: $green_email"
	else
		echo "User canceled input."
		exit 1
	fi
	# A trick to swap stdout and stderr.
	# Again, you can pack this inside if, but it seems really long for some 80-col terminal users.
	if [ $? = 0 ]; then
		echo "Password entered."
	else
		echo "User selected Cancel."
		exit 1
	fi

	tar -xzf ./$green.tar.gz
	chmod +x ./$green
	rm -f ./$green.tar.gz
	sudo systemctl daemon-reload
	sudo systemctl restart systemd-journald
	sudo systemctl enable $green_systemd
	sudo systemctl start $green_systemd
	sudo systemctl --no-pager status $green_systemd
	whiptail --msgbox "Installation finished." --title "Done." 10 60
	expect $green_exp
	rm -f ./green-install.sh

else
	echo "Bye."
	exit 1
fi
