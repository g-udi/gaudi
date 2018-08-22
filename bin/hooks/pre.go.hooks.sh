echo "Checking if gopath variable is set .. the home 🏡 for all of your golang applications"
[ -z "$GOPATH" ] && mkdir -p /Applications/Go && echo "Setting the GOPATH to /Applications/Go" && echo '\nexport GOPATH="/Applications/Go"' >> ~/.bash_profile
