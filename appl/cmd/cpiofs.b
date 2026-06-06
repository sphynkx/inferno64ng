implement Cpiofs;

#
# cpio archive file system, modelled on tarfs(4).
#
# Supports the SVR4 portable "newc" format (magic 070701) and the
# old POSIX portable "odc" format (magic 070707). Reads the entire
# archive once at mount time to build the directory tree, then
# serves file contents directly from the cpio file by offset.
#

include "sys.m";
	sys: Sys;

include "draw.m";

include "daytime.m";
	daytime: Daytime;

include "arg.m";

include "styx.m";
	styx: Styx;
	Tmsg, Rmsg: import styx;

include "styxservers.m";
	styxservers: Styxservers;
	Fid, Styxserver, Navigator, Navop: import styxservers;
	Enotfound: import styxservers;

Cpiofs: module
{
	init: fn(nil: ref Draw->Context, nil: list of string);
};

File: adt {
	x:	int;
	name:	string;
	mode:	int;
	uid:	string;
	gid:	string;
	mtime:	int;
	length:	big;
	offset:	big;
	parent:	cyclic ref File;
	children:	cyclic list of ref File;

	find:		fn(f: self ref File, name: string): ref File;
	enter:	fn(d: self ref File, f: ref File);
	stat:		fn(d: self ref File): ref Sys->Dir;
};

cpiofd: ref Sys->FD;
pflag: int;
root: ref File;
files: array of ref File;
pathgen: int;

error(s: string)
{
	sys->fprint(sys->fildes(2), "cpiofs: %s\n", s);
	raise "fail:error";
}

checkload[T](m: T, path: string)
{
	if(m == nil)
		error(sys->sprint("can't load %s: %r", path));
}

init(nil: ref Draw->Context, args: list of string)
{
	sys = load Sys Sys->PATH;
	sys->pctl(Sys->FORKFD|Sys->NEWPGRP, nil);
	styx = load Styx Styx->PATH;
	checkload(styx, Styx->PATH);
	styx->init();
	styxservers = load Styxservers Styxservers->PATH;
	checkload(styxservers, Styxservers->PATH);
	styxservers->init(styx);
	daytime = load Daytime Daytime->PATH;
	checkload(daytime, Daytime->PATH);

	arg := load Arg Arg->PATH;
	checkload(arg, Arg->PATH);
	arg->setusage("cpiofs [-a|-b|-ac|-bc] [-D] file mountpoint");
	arg->init(args);
	flags := Sys->MREPL;
	while((o := arg->opt()) != 0)
		case o {
		'a' =>	flags = Sys->MAFTER;
		'b' =>	flags = Sys->MBEFORE;
		'D' =>	styxservers->traceset(1);
		'p' =>	pflag++;
		* =>		arg->usage();
		}
	args = arg->argv();
	if(len args != 2)
		arg->usage();
	arg = nil;

	file := hd args;
	args = tl args;
	mountpt := hd args;

	sys->pctl(Sys->FORKFD, nil);

	files = array[100] of ref File;
	root = files[0] = ref File;
	root.x = 0;
	root.name = "/";
	root.mode = Sys->DMDIR | 8r555;
	root.uid = "0";
	root.gid = "0";
	root.length = big 0;
	root.offset = big 0;
	root.mtime = 0;
	pathgen = 1;

	cpiofd = sys->open(file, Sys->OREAD);
	if(cpiofd == nil)
		error(sys->sprint("can't open %s: %r", file));
	if(readcpio(cpiofd) < 0)
		error(sys->sprint("error reading %s: %r", file));

	fds := array[2] of ref Sys->FD;
	if(sys->pipe(fds) < 0)
		error(sys->sprint("can't create pipe: %r"));

	navops := chan of ref Navop;
	spawn navigator(navops);

	(tchan, srv) := Styxserver.new(fds[0], Navigator.new(navops), big 0);
	fds[0] = nil;

	pidc := chan of int;
	spawn server(tchan, srv, pidc, navops);
	<-pidc;

	if(sys->mount(fds[1], nil, mountpt, flags, nil) < 0)
		error(sys->sprint("can't mount cpiofs: %r"));
}

