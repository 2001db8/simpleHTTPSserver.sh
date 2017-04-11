#!/usr/bin/env bash

# Run a simple HTTPS server using OpenSSL s_server or Python.

# Variables and Stuff
# we can safely define at start

trap cleanup EXIT QUIT SIGINT

readonly HOSTNAME=$(hostname)
readonly BASENAME=$(command -v basename)
readonly PROG_NAME=$($BASENAME "$0")
readonly OPENSSL=$(command -v openssl)
readonly PYTHON2=$(command -v python2)
readonly PYTHON3=$(command -v python3)
readonly ECHO=$(command -v echo)
readonly DAYS="1"
readonly PGREP=$(command -v pgrep)
readonly KILL=$(command -v kill)

RED='\033[0;31m'                # some colors
GREEN='\033[0;32m'
BOLD='\033[1m'
NC='\033[0m'

SERVER="openssl"                # using openssl for the server is default
PORT="4443"                     # default port the server will listen on
OPT_O=""                        # for option checking
OPT_2=""                        # for option checking
OPT_3=""                        # for option checking

# First of all, check if OpenSSL was found

[[ -z $OPENSSL ]] && ($ECHO "OpenSSL not installed or not in path. Giving up."; exit 1)

# Functions

usage() {
        cat <<EOF

Usage: $PROG_NAME [options]

Start a simple HTTPS server serving files from the local directory. The required key and certificate will be
created prior to the start of the server and also will be deleted when the server is stopped.

Options:

-h           Show this help message.
-o           Run simple HTTPS server using OpenSSL. No directory listing supported.
             This is also the default mode if no server options are given.
-2           Run simple HTTPS server using Python 2.
-3           Run simple HTTPS server using Python 3.
-p [port]    Define the port to listen on. Default port is 4443.

EOF
}

make_cert() {
        readonly TMPCERT=$(mktemp -t cert.XXXXXXXXXX)  # Creating tempfiles not at start but now
        readonly TMPKEY=$(mktemp -t key.XXXXXXXXXX)    # when we know we will really need them
        $OPENSSL req -x509 -nodes -days "$DAYS" -sha256 -subj "/C=XX/ST=XX/L=XX/CN=$HOSTNAME" \
         -newkey rsa:2048 -keyout "$TMPKEY" -out "$TMPCERT"
        $ECHO -e "\nCreated temporary certificate $TMPCERT and temporary key $TMPKEY"
}

cleanup() {
        # Remove temporary files
        [[ -e "$TMPKEY" ]] && ($ECHO -en "\n\nRemoving temporary key... "; \
         rm -I "$TMPKEY" 2> /dev/null && $ECHO -e "${GREEN}success${NC}." || \
         $ECHO -e "${RED}FAILED${NC}! Please remove file ${RED}$TMPKEY${NC} by hand.")

        [[ -e "$TMPCERT" ]] && ($ECHO -en "Removing temporary certificate... "; \
         rm -I "$TMPCERT" 2> /dev/null && $ECHO -e "${GREEN}success${NC}." || \
         $ECHO -e "${RED}FAILED${NC}! Please remove file ${RED}$TMPCERT${NC} by hand.")

        # Check if the HTTPS server is still running in case this script
        # got killed and we ended up with a zombie HTTPS server
        [[ -v "$TMPCERT" ]] && local ZOMBIE=$($PGREP -f $($BASENAME $TMPCERT))
        [[ -n "$ZOMBIE" ]] && ($ECHO -en "\nZombie HTTPS server detected. Going full Daryl Dixon on it... "; \
         $KILL -9 $ZOMBIE > /dev/null 2>&1 && $ECHO -e "${GREEN}success${NC}:\n" || \
         $ECHO -e "${RED}FAILED${NC}! Please kill PID ${RED}$ZOMBIE${NC} by hand.")
}

python2serv() {
        if [[ "$OPT_2" -eq 1 ]] && [[ -n "$OPT_O" || -n "$OPT_O" ]]
        then
                $ECHO "$PROG_NAME: Multipe server options detected."  >&2
                usage
        elif [[ -z $PYTHON2 ]]
        then
                $ECHO -e "\nPython 2 not found or not in path."
                exit 1
        else
                make_cert
                $ECHO -e "\nStarting HTTPS server on port ${BOLD}$PORT${NC} with ${BOLD}Python 2${NC}.\n\nStop server with CTRL+C.\n"
                $PYTHON2 -c "import sys,BaseHTTPServer,SimpleHTTPServer,ssl; \
                 sys.tracebacklimit=0; \
                 httpd = BaseHTTPServer.HTTPServer(('', $PORT), SimpleHTTPServer.SimpleHTTPRequestHandler); \
                 httpd.socket = ssl.wrap_socket (httpd.socket, certfile='$TMPCERT', keyfile='$TMPKEY', server_side=True); \
                 httpd.serve_forever()"
        fi
}

python3serv() {
        if [[ "$OPT_3" -eq 1 ]] && [[ -n "$OPT_2" || -n "$OPT_O" ]]
        then
                $ECHO -e "$PROG_NAME: Multipe server options detected."  >&2
                usage
        elif [[ -z $PYTHON3 ]]
        then
                $ECHO -e "\nPython 3 not found or not in path."
                exit 1
        else
                make_cert
                $ECHO -e "\nStarting HTTPS server on port ${BOLD}$PORT${NC} with ${BOLD}Python 3${NC}.\n\nStop server with CTRL+C.\n"
                $PYTHON3 -c "import sys,http.server,http.server,ssl,signal; \
                 signal.signal(signal.SIGINT, lambda x,y: sys.exit(0)); \
                 httpd = http.server.HTTPServer(('', $PORT), http.server.SimpleHTTPRequestHandler) ; \
                 httpd.socket = ssl.wrap_socket (httpd.socket, certfile='$TMPCERT', keyfile='$TMPKEY', server_side=True) ; \
                 httpd.serve_forever()"
        fi
}

openssl_serv() {
        if [[ "$OPT_O" -eq 1 ]] && [[ -n "$OPT_2" || -n "$OPT_3" ]]
        then
                echo "$PROG_NAME: Multipe server options detected."  >&2 && usage
        else
                make_cert
                $ECHO -e "\nStarting HTTPS server on port ${BOLD}$PORT${NC} with ${BOLD}OpenSSL${NC}.\n\nStop server with CTRL+C.\n"
                $OPENSSL s_server -no_ssl2 -no_ssl3 -WWW -cert "$TMPCERT" -key "$TMPKEY" -accept "$PORT"
        fi
}

# Get options

while getopts ":hp:o23" OPTION
do
  case $OPTION in
        o)
        SERVER="openssl"
        OPT_O="1"
        ;;
        2)
        SERVER="python2"
        OPT_2="1"
        ;;
        3)
        SERVER="python3"
        OPT_3="1"
        ;;
        p)
        PORT="$2"
        ;;
        h)
        usage
        exit 0
        ;;
        \?)
        echo "$PROG_NAME: illegal option -- $OPTARG" >&2
        usage
        exit 1
        ;;
  esac
done

# main()

case $SERVER in
        openssl)
        openssl_serv
        ;;
        python2)
        python2serv
        ;;
        python3)
        python3serv
        ;;
esac
