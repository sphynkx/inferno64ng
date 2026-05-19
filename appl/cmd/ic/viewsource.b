implement IcViewSource;

include "ic/viewsource.m";

sys: Sys;

ScanChunkSize: con 32768;
InitialOffsetCap: con 1024;
MaxRawLineLen: con 4096;
ReplacementChar: con 16rFFFD;

appendoffset: fn(s: ref IcViewCommon->ViewerSource, off: big);
readlinebytes: fn(s: ref IcViewCommon->ViewerSource, line: int): (array of byte, int);
decodechunk: fn(buf: array of byte, n: int): string;
sanitizechunk: fn(text: string): string;
needsanitize: fn(text: string): int;
safecell: fn(c: int): string;
appendline: fn(a: array of string, s: string): array of string;
appendarray: fn(dst, src: array of string): array of string;
wrapline: fn(line: string, width: int): array of string;

init()
{
	sys = load Sys Sys->PATH;
	if(sys == nil)
		raise "fail:load sys";
}

newsource(path: string): ref IcViewCommon->ViewerSource
{
	s: ref IcViewCommon->ViewerSource;
	rc: int;
	d: Sys->Dir;

	s = ref IcViewCommon->ViewerSource;
	s.path = path;
	s.fd = sys->open(path, Sys->OREAD);
	s.length = big 0;
	s.offsetcap = InitialOffsetCap;
	s.offsets = array[s.offsetcap] of big;
	s.noffsets = 1;
	s.offsets[0] = big 0;
	s.scanoff = big 0;
	s.eof = 0;
	s.error = "";

	if(s.fd == nil){
		s.error = "Cannot open file: " + path;
		s.eof = 1;
		return s;
	}

	(rc, d) = sys->fstat(s.fd);
	if(rc >= 0)
		s.length = d.length;

	return s;
}

closefile(s: ref IcViewCommon->ViewerSource)
{
	if(s == nil)
		return;

	s.fd = nil;
}

appendoffset(s: ref IcViewCommon->ViewerSource, off: big)
{
	a: array of big;
	i, ncap: int;

	if(s == nil || off < big 0)
		return;

	if(s.length > big 0 && off >= s.length)
		return;

	if(s.noffsets > 0 && s.offsets[s.noffsets - 1] == off)
		return;

	if(s.noffsets >= s.offsetcap){
		ncap = s.offsetcap * 2;
		if(ncap < InitialOffsetCap)
			ncap = InitialOffsetCap;

		a = array[ncap] of big;
		for(i = 0; i < s.noffsets; i++)
			a[i] = s.offsets[i];

		s.offsets = a;
		s.offsetcap = ncap;
	}

	s.offsets[s.noffsets] = off;
	s.noffsets++;
}

ensureindexed(s: ref IcViewCommon->ViewerSource, line: int): int
{
	buf: array of byte;
	n, i: int;
	off: big;

	if(s == nil)
		return 0;

	if(line < 0)
		line = 0;

	if(s.error != "")
		return 0;

	if(line < s.noffsets)
		return 1;

	if(s.eof)
		return line < s.noffsets;

	buf = array[ScanChunkSize] of byte;

	while(!s.eof && s.noffsets <= line){
		n = sys->pread(s.fd, buf, len buf, s.scanoff);
		if(n < 0){
			s.error = "Cannot read file: " + s.path;
			s.eof = 1;
			break;
		}

		if(n == 0){
			s.eof = 1;
			s.length = s.scanoff;
			break;
		}

		for(i = 0; i < n; i++){
			if(int buf[i] == '\n'){
				off = s.scanoff + big (i + 1);
				appendoffset(s, off);
			}
		}

		s.scanoff += big n;

		if(s.length > big 0 && s.scanoff >= s.length){
			s.eof = 1;
			s.length = s.scanoff;
		}
	}

	return line < s.noffsets;
}

ensureeof(s: ref IcViewCommon->ViewerSource): int
{
	if(s == nil)
		return 0;

	while(!s.eof)
		ensureindexed(s, s.noffsets);

	return s.eof;
}

ensureoffset(s: ref IcViewCommon->ViewerSource, off: big): int
{
	if(s == nil)
		return 0;

	if(off < big 0)
		off = big 0;

	if(s.length > big 0 && off > s.length)
		off = s.length;

	while(!s.eof && s.scanoff < off)
		ensureindexed(s, s.noffsets);

	return 1;
}

