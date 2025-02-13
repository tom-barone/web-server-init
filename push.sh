# Environment variable checks
for var in SSH_CONNECTION_STRING; do
	if [ -z "${!var}" ]; then
		echo "$var environment variable must be set"
		exit 1
	fi
done

# Update the init.sh script
rsync -avz "init.sh" "$SSH_CONNECTION_STRING:~/init.sh"
# Update the logcheck regex files
rsync -avz "logcheck/" "$SSH_CONNECTION_STRING:~/logcheck"

## Run these commands on the server via SSH to update logcheck
ssh -t "$SSH_CONNECTION_STRING" <<'EOF'
sudo cp /etc/logcheck/logcheck.logfiles.d/syslog.logfiles /etc/logcheck/syslog.bak
sudo sed -i 's@^/var/log@# /var/log@g' /etc/logcheck/logcheck.logfiles.d/syslog.logfiles

for logfile in "$HOME"/logcheck/rules/*; do
	sudo cp "$logfile" /etc/logcheck/ignore.d.server
done
EOF

# Run manually with
# sudo -u logcheck logcheck -o -t
# sudo -u logcheck logcheck -m <EMAIL>
