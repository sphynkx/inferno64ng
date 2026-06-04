# Decompressor for the GNU bzip2 file format.
#
# Implements the Filter module interface (module/filter.m) and is
# loaded by appl/cmd/bunzip2.b from /dis/lib/bwtinflate.dis. The
# inverse pairing with a (future) appl/lib/bwtdeflate.b would form
# the complete bzip2 encode/decode pair, analogous to deflate.b /
# inflate.b for gzip.
#
# Wire format (high level):
#
#   "BZh"  3 bytes
#   digit  1 byte ('1'..'9'); block size hint = 100000 * digit
#   { block }*
#   0x177245385090  48-bit end-of-stream marker
#   crc            32-bit stream CRC (XOR-combined per-block CRCs)
#   padding        to byte boundary
#
# Block layout (all bit-level after the first byte of magic):
#
#   0x314159265359   48-bit block magic
#   crc             32-bit
#   randomised      1 bit (legacy; modern streams: 0)
#   origPtr         24-bit (BWT primary index)
#   alphabet bitmap:
#       16 bits     which groups of 16 bytes appear
#       {16 bits}*  for each '1' group, which bytes within it
#   nGroups         3 bits (2..6)
#   nSelectors     15 bits
#   {selector}*    each MTF-coded as unary (0='0', 1='10', 2='110',...)
#   {coding tree}*nGroups   each: 5-bit init length, then for each
#                           symbol: while bit '1' read another bit
#                           (0 -> +1 length, 1 -> -1), final '0' ends
#   coded symbols  change tree every 50 symbols per selector list
#   EOB symbol terminates the block
#
# Pipeline after Huffman decode of one block:
#
#   syms --inverse RLE-2--> mtf --inverse MTF--> L (BWT last col)
#        --inverse BWT-->  rle1 --inverse RLE-1--> original bytes
#
# CRC bits are consumed but not verified (block CRC and stream CRC).
# Randomised blocks return an error; that flag has been 0 in every
# bzip2 stream since version 1.0.2.

implement Filter;

include "sys.m";
	sys: Sys;

include "filter.m";

# Symbol IDs in the inner stream after MTF + RLE-2:
#   0 = RUNA  (bijective base-2 digit 1)
#   1 = RUNB  (bijective base-2 digit 2)
#   2..nSyms-2 = shifted MTF index (originals 1..alphaSize-1)
#   nSyms-1 = EOB (end of block)
RUNA:	con 0;
RUNB:	con 1;

MAX_GROUPS:	con 6;
MAX_SELECTORS:	con 18002;
GROUP_SIZE:	con 50;
MAX_SYMS:	con 258;	# alphaSize+2: up to 256 distinct bytes + RUNA + RUNB + EOB

# Block size cap (level=9 in upstream bzip2). Inflate can encounter any
# valid block, so we honour the full 900000.
MAX_BLOCK:	con 900000;

# ---------------- Reader: pulls bytes from the Filter Fill channel ----------------

Reader: adt {
	rq:	chan of ref Rq;
	buf:	array of byte;
	pos:	int;
	eof:	int;
};

# ---------------- Bit reader sitting on top of a byte Reader ----------------
# MSB-first within each byte (matches bzip2's bit packing).

BitR: adt {
	r:	ref Reader;
	cur:	int;	# 0..255, current byte
	left:	int;	# bits remaining in cur (0..8)
};

br_new(r: ref Reader): ref BitR
{
	b := ref BitR;
	b.r = r;
	b.cur = 0;
	b.left = 0;
	return b;
}

# Read one bit MSB-first. Returns -1 on EOF.
br_bit(b: ref BitR): int
{
	if(b.left == 0){
		buf := read_n(b.r, 1);
		if(buf == nil || len buf < 1) return -1;
		b.cur = int buf[0] & 16rFF;
		b.left = 8;
	}
	b.left--;
	return (b.cur >> b.left) & 1;
}

# Read n bits (1..32) MSB-first as a non-negative integer. -1 on EOF.
br_bits(b: ref BitR, n: int): int
{
	v := 0;
	for(i := 0; i < n; i++){
		bit := br_bit(b);
		if(bit < 0) return -1;
		v = (v << 1) | bit;
	}
	return v;
}

# ---------------- Filter entry points ----------------

init()
{
	sys = load Sys Sys->PATH;
}

start(param: string): chan of ref Rq
{
	param = param;	# no params
	rq := chan of ref Rq;
	spawn decompressor(rq);
	return rq;
}

# ---------------- Top-level decompressor ----------------

