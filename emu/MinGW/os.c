#define Unknown win_Unknown
#define UNICODE
#include	<windows.h>
#include <winbase.h>
#include	<winsock.h>
#undef Unknown
#include	<excpt.h>
#include	"dat.h"
#include	"fns.h"
#include	"error.h"
#include "keyboard.h"

#include	"r16.h"

#ifndef ENABLE_VIRTUAL_TERMINAL_PROCESSING
#define ENABLE_VIRTUAL_TERMINAL_PROCESSING 0x0004
#endif

#ifndef DISABLE_NEWLINE_AUTO_RETURN
#define DISABLE_NEWLINE_AUTO_RETURN 0x0008
#endif

int	SYS_SLEEP = 2;
int SOCK_SELECT = 3;
#define	MAXSLEEPERS	1500

extern	int	cflag;

DWORD	PlatformId;
DWORD	consolestate;
static	char*	path;
static HANDLE conh = INVALID_HANDLE_VALUE;
static HANDLE kbdh = INVALID_HANDLE_VALUE;
static HANDLE errh = INVALID_HANDLE_VALUE;

static int vtoutputactive = 0;
static UINT hostinputcp = 0;
static UINT hostoutputcp = 0;
static int consolecpsaved = 0;
static int consolecpchanged = 0;

static DWORD mouseconsolestate = 0;
static int mousemodesaved = 0;
static int mousemodeactive = 0;

static DWORD consoleoutstate = 0;
static int consoleoutstatesaved = 0;

enum {
	ConNorm,
	ConEsc,
	ConCsi
};

enum {
	ConEventKey = 1,
	ConEventMouse = 2
};

typedef struct ConParser ConParser;
struct ConParser
{
	int state;
	char buf[32];
	int n;

	int havsaved;
	SHORT savedx;
	SHORT savedy;

	int attrinit;
	WORD defattr;
};

static ConParser outparser;
static ConParser errparser;

enum {
	UTF8CP = 65001
};

static void
saveconsolecp(void)
{
	if(kbdh == INVALID_HANDLE_VALUE)
		return;

	hostinputcp = GetConsoleCP();
	hostoutputcp = GetConsoleOutputCP();

	if(hostinputcp != 0 && hostoutputcp != 0)
		consolecpsaved = 1;
}

static void
setutf8consolecp(void)
{
	if(!consolecpsaved)
		return;

	if(hostinputcp == UTF8CP && hostoutputcp == UTF8CP)
		return;

	if(SetConsoleCP(UTF8CP) && SetConsoleOutputCP(UTF8CP))
		consolecpchanged = 1;
	else{
		if(hostinputcp != 0)
			SetConsoleCP(hostinputcp);
		if(hostoutputcp != 0)
			SetConsoleOutputCP(hostoutputcp);
		consolecpchanged = 0;
	}
}

static void
enableconsolevtoutput(void)
{
	DWORD mode, newmode;

	vtoutputactive = 0;

	if(conh == INVALID_HANDLE_VALUE || conh == NULL)
		return;

	if(!GetConsoleMode(conh, &mode))
		return;

	if(!consoleoutstatesaved){
		consoleoutstate = mode;
		consoleoutstatesaved = 1;
	}

	newmode = mode;
	newmode |= ENABLE_PROCESSED_OUTPUT;
	newmode |= ENABLE_VIRTUAL_TERMINAL_PROCESSING;
	newmode &= ~DISABLE_NEWLINE_AUTO_RETURN;

	if(SetConsoleMode(conh, newmode)){
		vtoutputactive = 1;
		return;
	}

	newmode = mode;
	newmode |= ENABLE_PROCESSED_OUTPUT;
	newmode &= ~DISABLE_NEWLINE_AUTO_RETURN;
	SetConsoleMode(conh, newmode);
}

static void
restoreconsolecp(void)
{
	if(!consolecpsaved || !consolecpchanged)
		return;

	if(hostinputcp != 0)
		SetConsoleCP(hostinputcp);
	if(hostoutputcp != 0)
		SetConsoleOutputCP(hostoutputcp);

	consolecpchanged = 0;
}

static int
isconsolehandle(HANDLE h)
{
	CONSOLE_SCREEN_BUFFER_INFO info;

	if(h == INVALID_HANDLE_VALUE || h == NULL)
		return 0;
	if(!GetConsoleScreenBufferInfo(h, &info))
		return 0;
	return 1;
}

static int
consolegetinfo(HANDLE h, CONSOLE_SCREEN_BUFFER_INFO *info)
{
	if(!GetConsoleScreenBufferInfo(h, info))
		return 0;
	return 1;
}

static void
consolesetpos(HANDLE h, SHORT x, SHORT y)
{
	COORD p;
	CONSOLE_SCREEN_BUFFER_INFO info;

	if(!consolegetinfo(h, &info))
		return;

	if(x < 0)
		x = 0;
	if(y < 0)
		y = 0;
	if(x >= info.dwSize.X)
		x = info.dwSize.X - 1;
	if(y >= info.dwSize.Y)
		y = info.dwSize.Y - 1;

	p.X = x;
	p.Y = y;
	SetConsoleCursorPosition(h, p);
}

static void
consolemove(HANDLE h, int dx, int dy)
{
	CONSOLE_SCREEN_BUFFER_INFO info;
	SHORT x, y;

	if(!consolegetinfo(h, &info))
		return;

	x = info.dwCursorPosition.X + dx;
	y = info.dwCursorPosition.Y + dy;

	if(x < 0)
		x = 0;
	if(y < 0)
		y = 0;
	if(x >= info.dwSize.X)
		x = info.dwSize.X - 1;
	if(y >= info.dwSize.Y)
		y = info.dwSize.Y - 1;

	consolesetpos(h, x, y);
}

static void
consolehome(HANDLE h)
{
	consolesetpos(h, 0, 0);
}

static void
consoleclearscreen(HANDLE h)
{
	CONSOLE_SCREEN_BUFFER_INFO info;
	COORD home;
	DWORD n, nwritten;
	WORD attr;

	if(!consolegetinfo(h, &info))
		return;

	n = info.dwSize.X * info.dwSize.Y;
	home.X = 0;
	home.Y = 0;
	attr = info.wAttributes;

	FillConsoleOutputCharacter(h, ' ', n, home, &nwritten);
	FillConsoleOutputAttribute(h, attr, n, home, &nwritten);
	SetConsoleCursorPosition(h, home);
}

