#include	<sys/types.h>
#include	<time.h>
#include	<termios.h>
#include	<signal.h>
#include 	<pwd.h>
#include	<sched.h>
#include	<sys/resource.h>
#include	<sys/select.h>
#include	<sys/wait.h>
#include	<sys/time.h>
#include	<sys/ioctl.h>

#include	<errno.h>
#include	<stdint.h>

#include	"dat.h"
#include	"fns.h"
#include	"error.h"
#include	"keyboard.h"

#include <semaphore.h>

#include	<raise.h>

/* glibc 2.3.3-NTPL messes up getpid() by trying to cache the result, so we'll do it ourselves */
#include	<sys/syscall.h>
#define	getpid()	syscall(SYS_getpid)

enum
{
	DELETE	= 0x7f,
	CTRLC	= 'C'-'@',
	NSTACKSPERALLOC = 16,
	X11STACK=	256*1024,

	ConEventKey = 1,
	ConEventMouse = 2
};

char *hosttype = "Linux";
#if defined(__x86_64__)
char *cputype = "amd64";
#elif defined(__aarch64__)
char *cputype = "arm64";
#elif defined(__i386__)
char *cputype = "386";
#elif defined(__arm__)
char *cputype = "arm";
#elif defined(__mips__)
char *cputype = "mips";
#elif defined(__powerpc__) || defined(__powerpc64__)
char *cputype = "power";
#else
char *cputype;
#endif

typedef sem_t	Sem;

extern int dflag;

int	gidnobody = -1;
int	uidnobody = -1;
static struct 	termios tinit;
static int mousemodeactive = 0;

void enableconsolemouse(void);
void disableconsolemouse(void);

static void
sysfault(char *what, void *addr)
{
	char buf[64];

	snprint(buf, sizeof(buf), "sys: %s%#llux", what, addr);
	disfault(nil, buf);
}

static void
trapILL(int signo, siginfo_t *si, void *a)
{
	USED(signo);
	USED(a);
	sysfault("illegal instruction pc=", si->si_addr);
}

static int
isnilref(siginfo_t *si)
{
	return si != 0 && (si->si_addr == (void*)~(uintptr_t)0 || (uintptr_t)si->si_addr < 512);
}

static void
trapmemref(int signo, siginfo_t *si, void *a)
{
	USED(a);
	if(isnilref(si))
		disfault(nil, exNilref);
	else if(signo == SIGBUS)
		sysfault("bad address addr=", si->si_addr);
	else
		sysfault("segmentation violation addr=", si->si_addr);
}

static void
trapFPE(int signo, siginfo_t *si, void *a)
{
	char buf[64];

	USED(signo);
	USED(a);
	snprint(buf, sizeof(buf), "sys: fp: exception status=%.4lux pc=%#p", getfsr(), si->si_addr);
	disfault(nil, buf);
}

static void
trapUSR1(int signo)
{
	int intwait;

	USED(signo);

	intwait = up->intwait;
	up->intwait = 0;

	if(up->type != Interp)
		return;

	if(intwait == 0)
		disfault(nil, Eintr);
}

void
oslongjmp(void *regs, osjmpbuf env, int val)
{
	USED(regs);
	siglongjmp(env, val);
}

static void
termset(void)
{
	struct termios t;

	tcgetattr(0, &t);
	tinit = t;
	t.c_lflag &= ~(ICANON|ECHO|ISIG);
	t.c_cc[VMIN] = 1;
	t.c_cc[VTIME] = 0;
	tcsetattr(0, TCSANOW, &t);
}

static void
termrestore(void)
{
	disableconsolemouse();
	tcsetattr(0, TCSANOW, &tinit);
}

void
cleanexit(int x)
{
	USED(x);

	if(up->intwait) {
		up->intwait = 0;
		return;
	}

	if(dflag == 0)
		termrestore();

	exit(0);
}

void
osreboot(char *file, char **argv)
{
	if(dflag == 0)
		termrestore();
	execvp(file, argv);
	error("reboot failure");
}

