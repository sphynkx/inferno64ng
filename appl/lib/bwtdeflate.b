# Compressor for the GNU bzip2 file format.
#
# Implements the Filter module interface (module/filter.m) as the
# counterpart to appl/lib/bwtinflate.b. Produces output that decodes
# correctly with both our own bunzip2 and the standard GNU bunzip2(1).
#
# Pipeline:
#
#   raw --RLE-1--> BWT --MTF + RLE-2--> Huffman --bitstream
#
# Uses two identical Huffman tables (the minimum allowed by the spec,
# nGroups==2) with an all-zero selector list. That gives correct,
# well-formed output and good ratios for typical inputs; a multi-table
# compressor would compress better on heterogeneous data but is
# substantially more complex.
#
# Memory note: on 64-bit Inferno `array of int` costs 8 bytes per
# element, so a 900K-element int array is 7.2 MB. The hot paths
# below avoid that by keeping per-symbol data in `array of byte`
# where possible (MTF indices fit in 0..255) and by reusing buffers
# across blocks rather than reallocating.

implement Filter;

include "sys.m";
	sys: Sys;

include "filter.m";

RLE1_THRESHOLD:	con 4;

RUNA:	con 0;
RUNB:	con 1;

GROUP_SIZE:	con 50;
BLOCKMULT:	con 100000;

# ---------------- Module entry ----------------

init()
{
	sys = load Sys Sys->PATH;
}

# param: "1".."9" picks the block size (default "9").
start(param: string): chan of ref Rq
{
	level := 9;
	for(i := 0; i < len param; i++){
		c := param[i];
		if(c >= '1' && c <= '9')
			level = c - '0';
	}
	rq := chan of ref Rq;
	spawn compressor(level, rq);
	return rq;
}

# ---------------- Top-level compressor ----------------

compressor(level: int, rq: chan of ref Rq)
{
	bw := bw_new(rq);

	bw_byte(bw, byte 'B');
	bw_byte(bw, byte 'Z');
	bw_byte(bw, byte 'h');
	bw_byte(bw, byte ('0' + level));

	# Stream-level CRC: running combiner of per-block CRCs.
	streamCrc := 0;

	blockMax := level * BLOCKMULT;
	src := array[blockMax] of byte;
	srcLen := 0;
	for(;;){
		need := blockMax - srcLen;
		if(need > 0){
			n := request_fill(rq, src[srcLen:blockMax]);
			if(n < 0){
				error(rq, "read error");
				return;
			}
			if(n == 0){
				if(srcLen > 0){
					crc := compress_block(bw, src[0:srcLen]);
					streamCrc = (streamCrc << 1) | ((streamCrc >> 31) & 1);
					streamCrc ^= crc;
				}
				emit_eos(bw, streamCrc);
				bw_flush(bw);
				finished(rq);
				return;
			}
			srcLen += n;
			continue;
		}
		# Full block ready.
		crc := compress_block(bw, src[0:srcLen]);
		streamCrc = (streamCrc << 1) | ((streamCrc >> 31) & 1);
		streamCrc ^= crc;
		srcLen = 0;
	}
}

emit_eos(bw: ref Bitwriter, streamCrc: int)
{
	bw_bits(bw, 16r177245, 24);
	bw_bits(bw, 16r385090, 24);
	bw_bits(bw, streamCrc, 32);
	bw_align(bw);
}

# ---------------- One block ----------------

