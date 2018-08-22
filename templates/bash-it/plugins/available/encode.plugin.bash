cite about-plugin
about-plugin 'Encoding and decoding functions'

function escape() {
    about 'UTF-8-encode a string of Unicode symbols'
    group 'encode'

    printf "\\\x%s" $(printf "$@" | xxd -p -c1 -u);
    # print a newline unless we’re piping the output to another program
    if [ -t 1 ]; then
        echo ""; # newline
    fi;
}

function unidecode() {
    about 'Decode \x{ABCD}-style Unicode escape sequences'
    group 'encode'

    perl -e "binmode(STDOUT, ':utf8'); print \"$@\"";
    # print a newline unless we’re piping the output to another program
    if [ -t 1 ]; then
        echo ""; # newline
    fi;
}