void
libinit(char *imod)
{
	struct sigaction act;
	struct passwd *pw;
	Proc *p;
	char sys[64];

	setsid();

	gethostname(sys, sizeof(sys));
	kstrdup(&ossysname, sys);
	pw = getpwnam("nobody");
	if(pw != nil) {
		uidnobody = pw->pw_uid;
		gidnobody = pw->pw_gid;
	}

	if(dflag == 0)
		termset();

	memset(&act, 0, sizeof(act));
	act.sa_handler = trapUSR1;
	sigaction(SIGUSR1, &act, nil);

	act.sa_handler = SIG_IGN;
	sigaction(SIGCHLD, &act, nil);

	signal(SIGPIPE, SIG_IGN);
	if(signal(SIGTERM, SIG_IGN) != SIG_IGN)
		signal(SIGTERM, cleanexit);
	if(signal(SIGINT, SIG_IGN) != SIG_IGN)
		signal(SIGINT, cleanexit);

	if(sflag == 0) {
		act.sa_flags = SA_SIGINFO;
		act.sa_sigaction = trapILL;
		sigaction(SIGILL, &act, nil);
		act.sa_sigaction = trapFPE;
		sigaction(SIGFPE, &act, nil);
		act.sa_sigaction = trapmemref;
		sigaction(SIGBUS, &act, nil);
		sigaction(SIGSEGV, &act, nil);
		act.sa_flags &= ~SA_SIGINFO;
	}

	p = newproc();
	kprocinit(p);

	pw = getpwuid(getuid());
	if(pw != nil)
		kstrdup(&eve, pw->pw_name);
	else
		print("cannot getpwid\n");

	p->env->uid = getuid();
	p->env->gid = getgid();

	emuinit(imod);
}

int
readkbd(void)
{
	int n;
	char buf[1];

	n = read(0, buf, sizeof(buf));
	if(n < 0)
		print("keyboard close (n=%d, %s)\n", n, strerror(errno));
	if(n <= 0)
		pexit("keyboard thread", 0);

	switch(buf[0]) {
	case '\r':
		buf[0] = '\n';
		break;
	case DELETE:
		buf[0] = 'H' - '@';
		break;
	case CTRLC:
		cleanexit(0);
		break;
	}
	return buf[0];
}

static int
readkbdchar(int *cp, int timeoutms)
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
	if(n < 0){
		if(errno == EINTR)
			return 0;
		print("keyboard read error (n=%d, %s)\n", n, strerror(errno));
		pexit("keyboard thread", 0);
		return 0;
	}
	if(n <= 0)
		pexit("keyboard thread", 0);

	*cp = (uchar)ch;
	return 1;
}

static int
readkbdrune(int c0)
{
	int c, n;
	char buf[UTFmax];
	Rune r;

	buf[0] = c0;
	n = 1;
	while(n < UTFmax && !fullrune(buf, n)){
		if(!readkbdchar(&c, -1))
			return c0;
		buf[n++] = c;
	}

	if(chartorune(&r, buf) <= 0)
		return c0;
	return r;
}

/*
 * Map a VT extended modifier parameter and a base navigation key code
 * to the appropriate modifier+key constant.
 *
 * VT modifier encoding: N-1 encodes bit0=Shift, bit1=Alt, bit2=Ctrl.
 * N==1 means no modifier (plain key).
 * Only the three primary single-modifier cases are mapped to dedicated
 * key codes; combined or unknown modifiers fall back to the base key.
 */
