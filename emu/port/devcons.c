#include	"dat.h"
#include	"fns.h"
#include	"error.h"
#include	"version.h"
#include	"mp.h"
#include	"libsec.h"
#include	"keyboard.h"

#ifdef __linux__
#include	<sys/select.h>
#include	<unistd.h>
#endif

#if defined(__MINGW32__) || defined(__linux__)
extern int osconsinfo(char*, int);
#endif

extern int cflag;
extern int exdebug;
extern int keepbroken;

enum
{
	Qdir,
	Qcons,
	Qconsctl,
	Qconsinfo,
	Qdrivers,
	Qhostowner,
	Qhoststdin,
	Qhoststdout,
	Qhoststderr,
	Qjit,
	Qkeyboard,
	Qekeyboard,
	Qemouse,
	Qkprint,
	Qmemory,
	Qmsec,
	Qnotquiterandom,
	Qnull,
	Qrandom,
	Qscancode,
	Qsysctl,
	Qsysname,
	Qtime,
	Quser
};

Dirtab contab[] =
{
	".",		{Qdir, 0, QTDIR},	0,	DMDIR|0555,
	"cons",		{Qcons},		0,	0666,
	"consctl",	{Qconsctl},		0,	0222,
	"consinfo",	{Qconsinfo},		0,	0444,
	"drivers",	{Qdrivers},		0,	0444,
	"ekeyboard",	{Qekeyboard},	0,	0666,
	"emouse",	{Qemouse},	0,	0666,
	"hostowner",	{Qhostowner},	0,	0644,
	"hoststdin",	{Qhoststdin},	0,	0444,
	"hoststdout",	{Qhoststdout},	0,	0222,
	"hoststderr",	{Qhoststderr},	0,	0222,
	"jit",	{Qjit},	0,	0666,
	"keyboard",	{Qkeyboard},	0,	0666,
	"kprint",	{Qkprint},	0,	0444,
	"memory",	{Qmemory},	0,	0444,
	"msec",		{Qmsec},	NUMSIZE,	0444,
	"notquiterandom",	{Qnotquiterandom},	0,	0444,
	"null",		{Qnull},	0,	0666,
	"random",	{Qrandom},	0,	0444,
	"scancode",	{Qscancode},	0,	0444,
	"sysctl",	{Qsysctl},	0,	0644,
	"sysname",	{Qsysname},	0,	0644,
	"time",		{Qtime},	0,	0644,
	"user",		{Quser},	0,	0644,
};

Queue*	gkscanq;		/* Graphics keyboard raw scancodes */
extern	char	gkscanid[];	/* name of raw scan format (if defined) */
Queue*	ekbdq;			/* Enhanced console keyboard input */
Queue*	emouseq;		/* Enhanced console mouse input */
Queue*	gkbdq;			/* Graphics keyboard unprocessed input */
Queue*	kbdq;			/* Console window unprocessed keyboard input */
Queue*	lineq;			/* processed console input */

char	*ossysname;

static struct
{
	RWlock l;
	Queue*	q;
} kprintq;

vlong	timeoffset;

extern int	dflag;

static int	sysconwrite(void*, ulong);
extern char**	rebootargv;

static struct
{
	QLock	q;
	QLock	gq;		/* separate lock for the graphical input */

	int	raw;		/* true if we shouldn't process input */
	Ref	ctl;		/* number of opens to the control file */
	Ref	ptr;		/* number of opens to the ptr file */
	Ref	ekbd;		/* number of opens to the enhanced keyboard file */
	int	scan;		/* true if reading raw scancodes */
	int	x;		/* index into line */
	char	line[1024];	/* current input line */

	Rune	c;
	int	count;
} kbd;

static void
emouseput(char *buf, int n)
{
	if(emouseq == nil || n <= 0)
		return;
	qproduce(emouseq, buf, n);
}

