implement IcSearch;

include "ic/search.m";
include "regex.m";

RegexSpec: adt
{
	pattern: string;
	casefold: int;
	ok: int;
	err: string;
};

sys: Sys;
regex: Regex;

cachedpattern: string;
cachedcasefold: int;
cachedre: Regex->Re;
cachederr: string;

appendmatch: fn(a: array of IcViewCommon->SearchMatch, m: IcViewCommon->SearchMatch): array of IcViewCommon->SearchMatch;
lowerchar: fn(c: int): int;
findforward: fn(text, pattern: string, startcol: int): int;
findbackward: fn(text, pattern: string, startcol: int): int;

parseregex: fn(pattern: string, casefold: int): RegexSpec;
lastunescapedslash: fn(s: string): int;
compilere: fn(pattern: string, casefold: int): (Regex->Re, string);
findregexforward: fn(text, pattern: string, casefold, startcol: int): (int, int, string);
findregexbackward: fn(text, pattern: string, casefold, startcol: int): (int, int, string);
findregex: fn(text, pattern: string, casefold, startcol, backward: int): (int, int, string);

init()
{
	sys = load Sys Sys->PATH;
	if(sys == nil)
		raise "fail:load sys";

	regex = load Regex Regex->PATH;
	if(regex == nil)
		raise "fail:load regex";

	cachedpattern = "";
	cachedcasefold = -1;
	cachedre = nil;
	cachederr = "";
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

lastunescapedslash(s: string): int
{
	i, slash, bs: int;

	slash = -1;
	for(i = 1; i < len s; i++){
		if(s[i] != '/')
			continue;

		bs = 0;
		while(i - bs - 1 >= 0 && s[i - bs - 1] == '\\')
			bs++;

		if((bs % 2) == 0)
			slash = i;
	}

	return slash;
}

parseregex(pattern: string, casefold: int): RegexSpec
{
	r: RegexSpec;
	i, slash: int;
	flags: string;

	r.pattern = pattern;
	r.casefold = casefold;
	r.ok = 1;
	r.err = "";

	if(pattern == ""){
		r.ok = 0;
		r.err = "Empty search pattern";
		return r;
	}

	if(pattern[0] != '/')
		return r;

	slash = lastunescapedslash(pattern);
	if(slash <= 0){
		r.ok = 0;
		r.err = "Bad regex delimiter";
		return r;
	}

	r.pattern = pattern[1:slash];
	flags = pattern[slash + 1:];

	for(i = 0; i < len flags; i++){
		case flags[i] {
		'i' =>
			r.casefold = 1;

		* =>
			r.ok = 0;
			r.err = "Unsupported regex flag: " + sys->sprint("%c", flags[i]);
			return r;
		}
	}

	if(r.pattern == ""){
		r.ok = 0;
		r.err = "Empty regex pattern";
		return r;
	}

	return r;
}

compilere(pattern: string, casefold: int): (Regex->Re, string)
{
	re: Regex->Re;
	err: string;

	if(cachedre != nil && cachedpattern == pattern && cachedcasefold == casefold)
		return (cachedre, cachederr);

	if(casefold)
		pattern = lowerstr(pattern);

	(re, err) = regex->compile(pattern, 0);

	cachedpattern = pattern;
	cachedcasefold = casefold;
	cachedre = re;
	cachederr = err;

	if(re == nil){
		if(err == "")
			err = "Bad regex";
		return (nil, err);
	}

	return (re, "");
}

findregexforward(text, pattern: string, casefold, startcol: int): (int, int, string)
{
	re: Regex->Re;
	matches: array of (int, int);
	err, t: string;
	beg, end: int;

	if(startcol < 0)
		startcol = 0;

	if(startcol > len text)
		return (-1, 0, "");

	t = text;
	if(casefold)
		t = lowerstr(text);

	(re, err) = compilere(pattern, casefold);
	if(re == nil)
		return (-1, 0, err);

	matches = regex->executese(re, t, (startcol, len t), startcol == 0, 1);
	if(matches == nil)
		return (-1, 0, "");

	(beg, end) = matches[0];
	if(beg < 0 || end < beg)
		return (-1, 0, "");

	return (beg, end - beg, "");
}

findregexbackward(text, pattern: string, casefold, startcol: int): (int, int, string)
{
	re: Regex->Re;
	matches: array of (int, int);
	err, t: string;
	pos, limit, beg, end, bestbeg, bestend: int;

	t = text;
	if(casefold)
		t = lowerstr(text);

	if(startcol < 0 || startcol > len t)
		limit = len t;
	else
		limit = startcol;

	(re, err) = compilere(pattern, casefold);
	if(re == nil)
		return (-1, 0, err);

	bestbeg = -1;
	bestend = -1;
	pos = 0;

	for(;;){
		if(pos > len t)
			break;

		matches = regex->executese(re, t, (pos, len t), pos == 0, 1);
		if(matches == nil)
			break;

		(beg, end) = matches[0];
		if(beg < 0 || end < beg)
			break;

		if(beg > limit)
			break;

		bestbeg = beg;
		bestend = end;

		if(end <= pos)
			pos++;
		else
			pos = end;
	}

	if(bestbeg < 0)
		return (-1, 0, "");

	return (bestbeg, bestend - bestbeg, "");
}

findregex(text, pattern: string, casefold, startcol, backward: int): (int, int, string)
{
	spec: RegexSpec;

	spec = parseregex(pattern, casefold);
	if(!spec.ok)
		return (-1, 0, spec.err);

	if(backward)
		return findregexbackward(text, spec.pattern, spec.casefold, startcol);

	return findregexforward(text, spec.pattern, spec.casefold, startcol);
}

matchline(text, pattern: string, casefold, regexmode, startcol, backward: int): (int, int, string)
{
	col, n: int;
	err: string;

	if(pattern == "")
		return (-1, 0, "Empty search pattern");

	if(regexmode){
		(col, n, err) = findregex(text, pattern, casefold, startcol, backward);
		return (col, n, err);
	}

	(col, n) = findplain(text, pattern, casefold, startcol, backward);
	return (col, n, "");
}