static int
applycsikeymod(int vtmod, int basekey)
{
	int m;

	m = vtmod - 1;	/* normalise: 0=none, 1=Shift, 2=Alt, 4=Ctrl */

	if(m <= 0)
		return basekey;

	if(m == 1){	/* Shift only */
		switch(basekey){
		case Home:	return ShiftHome;
		case End:	return ShiftEnd;
		case Up:	return ShiftUp;
		case Down:	return ShiftDown;
		case Left:	return ShiftLeft;
		case Right:	return ShiftRight;
		case Pgup:	return ShiftPgup;
		case Pgdown:	return ShiftPgdown;
		}
	}

	if(m == 4){	/* Ctrl only */
		switch(basekey){
		case Home:	return CtrlHome;
		case End:	return CtrlEnd;
		case Up:	return CtrlUp;
		case Down:	return CtrlDown;
		case Left:	return CtrlLeft;
		case Right:	return CtrlRight;
		case Pgup:	return CtrlPgup;
		case Pgdown:	return CtrlPgdown;
		}
	}

	if(m == 2){	/* Alt only */
		switch(basekey){
		case Home:	return AltHome;
		case End:	return AltEnd;
		case Up:	return AltUp;
		case Down:	return AltDown;
		case Left:	return AltLeft;
		case Right:	return AltRight;
		case Pgup:	return AltPgup;
		case Pgdown:	return AltPgdown;
		}
	}

	/* Combined or unrecognised modifier: return base key unchanged */
	return basekey;
}

