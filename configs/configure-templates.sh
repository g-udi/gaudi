# Make sure that BEAMERY_HOME is set
sh "$SOURCE_LOCATION/configs/lib/configure-beamery-home.sh"

read -p "Do you want to copy the .editorconfig template to all beamery projects ? [Y/N] " -n 1;
echo "";
if [[ $REPLY =~ ^[yY]$ ]]; then
	find $BEAMERY_HOME -maxdepth 1 -type d \( ! -name ".*" \) | while read -r SUBFOLDER; do printf "\nAdding .editorconfig to Repository: ${MAGENTA}$SUBFOLDER${NC} " && cp "$SOURCE_LOCATION/configs/templates/.editorconfig"  "$SUBFOLDER"; done;
	echo ""
fi;