# Returns the block's 32-bit CRC.
compress_block(bw: ref Bitwriter, src: array of byte): int
{
	# CRC over the *raw* input bytes.
	crc := bzip2_crc(src);

	rle := rle1_encode(src);
	(L, origPtr) := bwt_encode(rle);
	rle = nil;	# free RLE-1 buffer before MTF allocates
	(syms, alphaBitmap, alphaCount) := mtf_rle2(L);
	L = nil;	# L is no longer needed
	nSyms := alphaCount + 2;

	# Build a Huffman table over the inner alphabet.
	lens := huff_lengths(syms, nSyms);
	codes := huff_canonical_codes(lens, nSyms);

	# Block magic + CRC + randomised flag (0) + 24-bit origPtr.
	bw_bits(bw, 16r314159, 24);
	bw_bits(bw, 16r265359, 24);
	bw_bits(bw, crc, 32);
	bw_bit(bw, 0);
	bw_bits(bw, origPtr, 24);

	bw_bits(bw, alphaBitmap.groupMask, 16);
	for(g := 0; g < 16; g++){
		if((alphaBitmap.groupMask >> (15 - g)) & 1)
			bw_bits(bw, alphaBitmap.groupBits[g], 16);
	}

	nGroups := 2;
	nSelectors := (len syms + GROUP_SIZE - 1) / GROUP_SIZE;
	if(nSelectors < 1) nSelectors = 1;
	bw_bits(bw, nGroups, 3);
	bw_bits(bw, nSelectors, 15);

	# All selectors zero. Group 0 is at front of the MTF list, so it
	# encodes as a single '0' bit.
	for(i := 0; i < nSelectors; i++)
		bw_bit(bw, 0);

	# nGroups identical code-length tables.
	for(g = 0; g < nGroups; g++)
		emit_code_table(bw, lens, nSyms);

	# Symbol stream.
	for(i = 0; i < len syms; i++){
		s := syms[i];
		bw_bits(bw, codes[s], lens[s]);
	}

	return crc;
}

AlphaBitmap: adt {
	groupMask:	int;
	groupBits:	array of int;
};

# ---------------- CRC-32 (bzip2 variant) ----------------
# Polynomial 0x04C11DB7, MSB-first, no input/output bit reflection.
# Initial register 0xFFFFFFFF, final XOR 0xFFFFFFFF.

bzcrcTab: array of int;

bzcrc_init()
{
	if(bzcrcTab != nil) return;
	bzcrcTab = array[256] of int;
	poly := 16r04C11DB7;
	highBit := 1 << 31;
	for(i := 0; i < 256; i++){
		c := i << 24;
		for(j := 0; j < 8; j++){
			if(c & highBit)
				c = (c << 1) ^ poly;
			else
				c = c << 1;
		}
		bzcrcTab[i] = c;
	}
}

bzip2_crc(buf: array of byte): int
{
	bzcrc_init();
	crc := ~0;
	for(i := 0; i < len buf; i++){
		b := int buf[i];
		crc = (crc << 8) ^ bzcrcTab[((crc >> 24) ^ b) & 16rFF];
	}
	return crc ^ ~0;
}

# ---------------- RLE-1 ----------------
rle1_encode(src: array of byte): array of byte
{
	if(len src == 0) return array[0] of byte;
	# Upper bound: worst case is a +25% expansion (5 bytes for 4 runs).
	# Pre-size to len src + a small margin and let growbytes handle the
	# rare overflow.
	out := array[len src + (len src >> 2) + 16] of byte;
	op := 0;
	i := 0;
	while(i < len src){
		b := src[i];
		run := 1;
		while(i + run < len src && src[i+run] == b && run < 255 + RLE1_THRESHOLD)
			run++;
		if(run < RLE1_THRESHOLD){
			for(k := 0; k < run; k++){
				if(op >= len out) out = growbytes(out, op + 16);
				out[op++] = b;
			}
		} else {
			for(k := 0; k < RLE1_THRESHOLD; k++){
				if(op >= len out) out = growbytes(out, op + 16);
				out[op++] = b;
			}
			if(op >= len out) out = growbytes(out, op + 16);
			out[op++] = byte (run - RLE1_THRESHOLD);
		}
		i += run;
	}
	if(op == len out) return out;
	trimmed := array[op] of byte;
	trimmed[0:] = out[0:op];
	return trimmed;
}

# ---------------- Burrows-Wheeler transform ----------------
bwt_encode(src: array of byte): (array of byte, int)
{
	n := len src;
	if(n == 0) return (array[0] of byte, 0);
	if(n == 1) return (src[0:1], 0);

	src2 := array[2*n] of byte;
	src2[0:] = src;
	src2[n:] = src;
	sa := array[n] of int;
	for(i := 0; i < n; i++) sa[i] = i;

	bwt_sort(sa, src2, n);

	L := array[n] of byte;
	primary := 0;
	for(i = 0; i < n; i++){
		off := sa[i];
		j := off + n - 1;
		if(j >= n) j -= n;
		L[i] = src[j];
		if(off == 0) primary = i;
	}
	return (L, primary);
}

