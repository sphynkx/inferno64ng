# Adapted from: https://github.com/LunarLambda/hexe

implement Hexe;

include "sys.m";
	sys: Sys;
	sprint: import sys;

include "draw.m";

include "bufio.m";
	bio: Bufio;
	Iobuf, OREAD, OWRITE: import bio;

Hexe: module {
	init: fn(nil: ref Draw->Context, argv: list of string);
};

# Input and output buffers
in:	ref Iobuf;
out:	ref Iobuf;

# Hexe is a hexdumping tool with 0% fat.
init(nil: ref Draw->Context, argv: list of string) {
	sys = load Sys Sys->PATH;
	bio = load Bufio Bufio->PATH;

	# Strip prog name, we don't use it
	argv = tl argv;
	argc := len argv;

	perm := 8r664;

	case argc {
	0 =>
		# Use stdin/stdout
		in = bio->open("/fd/0", OREAD);
		out = bio->open("/fd/1", OWRITE);

	1 =>
		# Form is equivalent to: hexe infile -
		inf := hd argv;

		if(inf == "-")
			inf = "/fd/0";

		in = bio->open(inf, OREAD);
		out = bio->create("/fd/1", OWRITE, perm);
		
	2 =>
		# Form is hexe infile outfile
		inf := hd argv;
		outf := hd tl argv;

		if(inf == "-")
			inf = "/fd/0";

		if(outf == "-")
			outf = "/fd/1";

		in = bio->open(inf, OREAD);
		out = bio->create(outf, OWRITE, perm);

	* =>
		usage();
	}

	if(in == nil)
		raise "input file is nil";
	if(out == nil)
		raise "output file is nil";

	# Hexdump
	bytes := array[16] of { * => byte 0 };
	nread: int;
	while(nread = in.read(bytes, len bytes)) {
		# Write the offset
		buf := array of byte sprint("%08bx\t", in.offset());
		ewrite(buf);

		# Write the ≤16 byte block
		for(i := 0; i < nread; i++) {
			buf = array of byte sprint("%02x", int bytes[i]);
			ewrite(buf);

			out.putc(' ');
		}
		out.putc('\n');
	}

	# Clean up -- flushes on close
	in.close();
	out.close();

	exit;
}

# Prints usage text -- may use a '-' to indicate stdin/stdout
usage() {
	sys->fprint(sys->fildes(2), "usage: hexe [infile] [outfile]\n");
	exit;
}

# Writes to output, tests for errors
ewrite(buf: array of byte) {
	n₀ := len buf;

	n₁ := out.write(buf, n₀);

	# Non-equal read -- see sys(2) and bufio(2)
	if(n₀ != n₁)
		raise "writing to file -- bad read of size " + string n₀ + " expected " + string n₁;
}