decompressor(rq: chan of ref Rq)
{
	r := ref Reader;
	r.rq = rq;
	r.buf = array[0] of byte;
	r.pos = 0;
	r.eof = 0;

	# Read 4-byte header: "BZh" + digit.
	hdr := read_n(r, 4);
	if(hdr == nil || len hdr < 4){
		error(rq, "short header");
		return;
	}
	if(hdr[0] != byte 'B' || hdr[1] != byte 'Z' || hdr[2] != byte 'h'){
		error(rq, "not a bzip2 stream: bad magic");
		return;
	}
	if(hdr[3] < byte '1' || hdr[3] > byte '9'){
		error(rq, "bad block-size digit");
		return;
	}
	# blockSize := (int hdr[3] - int byte '0') * 100000;	# informational only

	bits := br_new(r);
	streamCrc := 0;
	streamCrc = streamCrc;

	for(;;){
		# Read 48-bit magic. Spec defines:
		#   0x314159265359 = block magic
		#   0x177245385090 = EOS magic
		hi := br_bits(bits, 24);
		if(hi < 0){
			error(rq, "truncated stream (no block magic)");
			return;
		}
		lo := br_bits(bits, 24);
		if(lo < 0){
			error(rq, "truncated stream (no block magic)");
			return;
		}
		if(hi == 16r314159 && lo == 16r265359){
			# block follows
			ok := decompress_block(rq, bits);
			if(!ok) return;
			continue;
		}
		if(hi == 16r177245 && lo == 16r385090){
			# Followed by 32-bit stream CRC + byte padding.
			# We don't currently verify the stream CRC.
			br_bits(bits, 32);
			finished(rq);
			return;
		}
		error(rq, "unrecognised block magic");
		return;
	}
}

# ---------------- One block ----------------

