printf "\nThe next step will prompt you for the url of gaudi templates (lists, hooks, templates, etc.)...\n\n"
printf "${YELLOW}[D,d]${NC} will install Ahmad Assaf's default templates from: ${MAGENTA}https://github.com/ahmadassaf/gaudi-templates \n"
printf "\n${YELLOW}If you want to point to any other location then just type the github url of that repo${NC}\n\n"

read -rp ">> " GAUDI_TEMPLATE_URL </dev/tty;
echo ""

export GAUDI_TEMPLATES_LOCATION="${HOME}/.gaudi/templates/"
if [[ $GAUDI_TEMPLATE_URL =~ ^[dD]$ ]]; then
    GAUDI_TEMPLATE_URL="https://github.com/ahmadassaf/gaudi-templates"
fi;

if [[ -d $GAUDI_TEMPLATES_LOCATION ]]; then
    printf "${RED}We noticed that there already gaudi config files installed in $GAUDI_TEMPLATES_LOCATION${NC}\n\n"
    read -p "Would you like to overwrite those? [Y/N] " -n 1;
    echo "";
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf $GAUDI_TEMPLATES_LOCATION
    fi;
else
    mkdir "${HOME}/.gaudi/templates"
fi

git clone $GAUDI_TEMPLATE_URL $GAUDI_TEMPLATES_LOCATION
