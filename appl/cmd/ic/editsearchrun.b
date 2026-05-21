implement IcEditSearchRun;

include "ic/editsearchrun.m";

IcSearchMod: module
{
	PATH: con "/dis/ic/search.dis";

	init: fn();

	newsession: fn(path: string, opts: IcViewCommon->SearchOptions): ref IcViewCommon->SearchSession;
	reset: fn(s: ref IcViewCommon->SearchSession, path: string, opts: IcViewCommon->SearchOptions);

	addmatch: fn(s: ref IcViewCommon->SearchSession, m: IcViewCommon->SearchMatch): int;
	matchline: fn(text, pattern: string, casefold, regex, startcol, backward: int): (int, int, string);
};

IcEditSource: module
{
	PATH: con "/dis/ic/editsource.dis";

	init: fn();

	linecount: fn(e: ref IcState->EditorState): int;
	ensureline: fn(e: ref IcState->EditorState, line: int): int;
	getline: fn(e: ref IcState->EditorState, line: int): string;
};

searchmod: IcSearchMod;
source: IcEditSource;

searchsession: ref IcViewCommon->SearchSession;
lastsearchpattern: string;
matchcode: string;

result: fn(found, alert: int, text: string): SearchResult;
resetsearchifneeded: fn(e: ref IcState->EditorState, opts: IcViewCommon->SearchOptions);
searchstartline: fn(e: ref IcState->EditorState, direction, fromcurrent: int): (int, int);
searchline: fn(e: ref IcState->EditorState, line, startcol, backward: int, opts: IcViewCommon->SearchOptions): (int, int, string);

init()
{
	searchmod = load IcSearchMod IcSearchMod->PATH;
	if(searchmod == nil)
		raise "fail:load ic/search";

	source = load IcEditSource IcEditSource->PATH;
	if(source == nil)
		raise "fail:load ic/editsource";

	searchmod->init();
	source->init();

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

resetsearchifneeded(e: ref IcState->EditorState, opts: IcViewCommon->SearchOptions)
{
	path: string;

	if(e == nil)
		return;

	path = e.path;
	if(path == "")
		path = "<new>";

	if(searchsession == nil){
		searchsession = searchmod->newsession(path, opts);
		return;
	}

	if(searchsession.path != path || searchsession.opts.pattern != opts.pattern)
		searchmod->reset(searchsession, path, opts);
	else
		searchsession.opts = opts;
}

searchstartline(e: ref IcState->EditorState, direction, fromcurrent: int): (int, int)
{
	line, startcol: int;

	line = e.cursorline;
	startcol = 0;

	if(fromcurrent && searchsession != nil && searchsession.current >= 0){
		line = searchsession.lastline;

		if(direction == IcViewCommon->SearchDirBackward)
			startcol = searchsession.lastcol - 1;
		else
			startcol = searchsession.lastcol + 1;
	}else if(direction == IcViewCommon->SearchDirBackward)
		startcol = e.cursorcol - 1;
	else
		startcol = e.cursorcol + 1;

	return (line, startcol);
}

searchline(e: ref IcState->EditorState, line, startcol, backward: int, opts: IcViewCommon->SearchOptions): (int, int, string)
{
	text, err: string;
	col, n: int;

	if(e == nil)
		return (-1, 0, "No file");

	if(!source->ensureline(e, line))
		return (-1, 0, "");

	text = source->getline(e, line);
	(col, n, err) = searchmod->matchline(text, opts.pattern, opts.casefold, opts.regex, startcol, backward);

	return (col, n, err);
}

run(e: ref IcState->EditorState, opts: IcViewCommon->SearchOptions, direction: int, fromcurrent: int): SearchResult
{
	m: IcViewCommon->SearchMatch;
	line, col, n, startcol, wrapped, firstline, total: int;
	err: string;

	if(e == nil)
		return result(0, 0, "");

	if(direction == IcViewCommon->SearchDirBackward)
		opts.backward = 1;
	else
		opts.backward = 0;

	if(opts.pattern == "")
		return result(0, 1, "Nothing to search");

	resetsearchifneeded(e, opts);
	lastsearchpattern = opts.pattern;

	if(opts.anyencoding)
		return result(0, 1, "Any encoding search is not implemented for editor yet");

	total = source->linecount(e);
	if(total < 1)
		total = 1;

	(line, startcol) = searchstartline(e, direction, fromcurrent);
	firstline = line;
	wrapped = 0;

	if(direction == IcViewCommon->SearchDirBackward){
		for(;;){
			if(line < 0){
				if(!opts.wrap || wrapped)
					return result(0, 1, "Search finished");

				line = total - 1;
				startcol = -1;
				wrapped = 1;
			}

			(col, n, err) = searchline(e, line, startcol, 1, opts);
			if(err != "")
				return result(0, 1, err);

			if(col >= 0){
				m.offset = big 0;
				m.line = line;
				m.col = col;
				m.length = n;
				m.text = source->getline(e, line);

				searchmod->addmatch(searchsession, m);

				e.cursorline = line;
				e.cursorcol = col;
				e.topline = line;

				return result(1, 0, "");
			}

			line--;
			startcol = -1;

			if(wrapped && line < firstline)
				return result(0, 1, "Nothing found");
		}
	}

	for(;;){
		if(line >= total){
			if(!opts.wrap || wrapped)
				return result(0, 1, "Search finished");

			line = 0;
			startcol = 0;
			wrapped = 1;
		}

		if(!source->ensureline(e, line)){
			if(!opts.wrap || wrapped)
				return result(0, 1, "Search finished");

			line = 0;
			startcol = 0;
			wrapped = 1;
		}

		(col, n, err) = searchline(e, line, startcol, 0, opts);
		if(err != "")
			return result(0, 1, err);

		if(col >= 0){
			m.offset = big 0;
			m.line = line;
			m.col = col;
			m.length = n;
			m.text = source->getline(e, line);

			searchmod->addmatch(searchsession, m);

			e.cursorline = line;
			e.cursorcol = col;
			e.topline = line;

			return result(1, 0, "");
		}

		line++;
		startcol = 0;

		if(wrapped && line > firstline)
			return result(0, 1, "Nothing found");
	}
}

searchsarg(e: ref IcState->EditorState, h: int): string
{
	m: IcViewCommon->SearchMatch;
	row, start, end: int;

	if(e == nil)
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

	row = m.line - e.topline;
	if(row < 0 || row >= h)
		return "";

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