static void
consolecleartoeol(HANDLE h)
{
	CONSOLE_SCREEN_BUFFER_INFO info;
	COORD p;
	DWORD n, nwritten;
	WORD attr;

	if(!consolegetinfo(h, &info))
		return;

	p = info.dwCursorPosition;
	attr = info.wAttributes;
	n = info.dwSize.X - p.X;

	FillConsoleOutputCharacter(h, ' ', n, p, &nwritten);
	FillConsoleOutputAttribute(h, attr, n, p, &nwritten);
	SetConsoleCursorPosition(h, p);
}

static void
consoleclearline(HANDLE h)
{
	CONSOLE_SCREEN_BUFFER_INFO info;
	COORD p, start;
	DWORD n, nwritten;
	WORD attr;

	if(!consolegetinfo(h, &info))
		return;

	p = info.dwCursorPosition;
	start = p;
	start.X = 0;
	attr = info.wAttributes;
	n = info.dwSize.X;

	FillConsoleOutputCharacter(h, ' ', n, start, &nwritten);
	FillConsoleOutputAttribute(h, attr, n, start, &nwritten);
	SetConsoleCursorPosition(h, p);
}

static void
consolecleartobol(HANDLE h)
{
	CONSOLE_SCREEN_BUFFER_INFO info;
	COORD start, cur;
	DWORD n, nwritten;
	WORD attr;

	if(!consolegetinfo(h, &info))
		return;

	cur = info.dwCursorPosition;
	start = cur;
	start.X = 0;
	attr = info.wAttributes;
	n = cur.X + 1;

	FillConsoleOutputCharacter(h, ' ', n, start, &nwritten);
	FillConsoleOutputAttribute(h, attr, n, start, &nwritten);
	SetConsoleCursorPosition(h, cur);
}

static void
consoleclearfromcursor(HANDLE h)
{
	CONSOLE_SCREEN_BUFFER_INFO info;
	COORD p;
	DWORD n, nwritten;
	WORD attr;

	if(!consolegetinfo(h, &info))
		return;

	p = info.dwCursorPosition;
	attr = info.wAttributes;
	n = (info.dwSize.Y - p.Y - 1) * info.dwSize.X + (info.dwSize.X - p.X);

	FillConsoleOutputCharacter(h, ' ', n, p, &nwritten);
	FillConsoleOutputAttribute(h, attr, n, p, &nwritten);
	SetConsoleCursorPosition(h, p);
}

static void
consolecleartocursor(HANDLE h)
{
	CONSOLE_SCREEN_BUFFER_INFO info;
	COORD home, cur;
	DWORD n, nwritten;
	WORD attr;

	if(!consolegetinfo(h, &info))
		return;

	cur = info.dwCursorPosition;
	home.X = 0;
	home.Y = 0;
	attr = info.wAttributes;
	n = cur.Y * info.dwSize.X + cur.X + 1;

	FillConsoleOutputCharacter(h, ' ', n, home, &nwritten);
	FillConsoleOutputAttribute(h, attr, n, home, &nwritten);
	SetConsoleCursorPosition(h, cur);
}

static int
parse2params(ConParser *p, int *a, int *b, int defa, int defb)
{
	int i, v, seensemi, havev;

	*a = defa;
	*b = defb;

	if(p->n <= 0)
		return 1;

	v = 0;
	seensemi = 0;
	havev = 0;

	for(i = 0; i < p->n; i++){
		if(p->buf[i] >= '0' && p->buf[i] <= '9'){
			v = v * 10 + (p->buf[i] - '0');
			havev = 1;
			continue;
		}
		if(p->buf[i] == ';' && !seensemi){
			if(havev)
				*a = v;
			v = 0;
			havev = 0;
			seensemi = 1;
			continue;
		}
		return 0;
	}

	if(seensemi){
		if(havev)
			*b = v;
	}else if(havev){
		*a = v;
	}

	if(*a <= 0)
		*a = defa;
	if(*b <= 0)
		*b = defb;

	return 1;
}

static void
consolecup(HANDLE h, int row, int col)
{
	CONSOLE_SCREEN_BUFFER_INFO info;
	SHORT x, y;

	if(!consolegetinfo(h, &info))
		return;

	if(row <= 0)
		row = 1;
	if(col <= 0)
		col = 1;

	y = row - 1;
	x = col - 1;

	if(x >= info.dwSize.X)
		x = info.dwSize.X - 1;
	if(y >= info.dwSize.Y)
		y = info.dwSize.Y - 1;

	consolesetpos(h, x, y);
}

static void
consolecha(HANDLE h, int col)
{
	CONSOLE_SCREEN_BUFFER_INFO info;

	if(!consolegetinfo(h, &info))
		return;

	if(col <= 0)
		col = 1;

	consolesetpos(h, col - 1, info.dwCursorPosition.Y);
}

static void
consolenextline(HANDLE h, int n)
{
	CONSOLE_SCREEN_BUFFER_INFO info;
	SHORT y;

	if(!consolegetinfo(h, &info))
		return;

	if(n <= 0)
		n = 1;

	y = info.dwCursorPosition.Y + n;
	consolesetpos(h, 0, y);
}

static void
consoleprevline(HANDLE h, int n)
{
	CONSOLE_SCREEN_BUFFER_INFO info;
	SHORT y;

	if(!consolegetinfo(h, &info))
		return;

	if(n <= 0)
		n = 1;

	y = info.dwCursorPosition.Y - n;
	consolesetpos(h, 0, y);
}

static void
consolesavecurs(HANDLE h, ConParser *p)
{
	CONSOLE_SCREEN_BUFFER_INFO info;

	if(!consolegetinfo(h, &info))
		return;

	p->savedx = info.dwCursorPosition.X;
	p->savedy = info.dwCursorPosition.Y;
	p->havsaved = 1;
}

static void
consolerestorecurs(HANDLE h, ConParser *p)
{
	if(!p->havsaved)
		return;

	consolesetpos(h, p->savedx, p->savedy);
}

