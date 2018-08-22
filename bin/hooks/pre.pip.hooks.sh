echo "Checking if pip is installed 🤔"
if ! type pip &> /dev/null ; then
    printf "The required ${YELLOW}pip${NC} command was not found .. attempting to install it"
    easy_install pip
fi