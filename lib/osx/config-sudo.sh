#!/usr/bin/env bash
# shellcheck shell=bash

NEWTEXT='auth       sufficient     pam_tid.so'

# this is the file we are going to add it to
FILE='/etc/pam.d/sudo'

# this checks to see if the text is already in the file we want to modify
grep -F "$NEWTEXT" "$FILE" &> /dev/null

# here we save the exit code of the 'fgrep' command
EXIT="$?"

if [[ "$EXIT" == "0" ]]
then
    # if that code was zero, the file does not need to be modified
    printf "\n${BLUE}%s${NC}\n" "[INFO] TouchID enabled sudo settings have been already added"
else
    printf "Would you like to configure Touch ID with sudo? [Yy/Nn]";
    read -r REPLY
    echo "";
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # tell user what we are doing
        echo "Adding the needed settigs to $FILE"

        # get random tempfile name
        TEMPFILE="${TMPDIR-/tmp}/${NAME}.$$.$RANDOM.txt"

        # get comment line (this is usually the first line of the file)
        grep -E '^#' "$FILE" >| "$TEMPFILE"

        # add our custom line
        echo "$NEWTEXT" >> "$TEMPFILE"

        # get the other lines
        grep -E -v '^#' "$FILE" >> "$TEMPFILE"

        # tell the user what the filename is useful for debugging, if needed
        printf "%s${YELLOW}%s${NC}\n" "Backup file saved in: " "$TEMPFILE"

        # set the proper permissions and ownership and move the file into place
        sudo chmod 444 "$TEMPFILE" \
        && sudo chown root:wheel "$TEMPFILE" \
        && sudo mv -vf "$TEMPFILE" "$FILE"

            # check the exit code of the above 3 commands
        EXIT="$?"

        # if the commands exited = 0
        # then we're good
        if [[ "$EXIT" == "0" ]]
        then
            printf "%s${BLUE}%s${NC}\n" "'sudo' via TouchID successfully enabled"
        else
            # if we did not get a 'zero' result, tell the user and give up
            printf "%s${RED}%s${NC}\n" "[ERROR] 'sudo' failed to be configured with TouchID"
            exit 1
        fi
        
        # if iTerm is installed, check to see if one of its settings is set to work with this setting
        # and if not, tell the user what they need to change

        if [[ -d '/Applications/iTerm.app' || -d "$HOME/Applications/iTerm.app" ]]
        then

            PREFERENCE=$(defaults read com.googlecode.iterm2 BootstrapDaemon 2>/dev/null)

            if [[ "$PREFERENCE" == "0" ]]
            then

                echo "[INFO] 'iTerm' preference is already set properly."

            else

                printf "${YELLOW}%s${NC}\n" "[WARNING]: setting iTerm preferences via 'defaults write' may not work while iTerm is running"
                printf "${YELLOW}%s${NC}\n" "[WARNING]: Be sure to turn OFF this setting in iTerm's Preferences"
                printf "${WHITE}%s${NC}\n" "Preferences » Advanced » 'Allow sessions to survive logging out and back in'"

            fi
        fi
    fi;
fi