static WORD
ansi2fg(int n)
{
	switch(n){
	case 30: return 0;
	case 31: return FOREGROUND_RED;
	case 32: return FOREGROUND_GREEN;
	case 33: return FOREGROUND_RED | FOREGROUND_GREEN;
	case 34: return FOREGROUND_BLUE;
	case 35: return FOREGROUND_RED | FOREGROUND_BLUE;
	case 36: return FOREGROUND_GREEN | FOREGROUND_BLUE;
	case 37: return FOREGROUND_RED | FOREGROUND_GREEN | FOREGROUND_BLUE;

	case 90: return FOREGROUND_INTENSITY;
	case 91: return FOREGROUND_RED | FOREGROUND_INTENSITY;
	case 92: return FOREGROUND_GREEN | FOREGROUND_INTENSITY;
	case 93: return FOREGROUND_RED | FOREGROUND_GREEN | FOREGROUND_INTENSITY;
	case 94: return FOREGROUND_BLUE | FOREGROUND_INTENSITY;
	case 95: return FOREGROUND_RED | FOREGROUND_BLUE | FOREGROUND_INTENSITY;
	case 96: return FOREGROUND_GREEN | FOREGROUND_BLUE | FOREGROUND_INTENSITY;
	case 97: return FOREGROUND_RED | FOREGROUND_GREEN | FOREGROUND_BLUE | FOREGROUND_INTENSITY;
	}
	return (WORD)-1;
}

static WORD
ansi2bg(int n)
{
	switch(n){
	case 40: return 0;
	case 41: return BACKGROUND_RED;
	case 42: return BACKGROUND_GREEN;
	case 43: return BACKGROUND_RED | BACKGROUND_GREEN;
	case 44: return BACKGROUND_BLUE;
	case 45: return BACKGROUND_RED | BACKGROUND_BLUE;
	case 46: return BACKGROUND_GREEN | BACKGROUND_BLUE;
	case 47: return BACKGROUND_RED | BACKGROUND_GREEN | BACKGROUND_BLUE;

	case 100: return BACKGROUND_INTENSITY;
	case 101: return BACKGROUND_RED | BACKGROUND_INTENSITY;
	case 102: return BACKGROUND_GREEN | BACKGROUND_INTENSITY;
	case 103: return BACKGROUND_RED | BACKGROUND_GREEN | BACKGROUND_INTENSITY;
	case 104: return BACKGROUND_BLUE | BACKGROUND_INTENSITY;
	case 105: return BACKGROUND_RED | BACKGROUND_BLUE | BACKGROUND_INTENSITY;
	case 106: return BACKGROUND_GREEN | BACKGROUND_BLUE | BACKGROUND_INTENSITY;
	case 107: return BACKGROUND_RED | BACKGROUND_GREEN | BACKGROUND_BLUE | BACKGROUND_INTENSITY;
	}
	return (WORD)-1;
}

static void
consoleinitattr(HANDLE h, ConParser *p)
{
	CONSOLE_SCREEN_BUFFER_INFO info;

	if(p->attrinit)
		return;
	if(!consolegetinfo(h, &info))
		return;

	p->defattr = info.wAttributes;
	p->attrinit = 1;
}

static void
consoleapplysgr(HANDLE h, ConParser *p, int code)
{
	CONSOLE_SCREEN_BUFFER_INFO info;
	WORD attr, fg, bg, deffg, defbg;

	consoleinitattr(h, p);

	if(!consolegetinfo(h, &info))
		return;

	attr = info.wAttributes;

	deffg = p->defattr & (FOREGROUND_RED | FOREGROUND_GREEN | FOREGROUND_BLUE | FOREGROUND_INTENSITY);
	defbg = p->defattr & (BACKGROUND_RED | BACKGROUND_GREEN | BACKGROUND_BLUE | BACKGROUND_INTENSITY);

	if(code == 0){
		if(p->attrinit)
			SetConsoleTextAttribute(h, p->defattr);
		return;
	}

	if(code == 1){
		attr |= FOREGROUND_INTENSITY;
		SetConsoleTextAttribute(h, attr);
		return;
	}

	if(code == 22){
		attr &= ~FOREGROUND_INTENSITY;
		attr |= (deffg & FOREGROUND_INTENSITY);
		SetConsoleTextAttribute(h, attr);
		return;
	}

	if(code == 39){
		attr &= ~(FOREGROUND_RED | FOREGROUND_GREEN | FOREGROUND_BLUE | FOREGROUND_INTENSITY);
		attr |= deffg;
		SetConsoleTextAttribute(h, attr);
		return;
	}

	if(code == 49){
		attr &= ~(BACKGROUND_RED | BACKGROUND_GREEN | BACKGROUND_BLUE | BACKGROUND_INTENSITY);
		attr |= defbg;
		SetConsoleTextAttribute(h, attr);
		return;
	}

	fg = ansi2fg(code);
	if(fg != (WORD)-1){
		attr &= ~(FOREGROUND_RED | FOREGROUND_GREEN | FOREGROUND_BLUE | FOREGROUND_INTENSITY);
		attr |= fg;
		SetConsoleTextAttribute(h, attr);
		return;
	}

	bg = ansi2bg(code);
	if(bg != (WORD)-1){
		attr &= ~(BACKGROUND_RED | BACKGROUND_GREEN | BACKGROUND_BLUE | BACKGROUND_INTENSITY);
		attr |= bg;
		SetConsoleTextAttribute(h, attr);
		return;
	}
}

static void
consolehandlem(HANDLE h, ConParser *p)
{
	int i, v, havev;

	if(p->n == 0){
		consoleapplysgr(h, p, 0);
		return;
	}

	v = 0;
	havev = 0;

	for(i = 0; i < p->n; i++){
		if(p->buf[i] >= '0' && p->buf[i] <= '9'){
			v = v * 10 + (p->buf[i] - '0');
			havev = 1;
			continue;
		}
		if(p->buf[i] == ';'){
			if(havev)
				consoleapplysgr(h, p, v);
			else
				consoleapplysgr(h, p, 0);
			v = 0;
			havev = 0;
			continue;
		}
		return;
	}

	if(havev)
		consoleapplysgr(h, p, v);
	else
		consoleapplysgr(h, p, 0);
}

static void
consoleshowcursor(HANDLE h, int visible)
{
	CONSOLE_CURSOR_INFO ci;

	if(!GetConsoleCursorInfo(h, &ci))
		return;

	ci.bVisible = visible ? TRUE : FALSE;
	SetConsoleCursorInfo(h, &ci);
}

