IcViewCommon: module
{
	ViewerSource: adt
	{
		path: string;
		fd: ref Sys->FD;
		length: big;

		offsets: array of big;
		noffsets: int;
		offsetcap: int;

		scanoff: big;
		eof: int;
		error: string;

		encoding: string;
	};

	ViewerStats: adt
	{
		ready: int;
		dirty: int;
		bytes: big;
		lines: big;
		chars: big;
	};

	GotoState: adt
	{
		active: int;

		shadowid: int;
		windowid: int;
		inputid: int;
		typeids: array of int;
		buttonids: array of int;
		historyids: array of int;

		x: int;
		y: int;
		w: int;
		h: int;

		input: string;
		inputpos: int;
		inputhistoryopen: int;
		inputhistorysel: int;
		inputhistoryitems: array of string;

		mode: int;
		focus: int;
		result: int;
	};

	SearchOptions: adt
	{
		pattern: string;

		backward: int;
		casefold: int;
		wrap: int;
		regex: int;

		encoding: string;
		anyencoding: int;
	};

	SearchMatch: adt
	{
		offset: big;
		line: int;
		col: int;
		length: int;
		text: string;
	};

	SearchSession: adt
	{
		active: int;
		path: string;
		opts: SearchOptions;

		matches: array of SearchMatch;
		current: int;

		lastline: int;
		lastcol: int;
		lastdirection: int;
	};

	SearchDialogState: adt
	{
		active: int;
		alert: int;
		alerttext: string;

		shadowid: int;
		windowid: int;
		inputid: int;
		optionids: array of int;
		buttonids: array of int;
		historyids: array of int;

		x: int;
		y: int;
		w: int;
		h: int;

		input: string;
		inputpos: int;
		inputhistoryopen: int;
		inputhistorysel: int;
		inputhistoryitems: array of string;

		focus: int;

		case_sensitive: int;
		backward: int;
		wrap: int;
		regex: int;
		anyencoding: int;
		encoding: string;

		result: int;
	};

	GotoNone: con 0;
	GotoOk: con 1;
	GotoCancel: con 2;

	GotoLine: con 0;
	GotoPercent: con 1;
	GotoOffsetDec: con 2;
	GotoOffsetHex: con 3;

	GotoFocusInput: con 0;
	GotoFocusLine: con 1;
	GotoFocusPercent: con 2;
	GotoFocusOffsetDec: con 3;
	GotoFocusOffsetHex: con 4;
	GotoFocusOk: con 5;
	GotoFocusCancel: con 6;

	SearchNone: con 0;
	SearchForward: con 1;
	SearchBackward: con 2;
	SearchCancel: con 3;
	SearchAlertClosed: con 4;

	SearchFocusInput: con 0;
	SearchFocusCase: con 1;
	SearchFocusBackward: con 2;
	SearchFocusWrap: con 3;
	SearchFocusRegex: con 4;
	SearchFocusAnyEncoding: con 5;
	SearchFocusForward: con 6;
	SearchFocusBackwardButton: con 7;
	SearchFocusCancel: con 8;

	SearchDirForward: con 1;
	SearchDirBackward: con -1;
};