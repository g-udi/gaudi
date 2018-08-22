cite about-plugin
about-plugin 'Custom Text Editors'

function s() {
	about '`s` with no arguments opens the current directory in Sublime Text, otherwise opens the given location'
  group 'editors'

	if [ $# -eq 0 ]; then
		sublime .;
	else
		sublime "$@";
	fi;
}

function a() {
	about '`a` with no arguments opens the current directory in Atom Editor, otherwise opens the given location'
  group 'editors'

	if [ $# -eq 0 ]; then
		atom .;
	else
		atom "$@";
	fi;
}

function v() {
	about '`v` with no arguments opens the current directory in Vim, otherwise opens the given location'
  group 'editors'

	if [ $# -eq 0 ]; then
		vim .;
	else
		vim "$@";
	fi;
}