
if [[ `ls -ld /usr/local | awk '{print $3}'` != $(whoami) ]]; then
    echo "Making sure brew permissions are set up properly 🔑"
    sudo chown -R $(whoami) /usr/local
fi