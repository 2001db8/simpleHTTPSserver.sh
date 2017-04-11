# simpleHTTPSserver.sh

Start a simple HTTPS server serving files from the local directory.

Without any options provided the script will start a HTTPS server using OpenSSL on port 4443.

Usage:
```
# ./simpleHTTPSserver.sh -h

Usage: simpleHTTPSserver.sh [options]

Start a simple HTTPS server serving files from the local directory. The required key and certificate will be
created prior to the start of the server and also will be deleted when the server is stopped.

Options:

-h           Show this help message.
-o           Run simple HTTPS server using OpenSSL. No directory listing supported.
             This is also the default mode if no server options are given.
-2           Run simple HTTPS server using Python 2.
-3           Run simple HTTPS server using Python 3.
-p [port]    Define the port to listen on. Default port is 4443.
```

Tested on Linux and FreeBSD.