linecount(s: ref IcViewCommon->ViewerSource): int
{
	if(s == nil)
		return 0;

	if(s.error != "")
		return 1;

	if(s.noffsets <= 0)
		return 0;

	return s.noffsets;
}

lineforoffset(s: ref IcViewCommon->ViewerSource, off: big): int
{
	lo, hi, mid: int;

	if(s == nil)
		return 0;

	if(off < big 0)
		off = big 0;

	ensureoffset(s, off);

	lo = 0;
	hi = s.noffsets - 1;

	while(lo <= hi){
		mid = (lo + hi) / 2;

		if(s.offsets[mid] == off)
			return mid;

		if(s.offsets[mid] < off)
			lo = mid + 1;
		else
			hi = mid - 1;
	}

	if(hi < 0)
		return 0;

	return hi;
}

readlinebytes(s: ref IcViewCommon->ViewerSource, line: int): (array of byte, int)
{
	start, end, span: big;
	n, want: int;
	buf: array of byte;

	if(s == nil || s.fd == nil || line < 0)
		return (array[0] of byte, 0);

	if(!ensureindexed(s, line))
		return (array[0] of byte, 0);

	start = s.offsets[line];

	#
	# Ensure the next line offset if possible. Do not scan the whole file here:
	# visible rendering must stay bounded and lazy.
	#
	ensureindexed(s, line + 1);

	if(line + 1 < s.noffsets)
		end = s.offsets[line + 1];
	else if(s.eof && s.length > big 0)
		end = s.length;
	else
		end = s.scanoff;

	if(end < start)
		end = start;

	span = end - start;
	if(span > big MaxRawLineLen)
		span = big MaxRawLineLen;

	want = int span;
	if(want < 0)
		want = 0;

	buf = array[want] of byte;
	if(want == 0)
		return (buf, 0);

	n = sys->pread(s.fd, buf, want, start);
	if(n < 0)
		return (array[0] of byte, 0);

	while(n > 0 && (int buf[n - 1] == '\n' || int buf[n - 1] == '\r'))
		n--;

	return (buf, n);
}

getline(s: ref IcViewCommon->ViewerSource, line: int): string
{
	buf: array of byte;
	n: int;

	if(s == nil)
		return "";

	if(s.error != "")
		return s.error;

	(buf, n) = readlinebytes(s, line);
	if(n <= 0)
		return "";

	return sanitizechunk(decodechunk(buf, n));
}

decodechunk(buf: array of byte, n: int): string
{
	i, b0, b1, b2, b3, c: int;
	out: string;

	out = "";
	i = 0;

	while(i < n){
		b0 = int buf[i] & 16rFF;

		if(b0 < 16r80){
			out += sys->sprint("%c", b0);
			i++;
			continue;
		}

		if((b0 & 16rE0) == 16rC0 && i + 1 < n){
			b1 = int buf[i + 1] & 16rFF;
			if((b1 & 16rC0) == 16r80){
				c = ((b0 & 16r1F) << 6) | (b1 & 16r3F);
				if(c >= 16r80){
					out += sys->sprint("%c", c);
					i += 2;
					continue;
				}
			}
		}

		if((b0 & 16rF0) == 16rE0 && i + 2 < n){
			b1 = int buf[i + 1] & 16rFF;
			b2 = int buf[i + 2] & 16rFF;
			if((b1 & 16rC0) == 16r80 && (b2 & 16rC0) == 16r80){
				c = ((b0 & 16r0F) << 12) | ((b1 & 16r3F) << 6) | (b2 & 16r3F);
				if(c >= 16r800 && (c < 16rD800 || c > 16rDFFF)){
					out += sys->sprint("%c", c);
					i += 3;
					continue;
				}
			}
		}

		if((b0 & 16rF8) == 16rF0 && i + 3 < n){
			b1 = int buf[i + 1] & 16rFF;
			b2 = int buf[i + 2] & 16rFF;
			b3 = int buf[i + 3] & 16rFF;
			if((b1 & 16rC0) == 16r80 && (b2 & 16rC0) == 16r80 && (b3 & 16rC0) == 16r80){
				c = ((b0 & 16r07) << 18) | ((b1 & 16r3F) << 12) | ((b2 & 16r3F) << 6) | (b3 & 16r3F);
				if(c >= 16r10000 && c <= 16r10FFFF){
					out += sys->sprint("%c", c);
					i += 4;
					continue;
				}
			}
		}

		out += sys->sprint("%c", ReplacementChar);
		i++;
	}

	return out;
}