bwt_sort(sa: array of int, src2: array of byte, n: int)
{
	BUCKETS: con 256 * 256;
	bcount := array[BUCKETS + 1] of int;
	for(i := 0; i <= BUCKETS; i++) bcount[i] = 0;
	for(i = 0; i < n; i++){
		k := (int src2[sa[i]] << 8) | int src2[sa[i] + 1];
		bcount[k]++;
	}
	off := array[BUCKETS + 1] of int;
	for(i = 0; i <= BUCKETS; i++) off[i] = 0;
	sum := 0;
	for(i = 0; i < BUCKETS; i++){
		off[i] = sum;
		sum += bcount[i];
	}
	off[BUCKETS] = sum;
	tmp := array[n] of int;
	for(i = 0; i < n; i++) tmp[i] = 0;
	pos := array[BUCKETS] of int;
	for(i = 0; i < BUCKETS; i++) pos[i] = off[i];
	for(i = 0; i < n; i++){
		k := (int src2[sa[i]] << 8) | int src2[sa[i] + 1];
		tmp[pos[k]++] = sa[i];
	}
	for(i = 0; i < n; i++) sa[i] = tmp[i];
	tmp = nil;
	pos = nil;
	bcount = nil;
	for(i = 0; i < BUCKETS; i++){
		lo := off[i];
		hi := off[i+1] - 1;
		if(hi - lo >= 1)
			mksort(sa, lo, hi, 2, src2, n);
	}
}

mksort(sa: array of int, lo, hi, depth: int, src2: array of byte, n: int)
{
	while(hi - lo > 8 && depth < n){
		mid := (lo + hi) / 2;
		pv := int src2[sa[mid] + depth];
		lt := lo;
		gt := hi;
		i := lo;
		while(i <= gt){
			c := int src2[sa[i] + depth];
			if(c < pv){
				t := sa[lt]; sa[lt] = sa[i]; sa[i] = t;
				lt++; i++;
			} else if(c > pv){
				t := sa[gt]; sa[gt] = sa[i]; sa[i] = t;
				gt--;
			} else
				i++;
		}
		if(lt - lo > 1) mksort(sa, lo, lt-1, depth, src2, n);
		if(hi - gt > 1) mksort(sa, gt+1, hi, depth, src2, n);
		lo = lt;
		hi = gt;
		depth++;
	}
	for(i := lo + 1; i <= hi; i++){
		x := sa[i];
		j := i - 1;
		while(j >= lo && cmp_rot_from(sa[j], x, depth, src2, n) > 0){
			sa[j+1] = sa[j];
			j--;
		}
		sa[j+1] = x;
	}
}

cmp_rot_from(a, b, from: int, src2: array of byte, n: int): int
{
	if(a == b) return 0;
	for(k := from; k < n; k++){
		ca := int src2[a + k];
		cb := int src2[b + k];
		if(ca != cb) return ca - cb;
	}
	return 0;
}

# ---------------- MTF + RLE-2 combined pass ----------------
# Returns the inner symbol stream (RUNA, RUNB, shifted MTF indices,
# trailing EOB), the alphabet bitmap, and the alphabet size.
#
# Symbol encoding (per bzip2 spec):
#   0           = RUNA
#   1           = RUNB
#   2..alphaCount = shifted MTF index (originals 1..alphaCount-1)
#   alphaCount+1 = EOB
#
# Max value = alphaCount + 1, up to 257 when alphabet is full. We
# therefore store symbols as `array of int`. On 64-bit Inferno that
# costs 8 bytes per element, but the buffer is bounded by len L
# (block size, <= 900 KB), so peak ~7.2 MB matches the analogous
# `next[]` array in the inverse BWT in the decoder; both stay within
# the 32 MB heap.