void
kbdslave(void *a)
{
	char b;

	USED(a);
	for(;;) {
		b = readkbd();
		if(kbd.raw == 0){
			switch(b){
			case 0x15:
				write(1, "^U\n", 3);
				break;
			default:
				write(1, &b, 1);
				break;
			}
		}
		qproduce(kbdq, &b, 1);
	}
	/* pexit("kbdslave", 0); */	/* not reached */
}

static void
ekbdputc(int ch)
{
	if(ekbdq == nil)
		return;
	gkbdputc(ekbdq, ch);
}

static int
ordinarykey(int k)
{
	return k >= 0 && k < Spec;
}

static int
ekbdsessionactive(void)
{
	/*
	 * MinGW keeps draining host console input continuously, so gating
	 * legacy mirroring on kbd.ekbd.ref alone can keep shell input
	 * suppressed after the visible session has ended if FD finalization
	 * lags.  The proven leak only happens while the enhanced raw session
	 * is actively owning input, so require both raw mode and an open
	 * /dev/ekeyboard reference there.
	 */
#ifdef __MINGW32__
	return kbd.raw != 0 && kbd.ekbd.ref != 0;
#else
	return kbd.ekbd.ref != 0;
#endif
}

#ifdef __MINGW32__
extern int reademouse(char *buf, int n);
extern void enableconsolemouse(void);
extern void disableconsolemouse(void);

static int mouseprocstarted;

/*
 * MinGW/MSYS2 console keyboard reader:
 * single source of truth for console input.
 *
 * All key events go to /dev/ekeyboard.
 * Ordinary text input is also translated to the legacy console queue
 * so /dev/cons and the shell continue to work from the same event stream.
 */
void
winkbdslave(void *a)
{
	int k, nb;
	Rune r;
	char b;
	char ubuf[UTFmax];

	USED(a);
	for(;;){
		k = readekbd();
		if(k < 0)
			continue;

		/*
		 * Full event stream for enhanced console clients.
		 * MinGW keeps draining host console input into ekbdq and trims
		 * stale entries on open via qflush(ekbdq), rather than waiting
		 * for kbd.ekbd.ref before it starts collecting host events.
		 */
		ekbdputc(k);

		/*
		 * Legacy console path:
		 * ordinary text should only reach /dev/cons when the enhanced
		 * raw session does not currently own input.
		 *
		 * When MinGW raw + /dev/ekeyboard are both active, mirroring the
		 * same ordinary key into kbdq leaks dialog-consumed text back to
		 * the shell after the interactive session ends.
		 */
		if(ordinarykey(k) && !ekbdsessionactive()){
			r = k;
			if(r == '\r')
				r = '\n';

			if(r < 0x80){
				b = r;
				if(kbd.raw == 0){
					switch(b){
					case 0x15:
						write(1, "^U\n", 3);
						break;
					default:
						write(1, &b, 1);
						break;
					}
				}
				qproduce(kbdq, &b, 1);
			}else{
				nb = runetochar(ubuf, &r);
				if(nb <= 0)
					continue;
				if(kbd.raw == 0)
					write(1, ubuf, nb);
				qproduce(kbdq, ubuf, nb);
			}
		}
	}
	/* not reached */
}

void
winmouseslave(void *a)
{
	char buf[128];
	int n;

	USED(a);
	for(;;){
		n = reademouse(buf, sizeof(buf));
		if(n <= 0)
			continue;
		emouseput(buf, n);
	}
	/* not reached */
}

#endif

#ifdef __linux__

enum
{
	LinuxNoKey = -1000000,
	LinuxMouseEvent = -1000001,

	LinuxDeleteChar = 0x7F,
	LinuxCtrlC = 0x03
};

static int linuxmousebuttons;