static int
parsecsikey(int lead, int first)
{
	int c, i, n, num, mod;
	char seq[32];

	seq[0] = lead;
	n = 1;

	if(first >= 0)
		seq[n++] = first;

	while(n < (int)sizeof(seq)-1){
		if(seq[n-1] >= '@' && seq[n-1] <= '~')
			break;
		if(!readkbdchar(&c, 25))
			break;
		seq[n++] = c;
		if(c >= '@' && c <= '~')
			break;
	}
	seq[n] = 0;

	/*
	 * Extract VT extended modifier parameter from the sequence.
	 * Extended sequences carry a ';' separator followed by a modifier digit
	 * before the final character, e.g. ESC [ 1 ; 5 A for Ctrl+Up.
	 * VT modifier N encodes: N-1 bits: bit0=Shift, bit1=Alt, bit2=Ctrl.
	 * mod==1 means no modifier (plain key).
	 */
	mod = 1;
	for(i = 1; i < n-1; i++){
		if(seq[i] == ';'){
			mod = 0;
			i++;
			while(i < n-1 && seq[i] >= '0' && seq[i] <= '9'){
				mod = mod*10 + seq[i] - '0';
				i++;
			}
			if(mod == 0)
				mod = 1;
			break;
		}
	}

	if(lead == '['){
		switch(seq[n-1]){
		case 'A':
			return applycsikeymod(mod, Up);
		case 'B':
			return applycsikeymod(mod, Down);
		case 'C':
			return applycsikeymod(mod, Right);
		case 'D':
			return applycsikeymod(mod, Left);
		case 'F':
			return applycsikeymod(mod, End);
		case 'H':
			return applycsikeymod(mod, Home);
		case 'Z':
			return BackTab;
		case '~':
			num = 0;
			for(i = 1; i < n-1 && seq[i] >= '0' && seq[i] <= '9'; i++)
				num = num*10 + seq[i] - '0';
			switch(num){
			case 1:
			case 7:
				return applycsikeymod(mod, Home);
			case 2:
				return applycsikeymod(mod, Ins);
			case 3:
				return applycsikeymod(mod, Del);
			case 4:
			case 8:
				return applycsikeymod(mod, End);
			case 5:
				return applycsikeymod(mod, Pgup);
			case 6:
				return applycsikeymod(mod, Pgdown);
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
		switch(seq[1]){
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

	return No;
}

static int
mousemods(int cb)
{
	int m;

	m = 0;
	if(cb & 4)
		m |= 1;
	if(cb & 16)
		m |= 2;
	if(cb & 8)
		m |= 4;

	return m;
}

static int
mousebuttons(int cb, int release)
{
	int b;

	if(cb & 64){
		if(cb & 1)
			return 16;
		return 8;
	}

	if(release)
		return 0;

	b = cb & 3;
	if(b == 0)
		return 1;
	if(b == 1)
		return 4;
	if(b == 2)
		return 2;

	return 0;
}

static int
parsesgrmouse(char *mbuf, int mn)
{
	int c, nums[3], nnum, v, have, final, x, y, b, mods;

	nnum = 0;
	v = 0;
	have = 0;
	final = 0;

	for(;;){
		if(!readkbdchar(&c, 25))
			return 0;

		if(c >= '0' && c <= '9'){
			v = v*10 + c - '0';
			have = 1;
			continue;
		}

		if(c == ';'){
			if(!have || nnum >= 3)
				return 0;
			nums[nnum++] = v;
			v = 0;
			have = 0;
			continue;
		}

		if(c == 'M' || c == 'm'){
			if(!have || nnum >= 3)
				return 0;
			nums[nnum++] = v;
			final = c;
			break;
		}

		return 0;
	}

	if(nnum != 3)
		return 0;

	x = nums[1] - 1;
	y = nums[2] - 1;
	if(x < 0)
		x = 0;
	if(y < 0)
		y = 0;

	b = mousebuttons(nums[0], final == 'm');
	mods = mousemods(nums[0]);

	snprint(mbuf, mn, "m %d %d %d %d\n", x, y, b, mods);
	return 1;
}

int
readconsoleevent(int *key, char *mbuf, int mn)
{
	int c, k, first;

	for(;;){
		if(!readkbdchar(&c, -1))
			continue;

		switch(c){
		case '\r':
			if(key != nil)
				*key = '\n';
			return ConEventKey;

		case DELETE:
			if(key != nil)
				*key = '\b';
			return ConEventKey;

		case CTRLC:
			cleanexit(0);
			if(key != nil)
				*key = -1;
			return ConEventKey;

		case Esc:
			if(!readkbdchar(&c, 25)){
				if(key != nil)
					*key = Esc;
				return ConEventKey;
			}

			if(c == '['){
				if(!readkbdchar(&first, 25)){
					if(key != nil)
						*key = Esc;
					return ConEventKey;
				}

				if(first == '<'){
					if(mbuf != nil && mn > 0 && parsesgrmouse(mbuf, mn))
						return ConEventMouse;
					if(key != nil)
						*key = Esc;
					return ConEventKey;
				}

				k = parsecsikey('[', first);
				if(key != nil)
					*key = k != No ? k : Esc;
				return ConEventKey;
			}

			if(c == 'O'){
				if(!readkbdchar(&first, 25)){
					if(key != nil)
						*key = Esc;
					return ConEventKey;
				}
				k = parsecsikey('O', first);
				if(key != nil)
					*key = k != No ? k : Esc;
				return ConEventKey;
			}

			if((c & 0x80) != 0){
				if(key != nil)
					*key = readkbdrune(c);
				return ConEventKey;
			}

			if(key != nil)
				*key = APP | c;
			return ConEventKey;
		}

		if((c & 0x80) != 0)
			c = readkbdrune(c);

		if(key != nil)
			*key = c;
		return ConEventKey;
	}
}

int
readekbd(void)
{
	int t, k;
	char mbuf[128];

	for(;;){
		k = -1;
		t = readconsoleevent(&k, mbuf, sizeof(mbuf));
		if(t == ConEventKey)
			return k;
	}
}

void
enableconsolemouse(void)
{
	static char seq[] = "\033[?1003h\033[?1006h";

	if(mousemodeactive)
		return;

	write(1, seq, strlen(seq));
	mousemodeactive = 1;
}

void
disableconsolemouse(void)
{
	static char seq[] = "\033[?1006l\033[?1003l\033[?1002l\033[?1000l";

	if(!mousemodeactive)
		return;

	write(1, seq, strlen(seq));
	mousemodeactive = 0;
}

int
reademouse(char *buf, int n)
{
	int t, k;
	char mbuf[128];

	if(buf == nil || n <= 0)
		return -1;

	for(;;){
		k = -1;
		t = readconsoleevent(&k, mbuf, sizeof(mbuf));
		if(t == ConEventMouse)
			return snprint(buf, n, "%s", mbuf);
	}
}

long
osmillisec(void)
{
	static long sec0 = 0, usec0;
	struct timeval t;

	if(gettimeofday(&t,(struct timezone*)0)<0)
		return 0;

	if(sec0 == 0) {
		sec0 = t.tv_sec;
		usec0 = t.tv_usec;
	}
	return (t.tv_sec-sec0)*1000+(t.tv_usec-usec0+500)/1000;
}

/*
 * Detect whether the host locale advertises UTF-8 encoding.
 * Checks LC_ALL, LC_CTYPE and LANG in priority order.
 * Returns 1 if any of them contains "UTF-8", "UTF8" or "utf8".
 * Returns 0 when no locale variable is set or none advertises UTF-8,
 * so that /dev/consinfo reports a safe fallback rather than lying.
 */
static int
isutf8locale(void)
{
	char *s;

	s = getenv("LC_ALL");
	if(s == nil || *s == '\0')
		s = getenv("LC_CTYPE");
	if(s == nil || *s == '\0')
		s = getenv("LANG");
	if(s == nil || *s == '\0')
		return 0;

	return strstr(s, "UTF-8") != nil
		|| strstr(s, "UTF8") != nil
		|| strstr(s, "utf8") != nil;
}

int
osconsinfo(char *buf, int n)
{
	struct winsize ws;
	int cols, rows;
	int ok;
	char *source;

	if(buf == nil || n <= 0)
		return -1;

	cols = 80;
	rows = 24;
	ok = 0;
	source = "fallback-linux";

	memset(&ws, 0, sizeof ws);

	if(ioctl(1, TIOCGWINSZ, &ws) == 0 && ws.ws_col > 0 && ws.ws_row > 0){
		cols = ws.ws_col;
		rows = ws.ws_row;
		ok = 1;
		source = "linux-ioctl-stdout";
	}else{
		memset(&ws, 0, sizeof ws);
		if(ioctl(0, TIOCGWINSZ, &ws) == 0 && ws.ws_col > 0 && ws.ws_row > 0){
			cols = ws.ws_col;
			rows = ws.ws_row;
			ok = 1;
			source = "linux-ioctl-stdin";
		}else{
			memset(&ws, 0, sizeof ws);
			if(ioctl(2, TIOCGWINSZ, &ws) == 0 && ws.ws_col > 0 && ws.ws_row > 0){
				cols = ws.ws_col;
				rows = ws.ws_row;
				ok = 1;
				source = "linux-ioctl-stderr";
			}
		}
	}

	if(cols <= 0)
		cols = 80;
	if(rows <= 0)
		rows = 24;

	return snprint(buf, n,
		"%d %d\n"
		"cols=%d\n"
		"rows=%d\n"
		"pixelwidth=%d\n"
		"pixelheight=%d\n"
		"vt=1\n"
		"utf8=%d\n"
		"colors=%d\n"
		"truecolor=%d\n"
		"source=%s\n"
		"ok=%d\n",
		cols, rows,
		cols, rows,
		(int)ws.ws_xpixel,
		(int)ws.ws_ypixel,
		isutf8locale(),
		16777216,
		1,
		source,
		ok);
}

vlong
osnsec(void)
{
	struct timeval t;

	gettimeofday(&t, nil);
	return (vlong)t.tv_sec*1000000000L + t.tv_usec*1000;
}

vlong
osusectime(void)
{
	struct timeval t;
 
	gettimeofday(&t, nil);
	return (vlong)t.tv_sec * 1000000 + t.tv_usec;
}

int
osmillisleep(ulong milsec)
{
	struct  timespec time;

	time.tv_sec = milsec/1000;
	time.tv_nsec= (milsec%1000)*1000000;
	nanosleep(&time, NULL);
	return 0;
}

int
limbosleep(ulong milsec)
{
	return osmillisleep(milsec);
}