mtf_rle2(L: array of byte): (array of int, ref AlphaBitmap, int)
{
	used := array[256] of int;
	for(i := 0; i < 256; i++) used[i] = 0;
	for(i = 0; i < len L; i++) used[int L[i]] = 1;
	alphaCount := 0;
	for(i = 0; i < 256; i++) if(used[i]) alphaCount++;

	alpha := array[alphaCount] of byte;
	mtfPos := array[256] of int;
	for(i = 0; i < 256; i++) mtfPos[i] = -1;
	j := 0;
	for(i = 0; i < 256; i++){
		if(used[i]){
			alpha[j] = byte i;
			mtfPos[i] = j;
			j++;
		}
	}
	stack := array[alphaCount] of byte;
	stack[0:] = alpha;

	bm := ref AlphaBitmap;
	bm.groupMask = 0;
	bm.groupBits = array[16] of int;
	for(i = 0; i < 16; i++) bm.groupBits[i] = 0;
	for(i = 0; i < 256; i++){
		if(used[i]){
			gIdx := i / 16;
			bm.groupBits[gIdx] |= 1 << (15 - (i & 15));
		}
	}
	for(g := 0; g < 16; g++){
		if(bm.groupBits[g] != 0)
			bm.groupMask |= 1 << (15 - g);
	}

	# Output buffer. Length is bounded by len L (MTF/RLE-2 never
	# expands), so we pre-size and don't grow.
	cap := len L + 16;
	out := array[cap] of int;
	op := 0;
	zeros := 0;
	for(i = 0; i < len L; i++){
		v := int L[i];
		idx := mtfPos[v];
		if(idx == 0){
			zeros++;
			continue;
		}
		if(zeros > 0){
			op = emit_zerorun(out, op, zeros);
			zeros = 0;
		}
		if(op >= len out) out = growints(out, op + 32);
		out[op++] = idx + 1;
		for(k := idx; k > 0; k--){
			stack[k] = stack[k-1];
			mtfPos[int stack[k]] = k;
		}
		stack[0] = byte v;
		mtfPos[v] = 0;
	}
	if(zeros > 0)
		op = emit_zerorun(out, op, zeros);

	# Append EOB.
	if(op >= len out) out = growints(out, op + 8);
	out[op++] = alphaCount + 1;

	if(op == len out)
		return (out, bm, alphaCount);
	trimmed := array[op] of int;
	trimmed[0:] = out[0:op];
	return (trimmed, bm, alphaCount);
}

emit_zerorun(out: array of int, op: int, n: int): int
{
	while(n > 0){
		n--;
		if((n & 1) == 0){
			if(op >= len out) out = growints(out, op + 16);
			out[op++] = RUNA;
		} else {
			if(op >= len out) out = growints(out, op + 16);
			out[op++] = RUNB;
		}
		n >>= 1;
	}
	return op;
}

huff_lengths(syms: array of int, nSyms: int): array of int
{
	freq := array[nSyms] of int;
	for(i := 0; i < nSyms; i++) freq[i] = 0;
	for(i = 0; i < len syms; i++) freq[syms[i]]++;

	wfreq := array[nSyms] of int;
	for(i = 0; i < nSyms; i++)
		if(freq[i] > 0) wfreq[i] = freq[i];
		else wfreq[i] = 1;

	lens := huff_build(wfreq, nSyms);

	maxd := 0;
	for(i = 0; i < nSyms; i++) if(lens[i] > maxd) maxd = lens[i];
	if(maxd > 20){
		bits := 1;
		while((1 << bits) < nSyms) bits++;
		if(bits > 20) bits = 20;
		if(bits < 1) bits = 1;
		for(i = 0; i < nSyms; i++) lens[i] = bits;
	}
	for(i = 0; i < nSyms; i++)
		if(lens[i] < 1) lens[i] = 1;
	return lens;
}

huff_build(freq: array of int, nSyms: int): array of int
{
	lens := array[nSyms] of int;
	for(i := 0; i < nSyms; i++) lens[i] = 0;
	parent := array[2 * nSyms] of int;
	for(i = 0; i < 2 * nSyms; i++) parent[i] = -1;
	pq: list of (int, int);
	for(i = 0; i < nSyms; i++)
		pq = pq_insert(pq, freq[i], i);
	next := nSyms;
	while(pq_len(pq) > 1){
		(w1, n1, pq2) := pq_pop(pq);
		(w2, n2, pq3) := pq_pop(pq2);
		parent[n1] = next;
		parent[n2] = next;
		pq = pq_insert(pq3, w1 + w2, next);
		next++;
	}
	for(i = 0; i < nSyms; i++){
		d := 0;
		p := parent[i];
		while(p != -1){
			d++;
			p = parent[p];
		}
		if(d == 0) d = 1;
		lens[i] = d;
	}
	return lens;
}