static int
linuxreadkbdchar(int *cp, int timeoutms)
{
	int n;
	char ch;

	if(timeoutms >= 0){
		fd_set rd;
		struct timeval tv;

		FD_ZERO(&rd);
		FD_SET(0, &rd);
		tv.tv_sec = timeoutms/1000;
		tv.tv_usec = (timeoutms%1000)*1000;

		n = select(1, &rd, nil, nil, &tv);
		if(n <= 0)
			return 0;
	}

	n = read(0, &ch, sizeof(ch));
	if(n <= 0)
		return 0;

	*cp = (uchar)ch;
	return 1;
}

static int
linuxreadkbdrune(int c0)
{
	int c, n;
	char buf[UTFmax];
	Rune r;

	buf[0] = c0;
	n = 1;

	while(n < UTFmax && !fullrune(buf, n)){
		if(!linuxreadkbdchar(&c, -1))
			return c0;
		buf[n++] = c;
	}

	if(chartorune(&r, buf) <= 0)
		return c0;

	return r;
}

static int
linuxbuttonmask(int code, int release)
{
	if(release)
		return 0;

	if(code & 64){
		switch(code & 3){
		case 0:
			return 8;	/* wheel up */
		case 1:
			return 16;	/* wheel down */
		default:
			return 0;
		}
	}

	switch(code & 3){
	case 0:
		return 1;	/* left */
	case 1:
		return 4;	/* middle */
	case 2:
		return 2;	/* right */
	default:
		return 0;
	}
}

static int
linuxmodmask(int code)
{
	int m;

	m = 0;
	if(code & 4)
		m |= 1;		/* shift */
	if(code & 16)
		m |= 2;		/* ctrl */
	if(code & 8)
		m |= 4;		/* alt/meta */

	return m;
}

static int
linuxmouseevent(int code, int x, int y, int release)
{
	char buf[128];
	int b, mods, n;

	if(x > 0)
		x--;
	if(y > 0)
		y--;

	mods = linuxmodmask(code);

	if(code & 64){
		/*
		 * Wheel events are momentary.  Do not make them the persistent
		 * button state for later motion events.
		 */
		b = linuxbuttonmask(code, 0);
		linuxmousebuttons = 0;
	}else if(release || (code & 3) == 3){
		/*
		 * SGR mouse release normally arrives with final byte 'm'.
		 * Some terminals can also encode release/no-button as button
		 * number 3.  In both cases publish current buttons as none and
		 * reset the saved button state.
		 */
		b = 0;
		linuxmousebuttons = 0;
	}else if(code & 32){
		/*
		 * Button-motion event.  Keep the currently reported physical
		 * button as the persistent drag state.  With 1003 disabled this
		 * should not be flooded by passive no-button motion.
		 */
		b = linuxbuttonmask(code, 0);
		if(b != 0)
			linuxmousebuttons = b;
		else
			b = linuxmousebuttons;
	}else{
		b = linuxbuttonmask(code, 0);
		linuxmousebuttons = b;
	}

	n = snprint(buf, sizeof(buf), "m %d %d %d %d\n", x, y, b, mods);
	emouseput(buf, n);

	return LinuxMouseEvent;
}

static int
linuxparsesgrmouse(void)
{
	int c, code, x, y, release;

	code = 0;
	x = 0;
	y = 0;
	release = 0;

	for(;;){
		if(!linuxreadkbdchar(&c, 25))
			return LinuxNoKey;

		if(c >= '0' && c <= '9'){
			code = code * 10 + c - '0';
			continue;
		}

		if(c == ';')
			break;

		return LinuxNoKey;
	}

	for(;;){
		if(!linuxreadkbdchar(&c, 25))
			return LinuxNoKey;

		if(c >= '0' && c <= '9'){
			x = x * 10 + c - '0';
			continue;
		}

		if(c == ';')
			break;

		return LinuxNoKey;
	}

	for(;;){
		if(!linuxreadkbdchar(&c, 25))
			return LinuxNoKey;

		if(c >= '0' && c <= '9'){
			y = y * 10 + c - '0';
			continue;
		}

		if(c == 'M'){
			release = 0;
			break;
		}

		if(c == 'm'){
			release = 1;
			break;
		}

		return LinuxNoKey;
	}

	return linuxmouseevent(code, x, y, release);
}