static void
consolehandlepriv(HANDLE h, ConParser *p, int set)
{
	if(p->n == 3 && p->buf[0] == '?' && p->buf[1] == '2' && p->buf[2] == '5'){
		consoleshowcursor(h, set);
		return;
	}
}

static int
csiparam(ConParser *p, int def)
{
	int i, v;

	if(p->n <= 0)
		return def;

	v = 0;
	for(i = 0; i < p->n; i++){
		if(p->buf[i] < '0' || p->buf[i] > '9')
			return def;
		v = v * 10 + (p->buf[i] - '0');
	}
	if(v <= 0)
		return def;
	return v;
}

static void
flushplain(HANDLE h, char *buf, int n, int *total)
{
	DWORD nwritten;

	if(n <= 0)
		return;

	if(WriteFile(h, buf, n, &nwritten, NULL))
		*total += (int)nwritten;
}

static int
consolewritevt(HANDLE h, const void *vbuf, uint n)
{
	char *buf;
	char out[512];
	int i, np;
	DWORD nwritten;

	if(h == INVALID_HANDLE_VALUE || h == NULL)
		return -1;

	buf = (char*)vbuf;
	np = 0;

	for(i = 0; i < (int)n; i++){
		if(buf[i] == '\n' && (i == 0 || buf[i-1] != '\r')){
			if(np >= (int)sizeof(out)){
				if(!WriteFile(h, out, np, &nwritten, NULL))
					return -1;
				np = 0;
			}
			out[np++] = '\r';
		}

		if(np >= (int)sizeof(out)){
			if(!WriteFile(h, out, np, &nwritten, NULL))
				return -1;
			np = 0;
		}
		out[np++] = buf[i];
	}

	if(np > 0){
		if(!WriteFile(h, out, np, &nwritten, NULL))
			return -1;
	}

	return (int)n;
}

static int
consolewrite(HANDLE h, ConParser *p, const void *vbuf, uint n)
{
	char *buf;
	char plain[256];
	int i, np, total, m;
	char ch;

	if(!isconsolehandle(h)){
		DWORD nwritten;
		if(!WriteFile(h, vbuf, n, &nwritten, NULL))
			return -1;
		return (int)nwritten;
	}

	if(vtoutputactive)
		return consolewritevt(h, vbuf, n);

	buf = (char*)vbuf;
	np = 0;
	total = 0;

	for(i = 0; i < (int)n; i++){
		ch = buf[i];

		switch(p->state){
		case ConNorm:
			if(ch == 0x1B){
				flushplain(h, plain, np, &total);
				np = 0;
				p->state = ConEsc;
				total++;
			}else{
				if(np >= (int)sizeof(plain)){
					flushplain(h, plain, np, &total);
					np = 0;
				}
				plain[np++] = ch;
			}
			break;

		case ConEsc:
			if(ch == '['){
				p->state = ConCsi;
				p->n = 0;
				total++;
			}else{
				p->state = ConNorm;
				if(np >= (int)sizeof(plain)){
					flushplain(h, plain, np, &total);
					np = 0;
				}
				plain[np++] = ch;
				total++;
			}
			break;

		case ConCsi:
			if((ch >= '0' && ch <= '9') || ch == ';' || ch == '?'){
				if(p->n < (int)sizeof(p->buf)-1)
					p->buf[p->n++] = ch;
				total++;
				break;
			}

			p->buf[p->n] = 0;
			m = csiparam(p, 1);

			switch(ch){
			case 'A':
				consolemove(h, 0, -m);
				break;
			case 'B':
				consolemove(h, 0, m);
				break;
			case 'C':
				consolemove(h, m, 0);
				break;
			case 'D':
				consolemove(h, -m, 0);
				break;
			case 'E':
				consolenextline(h, m);
				break;
			case 'F':
				consoleprevline(h, m);
				break;
			case 'G':
				consolecha(h, m);
				break;
			case 'H':
			case 'f':
			{
				int row, col;

				if(p->n == 0){
					consolehome(h);
				}else if(parse2params(p, &row, &col, 1, 1)){
					consolecup(h, row, col);
				}
				break;
			}
			case 'J':
				if(p->n == 0 || (p->n == 1 && p->buf[0] == '0'))
					consoleclearfromcursor(h);
				else if(p->n == 1 && p->buf[0] == '1')
					consolecleartocursor(h);
				else if(p->n == 1 && p->buf[0] == '2')
					consoleclearscreen(h);
				break;
			case 'K':
				if(p->n == 0 || (p->n == 1 && p->buf[0] == '0'))
					consolecleartoeol(h);
				else if(p->n == 1 && p->buf[0] == '1')
					consolecleartobol(h);
				else if(p->n == 1 && p->buf[0] == '2')
					consoleclearline(h);
				break;
			case 's':
				consolesavecurs(h, p);
				break;
			case 'u':
				consolerestorecurs(h, p);
				break;
			case 'm':
				consolehandlem(h, p);
				break;
			case 'h':
				consolehandlepriv(h, p, 1);
				break;
			case 'l':
				consolehandlepriv(h, p, 0);
				break;
			default:
				break;
			}

			p->state = ConNorm;
			p->n = 0;
			total++;
			break;

		default:
			p->state = ConNorm;
			p->n = 0;
			break;
		}
	}

	flushplain(h, plain, np, &total);
	return total;
}

static	int	donetermset = 0;
static	int sleepers = 0;

__thread Proc    *up;

HANDLE	ntfd2h(vlong);
vlong	nth2fd(HANDLE);
static void	termrestore(void);
char *hosttype = "Nt";
char *cputype = "386";

static void
pfree(Proc *p)
{
	Osenv *e;

	lock(&procs.l);
	if(p->prev)
		p->prev->next = p->next;
	else
		procs.head = p->next;

	if(p->next)
		p->next->prev = p->prev;
	else
		procs.tail = p->prev;
	unlock(&procs.l);

	e = p->env;
	if(e != nil) {
		closefgrp(e->fgrp);
		closepgrp(e->pgrp);
		closeegrp(e->egrp);
		closesigs(e->sigs);
	}
	free(e->user);
	free(p->prog);
	CloseHandle((HANDLE)p->os);
	free(p);
}

void
osblock(void)
{
	if(WaitForSingleObject((HANDLE)up->os, INFINITE) != WAIT_OBJECT_0)
		panic("osblock failed");
}

