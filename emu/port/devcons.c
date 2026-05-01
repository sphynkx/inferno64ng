#include	"dat.h"
#include	"fns.h"
#include	"error.h"
#include	"version.h"
#include	"mp.h"
#include	"libsec.h"
#include	"keyboard.h"

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
	"time",		{Qtime},	0,	0444,
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
#ifdef __MINGW32__
	return kbd.raw != 0 && kbd.ekbd.ref != 0;
#else
	return kbd.ekbd.ref != 0;
#endif
}

#ifdef __linux__
static void
wakeekbdreaders(void)
{
	char z;

	if(ekbdq == nil)
		return;

	z = 0;
	qreopen(ekbdq);
	qproduce(ekbdq, &z, 1);
}

static void
wakeemousereaders(void)
{
	char msg[] = "m 0 0 0 0\n";

	if(emouseq == nil)
		return;

	qreopen(emouseq);
	qproduce(emouseq, msg, strlen(msg));
}
#endif

#ifdef __MINGW32__
extern int readconsoleevent(int *key, char *mbuf, int mn);
extern void enableconsolemouse(void);
extern void disableconsolemouse(void);

static void
emouseput(char *buf, int n)
{
	if(emouseq == nil || n <= 0)
		return;
	qproduce(emouseq, buf, n);
}

static void
processwinkey(int k)
{
	int nb;
	Rune r;
	char b;
	char ubuf[UTFmax];

	if(k < 0)
		return;

	/*
	 * Full enhanced keyboard stream.
	 *
	 * MinGW drains the host console continuously from a single dispatcher.
	 * Stale enhanced events are trimmed on /dev/ekeyboard open/close.
	 */
	ekbdputc(k);

	/*
	 * Legacy console path:
	 * ordinary text should only reach /dev/cons when the enhanced raw
	 * session does not currently own input.
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
				return;
			if(kbd.raw == 0)
				write(1, ubuf, nb);
			qproduce(kbdq, ubuf, nb);
		}
	}
}

/*
 * MinGW/MSYS2 unified console input dispatcher.
 *
 * This is the only backend thread that reads the Windows console input
 * stream through ReadConsoleInput().
 *
 * It routes:
 *   KEY_EVENT   -> /dev/ekeyboard and legacy /dev/cons
 *   MOUSE_EVENT -> /dev/emouse when /dev/emouse is open
 *
 * Keeping one reader avoids losing events between independent keyboard
 * and mouse readers.
 */
void
winkbdslave(void *a)
{
	int t, k;
	char mbuf[128];

	USED(a);

	for(;;){
		k = -1;
		mbuf[0] = 0;

		t = readconsoleevent(&k, mbuf, sizeof(mbuf));

		if(t == 1){
			processwinkey(k);
			continue;
		}

		if(t == 2){
			if(kbd.ptr.ref != 0 && mbuf[0] != 0)
				emouseput(mbuf, strlen(mbuf));
			continue;
		}
	}
	/* not reached */
}

#endif

#ifdef __linux__
extern int readconsoleevent(int *key, char *mbuf, int mn);
extern void enableconsolemouse(void);
extern void disableconsolemouse(void);

static void
linuxemouseput(char *buf, int n)
{
	if(emouseq == nil || n <= 0)
		return;
	qproduce(emouseq, buf, n);
}

static void
processlinuxkey(int k)
{
	int nb;
	Rune r;
	char b;
	char ubuf[UTFmax];

	if(k < 0)
		return;

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
				return;
			if(kbd.raw == 0)
				write(1, ubuf, nb);
			qproduce(kbdq, ubuf, nb);
		}
	}
}

/*
 * Linux console input dispatcher.
 *
 * Linux uses the newer host console event reader from emu/Linux/os.c.
 * Keep all Linux-specific queue reopening/wakeup behaviour out of the
 * MinGW path.
 */
void
linuxkbdslave(void *a)
{
	int t, k;
	char mbuf[128];

	USED(a);

	for(;;){
		k = -1;
		mbuf[0] = 0;

		t = readconsoleevent(&k, mbuf, sizeof(mbuf));

		if(t == 1){
			processlinuxkey(k);
			continue;
		}

		if(t == 2){
			if(kbd.ptr.ref != 0 && mbuf[0] != 0)
				linuxemouseput(mbuf, strlen(mbuf));
			continue;
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
	int r;

	c = devopen(c, omode, contab, nelem(contab), devgen);
	switch((ulong)c->qid.path) {
	case Qconsctl:
		incref(&kbd.ctl);
		break;

	case Qemouse:
#ifdef __MINGW32__
		if(incref(&kbd.ptr) == 1){
			qflush(emouseq);
			enableconsolemouse();
		}
#elif defined(__linux__)
		r = incref(&kbd.ptr);
		if(r == 1){
			qreopen(emouseq);
			qflush(emouseq);
			enableconsolemouse();
		}
#else
		incref(&kbd.ptr);
#endif
		break;

	case Qekeyboard:
#ifdef __MINGW32__
		incref(&kbd.ekbd);
		qflush(ekbdq);
		qflush(kbdq);
#elif defined(__linux__)
		r = incref(&kbd.ekbd);
		if(r == 1)
			qreopen(ekbdq);
		qflush(ekbdq);
#else
		if(incref(&kbd.ekbd) == 1)
			qflush(ekbdq);
#endif
		break;

	case Qscancode:
		qlock(&kbd.gq);
		if(gkscanq != nil || gkscanid[0] == '\0') {
			qunlock(&kbd.q);
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
		if(decref(&kbd.ctl) == 0){
			kbd.raw = 0;
#ifdef __linux__
			qflush(ekbdq);
			wakeekbdreaders();

			if(kbd.ptr.ref == 0){
				qflush(emouseq);
				wakeemousereaders();
			}
#endif
		}
		break;

	case Qemouse:
		if(decref(&kbd.ptr) == 0){
#ifdef __MINGW32__
			disableconsolemouse();
			qflush(emouseq);
#elif defined(__linux__)
			disableconsolemouse();
			qflush(emouseq);
			wakeemousereaders();
#endif
		}
		break;

	case Qekeyboard:
		if(decref(&kbd.ekbd) == 0){
			qflush(ekbdq);
#ifdef __linux__
			wakeekbdreaders();
#endif
#ifdef __MINGW32__
			qflush(kbdq);
#endif
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
#ifdef __linux__
				qreopen(ekbdq);
				qreopen(emouseq);
#endif
				/* clumsy hack - wake up reader */
				ch = 0;
				qwrite(kbdq, &ch, 1);
			} else if(strncmp(buf, "rawoff", 6) == 0){
				kbd.raw = 0;
#ifdef __linux__
				qflush(ekbdq);
				wakeekbdreaders();

				if(kbd.ptr.ref == 0){
					qflush(emouseq);
					wakeemousereaders();
				}
#endif
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
		cleanexit(e);
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