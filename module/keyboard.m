Keyboard : module {
	# Inferno Generic Scan Conversions
	# this file needs to be kept in sync with include/keyboard.h 

	No: con -1;
	Esc: con 16r1b;

	Spec: con 16rE000;		# Special Function Keys - mapped to Unicode reserved range
	Shift: con Spec|16r00;	# Shifter (Held) Keys 
	View: con Spec|16r10;	# View Keys
	PF: con	Spec|16r20;	# num pad
	KF: con	Spec|16r40;	# function keys

	LShift: con Shift|0;
	RShift: con Shift|1;
	LCtrl: con Shift|2;
	RCtrl: con Shift|3;
	Caps: con Shift|4;
	Num: con Shift|5;
	Meta: con Shift|6;
	LAlt: con Shift|7;
	RAlt: con Shift|8;
	NShifts: con 9;			# total number of shift keys

	Home: con View|0;
	End: con View|1;
	Up: con View|2;
	Down: con View|3;
	Left: con View|4;
	Right: con View|5;
	Pgup: con View|6;
	Pgdown: con View|7;
	BackTab: con View|8;

	Scroll: con Spec|16r62;
	Ins: con Spec|16r63;
	Del: con Spec|16r64;
	Print: con Spec|16r65;
	Pause: con Spec|16r66;
	Middle: con Spec|16r67;
	Break: con Spec|16r66;
	SysRq: con Spec|16r69;
	PwrOn: con Spec|16r6c;
	PwrOff: con Spec|16r6d;
	PwrLow: con Spec|16r6e;
	Latin: con Spec|16r6f;

	APP: con Spec|16r200;	# for application use (ALT keys)

	# Modifier prefix ranges for shifted/ctrl/alt navigation key combinations.
	# These occupy Spec|0x80-0xAF, unused by existing key definitions.
	# Offsets within each range match View offsets (Home=0,End=1,Up=2,...).
	KMshift: con Spec|16r80;	# Shift + navigation key base
	KMctrl: con Spec|16r90;	# Ctrl + navigation key base
	KMalt: con Spec|16ra0;	# Alt + navigation key base

	ShiftHome: con KMshift|0;
	ShiftEnd: con KMshift|1;
	ShiftUp: con KMshift|2;
	ShiftDown: con KMshift|3;
	ShiftLeft: con KMshift|4;
	ShiftRight: con KMshift|5;
	ShiftPgup: con KMshift|6;
	ShiftPgdown: con KMshift|7;

	CtrlHome: con KMctrl|0;
	CtrlEnd: con KMctrl|1;
	CtrlUp: con KMctrl|2;
	CtrlDown: con KMctrl|3;
	CtrlLeft: con KMctrl|4;
	CtrlRight: con KMctrl|5;
	CtrlPgup: con KMctrl|6;
	CtrlPgdown: con KMctrl|7;

	AltHome: con KMalt|0;
	AltEnd: con KMalt|1;
	AltUp: con KMalt|2;
	AltDown: con KMalt|3;
	AltLeft: con KMalt|4;
	AltRight: con KMalt|5;
	AltPgup: con KMalt|6;
	AltPgdown: con KMalt|7;
};