decompress_block(rq: chan of ref Rq, bits: ref BitR): int
{
	# Per-block CRC. We do not verify, but consume the bits.
	br_bits(bits, 32);

	# Randomised flag.
	rnd := br_bits(bits, 1);
	if(rnd < 0){ error(rq, "truncated block: rnd"); return 0; }
	if(rnd != 0){
		error(rq, "randomised blocks not supported");
		return 0;
	}

	# 24-bit BWT primary index.
	origPtr := br_bits(bits, 24);
	if(origPtr < 0){ error(rq, "truncated block: origPtr"); return 0; }

	# --- Symbol map: 16 bits "which groups", then 16 bits per used group ---
	groupMask := br_bits(bits, 16);
	if(groupMask < 0){ error(rq, "truncated block: groupMask"); return 0; }
	# Reconstruct the alphabet as a sorted array of byte values.
	alpha := array[256] of byte;
	alphaCount := 0;
	for(g := 0; g < 16; g++){
		if((groupMask >> (15 - g)) & 1){
			groupBits := br_bits(bits, 16);
			if(groupBits < 0){ error(rq, "truncated block: group bits"); return 0; }
			for(j := 0; j < 16; j++){
				if((groupBits >> (15 - j)) & 1){
					alpha[alphaCount++] = byte (g * 16 + j);
				}
			}
		}
	}
	if(alphaCount == 0){
		error(rq, "empty alphabet");
		return 0;
	}
	alphabet := alpha[0:alphaCount];

	# Inner symbol count = alphaCount + 2 (RUNA, RUNB and EOB sandwich
	# the shifted non-zero MTF indices). EOB = nSyms - 1.
	nSyms := alphaCount + 2;

	# --- nGroups and nSelectors ---
	nGroups := br_bits(bits, 3);
	if(nGroups < 2 || nGroups > MAX_GROUPS){
		error(rq, "bad nGroups");
		return 0;
	}
	nSelectors := br_bits(bits, 15);
	if(nSelectors < 1 || nSelectors > MAX_SELECTORS){
		error(rq, "bad nSelectors");
		return 0;
	}

	# --- Selector list: each value 0..nGroups-1, MTF-coded, written
	#     as unary (0='0', 1='10', 2='110', ...).
	selMtf := array[nSelectors] of int;
	for(i := 0; i < nSelectors; i++) selMtf[i] = 0;
	for(i = 0; i < nSelectors; i++){
		k := 0;
		for(;;){
			bit := br_bit(bits);
			if(bit < 0){ error(rq, "truncated: selector"); return 0; }
			if(bit == 0) break;
			k++;
			if(k >= nGroups){
				error(rq, "bad selector value");
				return 0;
			}
		}
		selMtf[i] = k;
	}
	# Invert the MTF on the selector list.
	mtfPos := array[MAX_GROUPS] of int;
	for(i = 0; i < nGroups; i++) mtfPos[i] = i;
	selectors := array[nSelectors] of int;
	for(i = 0; i < nSelectors; i++){
		k := selMtf[i];
		s := mtfPos[k];
		# move s to front
		for(j := k; j > 0; j--) mtfPos[j] = mtfPos[j-1];
		mtfPos[0] = s;
		selectors[i] = s;
	}

	# --- Per-group code-length tables, then build canonical codes ---
	# lengths[g][s] = bit-length for symbol s in group g
	lengths := array[nGroups] of array of int;
	for(g = 0; g < nGroups; g++){
		L := array[nSyms] of int;
		curLen := br_bits(bits, 5);
		if(curLen < 0){ error(rq, "truncated: tree init"); return 0; }
		for(s := 0; s < nSyms; s++){
			# while next bit == 1: read another and adjust
			for(;;){
				bit := br_bit(bits);
				if(bit < 0){ error(rq, "truncated: tree"); return 0; }
				if(bit == 0) break;
				bit2 := br_bit(bits);
				if(bit2 < 0){ error(rq, "truncated: tree"); return 0; }
				if(bit2 == 0) curLen++;
				else curLen--;
				if(curLen < 1 || curLen > 20){
					error(rq, "bad code length");
					return 0;
				}
			}
			L[s] = curLen;
		}
		lengths[g] = L;
	}
	# Build canonical (limits, base, perm) tables per group.
	# limits[g][L] = largest code value of length L
	# base[g][L]   = value at start of length L, normalised so that we
	#                can binary-decode by subtracting
	# perm[g][i]   = symbol index of the i-th code in ascending order
	limits := array[nGroups] of array of int;
	bases := array[nGroups] of array of int;
	perms := array[nGroups] of array of int;
	for(g = 0; g < nGroups; g++){
		(lim, bas, per) := build_huff_tables(lengths[g], nSyms);
		if(lim == nil){ error(rq, "bad huffman table"); return 0; }
		limits[g] = lim;
		bases[g] = bas;
		perms[g] = per;
	}

	# --- Decode symbols, switching trees every 50 syms ---
	# Maximum number of symbols in inner stream is roughly block * 2 plus EOB.
	# We grow as we go.
	syms := array[1024] of int;
	for(i = 0; i < 1024; i++) syms[i] = 0;
	op := 0;
	groupIdx := 0;
	groupLeft := 0;
	curG := 0;
	EOB := nSyms - 1;
	for(;;){
		if(groupLeft == 0){
			if(groupIdx >= nSelectors){
				error(rq, "selector list exhausted before EOB");
				return 0;
			}
			curG = selectors[groupIdx++];
			groupLeft = GROUP_SIZE;
		}
		sym := decode_one(bits, limits[curG], bases[curG], perms[curG]);
		if(sym < 0){ error(rq, "huff decode failed"); return 0; }
		if(op >= len syms) syms = growints(syms, op + 256);
		syms[op++] = sym;
		groupLeft--;
		if(sym == EOB) break;
	}
	symStream := syms[0:op];

	# --- Inverse RLE-2 (RUNA/RUNB bijective base-2 zero-runs) -> MTF ---
	mtf := rle2_inverse(symStream, alphaCount);

	# --- Inverse MTF -> BWT last-column bytes ---
	L := mtf_inverse(mtf, alphabet);

	# --- Inverse BWT -> RLE-1 stream ---
	rle1 := bwt_inverse(L, origPtr);

	# --- Inverse RLE-1 -> original bytes ---
	out := rle1_inverse(rle1);

	# Send to consumer.
	if(len out > 0)
		emit(rq, out);
	return 1;
}

# ---------------- Huffman: canonical tables and per-symbol decode ----------------