static int
linuxparsecsi(int lead)
{
	int c, i, n, num;
	char seq[32];

	if(lead == '['){
		if(!linuxreadkbdchar(&c, 25))
			return LinuxNoKey;

		if(c == '<')
			return linuxparsesgrmouse();

		seq[0] = lead;
		seq[1] = c;
		n = 2;
	}else{
		seq[0] = lead;
		n = 1;
	}

	while(n < (int)sizeof(seq)-1){
		if(n > 1 && seq[n-1] >= '@' && seq[n-1] <= '~')
			break;

		if(!linuxreadkbdchar(&c, 25))
			break;

		seq[n++] = c;

		if(c >= '@' && c <= '~')
			break;
	}

	seq[n] = 0;

	if(lead == '['){
		switch(seq[n-1]){
		case 'A':
			return Up;
		case 'B':
			return Down;
		case 'C':
			return Right;
		case 'D':
			return Left;
		case 'F':
			return End;
		case 'H':
			return Home;
		case 'Z':
			return BackTab;
		case '~':
			num = 0;
			for(i = 1; i < n; i++){
				if(seq[i] >= '0' && seq[i] <= '9')
					num = num * 10 + seq[i] - '0';
				else
					break;
			}

			switch(num){
			case 1:
			case 7:
				return Home;
			case 2:
				return Ins;
			case 3:
				return Del;
			case 4:
			case 8:
				return End;
			case 5:
				return Pgup;
			case 6:
				return Pgdown;
			case 11:
				return KF|1;
			case 12:
				return KF|2;
			case 13:
				return KF|3;
			case 14:
				return KF|4;
			case 15:
				return KF|5;
			case 17:
				return KF|6;
			case 18:
				return KF|7;
			case 19:
				return KF|8;
			case 20:
				return KF|9;
			case 21:
				return KF|10;
			case 23:
				return KF|11;
			case 24:
				return KF|12;
			}
			break;
		}
	}else if(lead == 'O'){
		switch(seq[n-1]){
		case 'A':
			return Up;
		case 'B':
			return Down;
		case 'C':
			return Right;
		case 'D':
			return Left;
		case 'F':
			return End;
		case 'H':
			return Home;
		case 'P':
			return KF|1;
		case 'Q':
			return KF|2;
		case 'R':
			return KF|3;
		case 'S':
			return KF|4;
		}
	}

	return LinuxNoKey;
}

static int
linuxreadenhancedkey(void)
{
	int c, k;

	if(!linuxreadkbdchar(&c, -1))
		return -1;

	switch(c){
	case '\r':
		return '\n';
	case LinuxDeleteChar:
		return '\b';
	case LinuxCtrlC:
		cleanexit(0);
		return -1;
	case Esc:
		if(!linuxreadkbdchar(&c, 25))
			return Esc;

		if(c == '[' || c == 'O'){
			k = linuxparsecsi(c);
			if(k != LinuxNoKey)
				return k;

			return Esc;
		}

		if((c & 0x80) != 0)
			return linuxreadkbdrune(c);

		return APP | c;
	}

	if((c & 0x80) != 0)
		return linuxreadkbdrune(c);

	return c;
}

static void
linuxconsolemouseon(void)
{
	static char seq[] =
		"\033[?1000h"
		"\033[?1002h"
		"\033[?1006h";

	write(1, seq, sizeof(seq)-1);
}

static void
linuxconsolemouseoff(void)
{
	static char seq[] =
		"\033[?1006l"
		"\033[?1002l"
		"\033[?1000l";

	write(1, seq, sizeof(seq)-1);
	linuxmousebuttons = 0;
}

