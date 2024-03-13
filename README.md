# Bizmonx: A Xymon Port

## What is Xymon ?

Xymon is a system for monitoring your network servers and 
applications. It is heavily inspired by the Big Brother
tool, but is a complete re-implementation with a lot of added
functionality and performance improvements. A slightly more
detailed rationale for Xymon is in the docs/about.html file.

NOTE: On Nov 10 2008, Hobbit was officially renamed to
"Xymon". The name "Hobbit" is trademarked, and therefore
cannot be used without permission from the trademark
holders. 

This project currently is nothing more than a monkey patched visual refresh.
All credits go to the original author and team.
Xymon is awesome and this will help me learn and understand Zig.


## How to install

Detailed installation instructions are in the 
docs/install.html file. Essentially, it boils down
to running
	./configure
	make
	make install
but do have a look at the install.html file for more
detailed instructions.




# License

Xymon is copyrighted (C) 2002-2017 by Henrik Storner.

Xymon is Open Source software, made available under the 
GNU General Public License (GPL) version 2, with the explicit 
exemption that linking with the OpenSSL libraries is permitted. 
See the file COPYING for details.

Xymon is released under the GPL, and therefore available
free of charge. However, if you find it useful and want
to encourage further development, I do have an Amazon
wishlist at http://www.amazon.co.uk/ - just search for
my mail-address (henrik@hswn.dk). A contribution in the 
form of a book, CD or DVD is appreciated.

The following files are distributed with Xymon and used
by Xymon, but written by others and are NOT licensed under the GPL:

* The lib/rmd160c.c, lib/rmdconst.h, lib/rmdlocl.h and lib/ripemd.h
  files are Copyright (C) 1995-1998 Eric Young (eay@cryptsoft.com).
  The license is BSD-like, but see these files for the exact license. 
  The version in Xymon was taken from the FreeBSD CVS archive.

* The lib/md5.c and lib/md5.h files are (C) L. Peter Deutsch,
  available under a BSD-like license from
  http://sourceforge.net/projects/libmd5-rfc/

* The lib/sha1.c file is originally written by by Steve Reid 
  <steve@edmweb.com> and placed in the public domain. The version 
  in Xymon was taken from the "mutt" mail client sources, so 
  some changes were done by Thomas Roessler <roessler@does-not-exist.org>.