# Build (limits, bases, perm) arrays for a Huffman code defined by its
# per-symbol bit lengths. Returns (nil, nil, nil) on a malformed table.
#
# Convention used here:
#   lengths[s] in 1..20
#   We compute, for each length L:
#       count[L]  -- number of codes of length L
#       first[L]  -- first canonical code of length L
#       limits[L] -- last canonical code of length L (-1 if none)
#       bases[L]  -- start index in `perm` of the L-length block, biased
#                    by first[L] so we can decode by subtraction
#   perm[]      -- symbols listed in (length, symbol-index) order
build_huff_tables(lengths: array of int, nSyms: int): (array of int, array of int, array of int)
{
	maxLen := 0;
	minLen := 21;
	for(s := 0; s < nSyms; s++){
		l := lengths[s];
		if(l < 1 || l > 20) return (nil, nil, nil);
		if(l > maxLen) maxLen = l;
		if(l < minLen) minLen = l;
	}
	if(maxLen == 0) return (nil, nil, nil);
	count := array[maxLen + 2] of int;
	for(i := 0; i <= maxLen + 1; i++) count[i] = 0;
	for(s = 0; s < nSyms; s++) count[lengths[s]]++;
	# first[L] = first code at length L (canonical)
	first := array[maxLen + 2] of int;
	for(i = 0; i <= maxLen + 1; i++) first[i] = 0;
	code := 0;
	for(L := 1; L <= maxLen; L++){
		first[L] = code;
		code += count[L];
		code <<= 1;
	}
	# limits[L] = last valid code of length L; -1 if none
	limits := array[maxLen + 2] of int;
	for(L = 0; L <= maxLen + 1; L++) limits[L] = -1;
	for(L = 1; L <= maxLen; L++){
		if(count[L] > 0)
			limits[L] = first[L] + count[L] - 1;
	}
	# bases[L]: offset into perm so that for an accepted code v of length L,
	# perm[bases[L] + v] is the symbol.
	# We assign perm in (length, symbol-index) order so the i-th symbol
	# of length L sits at position (sumPrev + i) where sumPrev = total
	# number of symbols with length < L. Thus bases[L] = sumPrev - first[L].
	bases := array[maxLen + 2] of int;
	for(L = 0; L <= maxLen + 1; L++) bases[L] = 0;
	cumulative := 0;
	for(L = 1; L <= maxLen; L++){
		bases[L] = cumulative - first[L];
		cumulative += count[L];
	}
	# perm[] in (length, symbol-index) order.
	perm := array[nSyms] of int;
	idxAt := array[maxLen + 2] of int;
	for(L = 0; L <= maxLen + 1; L++) idxAt[L] = 0;
	# Compute starting offset for each length.
	off := array[maxLen + 2] of int;
	for(L = 0; L <= maxLen + 1; L++) off[L] = 0;
	cumulative = 0;
	for(L = 1; L <= maxLen; L++){
		off[L] = cumulative;
		cumulative += count[L];
	}
	for(s = 0; s < nSyms; s++){
		l := lengths[s];
		if(l > 0){
			perm[off[l] + idxAt[l]] = s;
			idxAt[l]++;
		}
	}
	# Pack maxLen as the last element so the decoder knows the loop bound.
	# We use sentinel limits[0] = maxLen to communicate it.
	limits[0] = maxLen;
	return (limits, bases, perm);
}

# Decode one symbol from the bitstream using (limits, bases, perm).
# Returns -1 on EOF or invalid code.
decode_one(bits: ref BitR, limits: array of int, bases: array of int, perm: array of int): int
{
	maxLen := limits[0];
	v := 0;
	for(L := 1; L <= maxLen; L++){
		bit := br_bit(bits);
		if(bit < 0) return -1;
		v = (v << 1) | bit;
		if(limits[L] >= 0 && v <= limits[L]){
			# Found: symbol is perm[bases[L] + v]
			idx := bases[L] + v;
			if(idx < 0 || idx >= len perm) return -1;
			return perm[idx];
		}
	}
	return -1;
}

# ---------------- Inverse RLE-2 ----------------
# RUNA/RUNB symbols encode a zero-run length in bijective base 2:
#   value = sum over emitted digits d_i of d_i * 2^i,
#   with d_i in {1, 2} (RUNA=1, RUNB=2).
# Output indices are MTF indices (0..alphaCount-1). Non-zero MTF indices
# arrive as `sym - 1` for sym in 2..nSyms-2.
rle2_inverse(syms: array of int, alphaCount: int): array of int
{
	out := array[len syms * 4 + 16] of int;
	op := 0;
	runPos := 0;
	runVal := 0;

	for(i := 0; i < len syms; i++){
		s := syms[i];

		if(s == RUNA || s == RUNB){
			runVal += (s + 1) << runPos;
			runPos++;
			continue;
		}

		if(runPos > 0){
			while(runVal > 0){
				if(op >= len out)
					out = growints(out, op + 64);
				out[op++] = 0;
				runVal--;
			}
			runPos = 0;
			runVal = 0;
		}

		if(s >= alphaCount + 1)
			break;

		if(op >= len out)
			out = growints(out, op + 64);
		out[op++] = s - 1;
	}

	if(runPos > 0){
		while(runVal > 0){
			if(op >= len out)
				out = growints(out, op + 64);
			out[op++] = 0;
			runVal--;
		}
	}

	return out[0:op];
}

