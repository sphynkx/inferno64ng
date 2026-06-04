implement Bunzip2;

include "sys.m";
	sys:	Sys;
	fprint, sprint: import sys;

include "draw.m";

include "string.m";
	str: String;

include "bufio.m";
	bufio:	Bufio;
	Iobuf:	import bufio;

include "filter.m";
	bunz: Filter;

Bunzip2: module
{
	init:	fn(ctxt: ref Draw->Context, argv: list of string);
};

argv0:	con "bunzip2";
stderr:	ref Sys->FD;

BWTINFLATEPATH: con "/dis/lib/bwtinflate.dis";

tostdout := 0;
keep := 0;

init(nil: ref Draw->Context, argv: list of string)
{
	sys = load Sys Sys->PATH;
	stderr = sys->fildes(2);
	bufio = load Bufio Bufio->PATH;
	if (bufio == nil)
		fatal(sys->sprint("cannot load %s: %r", Bufio->PATH));
	str = load String String->PATH;
	if (str == nil)
		fatal(sys->sprint("cannot load %s: %r", String->PATH));
	bunz = load Filter BWTINFLATEPATH;
	if (bunz == nil)
		fatal(sys->sprint("cannot load %s: %r", BWTINFLATEPATH));

	bunz->init();

	tostdout = 0;
	keep = 0;

	if(argv != nil)
		argv = tl argv;

	while(argv != nil){
		a := hd argv;
		if(len a < 2 || a[0] != '-' || a == "--")
			break;
		case a[1] {
		'c' =>
			tostdout = 1;
		'k' =>
			keep = 1;
		* =>
			fprint(stderr, "usage: %s [-ck] [file ...]\n", argv0);
			raise "fail:usage";
		}
		argv = tl argv;
	}

	ok := 1;
	if(len argv == 0){
		bin := bufio->fopen(sys->fildes(0), Bufio->OREAD);
		bout := bufio->fopen(sys->fildes(1), Bufio->OWRITE);
		ok = bunzip2(bin, bout, "stdin", "stdout");
		bout.close();
		bin.close();
	} else if(tostdout){
		bout := bufio->fopen(sys->fildes(1), Bufio->OWRITE);
		for(; argv != nil; argv = tl argv){
			f := hd argv;
			bin := bufio->open(f, Bufio->OREAD);
			if(bin == nil){
				fprint(stderr, "%s: can't open %s: %r\n", argv0, f);
				ok = 0;
				continue;
			}
			if(!bunzip2(bin, bout, f, "stdout"))
				ok = 0;
			bin.close();
		}
		bout.close();
	} else {
		for(; argv != nil; argv = tl argv)
			ok &= bunzip2f(hd argv);
	}

	if(ok == 0)
		raise "fail:errors";
}

bunzip2f(file: string): int
{
	bin := bufio->open(file, Bufio->OREAD);
	if(bin == nil){
		fprint(stderr, "%s: can't open %s: %r\n", argv0, file);
		return 0;
	}

	n := len file;
	ofile: string;
	if(n >= 4 && file[n-4:] == ".bz2")
		ofile = file[:n-4];
	else if(n >= 4 && file[n-4:] == ".tbz")
		ofile = file[:n-4] + ".tar";
	else if(n >= 5 && file[n-5:] == ".tbz2")
		ofile = file[:n-5] + ".tar";
	else {
		fprint(stderr, "%s: .bz2 extension required: %s\n", argv0, file);
		bin.close();
		return 0;
	}

	bout := bufio->create(ofile, Bufio->OWRITE, 8r666);
	if(bout == nil){
		fprint(stderr, "%s: can't open %s: %r\n", argv0, ofile);
		bin.close();
		return 0;
	}

	ok := bunzip2(bin, bout, file, ofile);
	bin.close();
	bout.close();

	if(ok && !keep) {
		if (sys->remove(file) == -1)
			sys->fprint(stderr, "%s: cannot remove %s: %r\n", argv0, file);
	}

	return ok;
}

bunzip2(bin, bout: ref Iobuf, fin, fout: string): int
{
	rq := bunz->start("");
	for(;;) {
		pick m := <-rq {
		Fill =>
			n := bin.read(m.buf, len m.buf);
			m.reply <-= n;
			if (n == -1) {
				sys->fprint(stderr, "%s: %s: read error: %r\n", argv0, fin);
				return 0;
			}
		Result =>
			n := len m.buf;
			if (n > 0) {
				if (bout.write(m.buf, n) != n) {
					m.reply <-= -1;
					sys->fprint(stderr, "%s: %s: write error: %r\n", argv0, fout);
					return 0;
				}
			}
			m.reply <-= 0;
		Finished =>
			if (bout.flush() != 0) {
				sys->fprint(stderr, "%s: %s: flush error: %r\n", argv0, fout);
				return 0;
			}
			return 1;
		Error =>
			sys->fprint(stderr, "%s: %s: bunzip2 error: %s\n", argv0, fin, m.e);
			return 0;
		}
	}
}

fatal(msg: string)
{
	fprint(stderr, "%s: %s\n", argv0, msg);
	raise "fail:error";
}