void
linuxkbdslave(void *a)
{
	int k, nb;
	Rune r;
	char b;
	char ubuf[UTFmax];

	USED(a);
	for(;;){
		k = linuxreadenhancedkey();
		if(k < 0)
			continue;

		if(k == LinuxMouseEvent)
			continue;

		if(kbd.ekbd.ref != 0)
			ekbdputc(k);

		if(kbd.ekbd.ref == 0 && ordinarykey(k)){
			r = k;
			if(r == '\r')
				r = '\n';

			if(r < 0x80){
				b = r;
				if(kbd.raw == 0){
					switch(b){
					case 0x15:
						write(1, "^U\n", 3);
						break;
					default:
						write(1, &b, 1);
						break;
					}
				}
				qproduce(kbdq, &b, 1);
			}else{
				nb = runetochar(ubuf, &r);
				if(nb <= 0)
					continue;
				if(kbd.raw == 0)
					write(1, ubuf, nb);
				qproduce(kbdq, ubuf, nb);
			}
		}
	}
	/* not reached */
}
#endif

void
gkbdputc(Queue *q, int ch)
{
	int n;
	Rune r;
	static uchar kc[5*UTFmax];
	static int nk, collecting = 0;
	char buf[UTFmax];

	r = ch;
	if(r == Latin) {
		collecting = 1;
		nk = 0;
		return;
	}
	if(collecting) {
		int c;
		nk += runetochar((char*)&kc[nk], &r);
		c = latin1(kc, nk);
		if(c < -1)	/* need more keystrokes */
			return;
		collecting = 0;
		if(c == -1) {	/* invalid sequence */
			qproduce(q, kc, nk);
			return;
		}
		r = (Rune)c;
	}
	n = runetochar(buf, &r);
	if(n == 0)
		return;
	/* if(!isdbgkey(r)) */ 
		qproduce(q, buf, n);
}

void
consinit(void)
{
	kbdq = qopen(512, 0, nil, nil);
	if(kbdq == 0)
		panic("no memory");
	lineq = qopen(2*1024, 0, nil, nil);
	if(lineq == 0)
		panic("no memory");
	gkbdq = qopen(512, 0, nil, nil);
	if(gkbdq == 0)
		panic("no memory");
	ekbdq = qopen(512, 0, nil, nil);
	if(ekbdq == 0)
		panic("no memory");
	emouseq = qopen(2*1024, 0, nil, nil);
	if(emouseq == 0)
		panic("no memory");
	randominit();
}

/*
 *  return true if current user is eve
 */
int
iseve(void)
{
	return strcmp(eve, up->env->user) == 0;
}

static Chan*
consattach(char *spec)
{
	static int kp;

	if(kp == 0 && !dflag) {
		kp = 1;
#ifdef __MINGW32__
		kproc("kbd", winkbdslave, 0, 0);
#elif defined(__linux__)
		kproc("kbd", linuxkbdslave, 0, 0);
#else
		kproc("kbd", kbdslave, 0, 0);
#endif
	}
	return devattach('c', spec);
}

static Walkqid*
conswalk(Chan *c, Chan *nc, char **name, int nname)
{
	return devwalk(c, nc, name, nname, contab, nelem(contab), devgen);
}

static int
consstat(Chan *c, uchar *db, int n)
{
	return devstat(c, db, n, contab, nelem(contab), devgen);
}