# ---------------- Inverse MTF ----------------
# Given a stream of MTF indices and the initial alphabet (sorted byte
# values), produce the byte stream.
mtf_inverse(mtf: array of int, alpha: array of byte): array of byte
{
	count := len alpha;
	stack := array[count] of byte;
	stack[0:] = alpha;
	out := array[len mtf] of byte;
	for(i := 0; i < len mtf; i++){
		idx := mtf[i];
		if(idx < 0 || idx >= count){
			out[i] = byte 0;
			continue;
		}
		v := stack[idx];
		out[i] = v;
		if(idx > 0){
			for(k := idx; k > 0; k--) stack[k] = stack[k-1];
			stack[0] = v;
		}
	}
	return out;
}

# ---------------- Inverse BWT ----------------
# L is the last column of the sorted-rotations matrix; primary is the
# row index of the original rotation. Standard linear-time inversion.
bwt_inverse(L: array of byte, primary: int): array of byte
{
	n := len L;
	if(n == 0) return array[0] of byte;
	count := array[257] of int;
	for(i := 0; i < 257; i++) count[i] = 0;
	for(i = 0; i < n; i++) count[int L[i] + 1]++;
	for(i = 1; i <= 256; i++) count[i] += count[i-1];
	next := array[n] of int;
	for(i = 0; i < n; i++) next[i] = 0;
	pos := array[256] of int;
	pos[0:] = count[0:256];
	for(i = 0; i < n; i++){
		c := int L[i];
		next[pos[c]++] = i;
	}
	out := array[n] of byte;
	# bzip2 spec: the original first byte is at row `next[primary]`,
	# i.e. we start the walk from there.
	j := next[primary];
	for(i = 0; i < n; i++){
		out[i] = L[j];
		j = next[j];
	}
	return out;
}

# ---------------- Inverse RLE-1 ----------------
# Sequences of 4 identical bytes are followed by a length byte L (0..251);
# expand to 4+L copies.
rle1_inverse(src: array of byte): array of byte
{
	if(len src == 0) return array[0] of byte;
	out := array[len src * 4 + 16] of byte;
	op := 0;
	i := 0;
	while(i < len src){
		b := src[i];
		if(i + 3 < len src && src[i+1] == b && src[i+2] == b && src[i+3] == b){
			if(i + 4 >= len src){
				for(k := 0; k < 4; k++){
					if(op >= len out) out = growbytes(out, op + 16);
					out[op++] = b;
				}
				i += 4;
				continue;
			}
			extra := int src[i+4];
			total := 4 + extra;
			for(k := 0; k < total; k++){
				if(op >= len out) out = growbytes(out, op + 16);
				out[op++] = b;
			}
			i += 5;
		} else {
			if(op >= len out) out = growbytes(out, op + 16);
			out[op++] = b;
			i++;
		}
	}
	return out[0:op];
}

# ---------------- Reader over the Filter Fill channel ----------------

read_n(r: ref Reader, n: int): array of byte
{
	out := array[n] of byte;
	got := 0;
	while(got < n){
		if(r.pos >= len r.buf){
			if(r.eof) break;
			tmp := array[4096] of byte;
			reply := chan of int;
			r.rq <-= ref Rq.Fill(tmp, reply);
			k := <-reply;
			if(k < 0) return nil;
			if(k == 0){
				r.eof = 1;
				break;
			}
			r.buf = tmp[0:k];
			r.pos = 0;
		}
		take := n - got;
		avail := len r.buf - r.pos;
		if(take > avail) take = avail;
		out[got:] = r.buf[r.pos:r.pos+take];
		r.pos += take;
		got += take;
	}
	if(got < n) return out[0:got];
	return out;
}

# ---------------- Helpers ----------------

growbytes(a: array of byte, newlen: int): array of byte
{
	if(newlen <= len a) return a;
	nl := len a * 2;
	if(nl < newlen) nl = newlen;
	b := array[nl] of byte;
	b[0:] = a;
	return b;
}

growints(a: array of int, newlen: int): array of int
{
	if(newlen <= len a) return a;
	nl := len a * 2;
	if(nl < newlen) nl = newlen;
	b := array[nl] of int;
	b[0:] = a;
	return b;
}

emit(rq: chan of ref Rq, b: array of byte)
{
	reply := chan of int;
	rq <-= ref Rq.Result(b, reply);
	<-reply;
}

error(rq: chan of ref Rq, msg: string)
{
	rq <-= ref Rq.Error(msg);
}

finished(rq: chan of ref Rq)
{
	rq <-= ref Rq.Finished(nil);
}