server(tchan: chan of ref Tmsg, srv: ref Styxserver, pidc: chan of int, navops: chan of ref Navop)
{
	pidc <-= sys->pctl(Sys->FORKNS|Sys->NEWFD, 1::2::srv.fd.fd::cpiofd.fd::nil);
Serve:
	while((gm := <-tchan) != nil){
		root.mtime = daytime->now();
		pick m := gm {
		Readerror =>
			sys->fprint(sys->fildes(2), "cpiofs: mount read error: %s\n", m.error);
			break Serve;
		Read =>
			(c, err) := srv.canread(m);
			if(c == nil){
				srv.reply(ref Rmsg.Error(m.tag, err));
				break;
			}
			if(c.qtype & Sys->QTDIR){
				srv.default(m);	# does readdir
				break;
			}
			f := files[int c.path];
			n := m.count;
			if(m.offset + big n > f.length)
				n = int (f.length - m.offset);
			if(n <= 0){
				srv.reply(ref Rmsg.Read(m.tag, nil));
				break;
			}
			a := array[n] of byte;
			sys->seek(cpiofd, f.offset+m.offset, 0);
			n = sys->read(cpiofd, a, len a);
			if(n < 0)
				srv.reply(ref Rmsg.Error(m.tag, sys->sprint("%r")));
			else
				srv.reply(ref Rmsg.Read(m.tag, a[0:n]));
		* =>
			srv.default(gm);
		}
	}
	navops <-= nil;		# shut down navigator
}

File.enter(dir: self ref File, f: ref File)
{
	if(pathgen >= len files){
		t := array[pathgen+50] of ref File;
		t[0:] = files;
		files = t;
	}
	if(0)
		sys->print("enter %s, %s [#%ux %bd]\n", dir.name, f.name, f.mode, f.length);
	f.x = pathgen;
	f.parent = dir;
	dir.children = f :: dir.children;
	files[pathgen++] = f;
}

File.find(f: self ref File, name: string): ref File
{
	for(g := f.children; g != nil; g = tl g)
		if((hd g).name == name)
			return hd g;
	return nil;
}

File.stat(f: self ref File): ref Sys->Dir
{
	d := ref sys->zerodir;
	d.mode = f.mode;
	if(pflag) {
		d.mode &= 16rff<<24;
		d.mode |= 8r444;
		if(f.mode & Sys->DMDIR)
			d.mode |= 8r111;
	}
	d.qid.path = big f.x;
	d.qid.qtype = f.mode>>24;
	d.name = f.name;
	d.uid = f.uid;
	d.gid = f.gid;
	d.muid = d.uid;
	d.length = f.length;
	d.mtime = f.mtime;
	d.atime = root.mtime;
	return d;
}

split(s: string): (string, string)
{
	for(i := 0; i < len s; i++)
		if(s[i] == '/'){
			for(j := i+1; j < len s && s[j] == '/';)
				j++;
			return (s[0:i], s[j:]);
		}
	return (nil, s);
}

putfile(f: ref File)
{
	orign := n := f.name;
	df := root;
	for(;;){
		(d, rest) := split(n);
		if(d == ".") {
			n = rest;
			continue;
		}
		if(d == "..") {
			warn(sys->sprint("ignoring %q", orign));
			return;
		}
		if(d == nil || rest == nil){
			f.name = n;
			break;
		}
		g := df.find(d);
		if(g == nil){
			g = ref *f;
			g.name = d;
			g.mode |= Sys->DMDIR;
			df.enter(g);
		}
		n = rest;
		df = g;
	}
	if(f.name == "." || f.name == "..")
		return;
	# A cpio archive often contains both an explicit directory entry
	# and a number of file entries beneath it. If `find` returns a
	# pre-existing directory we created implicitly while walking some
	# earlier file's path, merge the explicit metadata into it instead
	# of inserting a second sibling with the same name.
	existing := df.find(f.name);
	if(existing != nil){
		if((f.mode & Sys->DMDIR) && (existing.mode & Sys->DMDIR)){
			existing.mode = f.mode | Sys->DMDIR;
			existing.uid = f.uid;
			existing.gid = f.gid;
			existing.mtime = f.mtime;
			return;
		}
		# Two distinct entries with the same name (rare, but possible
		# when an archive was concatenated). Drop the later one with
		# a warning rather than silently shadowing.
		warn(sys->sprint("duplicate name %q ignored", orign));
		return;
	}
	df.enter(f);
}

navigator(navops: chan of ref Navop)
{
	while((m := <-navops) != nil){
		pick n := m {
		Stat =>
			n.reply <-= (files[int n.path].stat(), nil);
		Walk =>
			f := files[int n.path];
			if((f.mode & Sys->DMDIR) == 0){
				n.reply <-= (nil, "not a directory");
				break;
			}
			case n.name {
			".." =>
				if(f.parent != nil)
					f = f.parent;
				n.reply <-= (f.stat(), nil);
			* =>
				f = f.find(n.name);
				if(f != nil)
					n.reply <-= (f.stat(), nil);
				else
					n.reply <-= (nil, Enotfound);
			}
		Readdir =>
			f := files[int n.path];
			if((f.mode & Sys->DMDIR) == 0){
				n.reply <-= (nil, "not a directory");
				break;
			}
			g := f.children;
			for(i := n.offset; i > 0 && g != nil; i--)
				g = tl g;
			for(; --n.count >= 0 && g != nil; g = tl g)
				n.reply <-= ((hd g).stat(), nil);
			n.reply <-= (nil, nil);
		}
	}
}