static Chan*
consopen(Chan *c, int omode)
{
	c = devopen(c, omode, contab, nelem(contab), devgen);
	switch((ulong)c->qid.path) {
	case Qconsctl:
		incref(&kbd.ctl);
		break;

	case Qemouse:
#ifdef __MINGW32__
		if(incref(&kbd.ptr) == 1)
			enableconsolemouse();
		if(mouseprocstarted == 0){
			mouseprocstarted = 1;
			kproc("mouse", winmouseslave, 0, 0);
		}
#elif defined(__linux__)
		if(incref(&kbd.ptr) == 1){
			qflush(emouseq);
			linuxconsolemouseon();
		}
#else
		incref(&kbd.ptr);
#endif
		break;

	case Qekeyboard:
	{
#ifdef __MINGW32__
		incref(&kbd.ekbd);
		/*
		 * Drop stale enhanced-key events on every open.
		 *
		 * The MinGW reader already drains console input continuously
		 * into ekbdq, so flushing the queue here is enough to discard
		 * pre-open shell/build keystrokes without depending on
		 * first-open / last-close transitions that can lag under
		 * GC-driven FD finalization.
		 */
		qflush(ekbdq);
		qflush(kbdq);
#else
		if(incref(&kbd.ekbd) == 1){
			qflush(ekbdq);
		}
#endif
		break;
	}

	case Qscancode:
		qlock(&kbd.gq);
		if(gkscanq != nil || gkscanid[0] == '\0') {
			qunlock(&kbd.gq);
			c->flag &= ~COPEN;
			if(gkscanq)
				error(Einuse);
			else
				error("not supported");
		}
		gkscanq = qopen(256, 0, nil, nil);
		qunlock(&kbd.gq);
		break;

	case Qkprint:
		wlock(&kprintq.l);
		if(waserror()){
			wunlock(&kprintq.l);
			c->flag &= ~COPEN;
			nexterror();
		}
		if(kprintq.q != nil)
			error(Einuse);
		kprintq.q = qopen(32*1024, Qcoalesce, nil, nil);
		if(kprintq.q == nil)
			error(Enomem);
		qnoblock(kprintq.q, 1);
		poperror();
		wunlock(&kprintq.l);
		c->iounit = qiomaxatomic;
		break;
	}
	return c;
}

static void
consclose(Chan *c)
{
	if((c->flag & COPEN) == 0)
		return;

	switch((ulong)c->qid.path) {
	case Qconsctl:
		/* last close of control file turns off raw */
		if(decref(&kbd.ctl) == 0)
			kbd.raw = 0;
		break;

	case Qemouse:
		if(decref(&kbd.ptr) == 0){
#ifdef __MINGW32__
			disableconsolemouse();
#elif defined(__linux__)
			linuxconsolemouseoff();
			qflush(emouseq);
#endif
		}
		break;

	case Qekeyboard:
		if(decref(&kbd.ekbd) == 0)
		{
			qflush(ekbdq);
			qflush(kbdq);
		}
		break;

	case Qscancode:
		qlock(&kbd.gq);
		if(gkscanq) {
			qfree(gkscanq);
			gkscanq = nil;
		}
		qunlock(&kbd.gq);
		break;

	case Qkprint:
		wlock(&kprintq.l);
		qfree(kprintq.q);
		kprintq.q = nil;
		wunlock(&kprintq.l);
		break;
	}
}

