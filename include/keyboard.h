/************** Inferno Generic Scan Conversions ************/

/* this file needs to be kept in sync with module/keyboard.m */

enum {
	Esc=		0x1b,

	Spec=		0xe000,		/* Special Function Keys, mapped to Unicode reserved range (E000-F8FF) */

	Shift=		Spec|0x0,	/* Shifter (Held and Toggle) Keys  */
	View=		Spec|0x10,	/* View Keys 		*/
	PF=		Spec|0x20,	/* num pad		*/
	KF=		Spec|0x40,	/* function keys        */

	LShift=		Shift|0,
	RShift=		Shift|1,
	LCtrl=		Shift|2,
	RCtrl=		Shift|3,
	Caps=		Shift|4,
	Num=		Shift|5,	
	Meta=		Shift|6,
	LAlt=		Shift|7,
	RAlt=		Shift|8,
	NShifts=	9,

	Home=	   	View|0,
	End=		View|1,
	Up=		View|2,
	Down=		View|3,
	Left=		View|4,
	Right=		View|5,
	Pgup=		View|6,
	Pgdown=		View|7,
	BackTab=	View|8,

	Scroll=		Spec|0x62,
	Ins=		Spec|0x63,
	Del=		Spec|0x64,
	Print=		Spec|0x65,
	Pause=		Spec|0x66,
	Middle=		Spec|0x67,
	Break=		Spec|0x66,
	SysRq=		Spec|0x69,
	PwrOn=		Spec|0x6c,
	PwrOff=		Spec|0x6d,
	PwrLow=		Spec|0x6e,
	Latin=		Spec|0x6f,

	/* for German keyboard */
	German=		Spec|0xf00,

	Grave=		German|0x1,
	Acute=		German|0x2,
	Circumflex=	German|0x3,

	APP=		Spec|0x200,		/* for ALT application keys */

	/*
	 * Modifier prefix ranges for shifted/ctrl/alt navigation key combinations.
	 * These occupy Spec|0x80-0xAF, unused by existing key definitions.
	 * Offsets within each range match View offsets (Home=0,End=1,Up=2,...,BackTab=8).
	 */
	KMshift=	Spec|0x80,		/* Shift + navigation key base */
	KMctrl=		Spec|0x90,		/* Ctrl + navigation key base */
	KMalt=		Spec|0xa0,		/* Alt + navigation key base */

	ShiftHome=	KMshift|0,
	ShiftEnd=	KMshift|1,
	ShiftUp=	KMshift|2,
	ShiftDown=	KMshift|3,
	ShiftLeft=	KMshift|4,
	ShiftRight=	KMshift|5,
	ShiftPgup=	KMshift|6,
	ShiftPgdown=	KMshift|7,

	CtrlHome=	KMctrl|0,
	CtrlEnd=	KMctrl|1,
	CtrlUp=		KMctrl|2,
	CtrlDown=	KMctrl|3,
	CtrlLeft=	KMctrl|4,
	CtrlRight=	KMctrl|5,
	CtrlPgup=	KMctrl|6,
	CtrlPgdown=	KMctrl|7,

	AltHome=	KMalt|0,
	AltEnd=		KMalt|1,
	AltUp=		KMalt|2,
	AltDown=	KMalt|3,
	AltLeft=	KMalt|4,
	AltRight=	KMalt|5,
	AltPgup=	KMalt|6,
	AltPgdown=	KMalt|7,

	No=			-1,			/* peter */
};