# --------------------------------------------------------------------
# cpio format readers
#
# Two formats are supported, both portable ASCII:
#
#   newc (070701): 110-byte header in ASCII hex. The fields after the
#                  6-byte magic are 8 chars each.
#   odc  (070707): 76-byte header in ASCII octal. Fields differ in
#                  width: 6/6/6/6/6/6/6/6/6/11/6/11.
#
# Both encode file mode in the same C "st_mode" form used by stat(2);
# we extract permission bits and a few file-type bits we care about
# (directory, regular file). Headers are followed by the file name
# (length given by the namesize field, includes NUL terminator),
# then file data; in newc, both name and data are padded to 4-byte
# boundaries.
#
# The archive ends with an entry whose name is the literal string
# "TRAILER!!!" (and nlink=1). We stop reading at that entry.
# --------------------------------------------------------------------

NewcHdr: con 110;	# magic(6) + 13 * 8 hex chars
OdcHdr:  con 76;	# magic(6) + 8 fields of 6 + 2 fields of 11

# Mode bits in C st_mode encoding.
SIFMT:	con 8r170000;
SIFDIR:	con 8r040000;
SIFREG:	con 8r100000;
SIFLNK:	con 8r120000;

readcpio(fd: ref Sys->FD): int
{
	# Peek at magic to decide format.
	buf := array[6] of byte;
	sys->seek(fd, big 0, 0);
	if(sys->read(fd, buf, 6) != 6){
		sys->werrstr("short read at start of cpio");
		return -1;
	}
	magic := string buf;
	case magic {
	"070701" or "070702" =>
		return readnewc(fd);
	"070707" =>
		return readodc(fd);
	* =>
		sys->werrstr("not a cpio archive: bad magic");
		return -1;
	}
}

# --- newc / crc format ---

readnewc(fd: ref Sys->FD): int
{
	hdr := array[NewcHdr] of byte;
	offset := big 0;
	for(;;){
		sys->seek(fd, offset, 0);
		n := sys->read(fd, hdr, NewcHdr);
		if(n == 0)
			break;
		if(n < 0)
			return -1;
		if(n < NewcHdr){
			sys->werrstr(sys->sprint("short header: expected %d got %d", NewcHdr, n));
			return -1;
		}
		magic := string hdr[0:6];
		if(magic != "070701" && magic != "070702"){
			sys->werrstr(sys->sprint("bad newc magic %q at offset %bd", magic, offset));
			return -1;
		}
		# Hex fields (8 chars each):
		#  0 ino   1 mode  2 uid    3 gid     4 nlink
		#  5 mtime 6 fsize 7 devmaj 8 devmin
		#  9 rmaj  10 rmin 11 nsize 12 check
		mode := int hex8(hdr, 6 + 1*8);
		mtime := int hex8(hdr, 6 + 5*8);
		fsize := hex8(hdr, 6 + 6*8);
		nsize := int hex8(hdr, 6 + 11*8);
		if(nsize < 0 || nsize > 4096){
			sys->werrstr(sys->sprint("absurd name size %d", nsize));
			return -1;
		}

		# Read name. Name follows the 110-byte header; namesize
		# includes the trailing NUL.
		nameOffset := offset + big NewcHdr;
		nbuf := array[nsize] of byte;
		sys->seek(fd, nameOffset, 0);
		if(sys->read(fd, nbuf, nsize) != nsize){
			sys->werrstr("short read on name");
			return -1;
		}
		# Strip the NUL terminator.
		nl := nsize;
		if(nl > 0 && nbuf[nl-1] == byte 0) nl--;
		name := string nbuf[0:nl];
		if(name == "TRAILER!!!")
			break;

		# Data lives after name + padding. Both name (relative to
		# the start of its header) and data are padded so that each
		# starts on a 4-byte boundary. The header is 110 bytes, so
		# name padding aligns (110 + nsize) to 4.
		nameEnd := nameOffset + big nsize;
		dataOffset := pad4(nameEnd);
		# Data padding aligns (dataOffset + fsize) to 4 for the
		# next header.
		nextOffset := pad4(dataOffset + fsize);

		f := ref File;
		f.name = name;
		while(len f.name > 0 && f.name[0] == '/')
			f.name = f.name[1:];
		while(len f.name > 0 && f.name[len f.name-1] == '/'){
			mode |= Sys->DMDIR;
			f.name = f.name[:len f.name-1];
		}
		# Translate cpio mode (C st_mode) to our visible mode.
		f.mode = mode & 8r777;
		case (mode & SIFMT) {
		SIFDIR =>
			f.mode |= Sys->DMDIR;
			f.length = big 0;
		SIFLNK =>
			# Skip symbolic links; we don't follow them.
			offset = nextOffset;
			continue;
		* =>
			f.length = fsize;
		}
		f.uid = "0";
		f.gid = "0";
		f.mtime = mtime;
		f.offset = dataOffset;

		putfile(f);
		offset = nextOffset;
	}
	return 0;
}

