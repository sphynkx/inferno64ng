implement IcSearch;

include "ic/search.m";

sys: Sys;

appendmatch: fn(a: array of IcViewCommon->SearchMatch, m: IcViewCommon->SearchMatch): array of IcViewCommon->SearchMatch;
lowerchar: fn(c: int): int;
findforward: fn(text, pattern: string, startcol: int): int;
findbackward: fn(text, pattern: string, startcol: int): int;

init()
{
	sys = load Sys Sys->PATH;
	if(sys == nil)
		raise "fail:load sys";
}

defaultopts(): IcViewCommon->SearchOptions
{
	o: IcViewCommon->SearchOptions;

	o.pattern = "";
	o.backward = 0;
	o.casefold = 0;
	o.wrap = 1;
	o.regex = 0;
	o.encoding = "utf-8";
	o.anyencoding = 0;

	return o;
}

newsession(path: string, opts: IcViewCommon->SearchOptions): ref IcViewCommon->SearchSession
{
	s: ref IcViewCommon->SearchSession;

	s = ref IcViewCommon->SearchSession;
	reset(s, path, opts);

	return s;
}

reset(s: ref IcViewCommon->SearchSession, path: string, opts: IcViewCommon->SearchOptions)
{
	if(s == nil)
		return;

	s.active = 1;
	s.path = path;
	s.opts = opts;
	s.matches = array[0] of IcViewCommon->SearchMatch;
	s.current = -1;
	s.lastline = 0;
	s.lastcol = 0;
	s.lastdirection = IcViewCommon->SearchDirForward;
}

appendmatch(a: array of IcViewCommon->SearchMatch, m: IcViewCommon->SearchMatch): array of IcViewCommon->SearchMatch
{
	b: array of IcViewCommon->SearchMatch;
	i, n: int;

	if(a == nil){
		b = array[1] of IcViewCommon->SearchMatch;
		b[0] = m;
		return b;
	}

	n = len a;
	b = array[n + 1] of IcViewCommon->SearchMatch;

	for(i = 0; i < n; i++)
		b[i] = a[i];

	b[n] = m;
	return b;
}

addmatch(s: ref IcViewCommon->SearchSession, m: IcViewCommon->SearchMatch): int
{
	if(s == nil)
		return -1;

	s.matches = appendmatch(s.matches, m);
	s.current = len s.matches - 1;
	s.lastline = m.line;
	s.lastcol = m.col;

	if(s.opts.backward)
		s.lastdirection = IcViewCommon->SearchDirBackward;
	else
		s.lastdirection = IcViewCommon->SearchDirForward;

	return s.current;
}

lowerchar(c: int): int
{
	if(c >= 'A' && c <= 'Z')
		return c + ('a' - 'A');

	if(c >= 16r410 && c <= 16r42F)
		return c + 32;

	if(c == 16r401)
		return 16r451;

	return c;
}

lowerstr(s: string): string
{
	i: int;
	out: string;

	out = "";
	for(i = 0; i < len s; i++)
		out += sys->sprint("%c", lowerchar(s[i]));

	return out;
}

findforward(text, pattern: string, startcol: int): int
{
	i, j, ok: int;

	if(pattern == "")
		return -1;

	if(startcol < 0)
		startcol = 0;

	if(startcol >= len text)
		return -1;

	for(i = startcol; i + len pattern <= len text; i++){
		ok = 1;

		for(j = 0; j < len pattern; j++){
			if(text[i + j] != pattern[j]){
				ok = 0;
				break;
			}
		}

		if(ok)
			return i;
	}

	return -1;
}

findbackward(text, pattern: string, startcol: int): int
{
	i, j, ok: int;

	if(pattern == "")
		return -1;

	if(len pattern > len text)
		return -1;

	if(startcol < 0 || startcol > len text - len pattern)
		startcol = len text - len pattern;

	for(i = startcol; i >= 0; i--){
		ok = 1;

		for(j = 0; j < len pattern; j++){
			if(text[i + j] != pattern[j]){
				ok = 0;
				break;
			}
		}

		if(ok)
			return i;
	}

	return -1;
}

findplain(text, pattern: string, casefold, startcol, backward: int): (int, int)
{
	t, p: string;
	col: int;

	if(pattern == "")
		return (-1, 0);

	t = text;
	p = pattern;

	if(casefold){
		t = lowerstr(text);
		p = lowerstr(pattern);
	}

	if(backward)
		col = findbackward(t, p, startcol);
	else
		col = findforward(t, p, startcol);

	if(col < 0)
		return (-1, 0);

	return (col, len pattern);
}

matchline(text, pattern: string, casefold, regex, startcol, backward: int): (int, int, string)
{
	col, n: int;

	if(pattern == "")
		return (-1, 0, "Empty search pattern");

	if(regex)
		return (-1, 0, "Regex search is not implemented yet");

	(col, n) = findplain(text, pattern, casefold, startcol, backward);
	return (col, n, "");
}