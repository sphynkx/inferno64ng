implement IcTextView;

include "icurses/textview.m";

init()
{
}

new(): ref IcTextView->Model
{
	m: ref IcTextView->Model;

	m = ref IcTextView->Model;
	m.lines = array[0] of string;
	m.spans = array[0] of IcTextView->Span;
	m.topline = 0;
	m.leftcol = 0;
	m.basecode = "";
	m.sanitizecode = "";
	m.selectcode = "";
	m.searchcode = "";

	return m;
}

clear(m: ref IcTextView->Model)
{
	if(m == nil)
		return;

	m.lines = array[0] of string;
	m.spans = array[0] of IcTextView->Span;
	m.topline = 0;
	m.leftcol = 0;
}

setlines(m: ref IcTextView->Model, lines: array of string)
{
	if(m == nil)
		return;

	if(lines == nil)
		m.lines = array[0] of string;
	else
		m.lines = lines;
}

setscroll(m: ref IcTextView->Model, topline, leftcol: int)
{
	if(m == nil)
		return;

	if(topline < 0)
		topline = 0;
	if(leftcol < 0)
		leftcol = 0;

	m.topline = topline;
	m.leftcol = leftcol;
}

setcodes(m: ref IcTextView->Model, basecode, sanitizecode, selectcode, searchcode: string)
{
	if(m == nil)
		return;

	m.basecode = basecode;
	m.sanitizecode = sanitizecode;
	m.selectcode = selectcode;
	m.searchcode = searchcode;
}

setspans(m: ref IcTextView->Model, spans: array of IcTextView->Span)
{
	if(m == nil)
		return;

	if(spans == nil)
		m.spans = array[0] of IcTextView->Span;
	else
		m.spans = spans;
}

linecount(m: ref IcTextView->Model): int
{
	if(m == nil || m.lines == nil)
		return 0;

	return len m.lines;
}