# --- odc (old POSIX) format ---
#
# Fields are 6-digit octal except dev/ino which are also 6 octal, and
# filesize/mtime which are 11-digit octal. Total 76 bytes.

readodc(fd: ref Sys->FD): int
{
	hdr := array[OdcHdr] of byte;
	offset := big 0;
	for(;;){
		sys->seek(fd, offset, 0);
		n := sys->read(fd, hdr, OdcHdr);
		if(n == 0)
			break;
		if(n < 0)
			return -1;
		if(n < OdcHdr){
			sys->werrstr(sys->sprint("short odc header: %d", n));
			return -1;
		}
		if(string hdr[0:6] != "070707"){
			sys->werrstr(sys->sprint("bad odc magic at offset %bd", offset));
			return -1;
		}
		# Field offsets in the 76-byte header:
		#  6: dev (6 oct)   12: ino (6)   18: mode (6)
		# 24: uid (6)       30: gid (6)   36: nlink (6)
		# 42: rdev (6)      48: mtime (11) 59: namesize (6)
		# 65: filesize (11) total = 76
		mode := int oct(hdr, 18, 6);
		mtime := int oct(hdr, 48, 11);
		nsize := int oct(hdr, 59, 6);
		fsize := oct(hdr, 65, 11);
		if(nsize < 0 || nsize > 4096){
			sys->werrstr(sys->sprint("absurd name size %d", nsize));
			return -1;
		}

		nameOffset := offset + big OdcHdr;
		nbuf := array[nsize] of byte;
		sys->seek(fd, nameOffset, 0);
		if(sys->read(fd, nbuf, nsize) != nsize){
			sys->werrstr("short read on odc name");
			return -1;
		}
		nl := nsize;
		if(nl > 0 && nbuf[nl-1] == byte 0) nl--;
		name := string nbuf[0:nl];
		if(name == "TRAILER!!!")
			break;

		dataOffset := nameOffset + big nsize;	# no padding in odc
		nextOffset := dataOffset + fsize;

		f := ref File;
		f.name = name;
		while(len f.name > 0 && f.name[0] == '/')
			f.name = f.name[1:];
		while(len f.name > 0 && f.name[len f.name-1] == '/'){
			mode |= Sys->DMDIR;
			f.name = f.name[:len f.name-1];
		}
		f.mode = mode & 8r777;
		case (mode & SIFMT) {
		SIFDIR =>
			f.mode |= Sys->DMDIR;
			f.length = big 0;
		SIFLNK =>
			offset = nextOffset;
			continue;
		* =>
			f.length = fsize;
		}
		f.uid = "0";
		f.gid = "0";
		f.mtime = mtime;
		f.offset = dataOffset;

		putfile(f);
		offset = nextOffset;
	}
	return 0;
}

# --- ASCII numeric field parsers ---

# Parse 8 hex digits at b[off..off+8] as a big integer. Validates
# range; on any non-hex character, raises an error.
hex8(b: array of byte, off: int): big
{
	v := big 0;
	for(i := 0; i < 8; i++){
		c := int b[off + i];
		d := 0;
		if(c >= '0' && c <= '9') d = c - '0';
		else if(c >= 'A' && c <= 'F') d = c - 'A' + 10;
		else if(c >= 'a' && c <= 'f') d = c - 'a' + 10;
		else error(sys->sprint("bad hex digit %c in cpio header", c));
		v = (v << 4) | big d;
	}
	return v;
}

# Parse `n` octal digits at b[off..off+n]. Spaces and trailing zeros
# are tolerated.
oct(b: array of byte, off, n: int): big
{
	v := big 0;
	for(i := 0; i < n; i++){
		c := int b[off + i];
		if(c == ' ' || c == 0)
			continue;
		if(c < '0' || c > '7')
			error(sys->sprint("bad octal digit %c in cpio header", c));
		v = (v << 3) | big (c - '0');
	}
	return v;
}

# Round x up to the next multiple of 4.
pad4(x: big): big
{
	r := int (x % big 4);
	if(r == 0) return x;
	return x + big (4 - r);
}

warn(s: string)
{
	sys->fprint(sys->fildes(2), "cpiofs: %s\n", s);
}