void
osready(Proc *p)
{
	if(SetEvent((HANDLE)p->os) == FALSE)
		panic("osready failed");
}

void
pexit(char *msg, int t)
{
	pfree(up);
	ExitThread(0);
}

LONG TrapHandler(LPEXCEPTION_POINTERS ureg);

__cdecl int
Exhandler(EXCEPTION_RECORD *rec, void *frame, CONTEXT *context, void *dcon)
{
	EXCEPTION_POINTERS ep;
	ep.ExceptionRecord = rec;
	ep.ContextRecord = context;
	TrapHandler(&ep);
	return ExceptionContinueExecution;
}

DWORD WINAPI
tramp(LPVOID p)
{
	up = p;
	up->func(up->arg);
	pexit("", 0);
	for(;;)
		panic("tramp");
	return 0;
}

void
kproc(char *name, void (*func)(void*), void *arg, int flags)
{
	DWORD h;
	Proc *p;
	Pgrp *pg;
	Fgrp *fg;
	Egrp *eg;

	p = newproc();
	if(p == nil)
		panic("out of kernel processes");
	p->os = CreateEvent(NULL, FALSE, FALSE, NULL);
	if(p->os == NULL)
		panic("can't allocate os event");
		
	if(flags & KPDUPPG) {
		pg = up->env->pgrp;
		incref(&pg->r);
		p->env->pgrp = pg;
	}
	if(flags & KPDUPFDG) {
		fg = up->env->fgrp;
		incref(&fg->r);
		p->env->fgrp = fg;
	}
	if(flags & KPDUPENVG) {
		eg = up->env->egrp;
		incref(&eg->r);
		p->env->egrp = eg;
	}

	p->env->ui = up->env->ui;
	kstrdup(&p->env->user, up->env->user);
	strcpy(p->text, name);

	p->func = func;
	p->arg = arg;

	lock(&procs.l);
	if(procs.tail != nil) {
		p->prev = procs.tail;
		procs.tail->next = p->next;
	}
	else {
		procs.head = p;
		p->prev = nil;
	}
	procs.tail = p;
	unlock(&procs.l);

	p->pid = (uvlong) CreateThread(0, 16384, tramp, p, 0, &h);
	if(p->pid <= 0)
		panic("ran out of  kernel processes");
}

#if(_WIN32_WINNT >= 0x0400)
void APIENTRY sleepintr(uvlong param)
{
}
#endif

void
oshostintr(Proc *p)
{
	if (p->syscall == SOCK_SELECT)
		return;
	p->intwait = 0;
#if(_WIN32_WINNT >= 0x0400)
	if(p->syscall == SYS_SLEEP) {
		QueueUserAPC(sleepintr, (HANDLE) p->pid, (DWORD) p->pid);
	}
#endif
}

void
oslongjmp(void *regs, osjmpbuf env, int val)
{
	USED(regs);
	longjmp(env, val);
}

int
readkbd(void)
{
	DWORD r;
	char buf[1];

	if(ReadFile(kbdh, buf, sizeof(buf), &r, 0) == FALSE)
		panic("keyboard fail");
	if (r == 0)
		panic("keyboard EOF");

	if (buf[0] == 0x03) {
		termrestore();
		ExitProcess(0);
	}
	if(buf[0] == '\r')
		buf[0] = '\n';
	return buf[0];
}

static int
keyeventcode(KEY_EVENT_RECORD *k, int *out)
{
	WCHAR wc;
	DWORD ctrl;
	int ch;

	if(k == nil || out == nil)
		return 0;

	if(!k->bKeyDown)
		return 0;

	ctrl = k->dwControlKeyState;

	switch(k->wVirtualKeyCode){
	case VK_LEFT:
		if(ctrl & SHIFT_PRESSED)
			*out = ShiftLeft;
		else if(ctrl & (LEFT_CTRL_PRESSED|RIGHT_CTRL_PRESSED))
			*out = CtrlLeft;
		else if(ctrl & (LEFT_ALT_PRESSED|RIGHT_ALT_PRESSED))
			*out = AltLeft;
		else
			*out = Left;
		return 1;
	case VK_RIGHT:
		if(ctrl & SHIFT_PRESSED)
			*out = ShiftRight;
		else if(ctrl & (LEFT_CTRL_PRESSED|RIGHT_CTRL_PRESSED))
			*out = CtrlRight;
		else if(ctrl & (LEFT_ALT_PRESSED|RIGHT_ALT_PRESSED))
			*out = AltRight;
		else
			*out = Right;
		return 1;
	case VK_UP:
		if(ctrl & SHIFT_PRESSED)
			*out = ShiftUp;
		else if(ctrl & (LEFT_CTRL_PRESSED|RIGHT_CTRL_PRESSED))
			*out = CtrlUp;
		else if(ctrl & (LEFT_ALT_PRESSED|RIGHT_ALT_PRESSED))
			*out = AltUp;
		else
			*out = Up;
		return 1;
	case VK_DOWN:
		if(ctrl & SHIFT_PRESSED)
			*out = ShiftDown;
		else if(ctrl & (LEFT_CTRL_PRESSED|RIGHT_CTRL_PRESSED))
			*out = CtrlDown;
		else if(ctrl & (LEFT_ALT_PRESSED|RIGHT_ALT_PRESSED))
			*out = AltDown;
		else
			*out = Down;
		return 1;
	case VK_HOME:
		if(ctrl & SHIFT_PRESSED)
			*out = ShiftHome;
		else if(ctrl & (LEFT_CTRL_PRESSED|RIGHT_CTRL_PRESSED))
			*out = CtrlHome;
		else if(ctrl & (LEFT_ALT_PRESSED|RIGHT_ALT_PRESSED))
			*out = AltHome;
		else
			*out = Home;
		return 1;
	case VK_END:
		if(ctrl & SHIFT_PRESSED)
			*out = ShiftEnd;
		else if(ctrl & (LEFT_CTRL_PRESSED|RIGHT_CTRL_PRESSED))
			*out = CtrlEnd;
		else if(ctrl & (LEFT_ALT_PRESSED|RIGHT_ALT_PRESSED))
			*out = AltEnd;
		else
			*out = End;
		return 1;
	case VK_PRIOR:
		if(ctrl & SHIFT_PRESSED)
			*out = ShiftPgup;
		else if(ctrl & (LEFT_CTRL_PRESSED|RIGHT_CTRL_PRESSED))
			*out = CtrlPgup;
		else if(ctrl & (LEFT_ALT_PRESSED|RIGHT_ALT_PRESSED))
			*out = AltPgup;
		else
			*out = Pgup;
		return 1;
	case VK_NEXT:
		if(ctrl & SHIFT_PRESSED)
			*out = ShiftPgdown;
		else if(ctrl & (LEFT_CTRL_PRESSED|RIGHT_CTRL_PRESSED))
			*out = CtrlPgdown;
		else if(ctrl & (LEFT_ALT_PRESSED|RIGHT_ALT_PRESSED))
			*out = AltPgdown;
		else
			*out = Pgdown;
		return 1;
	case VK_INSERT:
		*out = Ins;
		return 1;
	case VK_DELETE:
		*out = Del;
		return 1;
	case VK_PRINT:
	case VK_SNAPSHOT:
		*out = Print;
		return 1;
	case VK_SCROLL:
		*out = Scroll;
		return 1;
	case VK_PAUSE:
		*out = Pause;
		return 1;
	case VK_CANCEL:
		*out = Break;
		return 1;

	case VK_F1:
		*out = KF|1;
		return 1;
	case VK_F2:
		*out = KF|2;
		return 1;
	case VK_F3:
		*out = KF|3;
		return 1;
	case VK_F4:
		*out = KF|4;
		return 1;
	case VK_F5:
		*out = KF|5;
		return 1;
	case VK_F6:
		*out = KF|6;
		return 1;
	case VK_F7:
		*out = KF|7;
		return 1;
	case VK_F8:
		*out = KF|8;
		return 1;
	case VK_F9:
		*out = KF|9;
		return 1;
	case VK_F10:
		*out = KF|10;
		return 1;
	case VK_F11:
		*out = KF|11;
		return 1;
	case VK_F12:
		*out = KF|12;
		return 1;

	case VK_CAPITAL:
		*out = Caps;
		return 1;
	case VK_NUMLOCK:
		*out = Num;
		return 1;

	case VK_TAB:
		if(ctrl & SHIFT_PRESSED)
			*out = BackTab;
		else
			*out = '\t';
		return 1;
	case VK_RETURN:
		*out = '\n';
		return 1;
	case VK_ESCAPE:
		*out = Esc;
		return 1;
	}

	wc = k->uChar.UnicodeChar;
	if(wc != 0){
		ch = (int)wc;

		if(ch == 0x03){
			termrestore();
			ExitProcess(0);
		}

		if(ch == '\r')
			ch = '\n';

		if(ctrl & (LEFT_ALT_PRESSED|RIGHT_ALT_PRESSED)){
			if((ch & ~0xFF) == 0){
				*out = APP | (ch & 0xFF);
				return 1;
			}
		}

		*out = ch;
		return 1;
	}

	return 0;
}