static long
consread(Chan *c, void *va, long n, vlong offset)
{
	int send;
	long r;
	char buf[64], ch, *s;

	if(c->qid.type & QTDIR)
		return devdirread(c, va, n, contab, nelem(contab), devgen);

	switch((ulong)c->qid.path) {
	default:
		error(Egreg);

	case Qsysctl:
		return readstr(offset, va, n, VERSION);

	case Qsysname:
		if(ossysname == nil)
			return 0;
		return readstr(offset, va, n, ossysname);

	case Qrandom:
		return randomread(va, n);

	case Qnotquiterandom:
		genrandom(va, n);
		return n;

	case Qhostowner:
		return readstr(offset, va, n, eve);

	case Qhoststdin:
		return read(0, va, n);	/* should be pread */

	case Quser:
		return readstr(offset, va, n, up->env->user);

	case Qjit:
		snprint(buf, sizeof(buf), "%d", cflag);
		return readstr(offset, va, n, buf);

	case Qtime:
		snprint(buf, sizeof(buf), "%.lld", timeoffset + osusectime());
		return readstr(offset, va, n, buf);

	case Qconsinfo:
		s = malloc(READSTR);
		if(s == nil)
			error(Enomem);

		if(waserror()){
			free(s);
			nexterror();
		}

#if defined(__MINGW32__) || defined(__linux__)
		if(osconsinfo(s, READSTR) < 0)
			snprint(s, READSTR,
				"80 24\n"
				"cols=80\n"
				"rows=24\n"
				"source=fallback-osconsinfo\n");
#else
		snprint(s, READSTR,
			"80 24\n"
			"cols=80\n"
			"rows=24\n"
			"source=fallback-generic\n");
#endif

		r = readstr(offset, va, n, s);
		free(s);
		poperror();
		return r;

	case Qdrivers:
		return devtabread(c, va, n, offset);

	case Qmemory:
		return poolread(va, n, offset);

	case Qnull:
		return 0;

	case Qmsec:
		return readnum(offset, va, n, osmillisec(), NUMSIZE);

	case Qcons:
		qlock(&kbd.q);
		if(waserror()){
			qunlock(&kbd.q);
			nexterror();
		}

		if(dflag)
			error(Enonexist);

		while(!qcanread(lineq)) {
			if(qread(kbdq, &ch, 1) == 0)
				continue;
			send = 0;
			if(ch == 0){
				/* flush output on rawoff -> rawon */
				if(kbd.x > 0)
					send = !qcanread(kbdq);
			}else if(kbd.raw){
				kbd.line[kbd.x++] = ch;
				send = !qcanread(kbdq);
			}else{
				switch(ch){
				case '\b':
					if(kbd.x)
						kbd.x--;
					break;
				case 0x15:
					kbd.x = 0;
					break;
				case 0x04:
					send = 1;
					break;
				case '\n':
					send = 1;
				default:
					kbd.line[kbd.x++] = ch;
					break;
				}
			}
			if(send || kbd.x == sizeof kbd.line){
				qwrite(lineq, kbd.line, kbd.x);
				kbd.x = 0;
			}
		}
		n = qread(lineq, va, n);
		qunlock(&kbd.q);
		poperror();
		return n;

	case Qscancode:
		if(offset == 0)
			return readstr(0, va, n, gkscanid);
		return qread(gkscanq, va, n);

	case Qekeyboard:
		return qread(ekbdq, va, n);

	case Qemouse:
		return qread(emouseq, va, n);

	case Qkeyboard:
		return qread(gkbdq, va, n);

	case Qkprint:
		rlock(&kprintq.l);
		if(waserror()){
			runlock(&kprintq.l);
			nexterror();
		}
		n = qread(kprintq.q, va, n);
		poperror();
		runlock(&kprintq.l);
		return n;
	}
}

