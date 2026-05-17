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

	/*
	 * Modified function key groups: KFxxx|1..KFxxx|12
	 * Modifier bitmask (used as table index): Shift=1, Alt=2, Ctrl=4
	 * kftab[mask] below maps mask -> base constant:
	 *   0=KF, 1=KFShift, 2=KFAlt, 3=KFAltShift,
	 *   4=KFCtrl, 5=KFCtrlShift, 6=KFCtrlAlt, 7=KFCtrlAltShift
	 * Ranges are non-overlapping; each group holds indices 1..12.
	 */
	KFShift=	Spec|0x070,	/* Shift+F1..F12 */
	KFAlt=		Spec|0x080,	/* Alt+F1..F12 */
	KFAltShift=	Spec|0x090,	/* Alt+Shift+F1..F12 */
	KFCtrl=		Spec|0x0A0,	/* Ctrl+F1..F12 */
	KFCtrlShift=	Spec|0x0B0,	/* Ctrl+Shift+F1..F12 */
	KFCtrlAlt=	Spec|0x0C0,	/* Ctrl+Alt+F1..F12 */
	KFCtrlAltShift=	Spec|0x0D0,	/* Ctrl+Alt+Shift+F1..F12 */

	/*
	 * Modified navigation key groups: ViewXxx|k
	 * k is the View sub-index: Home=0, End=1, Up=2, Down=3,
	 *   Left=4, Right=5, Pgup=6, Pgdown=7
	 * vwtab[mask] maps mask -> base constant (same mask encoding as KF above).
	 * ViewCtrlAltShift is placed above APP range (0xE200..0xE2FF).
	 */
	ViewShift=		Spec|0x1A0,	/* Shift+navigation */
	ViewAlt=		Spec|0x1B0,	/* Alt+navigation */
	ViewAltShift=		Spec|0x1C0,	/* Alt+Shift+navigation */
	ViewCtrl=		Spec|0x1D0,	/* Ctrl+navigation */
	ViewCtrlShift=		Spec|0x1E0,	/* Ctrl+Shift+navigation */
	ViewCtrlAlt=		Spec|0x1F0,	/* Ctrl+Alt+navigation */
	ViewCtrlAltShift=	Spec|0x300,	/* Ctrl+Alt+Shift+navigation */

	/*
	 * Modified Insert/Delete keys.
	 * instab[mask] / deltab[mask] below map modifier mask -> key code.
	 */
	ShiftIns=	Spec|0x310,
	AltIns=		Spec|0x311,
	AltShiftIns=	Spec|0x312,
	CtrlIns=	Spec|0x313,
	CtrlShiftIns=	Spec|0x314,
	CtrlAltIns=	Spec|0x315,
	CtrlAltShiftIns=Spec|0x316,
	ShiftDel=	Spec|0x317,
	AltDel=		Spec|0x318,
	AltShiftDel=	Spec|0x319,
	CtrlDel=	Spec|0x31A,
	CtrlShiftDel=	Spec|0x31B,
	CtrlAltDel=	Spec|0x31C,
	CtrlAltShiftDel=Spec|0x31D,

	/* for German keyboard */
	German=		Spec|0xf00,

	Grave=		German|0x1,
	Acute=		German|0x2,
	Circumflex=	German|0x3,

	APP=		Spec|0x200,		/* for ALT application keys */

	No=			-1,			/* peter */
};

