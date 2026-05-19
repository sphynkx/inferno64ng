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

		x: int;
		y: int;
		w: int;
		h: int;

		input: string;
		mode: int;
		focus: int;
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
};