static long
conswrite(Chan *c, void *va, long n, vlong offset)
{
	char buf[128], *a, ch;
	int x;

	if(c->qid.type & QTDIR)
		error(Eperm);

	switch((ulong)c->qid.path) {
	default:
		error(Egreg);

	case Qcons:
		if(canrlock(&kprintq.l)){
			if(kprintq.q != nil){
				if(waserror()){
					runlock(&kprintq.l);
					nexterror();
				}
				qwrite(kprintq.q, va, n);
				poperror();
				runlock(&kprintq.l);
				return n;
			}
			runlock(&kprintq.l);
		}
		return write(1, va, n);

	case Qsysctl:
		return sysconwrite(va, n);

	case Qconsctl:
		if(n >= sizeof(buf))
			n = sizeof(buf)-1;
		strncpy(buf, va, n);
		buf[n] = 0;
		for(a = buf; a;){
			if(strncmp(a, "rawon", 5) == 0){
				kbd.raw = 1;
				/* clumsy hack - wake up reader */
				ch = 0;
				qwrite(kbdq, &ch, 1);
			} else if(strncmp(buf, "rawoff", 6) == 0){
				kbd.raw = 0;
			}
			if((a = strchr(a, ' ')) != nil)
				a++;
		}
		break;

	case Qkeyboard:
		for(x=0; x<n; ) {
			Rune r;
			x += chartorune(&r, &((char*)va)[x]);
			gkbdputc(gkbdq, r);
		}
		break;

	case Qnull:
		break;

	case Qtime:
		if(n >= sizeof(buf))
			n = sizeof(buf)-1;
		strncpy(buf, va, n);
		buf[n] = '\0';
		timeoffset = strtoll(buf, 0, 0)-osusectime();
		break;

	case Qhostowner:
		if(!iseve())
			error(Eperm);
		if(offset != 0 || n >= sizeof(buf))
			error(Ebadarg);
		memmove(buf, va, n);
		buf[n] = '\0';
		if(n > 0 && buf[n-1] == '\n')
			buf[--n] = '\0';
		if(n == 0)
			error(Ebadarg);
		/* renameuser(eve, buf); */
		/* renameproguser(eve, buf); */
		kstrdup(&eve, buf);
		kstrdup(&up->env->user, buf);
		break;

	case Quser:
		if(!iseve())
			error(Eperm);
		if(offset != 0)
			error(Ebadarg);
		if(n <= 0 || n >= sizeof(buf))
			error(Ebadarg);
		strncpy(buf, va, n);
		buf[n] = '\0';
		if(n > 0 && buf[n-1] == '\n')
			buf[--n] = '\0';
		if(n == 0)
			error(Ebadarg);
		setid(buf, 0);
		break;

	case Qhoststdout:
		return write(1, va, n);

	case Qhoststderr:
		return write(2, va, n);

	case Qjit:
		if(n >= sizeof(buf))
			n = sizeof(buf)-1;
		strncpy(buf, va, n);
		buf[n] = '\0';
		x = atoi(buf);
		if(x < 0 || x > 9)
			error(Ebadarg);
		cflag = x;
		break;

	case Qsysname:
		if(offset != 0)
			error(Ebadarg);
		if(n < 0 || n >= sizeof(buf))
			error(Ebadarg);
		strncpy(buf, va, n);
		buf[n] = '\0';
		if(buf[n-1] == '\n')
			buf[n-1] = 0;
		kstrdup(&ossysname, buf);
		break;
	}
	return n;
}

static int	
sysconwrite(void *va, ulong count)
{
	Cmdbuf *cb;
	int e;
	cb = parsecmd(va, count);
	if(waserror()){
		free(cb);
		nexterror();
	}
	if(cb->nf == 0)
		error(Enoctl);
	if(strcmp(cb->f[0], "reboot") == 0){
		osreboot(rebootargv[0], rebootargv);
		error("reboot not supported");
	}else if(strcmp(cb->f[0], "halt") == 0){
		if(cb->nf > 1)
			e = atoi(cb->f[1]);
		else
			e = 0;
		cleanexit(e);		/* XXX ignored for the time being (and should be a string anyway) */
	}else if(strcmp(cb->f[0], "broken") == 0)
		keepbroken = 1;
	else if(strcmp(cb->f[0], "nobroken") == 0)
		keepbroken = 0;
	else if(strcmp(cb->f[0], "exdebug") == 0)
		exdebug = !exdebug;
	else
		error(Enoctl);
	poperror();
	free(cb);
	return count;
} 

Dev consdevtab = {
	'c',
	"cons",

	consinit,
	consattach,
	conswalk,
	consstat,
	consopen,
	devcreate,
	consclose,
	consread,
	devbread,
	conswrite,
	devbwrite,
	devremove,
	devwstat
};

static	ulong	randn;

static void
seedrand(void)
{
	randomread((void*)&randn, sizeof(randn));
}

int
nrand(int n)
{
	if(randn == 0)
		seedrand();
	randn = randn*1103515245 + 12345 + osusectime();
	return (randn>>16) % n;
}

int
rand(void)
{
	nrand(1);
	return randn;
}

ulong
truerand(void)
{
	ulong x;

	randomread(&x, sizeof(x));
	return x;
}