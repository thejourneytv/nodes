rm /etc/machine-id /var/lib/dbus/machine-id 
dbus-uuidgen | sudo tee /etc/machine-id 
cp /etc/machine-id /var/lib/dbus/machine-id