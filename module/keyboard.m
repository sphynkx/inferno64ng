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

	# Modified function key groups: KFxxx|1..KFxxx|12
	# Modifier mask: Shift=1, Alt=2, Ctrl=4 (combined by OR).
	KFShift: con Spec|16r070;		# Shift+F1..F12
	KFAlt: con Spec|16r080;			# Alt+F1..F12
	KFAltShift: con Spec|16r090;		# Alt+Shift+F1..F12
	KFCtrl: con Spec|16r0A0;		# Ctrl+F1..F12
	KFCtrlShift: con Spec|16r0B0;		# Ctrl+Shift+F1..F12
	KFCtrlAlt: con Spec|16r0C0;		# Ctrl+Alt+F1..F12
	KFCtrlAltShift: con Spec|16r0D0;	# Ctrl+Alt+Shift+F1..F12

	# Modified navigation key groups: ViewXxx|k
	# k is View sub-index: Home=0,End=1,Up=2,Down=3,Left=4,Right=5,Pgup=6,Pgdown=7
	ViewShift: con Spec|16r1A0;		# Shift+navigation
	ViewAlt: con Spec|16r1B0;		# Alt+navigation
	ViewAltShift: con Spec|16r1C0;		# Alt+Shift+navigation
	ViewCtrl: con Spec|16r1D0;		# Ctrl+navigation
	ViewCtrlShift: con Spec|16r1E0;		# Ctrl+Shift+navigation
	ViewCtrlAlt: con Spec|16r1F0;		# Ctrl+Alt+navigation
	ViewCtrlAltShift: con Spec|16r300;	# Ctrl+Alt+Shift+navigation (above APP range)

	# Modified Insert/Delete keys
	ShiftIns: con Spec|16r310;
	AltIns: con Spec|16r311;
	AltShiftIns: con Spec|16r312;
	CtrlIns: con Spec|16r313;
	CtrlShiftIns: con Spec|16r314;
	CtrlAltIns: con Spec|16r315;
	CtrlAltShiftIns: con Spec|16r316;
	ShiftDel: con Spec|16r317;
	AltDel: con Spec|16r318;
	AltShiftDel: con Spec|16r319;
	CtrlDel: con Spec|16r31A;
	CtrlShiftDel: con Spec|16r31B;
	CtrlAltDel: con Spec|16r31C;
	CtrlAltShiftDel: con Spec|16r31D;

	APP: con Spec|16r200;	# for application use (ALT keys)
};