safecell(c: int): string
{
	if(c == '\t')
		return " ";

	if(c == '\r')
		return "\r";

	if(c == '\n')
		return "\n";

	if(c < 32 || c == 127)
		return ".";

	if(c >= 16r80 && c < 16rA0)
		return ".";

	if(c == ReplacementChar)
		return ".";

	return sys->sprint("%c", c);
}

needsanitize(text: string): int
{
	i, c: int;

	for(i = 0; i < len text; i++){
		c = text[i];

		if(c == '\t')
			return 1;

		if(c < 32 && c != '\n' && c != '\r')
			return 1;

		if(c == 127)
			return 1;

		if(c >= 16r80 && c < 16rA0)
			return 1;

		if(c == ReplacementChar)
			return 1;
	}

	return 0;
}

sanitizechunk(text: string): string
{
	i: int;
	out: string;

	if(text == "")
		return "";

	if(!needsanitize(text))
		return text;

	out = "";
	for(i = 0; i < len text; i++)
		out += safecell(text[i]);

	return out;
}

appendline(a: array of string, s: string): array of string
{
	b: array of string;
	i, n: int;

	if(a == nil){
		b = array[1] of string;
		b[0] = s;
		return b;
	}

	n = len a;
	b = array[n + 1] of string;
	for(i = 0; i < n; i++)
		b[i] = a[i];
	b[n] = s;

	return b;
}

appendarray(dst, src: array of string): array of string
{
	i: int;

	if(src == nil)
		return dst;

	for(i = 0; i < len src; i++)
		dst = appendline(dst, src[i]);

	return dst;
}

spaces(n: int): string
{
	s: string;
	i: int;

	s = "";
	for(i = 0; i < n; i++)
		s += " ";

	return s;
}

fittext(s: string, w: int): string
{
	if(w <= 0)
		return "";

	if(len s > w)
		return s[0:w];

	if(len s < w)
		return s + spaces(w - len s);

	return s;
}

wrapline(line: string, width: int): array of string
{
	out: array of string;
	current, word: string;
	i, start, cut: int;

	if(width < 1)
		width = 1;

	out = array[0] of string;
	current = "";

	for(i = 0; i < len line; i++){
		if(line[i] == ' ' || line[i] == '\t' || line[i] == '\r')
			continue;

		start = i;
		while(i < len line && line[i] != ' ' && line[i] != '\t' && line[i] != '\r')
			i++;

		word = line[start:i];
		i--;

		if(len word > width){
			if(current != ""){
				out = appendline(out, current);
				current = "";
			}

			start = 0;
			while(start < len word){
				cut = start + width;
				if(cut > len word)
					cut = len word;
				out = appendline(out, word[start:cut]);
				start = cut;
			}

			continue;
		}

		if(current == "")
			current = word;
		else if(len current + 1 + len word <= width)
			current += " " + word;
		else{
			out = appendline(out, current);
			current = word;
		}
	}

	if(current != "")
		out = appendline(out, current);

	if(out == nil || len out == 0)
		out = appendline(out, "");

	return out;
}

wraplines(lines: array of string, width: int): array of string
{
	out: array of string;
	i: int;

	out = array[0] of string;

	if(lines == nil)
		return appendline(out, "");

	for(i = 0; i < len lines; i++)
		out = appendarray(out, wrapline(lines[i], width));

	if(out == nil || len out == 0)
		out = appendline(out, "");

	return out;
}

visiblecontent(lines: array of string, top, rows: int): string
{
	i, idx: int;
	s: string;

	if(lines == nil || rows <= 0)
		return "";

	s = "";

	for(i = 0; i < rows; i++){
		idx = top + i;
		if(idx >= 0 && idx < len lines)
			s += lines[idx];

		if(i < rows - 1)
			s += "\n";
	}

	return s;
}