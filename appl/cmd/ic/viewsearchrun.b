implement IcViewSearchRun;

include "ic/viewsearchrun.m";

IcSearchMod: module
{
	PATH: con "/dis/ic/search.dis";

	init: fn();

	newsession: fn(path: string, opts: IcViewCommon->SearchOptions): ref IcViewCommon->SearchSession;
	reset: fn(s: ref IcViewCommon->SearchSession, path: string, opts: IcViewCommon->SearchOptions);

	addmatch: fn(s: ref IcViewCommon->SearchSession, m: IcViewCommon->SearchMatch): int;
	matchline: fn(text, pattern: string, casefold, regex, startcol, backward: int): (int, int, string);
};

IcViewSourceMod: module
{
	PATH: con "/dis/ic/viewsource.dis";

	init: fn();

	ensureindexed: fn(s: ref IcViewCommon->ViewerSource, line: int): int;
	ensureeof: fn(s: ref IcViewCommon->ViewerSource): int;
	linecount: fn(s: ref IcViewCommon->ViewerSource): int;
	getline: fn(s: ref IcViewCommon->ViewerSource, line: int): string;
};

searchmod: IcSearchMod;
srcmod: IcViewSourceMod;

searchsession: ref IcViewCommon->SearchSession;
lastsearchpattern: string;
matchcode: string;

searchline: fn(source: ref IcViewCommon->ViewerSource, line, startcol, backward: int,
	opts: IcViewCommon->SearchOptions): (int, int, string);
resetsearchifneeded: fn(v: ref IcState->ViewerState, opts: IcViewCommon->SearchOptions);
searchstartline: fn(v: ref IcState->ViewerState, direction, fromcurrent: int): (int, int);
result: fn(found, alert: int, text: string): SearchResult;

init()
{
	searchmod = load IcSearchMod IcSearchMod->PATH;
	if(searchmod == nil)
		raise "fail:load ic/search";

	srcmod = load IcViewSourceMod IcViewSourceMod->PATH;
	if(srcmod == nil)
		raise "fail:load ic/viewsource";

	searchmod->init();
	srcmod->init();

	searchsession = nil;
	lastsearchpattern = "";
	matchcode = "1;38;2;0;0;0;48;2;170;225;255";
}

reset()
{
	searchsession = nil;
	lastsearchpattern = "";
}

lastpattern(): string
{
	return lastsearchpattern;
}

result(found, alert: int, text: string): SearchResult
{
	r: SearchResult;

	r.found = found;
	r.alert = alert;
	r.alerttext = text;

	return r;
}

searchline(source: ref IcViewCommon->ViewerSource, line, startcol, backward: int,
	opts: IcViewCommon->SearchOptions): (int, int, string)
{
	text, err: string;
	col, n: int;

	if(source == nil)
		return (-1, 0, "No file");

	if(!srcmod->ensureindexed(source, line))
		return (-1, 0, "");

	text = srcmod->getline(source, line);
	(col, n, err) = searchmod->matchline(text, opts.pattern, opts.casefold, opts.regex, startcol, backward);

	return (col, n, err);
}

resetsearchifneeded(v: ref IcState->ViewerState, opts: IcViewCommon->SearchOptions)
{
	if(v == nil)
		return;

	if(searchsession == nil){
		searchsession = searchmod->newsession(v.path, opts);
		return;
	}

	if(searchsession.path != v.path || searchsession.opts.pattern != opts.pattern)
		searchmod->reset(searchsession, v.path, opts);
	else
		searchsession.opts = opts;
}

searchstartline(v: ref IcState->ViewerState, direction, fromcurrent: int): (int, int)
{
	line, startcol: int;

	line = v.topline;
	startcol = 0;

	if(fromcurrent && searchsession != nil && searchsession.current >= 0){
		line = searchsession.lastline;

		if(direction == IcViewCommon->SearchDirBackward)
			startcol = searchsession.lastcol - 1;
		else
			startcol = searchsession.lastcol + 1;
	}else if(direction == IcViewCommon->SearchDirBackward)
		startcol = -1;

	return (line, startcol);
}