static int
mousebuttons(DWORD state, DWORD flags)
{
	int b;
	short delta;

	b = 0;

	if(state & FROM_LEFT_1ST_BUTTON_PRESSED)
		b |= 1;
	if(state & RIGHTMOST_BUTTON_PRESSED)
		b |= 2;
	if(state & FROM_LEFT_2ND_BUTTON_PRESSED)
		b |= 4;

	if(flags == MOUSE_WHEELED){
		delta = (short)HIWORD(state);
		if(delta > 0)
			b |= 8;
		else if(delta < 0)
			b |= 16;
	}

	if(flags == DOUBLE_CLICK)
		b |= 256;

	return b;
}

static int
mousemods(DWORD state)
{
	int m;

	m = 0;
	if(state & SHIFT_PRESSED)
		m |= 1;
	if(state & (LEFT_CTRL_PRESSED|RIGHT_CTRL_PRESSED))
		m |= 2;
	if(state & (LEFT_ALT_PRESSED|RIGHT_ALT_PRESSED))
		m |= 4;

	return m;
}

static int
mouseeventtext(MOUSE_EVENT_RECORD *m, char *buf, int n)
{
	int x, y, b, mods;

	if(m == nil || buf == nil || n <= 0)
		return -1;

	x = m->dwMousePosition.X;
	y = m->dwMousePosition.Y;
	b = mousebuttons(m->dwButtonState, m->dwEventFlags);
	mods = mousemods(m->dwControlKeyState);

	return snprint(buf, n, "m %d %d %d %d\n", x, y, b, mods);
}

int
readconsoleevent(int *key, char *mbuf, int mn)
{
	INPUT_RECORD rec;
	DWORD r;
	int k;

	for(;;){
		if(!ReadConsoleInput(kbdh, &rec, 1, &r))
			return -1;

		if(r == 0)
			continue;

		if(rec.EventType == KEY_EVENT){
			k = -1;
			if(keyeventcode(&rec.Event.KeyEvent, &k)){
				if(key != nil)
					*key = k;
				return ConEventKey;
			}
			continue;
		}

		if(rec.EventType == MOUSE_EVENT){
			if(mbuf != nil && mn > 0){
				if(mouseeventtext(&rec.Event.MouseEvent, mbuf, mn) >= 0)
					return ConEventMouse;
			}
			continue;
		}
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
		if(t < 0)
			panic("enhanced keyboard fail");
	}
}

void
enableconsolemouse(void)
{
	DWORD mode;

	if(kbdh == INVALID_HANDLE_VALUE)
		return;
	if(mousemodeactive)
		return;
	if(!GetConsoleMode(kbdh, &mode))
		return;

	mouseconsolestate = mode;
	mousemodesaved = 1;

	mode |= ENABLE_MOUSE_INPUT;
	mode |= ENABLE_EXTENDED_FLAGS;
	mode &= ~ENABLE_QUICK_EDIT_MODE;

	SetConsoleMode(kbdh, mode);
	mousemodeactive = 1;
}

void
disableconsolemouse(void)
{
	if(kbdh == INVALID_HANDLE_VALUE)
		return;
	if(!mousemodeactive)
		return;
	if(mousemodesaved)
		SetConsoleMode(kbdh, mouseconsolestate);
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
		if(t < 0)
			return -1;
	}
}

void
cleanexit(int x)
{
	sleep(2);
	termrestore();
	ExitProcess(x);
}