pq_insert(pq: list of (int, int), w, n: int): list of (int, int)
{
	if(pq == nil) return (w, n) :: nil;
	(hw, hn) := hd pq;
	if(w < hw || (w == hw && n < hn))
		return (w, n) :: pq;
	return (hw, hn) :: pq_insert(tl pq, w, n);
}

pq_pop(pq: list of (int, int)): (int, int, list of (int, int))
{
	(w, n) := hd pq;
	return (w, n, tl pq);
}

pq_len(pq: list of (int, int)): int
{
	n := 0;
	for(l := pq; l != nil; l = tl l) n++;
	return n;
}

huff_canonical_codes(lens: array of int, nSyms: int): array of int
{
	codes := array[nSyms] of int;
	for(i := 0; i < nSyms; i++) codes[i] = 0;
	maxLen := 0;
	for(i = 0; i < nSyms; i++) if(lens[i] > maxLen) maxLen = lens[i];
	if(maxLen == 0) return codes;
	lenCount := array[maxLen + 1] of int;
	for(i = 0; i <= maxLen; i++) lenCount[i] = 0;
	for(i = 0; i < nSyms; i++)
		if(lens[i] > 0) lenCount[lens[i]]++;
	nextCode := array[maxLen + 2] of int;
	for(i = 0; i <= maxLen + 1; i++) nextCode[i] = 0;
	code := 0;
	for(b := 1; b <= maxLen; b++){
		code = (code + lenCount[b - 1]) << 1;
		nextCode[b] = code;
	}
	for(i = 0; i < nSyms; i++){
		l := lens[i];
		if(l > 0){
			codes[i] = nextCode[l];
			nextCode[l]++;
		}
	}
	return codes;
}

emit_code_table(bw: ref Bitwriter, lens: array of int, nSyms: int)
{
	cur := lens[0];
	if(cur < 1) cur = 1;
	if(cur > 20) cur = 20;
	bw_bits(bw, cur, 5);
	for(s := 0; s < nSyms; s++){
		tgt := lens[s];
		while(cur != tgt){
			bw_bit(bw, 1);
			if(cur < tgt){
				bw_bit(bw, 0);
				cur++;
			} else {
				bw_bit(bw, 1);
				cur--;
			}
		}
		bw_bit(bw, 0);
	}
}

# ---------------- Bitwriter ----------------

Bitwriter: adt {
	rq:	chan of ref Rq;
	buf:	array of byte;
	pos:	int;
	bit:	int;
	cur:	int;
};

bw_new(rq: chan of ref Rq): ref Bitwriter
{
	b := ref Bitwriter;
	b.rq = rq;
	b.buf = array[4096] of byte;
	b.pos = 0;
	b.bit = 8;
	b.cur = 0;
	return b;
}

bw_bit(b: ref Bitwriter, v: int)
{
	b.bit--;
	if(v & 1)
		b.cur |= 1 << b.bit;
	if(b.bit == 0){
		if(b.pos >= len b.buf)
			bw_flush(b);
		b.buf[b.pos++] = byte b.cur;
		b.cur = 0;
		b.bit = 8;
	}
}

bw_bits(b: ref Bitwriter, v: int, nbits: int)
{
	for(i := nbits - 1; i >= 0; i--)
		bw_bit(b, (v >> i) & 1);
}

bw_byte(b: ref Bitwriter, by: byte)
{
	bw_bits(b, int by & 16rFF, 8);
}

bw_align(b: ref Bitwriter)
{
	if(b.bit != 8){
		if(b.pos >= len b.buf)
			bw_flush(b);
		b.buf[b.pos++] = byte b.cur;
		b.cur = 0;
		b.bit = 8;
	}
}

bw_flush(b: ref Bitwriter)
{
	if(b.pos == 0) return;
	chunk := array[b.pos] of byte;
	chunk[0:] = b.buf[0:b.pos];
	reply := chan of int;
	b.rq <-= ref Rq.Result(chunk, reply);
	<-reply;
	b.pos = 0;
}

# ---------------- Filter protocol helpers ----------------

request_fill(rq: chan of ref Rq, buf: array of byte): int
{
	reply := chan of int;
	rq <-= ref Rq.Fill(buf, reply);
	return <-reply;
}

error(rq: chan of ref Rq, msg: string)
{
	rq <-= ref Rq.Error(msg);
}

finished(rq: chan of ref Rq)
{
	rq <-= ref Rq.Finished(nil);
}

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
