IcTextView: module
{
	PATH: con "/dis/lib/icurses/textview.dis";

	SpanSanitized: con 1;
	SpanSelect: con 2;
	SpanSearch: con 3;
	SpanCustom: con 4;

	Span: adt
	{
		line: int;
		start: int;
		end: int;
		code: string;
		kind: int;
	};

	Model: adt
	{
		lines: array of string;
		spans: array of Span;

		topline: int;
		leftcol: int;

		basecode: string;
		sanitizecode: string;
		selectcode: string;
		searchcode: string;
	};

	init: fn();

	new: fn(): ref Model;
	clear: fn(m: ref Model);

	setlines: fn(m: ref Model, lines: array of string);
	setscroll: fn(m: ref Model, topline, leftcol: int);
	setcodes: fn(m: ref Model, basecode, sanitizecode, selectcode, searchcode: string);
	setspans: fn(m: ref Model, spans: array of Span);

	linecount: fn(m: ref Model): int;
};