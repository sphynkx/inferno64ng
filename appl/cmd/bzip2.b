implement Bzip2;

include "sys.m";
	sys:	Sys;
	fprint: import sys;

include "draw.m";

include "string.m";
	str: String;

include "bufio.m";
	bufio:	Bufio;
	Iobuf: import bufio;

include "filter.m";
	bwt: Filter;

BWTDEFLATEPATH: con "/dis/lib/bwtdeflate.dis";

Bzip2: module
{
	init:	fn(ctxt: ref Draw->Context, argv: list of string);
};

argv0:		con "bzip2";
stderr:		ref Sys->FD;
verbose		:= 0;
level		:= 0;
tostdout	:= 0;
keep		:= 0;

usage()
{
	fprint(stderr, "usage: %s [-cdkv1-9] [file ...]\n", argv0);
	raise "fail:usage";
}

nomod(path: string)
{
	sys->fprint(stderr, "%s: cannot load %s: %r\n", argv0, path);
	raise "fail:bad module";
}

init(nil: ref Draw->Context, argv: list of string)
{
	sys = load Sys Sys->PATH;
	stderr = sys->fildes(2);
	bufio = load Bufio Bufio->PATH;
	if (bufio == nil)
		nomod(Bufio->PATH);
	str = load String String->PATH;
	if (str == nil)
		nomod(String->PATH);
	bwt = load Filter BWTDEFLATEPATH;
	if(bwt == nil)
		nomod(BWTDEFLATEPATH);

	bwt->init();

	verbose = 0;
	tostdout = 0;
	keep = 0;
	level = 9;

	if(argv != nil)
		argv = tl argv;

	while(argv != nil){
		a := hd argv;
		if(len a < 2 || a[0] != '-' || a == "--")
			break;
		ok := 1;
		for(i := 1; i < len a; i++){
			c := a[i];
			case c {
			'v' => verbose++;
			'c' => tostdout = 1;
			'k' => keep = 1;
			'd' =>
				fprint(stderr, "%s: use bunzip2 for decompression\n", argv0);
				raise "fail:usage";
			'1' to '9' => level = c - '0';
			* => ok = 0;
			}
		}
		if(!ok)
			usage();
		argv = tl argv;
	}

	rc := 1;
	if(len argv == 0){
		bin := bufio->fopen(sys->fildes(0), Bufio->OREAD);
		bout := bufio->fopen(sys->fildes(1), Bufio->OWRITE);
		rc = bzip2(bin, bout, "stdin", "stdout");
		bout.close();
		bin.close();
	} else if(tostdout){
		bout := bufio->fopen(sys->fildes(1), Bufio->OWRITE);
		for(; argv != nil; argv = tl argv){
			f := hd argv;
			bin := bufio->open(f, Bufio->OREAD);
			if(bin == nil){
				fprint(stderr, "%s: can't open %s: %r\n", argv0, f);
				rc = 0;
				continue;
			}
			if(!bzip2(bin, bout, f, "stdout"))
				rc = 0;
			bin.close();
		}
		bout.close();
	} else {
		for(; argv != nil; argv = tl argv)
			rc &= bzip2f(hd argv);
	}
	if(!rc)
		raise "fail:errors";
}

bzip2f(file: string): int
{
	bin := bufio->open(file, Bufio->OREAD);
	if(bin == nil){
		fprint(stderr, "%s: can't open %s: %r\n", argv0, file);
		return 0;
	}

	ofile := file + ".bz2";
	bout := bufio->create(ofile, Bufio->OWRITE, 8r666);
	if(bout == nil){
		fprint(stderr, "%s: can't open %s: %r\n", argv0, ofile);
		bin.close();
		return 0;
	}

	rc := bzip2(bin, bout, file, ofile);
	bin.close();
	bout.close();
	if(rc && !keep){
		if(sys->remove(file) == -1)
			fprint(stderr, "%s: cannot remove %s: %r\n", argv0, file);
	} else if(!rc)
		sys->remove(ofile);
	return rc;
}

bzip2(bin, bout: ref Iobuf, fin, fout: string): int
{
	incount := 0;
	outcount := 0;
	rq := bwt->start(string level);

	for (;;) {
		pick m := <-rq {
		Fill =>
			n := bin.read(m.buf, len m.buf);
			m.reply <-= n;
			if (n == -1) {
				sys->fprint(stderr, "%s: error reading %s: %r\n", argv0, fin);
				return 0;
			}
			incount += n;
		Result =>
			n := len m.buf;
			if (bout.write(m.buf, n) != n) {
				sys->fprint(stderr, "%s: error writing %s: %r\n", argv0, fout);
				m.reply <-= -1;
				return 0;
			}
			m.reply <-= 0;
			outcount += n;
		Info =>
			sys->fprint(stderr, "%s\n", m.msg);
		Finished =>
			if(bout.flush() != 0){
				sys->fprint(stderr, "%s: %s: flush error: %r\n", argv0, fout);
				return 0;
			}
			if(verbose){
				ratio := 0.0;
				if(incount > 0)
					ratio = 100.0 * real outcount / real incount;
				sys->fprint(stderr, "%s: %5.2f%%\n", fin, ratio);
			}
			return 1;
		Error =>
			sys->fprint(stderr, "%s: error compressing %s: %s\n", argv0, fin, m.e);
			return 0;
		}
	}
}