run(source: ref IcViewCommon->ViewerSource, v: ref IcState->ViewerState,
	opts: IcViewCommon->SearchOptions, direction: int, fromcurrent: int): SearchResult
{
	m: IcViewCommon->SearchMatch;
	line, col, n, startcol, wrapped, firstline: int;
	err: string;

	if(v == nil || source == nil)
		return result(0, 0, "");

	if(direction == IcViewCommon->SearchDirBackward)
		opts.backward = 1;
	else
		opts.backward = 0;

	if(opts.pattern == "")
		return result(0, 1, "Nothing to search");

	resetsearchifneeded(v, opts);
	lastsearchpattern = opts.pattern;

	if(opts.anyencoding)
		return result(0, 1, "Any encoding search is not implemented yet");

	(line, startcol) = searchstartline(v, direction, fromcurrent);
	firstline = line;
	wrapped = 0;

	if(direction == IcViewCommon->SearchDirBackward){
		for(;;){
			if(line < 0){
				if(!opts.wrap || wrapped)
					return result(0, 1, "Search finished");

				srcmod->ensureeof(source);
				line = srcmod->linecount(source) - 1;
				startcol = -1;
				wrapped = 1;
			}

			(col, n, err) = searchline(source, line, startcol, 1, opts);
			if(err != "")
				return result(0, 1, err);

			if(col >= 0){
				m.offset = source.offsets[line] + big col;
				m.line = line;
				m.col = col;
				m.length = n;
				m.text = srcmod->getline(source, line);

				searchmod->addmatch(searchsession, m);
				v.topline = line;

				return result(1, 0, "");
			}

			line--;
			startcol = -1;

			if(wrapped && line < firstline)
				return result(0, 1, "Nothing found");
		}
	}

	for(;;){
		if(source.eof && line >= srcmod->linecount(source)){
			if(!opts.wrap || wrapped)
				return result(0, 1, "Search finished");

			line = 0;
			startcol = 0;
			wrapped = 1;
		}

		if(!srcmod->ensureindexed(source, line)){
			if(!opts.wrap || wrapped)
				return result(0, 1, "Search finished");

			line = 0;
			startcol = 0;
			wrapped = 1;
		}

		(col, n, err) = searchline(source, line, startcol, 0, opts);
		if(err != "")
			return result(0, 1, err);

		if(col >= 0){
			m.offset = source.offsets[line] + big col;
			m.line = line;
			m.col = col;
			m.length = n;
			m.text = srcmod->getline(source, line);

			searchmod->addmatch(searchsession, m);
			v.topline = line;

			return result(1, 0, "");
		}

		line++;
		startcol = 0;

		if(wrapped && line > firstline)
			return result(0, 1, "Nothing found");
	}
}

searchsarg(source: ref IcViewCommon->ViewerSource, v: ref IcState->ViewerState, h: int): string
{
	m: IcViewCommon->SearchMatch;
	row, line, start, end: int;
	lineoff, nextoff: big;

	if(v == nil || source == nil)
		return "";

	if(searchsession == nil)
		return "";

	if(searchsession.current < 0)
		return "";

	if(searchsession.matches == nil)
		return "";

	if(searchsession.current >= len searchsession.matches)
		return "";

	m = searchsession.matches[searchsession.current];

	if(m.length <= 0)
		return "";

	for(row = 0; row < h; row++){
		line = v.topline + row;

		if(line < 0)
			continue;

		if(line >= source.noffsets)
			continue;

		lineoff = source.offsets[line];

		if(line + 1 < source.noffsets)
			nextoff = source.offsets[line + 1];
		else if(source.eof)
			nextoff = source.length;
		else
			nextoff = source.scanoff;

		if(nextoff < lineoff)
			nextoff = lineoff;

		if(m.offset < lineoff || m.offset >= nextoff)
			continue;

		start = m.col;
		end = start + m.length;

		if(start < 0)
			start = 0;

		if(end < start)
			end = start;

		return "search_line=" + string row + "\n"
			+ "search_start=" + string start + "\n"
			+ "search_end=" + string end + "\n"
			+ "search_code=" + matchcode + "\n";
	}

	return "";
}