# Configure text editors of the choice between SublimeText or Atom
printf "We will install and configure some text editors for you if you wish ..."

echo "";
read -p "Would you like to set up SublimeText now? [Y/N] " -n 1;
echo "";
if [[ $REPLY =~ ^[Yy]$ ]]; then
	python "$SOURCE_LOCATION/configs/templates/editors/sublime/setup.py"
fi;

echo "";
read -p "Would you like to set up Atom now? [Y/N] " -n 1;
echo "";
if [[ $REPLY =~ ^[Yy]$ ]]; then
	sh "$SOURCE_LOCATION/configs/templates/editors/atom/setup.sh"
fi;