struct ecodes {
	DWORD	code;
	char*	name;
} ecodes[] = {
	EXCEPTION_ACCESS_VIOLATION,		"segmentation violation",
	EXCEPTION_DATATYPE_MISALIGNMENT,	"data alignment",
	EXCEPTION_BREAKPOINT,                	"breakpoint",
	EXCEPTION_SINGLE_STEP,               	"single step",
	EXCEPTION_ARRAY_BOUNDS_EXCEEDED,	"array bounds check",
	EXCEPTION_FLT_DENORMAL_OPERAND,		"denormalized float",
	EXCEPTION_FLT_DIVIDE_BY_ZERO,		"floating point divide by zero",
	EXCEPTION_FLT_INEXACT_RESULT,		"inexact floating point",
	EXCEPTION_FLT_INVALID_OPERATION,	"invalid floating operation",
	EXCEPTION_FLT_OVERFLOW,			"floating point result overflow",
	EXCEPTION_FLT_STACK_CHECK,		"floating point stack check",
	EXCEPTION_FLT_UNDERFLOW,		"floating point result underflow",
	EXCEPTION_INT_DIVIDE_BY_ZERO,		"divide by zero",
	EXCEPTION_INT_OVERFLOW,			"integer overflow",
	EXCEPTION_PRIV_INSTRUCTION,		"privileged instruction",
	EXCEPTION_IN_PAGE_ERROR,		"page-in error",
	EXCEPTION_ILLEGAL_INSTRUCTION,		"illegal instruction",
	EXCEPTION_NONCONTINUABLE_EXCEPTION,	"non-continuable exception",
	EXCEPTION_STACK_OVERFLOW,		"stack overflow",
	EXCEPTION_INVALID_DISPOSITION,		"invalid disposition",
	EXCEPTION_GUARD_PAGE,			"guard page violation",
	0,					nil
};

LONG
TrapHandler(LPEXCEPTION_POINTERS ureg)
{
	int i;
	char *name;
	DWORD code;
	char buf[ERRMAX];

	code = ureg->ExceptionRecord->ExceptionCode;

	name = nil;
	for(i = 0; i < nelem(ecodes); i++) {
		if(ecodes[i].code == code) {
			name = ecodes[i].name;
			break;
		}
	}

	if(name == nil) {
		snprint(buf, sizeof(buf), "unknown trap type (%#.8lux)\n", code);
		name = buf;
	}

	switch (code) {
	case EXCEPTION_FLT_DENORMAL_OPERAND:
	case EXCEPTION_FLT_DIVIDE_BY_ZERO:
	case EXCEPTION_FLT_INEXACT_RESULT:
	case EXCEPTION_FLT_INVALID_OPERATION:
	case EXCEPTION_FLT_OVERFLOW:
	case EXCEPTION_FLT_STACK_CHECK:
	case EXCEPTION_FLT_UNDERFLOW:
		break;
	}
	if (code == EXCEPTION_ACCESS_VIOLATION || code == EXCEPTION_DATATYPE_MISALIGNMENT || code == EXCEPTION_ILLEGAL_INSTRUCTION) {
		MessageBoxA(NULL, name, "Inferno Fatal Exception", MB_OK | MB_ICONERROR);
		panic("fatal exception: %s", name);
	}

	disfault(nil, name);
	return EXCEPTION_CONTINUE_EXECUTION;
}

static void
termset(void)
{
	DWORD flag;

	if(donetermset)
		return;
	donetermset = 1;

	conh = GetStdHandle(STD_OUTPUT_HANDLE);
	kbdh = GetStdHandle(STD_INPUT_HANDLE);
	errh = GetStdHandle(STD_ERROR_HANDLE);
	if(errh == INVALID_HANDLE_VALUE)
		errh = conh;

	enableconsolevtoutput();

	if(GetConsoleMode(kbdh, &consolestate)){
		flag = consolestate;
		flag &= ~(ENABLE_PROCESSED_INPUT|ENABLE_LINE_INPUT|ENABLE_ECHO_INPUT);
		SetConsoleMode(kbdh, flag);

		saveconsolecp();

		setutf8consolecp();

	}
}

static void
termrestore(void)
{
	disableconsolemouse();

	if(kbdh != INVALID_HANDLE_VALUE)
		SetConsoleMode(kbdh, consolestate);

	if(conh != INVALID_HANDLE_VALUE && consoleoutstatesaved)
		SetConsoleMode(conh, consoleoutstate);

	if(consolecpsaved)
		restoreconsolecp();

}

int
osconsinfo(char *buf, int n)
{
	CONSOLE_SCREEN_BUFFER_INFO info;
	HANDLE h;
	int cols, rows;
	int buffercols, bufferrows;
	int left, top, right, bottom;
	int cursorx, cursory;

	if(buf == nil || n <= 0)
		return -1;

	h = conh;
	if(h == INVALID_HANDLE_VALUE || h == NULL)
		h = GetStdHandle(STD_OUTPUT_HANDLE);

	if(h == INVALID_HANDLE_VALUE || h == NULL)
		return snprint(buf, n,
			"80 24\n"
			"cols=80\n"
			"rows=24\n"
			"source=fallback-no-console\n");

	if(!GetConsoleScreenBufferInfo(h, &info))
		return snprint(buf, n,
			"80 24\n"
			"cols=80\n"
			"rows=24\n"
			"source=fallback-consolegetinfo\n");

	left = info.srWindow.Left;
	top = info.srWindow.Top;
	right = info.srWindow.Right;
	bottom = info.srWindow.Bottom;

	cols = right - left + 1;
	rows = bottom - top + 1;

	buffercols = info.dwSize.X;
	bufferrows = info.dwSize.Y;

	cursorx = info.dwCursorPosition.X;
	cursory = info.dwCursorPosition.Y;

	if(cols <= 0)
		cols = 80;
	if(rows <= 0)
		rows = 24;

	return snprint(buf, n,
		"%d %d\n"
		"cols=%d\n"
		"rows=%d\n"
		"buffercols=%d\n"
		"bufferrows=%d\n"
		"left=%d\n"
		"top=%d\n"
		"right=%d\n"
		"bottom=%d\n"
		"cursorx=%d\n"
		"cursory=%d\n"
		"vt=%d\n"
		"utf8=%d\n"
		"colors=%d\n"
		"truecolor=%d\n"
		"source=mingw-console\n",
		cols, rows,
		cols, rows,
		buffercols, bufferrows,
		left, top, right, bottom,
		cursorx, cursory,
		vtoutputactive,
		consolecpchanged ? 1 : 0,
		vtoutputactive ? 16777216 : 16,
		vtoutputactive ? 1 : 0);
}

