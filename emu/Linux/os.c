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

static int
parsecsikey(int lead, int first)
{
	int c, i, n;
	char seq[32];
	int nums[2], nnum, v, have;
	int mod;
	char final;

	/*
	 * Modifier bitmask tables indexed by mod (0..7):
	 *   mod = vtmod_param - 1, where vtmod_param is the VT modifier parameter:
	 *     1=none, 2=Shift, 3=Alt, 4=Alt+Shift, 5=Ctrl, 6=Ctrl+Shift,
	 *     7=Ctrl+Alt, 8=Ctrl+Alt+Shift
	 *   bit0=Shift, bit1=Alt, bit2=Ctrl
	 */
	static const int kftab[8] = {
		KF, KFShift, KFAlt, KFAltShift,
		KFCtrl, KFCtrlShift, KFCtrlAlt, KFCtrlAltShift
	};
	static const int vwtab[8] = {
		View, ViewShift, ViewAlt, ViewAltShift,
		ViewCtrl, ViewCtrlShift, ViewCtrlAlt, ViewCtrlAltShift
	};
	static const int instab[8] = {
		Ins, ShiftIns, AltIns, AltShiftIns,
		CtrlIns, CtrlShiftIns, CtrlAltIns, CtrlAltShiftIns
	};
	static const int deltab[8] = {
		Del, ShiftDel, AltDel, AltShiftDel,
		CtrlDel, CtrlShiftDel, CtrlAltDel, CtrlAltShiftDel
	};

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

	if(n < 2)
		return No;

	final = seq[n-1];

	/* Parse up to two semicolon-separated numeric params from seq[1..n-2]. */
	nnum = 0;
	v = 0;
	have = 0;
	for(i = 1; i < n-1; i++){
		c = (unsigned char)seq[i];
		if(c >= '0' && c <= '9'){
			v = v * 10 + c - '0';
			have = 1;
		} else if(c == ';'){
			if(nnum < 2)
				nums[nnum++] = have ? v : 1;
			v = 0;
			have = 0;
		}
	}
	if(have && nnum < 2)
		nums[nnum++] = v;
	/* Ensure both slots are filled with defaults. */
	if(nnum < 1)
		nums[0] = 1;
	if(nnum < 2)
		nums[1] = 1;

	/*
	 * VT modifier param nums[1]: 1=none, 2=Shift, 3=Alt, 4=Alt+Shift,
	 * 5=Ctrl, 6=Ctrl+Shift, 7=Ctrl+Alt, 8=Ctrl+Alt+Shift.
	 * mod = nums[1] - 1 gives the bitmask index into the tables above.
	 */
	mod = (nums[1] >= 1 && nums[1] <= 8) ? (nums[1] - 1) : 0;

	if(lead == '['){
		switch(final){
		case 'A':
			return vwtab[mod] | (Up-View);
		case 'B':
			return vwtab[mod] | (Down-View);
		case 'C':
			return vwtab[mod] | (Right-View);
		case 'D':
			return vwtab[mod] | (Left-View);
		case 'F':
			return vwtab[mod] | (End-View);
		case 'H':
			return vwtab[mod] | (Home-View);
		case 'Z':
			return BackTab;
		case 'P':
			return kftab[mod] | 1;
		case 'Q':
			return kftab[mod] | 2;
		case 'R':
			return kftab[mod] | 3;
		case 'S':
			return kftab[mod] | 4;
		case '~':
			switch(nums[0]){
			case 1:
			case 7:
				return vwtab[mod] | (Home-View);
			case 2:
				return instab[mod];
			case 3:
				return deltab[mod];
			case 4:
			case 8:
				return vwtab[mod] | (End-View);
			case 5:
				return vwtab[mod] | (Pgup-View);
			case 6:
				return vwtab[mod] | (Pgdown-View);
			case 15:
				return kftab[mod] | 5;
			case 17:
				return kftab[mod] | 6;
			case 18:
				return kftab[mod] | 7;
			case 19:
				return kftab[mod] | 8;
			case 20:
				return kftab[mod] | 9;
			case 21:
				return kftab[mod] | 10;
			case 23:
				return kftab[mod] | 11;
			case 24:
				return kftab[mod] | 12;
			}
			break;
		}
	}else if(lead == 'O'){
		if(nnum <= 1){
			/* Plain SS3: direct letter final (e.g. ESC O P = F1). */
			switch(final){
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
		}else{
			/* SS3 with modifier params (e.g. ESC O 1;3P = Alt+F1). */
			switch(final){
			case 'A':
				return vwtab[mod] | (Up-View);
			case 'B':
				return vwtab[mod] | (Down-View);
			case 'C':
				return vwtab[mod] | (Right-View);
			case 'D':
				return vwtab[mod] | (Left-View);
			case 'F':
				return vwtab[mod] | (End-View);
			case 'H':
				return vwtab[mod] | (Home-View);
			case 'P':
				return kftab[mod] | 1;
			case 'Q':
				return kftab[mod] | 2;
			case 'R':
				return kftab[mod] | 3;
			case 'S':
				return kftab[mod] | 4;
			}
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

int
osconsinfo(char *buf, int n)
{
	struct winsize ws;
	int cols, rows;
	int ok;
	int utf8;
	char *source;
	const char *v;

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

	/*
	 * Detect UTF-8 capability from the process locale environment.
	 * Precedence: LC_ALL > LC_CTYPE > LANG (standard POSIX locale order).
	 * We look for "UTF-8" or "UTF8" (locale encoding fields always use
	 * this upper-case form; strstr avoids any pointer arithmetic).
	 * This reflects actual terminal/locale configuration, not self-set state.
	 */
	utf8 = 0;
	v = getenv("LC_ALL");
	if(v == nil || *v == '\0')
		v = getenv("LC_CTYPE");
	if(v == nil || *v == '\0')
		v = getenv("LANG");
	if(v != nil && *v != '\0'){
		if(strstr(v, "UTF-8") != nil || strstr(v, "UTF8") != nil ||
		   strstr(v, "utf-8") != nil || strstr(v, "utf8") != nil)
			utf8 = 1;
	}

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
		utf8,
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