static	int	rebootok = 0;

void
osreboot(char *file, char **argv)
{
	if(rebootok){
		termrestore();
		execvp(file, argv);
		panic("reboot failure");
	}
}

void
libinit(char *imod)
{
	WSADATA wasdat;
	DWORD lasterror, namelen;
	OSVERSIONINFO os;
	char sys[64], uname[64];
	wchar_t wuname[64];
	char *uns;

	os.dwOSVersionInfoSize = sizeof(os);
	if(!GetVersionEx(&os))
		panic("can't get os version");
	PlatformId = os.dwPlatformId;
	if (PlatformId == VER_PLATFORM_WIN32_NT)
		rebootok = 1;
	else
		rebootok = 0;

	termset();

	if(WSAStartup(MAKEWORD(1, 1), &wasdat) != 0)
		panic("no winsock.dll");

	gethostname(sys, sizeof(sys));
	kstrdup(&ossysname, sys);
	if(sflag == 0)
		SetUnhandledExceptionFilter((LPTOP_LEVEL_EXCEPTION_FILTER)TrapHandler);

	path = getenv("PATH");
	if(path == nil)
		path = ".";

	up = newproc();
	if(up == nil)
		panic("cannot create kernel process");

	strcpy(uname, "inferno");
	namelen = sizeof(wuname);
	if(GetUserName(wuname, &namelen) != TRUE) {
		lasterror = GetLastError();	
		if(PlatformId == VER_PLATFORM_WIN32_NT || lasterror != ERROR_NOT_LOGGED_ON)
			print("cannot GetUserName: %d\n", lasterror);
	}else{
		uns = narrowen(wuname);
		snprint(uname, sizeof(uname), "%s", uns);
		free(uns);
	}
	kstrdup(&eve, uname);

	emuinit(imod);
}

int
close(int fd)
{
	if(fd == -1)
		return 0;
	CloseHandle(ntfd2h(fd));
	return 0;
}

int
read(int fd, void *buf, unsigned int n)
{
	HANDLE h;
	DWORD nn;

	if(fd == 0)
		h = kbdh;
	else
		h = ntfd2h(fd);
	if(h == INVALID_HANDLE_VALUE)
		return -1;
	if(!ReadFile(h, buf, n, &nn, NULL))
		return -1;
	return (int)nn;
}

int
write(int fd, const void *buf, uint n)
{
	HANDLE h;
	DWORD nn;

	if(fd == 1 || fd == 2){
		if(!donetermset)
			termset();
		if(fd == 1){
			h = conh;
			if(h == INVALID_HANDLE_VALUE)
				return -1;
			return consolewrite(h, &outparser, buf, n);
		}else{
			h = errh;
			if(h == INVALID_HANDLE_VALUE)
				return -1;
			return consolewrite(h, &errparser, buf, n);
		}
	}

	if(!WriteFile(ntfd2h(fd), buf, n, &nn, NULL))
		return -1;
	return (int)nn;
}

vlong
nth2fd(HANDLE h)
{
	return (vlong)h;
}

HANDLE
ntfd2h(vlong fd)
{
	return (HANDLE)fd;
}

void
oslopri(void)
{
	SetThreadPriority(GetCurrentThread(), THREAD_PRIORITY_BELOW_NORMAL);
}

#undef Sleep
void
sleep(int secs)
{
	Sleep(secs*1000);
}

void*
sbrk(int size)
{
	void *brk;

	brk = VirtualAlloc(NULL, size, MEM_COMMIT, PAGE_EXECUTE_READWRITE); 	
	if(brk == 0)
		return (void*)-1;

	return brk;
}

long
osmillisec(void)
{
	return GetTickCount();
}

#define SEC2MIN 60L
#define SEC2HOUR (60L*SEC2MIN)
#define SEC2DAY (24L*SEC2HOUR)

static	int	dmsize[] =
{
	365, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31
};
static	int	ldmsize[] =
{
	366, 31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31
};

static int*
yrsize(int yr)
{
	if( (yr % 4 == 0) && (yr % 100 != 0 || yr % 400 == 0) )
		return ldmsize;
	else
		return dmsize;
}

static long
tm2sec(SYSTEMTIME *tm)
{
	long secs;
	int i, *d2m;

	secs = 0;

	for(i = 1970; i < tm->wYear; i++){
		d2m = yrsize(i);
		secs += d2m[0] * SEC2DAY;
	}

	d2m = yrsize(tm->wYear);
	for(i = 1; i < tm->wMonth; i++)
		secs += d2m[i] * SEC2DAY;

	secs += (tm->wDay-1) * SEC2DAY;

	secs += tm->wHour * SEC2HOUR;
	secs += tm->wMinute * SEC2MIN;
	secs += tm->wSecond;

	return secs;
}

vlong
osusectime(void)
{
	SYSTEMTIME tm;
	vlong secs;

	GetSystemTime(&tm);
	secs = tm2sec(&tm);
	return secs * 1000000 + tm.wMilliseconds * 1000;
}

vlong
osnsec(void)
{
	return osusectime()*1000;
}

int
osmillisleep(ulong milsec)
{
	SleepEx(milsec, FALSE);
	return 0;
}

int
limbosleep(ulong milsec)
{
	if (sleepers > MAXSLEEPERS)
		return -1;
	sleepers++;
	up->syscall = SYS_SLEEP;
	SleepEx(milsec, TRUE);
	up->syscall = 0;
	sleepers--;
	return 0;
}

void
osyield(void)
{	
	SwitchToThread();
}

void
ospause(void)
{
	for(;;)
		sleep(1000000);
}

int
open(const char *path, int how, ...)
{
	panic("open");
	return -1;
}

int
creat(const char *path, int how)
{
	panic("creat");
	return -1;
}

int
stat(const char *path, struct stat *sp)
{
	panic("stat");
	return -1;
}

int
chown(const char *path, int uid, int gid)
{
	panic("chown");
	return -1;
}

int
chmod(const char *path, int mode)
{
	panic("chmod");
	return -1;
}

void
link(char *path, char *next)
{
	panic("link");
}

int
segflush(void *a, ulong n)
{
	return 0;
}