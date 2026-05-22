implement Awk;

#
# awk - implementation of the AWK programming language (the True AWK,
# Aho/Kernighan/Weinberger 1988) for Inferno/Limbo.
#
# Supports: BEGIN/END, pattern-action rules, expressions with full
# string/number duality, associative arrays, user-defined functions,
# control flow (if/else/while/do/for/for-in/break/continue/next/exit/return),
# regular expressions, printf/sprintf, getline, system, and the standard
# built-in functions (length, substr, index, split, sub, gsub, match,
# sin, cos, atan2, exp, log, sqrt, int, rand, srand, tolower, toupper).
#
# Built-in variables: NR, NF, NR, FNR, FS, OFS, ORS, RS, FILENAME, SUBSEP,
# RSTART, RLENGTH.
#

include "sys.m";
	sys: Sys;
	FD, Dir: import sys;

include "draw.m";

include "sh.m";
	sh: Sh;	# loaded lazily on first use

include "awk.m";

# -------------- Cell: an AWK runtime value --------------
# AWK values are dual: they can be both string and number. We carry
# whichever representation we have; conversions happen on demand.
# Arrays are also Cells whose value is a hash map from string to ref Cell.

Cell: adt {
	# flag bits
	sval:		string;		# string value (if HASSTR)
	nval:		real;		# numeric value (if HASNUM)
	flags:		int;		# bitmask: see HASNUM etc. below
	arr:		ref ATab;	# for array cells
	fnidx:		int;		# for function cells: index into program funcs
};

# Cell flags
HASSTR:		con 1 << 0;
HASNUM:		con 1 << 1;
ISARR:		con 1 << 2;
ISFUNC:		con 1 << 3;
ISFLD:		con 1 << 4;	# $i field — assignment must rebuild record
ISREC:		con 1 << 5;	# $0
STRINGOF:	con 1 << 6;	# numeric string (e.g. read from input)

# -------------- Associative-array hash table --------------
# Used both for AWK arrays and for the global/local symbol tables.

ABUCKETS:	con 31;

ATab: adt {
	bkt:	array of list of (string, ref Cell);
	n:	int;
};

newtab(): ref ATab
{
	t := ref ATab;
	t.bkt = array[ABUCKETS] of list of (string, ref Cell);
	for(i := 0; i < ABUCKETS; i++)
		t.bkt[i] = nil;
	t.n = 0;
	return t;
}

hashstr(s: string): int
{
	h := 0;
	for(i := 0; i < len s; i++)
		h = h*31 + s[i];
	# Mask to 31 bits to guarantee non-negative result.
	# (Without this, h == MIN_INT survives -h and yields a negative %.)
	h &= 16r7FFFFFFF;
	return h % ABUCKETS;
}

tabget(t: ref ATab, k: string): ref Cell
{
	if(t == nil)
		return nil;
	h := hashstr(k);
	for(l := t.bkt[h]; l != nil; l = tl l){
		(kk, vv) := hd l;
		if(kk == k)
			return vv;
	}
	return nil;
}

tabput(t: ref ATab, k: string, v: ref Cell)
{
	h := hashstr(k);
	nl: list of (string, ref Cell);
	found := 0;
	for(l := t.bkt[h]; l != nil; l = tl l){
		(kk, vv) := hd l;
		if(kk == k){
			nl = (kk, v) :: nl;
			found = 1;
		} else
			nl = (kk, vv) :: nl;
	}
	if(!found){
		nl = (k, v) :: nl;
		t.n++;
	}
	t.bkt[h] = nl;
}

tabdel(t: ref ATab, k: string): int
{
	if(t == nil)
		return 0;
	h := hashstr(k);
	nl: list of (string, ref Cell);
	found := 0;
	for(l := t.bkt[h]; l != nil; l = tl l){
		(kk, vv) := hd l;
		if(kk == k)
			found = 1;
		else
			nl = (kk, vv) :: nl;
	}
	if(found){
		t.bkt[h] = nl;
		t.n--;
	}
	return found;
}

tabkeys(t: ref ATab): list of string
{
	r: list of string;
	if(t == nil)
		return nil;
	for(i := 0; i < ABUCKETS; i++)
		for(l := t.bkt[i]; l != nil; l = tl l){
			(k, nil) := hd l;
			r = k :: r;
		}
	return r;
}

# -------------- Tokens --------------

# token codes
TEOF, TNL, TNUM, TSTRING, TREGEX, TVAR, TFUNC, TBUILTIN, TGETLINE,
TBEGIN, TEND, TIF, TELSE, TWHILE, TDO, TFOR, TIN, TBREAK, TCONTINUE,
TNEXT, TEXIT, TRETURN, TFUNCTION, TPRINT, TPRINTF, TDELETE,
# punctuation
TLBRACE, TRBRACE, TLPAREN, TRPAREN, TLBRACK, TRBRACK, TSEMI, TCOMMA,
TQUESTION, TCOLON, TDOLLAR,
# operators
TASSIGN, TADDEQ, TSUBEQ, TMULEQ, TDIVEQ, TMODEQ, TEXPEQ,
TOR, TAND, TNOT,
TMATCH, TNOMATCH,
TLT, TLE, TGT, TGE, TEQ, TNE,
TADD, TSUB, TMUL, TDIV, TMOD, TEXP,
TINCR, TDECR,
TAPPEND, TPIPE,
# special
TFUNCALL: con iota;

# Built-in function ids
BLEN, BSUBSTR, BINDEX, BSPLIT, BSPRINTF, BSUB, BGSUB, BMATCH,
BSIN, BCOS, BATAN2, BEXP, BLOG, BSQRT, BINT, BRAND, BSRAND,
BTOLOWER, BTOUPPER, BSYSTEM: con iota;

# print/printf redirection codes
RNONE, RFILE, RAPP, RPIPE: con iota;

Token: adt {
	typ:	int;
	sval:	string;
	nval:	real;
	bval:	int;	# builtin id / aux
	line:	int;
};

newtoken(): ref Token
{
	t := ref Token;
	t.typ = 0;
	t.sval = "";
	t.nval = 0.0;
	t.bval = 0;
	t.line = 0;
	return t;
}

# -------------- Lexer --------------

Lex: adt {
	src:	string;
	pos:	int;
	line:	int;
	peeked:	ref Token;
	# secondary push-back slot (for two-token look-ahead from the parser, e.g. for-in)
	peeked2:	ref Token;
	# state to disambiguate '/' between divide and regex
	prev:	int;
};

newlex(s: string): ref Lex
{
	l := ref Lex;
	l.src = s;
	l.pos = 0;
	l.line = 1;
	l.peeked = nil;
	l.peeked2 = nil;
	l.prev = TNL;	# at start, '/' is regex
	return l;
}

# keywords
keywords := array[] of {
	("BEGIN", TBEGIN),
	("END", TEND),
	("if", TIF),
	("else", TELSE),
	("while", TWHILE),
	("do", TDO),
	("for", TFOR),
	("in", TIN),
	("break", TBREAK),
	("continue", TCONTINUE),
	("next", TNEXT),
	("exit", TEXIT),
	("return", TRETURN),
	("function", TFUNCTION),
	("func", TFUNCTION),
	("print", TPRINT),
	("printf", TPRINTF),
	("delete", TDELETE),
	("getline", TGETLINE),
};

builtins := array[] of {
	("length", BLEN),
	("substr", BSUBSTR),
	("index", BINDEX),
	("split", BSPLIT),
	("sprintf", BSPRINTF),
	("sub", BSUB),
	("gsub", BGSUB),
	("match", BMATCH),
	("sin", BSIN),
	("cos", BCOS),
	("atan2", BATAN2),
	("exp", BEXP),
	("log", BLOG),
	("sqrt", BSQRT),
	("int", BINT),
	("rand", BRAND),
	("srand", BSRAND),
	("tolower", BTOLOWER),
	("toupper", BTOUPPER),
	("system", BSYSTEM),
};

isdigit(c: int): int { return c >= '0' && c <= '9'; }
isalpha(c: int): int { return c == '_' || (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z'); }
isalnum(c: int): int { return isdigit(c) || isalpha(c); }
isspace(c: int): int { return c == ' ' || c == '\t'; }

lexerror(l: ref Lex, msg: string)
{
	sys->fprint(sys->fildes(2), "awk: lex error line %d: %s\n", l.line, msg);
	raise "fail:awklex";
}

lpeekc(l: ref Lex): int
{
	if(l.pos >= len l.src)
		return -1;
	return l.src[l.pos];
}

lgetc(l: ref Lex): int
{
	if(l.pos >= len l.src)
		return -1;
	c := l.src[l.pos++];
	if(c == '\n')
		l.line++;
	return c;
}

lungetc(l: ref Lex)
{
	if(l.pos > 0){
		l.pos--;
		if(l.pos < len l.src && l.src[l.pos] == '\n')
			l.line--;
	}
}

# is '/' a regex right now? Depends on previous token.
regexallowed(prev: int): int
{
	case prev {
	TNUM or TSTRING or TVAR or TRPAREN or TRBRACK or TINCR or TDECR or TDOLLAR =>
		return 0;
	}
	return 1;
}

# read string literal "..."
lexstr(l: ref Lex): string
{
	s := "";
	for(;;){
		c := lgetc(l);
		if(c == -1)
			lexerror(l, "unterminated string");
		if(c == '"')
			break;
		if(c == '\\'){
			nc := lgetc(l);
			case nc {
			'n' => c = '\n';
			't' => c = '\t';
			'r' => c = '\r';
			'\\' => c = '\\';
			'"' => c = '"';
			'/' => c = '/';
			'a' => c = '\a';
			'b' => c = '\b';
			'f' => c = '\f';
			'v' => c = '\v';
			'0' => c = 0;
			-1 => lexerror(l, "bad escape");
			* => c = nc;
			}
		}
		s[len s] = c;
	}
	return s;
}

# read regex literal /.../ — keep escapes intact for the regex compiler
lexregex(l: ref Lex): string
{
	s := "";
	for(;;){
		c := lgetc(l);
		if(c == -1 || c == '\n')
			lexerror(l, "unterminated regex");
		if(c == '/')
			break;
		if(c == '\\'){
			nc := lgetc(l);
			if(nc == -1)
				lexerror(l, "bad regex escape");
			if(nc == '/'){
				s[len s] = '/';
				continue;
			}
			s[len s] = '\\';
			s[len s] = nc;
			continue;
		}
		s[len s] = c;
	}
	return s;
}

# read number; returns text
lexnum(l: ref Lex): (real, string)
{
	buf := "";
	c := lgetc(l);
	for(; c != -1 && isdigit(c); c = lgetc(l))
		buf[len buf] = c;
	if(c == '.'){
		buf[len buf] = c;
		for(c = lgetc(l); c != -1 && isdigit(c); c = lgetc(l))
			buf[len buf] = c;
	}
	if(c == 'e' || c == 'E'){
		buf[len buf] = c;
		c = lgetc(l);
		if(c == '+' || c == '-'){
			buf[len buf] = c;
			c = lgetc(l);
		}
		for(; c != -1 && isdigit(c); c = lgetc(l))
			buf[len buf] = c;
	}
	if(c != -1)
		lungetc(l);
	v := real buf;
	return (v, buf);
}

lookupkw(s: string): int
{
	for(i := 0; i < len keywords; i++){
		(k, t) := keywords[i];
		if(k == s)
			return t;
	}
	return -1;
}

lookupbuiltin(s: string): int
{
	for(i := 0; i < len builtins; i++){
		(k, t) := builtins[i];
		if(k == s)
			return t;
	}
	return -1;
}

# read one token
lexone(l: ref Lex): ref Token
{
	# skip whitespace and comments
	for(;;){
		c := lgetc(l);
		if(c == -1){
			t := newtoken(); t.typ = TEOF; t.line = l.line;
			return t;
		}
		if(c == '\\' && lpeekc(l) == '\n'){
			lgetc(l);
			continue;
		}
		if(c == '#'){
			for(c = lgetc(l); c != -1 && c != '\n'; c = lgetc(l)){}
			if(c == -1){
				t := newtoken(); t.typ = TEOF; t.line = l.line;
				return t;
			}
			# fall through with c='\n'
		}
		if(c == '\n'){
			t := newtoken(); t.typ = TNL; t.line = l.line;
			return t;
		}
		if(isspace(c))
			continue;
		lungetc(l);
		break;
	}
	t := newtoken(); t.line = l.line;
	c := lgetc(l);
	if(isdigit(c) || (c == '.' && isdigit(lpeekc(l)))){
		lungetc(l);
		(v, txt) := lexnum(l);
		t.typ = TNUM; t.nval = v; t.sval = txt;
		return t;
	}
	if(isalpha(c)){
		s := ""; s[0] = c;
		for(;;){
			nc := lgetc(l);
			if(nc == -1) break;
			if(!isalnum(nc)){
				lungetc(l);
				break;
			}
			s[len s] = nc;
		}
		kw := lookupkw(s);
		if(kw >= 0){
			t.typ = kw; t.sval = s;
			return t;
		}
		bi := lookupbuiltin(s);
		if(bi >= 0){
			t.typ = TBUILTIN; t.sval = s; t.bval = bi;
			return t;
		}
		t.typ = TVAR; t.sval = s;
		return t;
	}
	if(c == '"'){
		t.typ = TSTRING; t.sval = lexstr(l);
		return t;
	}
	if(c == '/' && regexallowed(l.prev)){
		t.typ = TREGEX; t.sval = lexregex(l);
		return t;
	}
	case c {
	'{' => t.typ = TLBRACE;
	'}' => t.typ = TRBRACE;
	'(' => t.typ = TLPAREN;
	')' => t.typ = TRPAREN;
	'[' => t.typ = TLBRACK;
	']' => t.typ = TRBRACK;
	';' => t.typ = TSEMI;
	',' => t.typ = TCOMMA;
	'?' => t.typ = TQUESTION;
	':' => t.typ = TCOLON;
	'$' => t.typ = TDOLLAR;
	'|' =>
		if(lpeekc(l) == '|'){ lgetc(l); t.typ = TOR; }
		else t.typ = TPIPE;
	'&' =>
		if(lpeekc(l) == '&'){ lgetc(l); t.typ = TAND; }
		else lexerror(l, "stray &");
	'!' =>
		if(lpeekc(l) == '='){ lgetc(l); t.typ = TNE; }
		else if(lpeekc(l) == '~'){ lgetc(l); t.typ = TNOMATCH; }
		else t.typ = TNOT;
	'~' => t.typ = TMATCH;
	'<' =>
		if(lpeekc(l) == '='){ lgetc(l); t.typ = TLE; }
		else t.typ = TLT;
	'>' =>
		if(lpeekc(l) == '='){ lgetc(l); t.typ = TGE; }
		else if(lpeekc(l) == '>'){ lgetc(l); t.typ = TAPPEND; }
		else t.typ = TGT;
	'=' =>
		if(lpeekc(l) == '='){ lgetc(l); t.typ = TEQ; }
		else t.typ = TASSIGN;
	'+' =>
		if(lpeekc(l) == '+'){ lgetc(l); t.typ = TINCR; }
		else if(lpeekc(l) == '='){ lgetc(l); t.typ = TADDEQ; }
		else t.typ = TADD;
	'-' =>
		if(lpeekc(l) == '-'){ lgetc(l); t.typ = TDECR; }
		else if(lpeekc(l) == '='){ lgetc(l); t.typ = TSUBEQ; }
		else t.typ = TSUB;
	'*' =>
		if(lpeekc(l) == '*'){ lgetc(l);
			if(lpeekc(l) == '='){ lgetc(l); t.typ = TEXPEQ; }
			else t.typ = TEXP;
		}
		else if(lpeekc(l) == '='){ lgetc(l); t.typ = TMULEQ; }
		else t.typ = TMUL;
	'/' =>
		if(lpeekc(l) == '='){ lgetc(l); t.typ = TDIVEQ; }
		else t.typ = TDIV;
	'%' =>
		if(lpeekc(l) == '='){ lgetc(l); t.typ = TMODEQ; }
		else t.typ = TMOD;
	'^' =>
		if(lpeekc(l) == '='){ lgetc(l); t.typ = TEXPEQ; }
		else t.typ = TEXP;
	* => lexerror(l, sys->sprint("bad char %c (%d)", c, c));
	}
	return t;
}

lpeek(l: ref Lex): ref Token
{
	if(l.peeked == nil)
		l.peeked = lexone(l);
	return l.peeked;
}

# peek the token AFTER the next one. Used by the parser when it needs to
# disambiguate between e.g. `for (var in arr ...)` and `for (var = expr; ...)`.
lpeek2(l: ref Lex): ref Token
{
	if(l.peeked == nil)
		l.peeked = lexone(l);
	if(l.peeked2 == nil)
		l.peeked2 = lexone(l);
	return l.peeked2;
}

lnext(l: ref Lex): ref Token
{
	t: ref Token;
	if(l.peeked != nil){
		t = l.peeked;
		l.peeked = l.peeked2;
		l.peeked2 = nil;
	} else
		t = lexone(l);
	l.prev = t.typ;
	return t;
}

# skip optional newlines and semicolons
lskipnl(l: ref Lex)
{
	for(;;){
		t := lpeek(l);
		if(t.typ == TNL || t.typ == TSEMI)
			lnext(l);
		else
			break;
	}
}

# expect a particular token
lexpect(l: ref Lex, typ: int, what: string): ref Token
{
	t := lnext(l);
	if(t.typ != typ){
		sys->fprint(sys->fildes(2), "awk: line %d: expected %s, got token %d (%s)\n",
			t.line, what, t.typ, t.sval);
		raise "fail:awkparse";
	}
	return t;
}

# -------------- AST --------------

# Node kinds
NPROG, NPATACT, NBEGIN, NEND, NRULE, NFUNC,
NNUM, NSTR, NREGEX, NVAR, NIDX, NFIELD, NGETLINE,
NASSIGN, NOPASSIGN, NCOND, NLOR, NLAND, NNOT, NMATCH, NNOMATCH,
NREL, NCAT, NADD, NSUB, NMUL, NDIV, NMOD, NEXP, NNEG, NUPLUS,
NPREINCR, NPREDECR, NPOSTINCR, NPOSTDECR,
NIN, NCALL, NBUILTIN, NPRINT, NPRINTF, NDELETE,
NIF, NWHILE, NDO, NFOR, NFORIN, NBLOCK, NBREAK, NCONTINUE, NNEXT,
NEXIT, NRETURN, NEXPR: con iota;

# rel ops codes (stored in Node.iv)
RELLT, RELLE, RELGT, RELGE, RELEQ, RELNE: con iota;

Node: adt {
	kind:	int;
	sval:	string;	# var name, string literal, regex text
	nval:	real;	# numeric literal
	iv:	int;	# auxiliary integer (op code, builtin id, getline form)
	line:	int;
	# children — keep it generic with a list
	kids:	array of ref Node;
	# extras
	re:	ref Regex;	# compiled regex
};

# Allocate a freshly zeroed Node. The 64-bit Inferno runtime does NOT
# reliably zero fields of a newly-allocated `ref X`; always init explicitly.
newnode(): ref Node
{
	n := ref Node;
	n.kind = 0;
	n.sval = "";
	n.nval = 0.0;
	n.iv = 0;
	n.line = 0;
	n.kids = nil;
	n.re = nil;
	return n;
}

mknode(k: int, kids: array of ref Node): ref Node
{
	n := newnode();
	n.kind = k;
	n.kids = kids;
	return n;
}

# -------------- Parser --------------
# AWK grammar (simplified, sufficient for the True AWK).
#
# program  := { pattern action | pattern | action | function-def }
# pattern  := BEGIN | END | expr | expr , expr
# action   := '{' stmts '}'
# stmts    := { stmt (NL|;) }
# stmt     := if(expr) stmt [else stmt]
#           | while(expr) stmt
#           | do stmt while(expr)
#           | for(e1;e2;e3) stmt
#           | for(var in arr) stmt
#           | break | continue | next | exit [expr] | return [expr]
#           | delete arr[idx] | delete arr
#           | { stmts }
#           | print [expr-list] [> file | >> file | | cmd]
#           | printf fmt, args [redir]
#           | expr
#
# Expressions (precedence, lowest to highest, like POSIX awk):
#   assignment    = += -= *= /= %= ^=   (right assoc)
#   ternary       ? :                    (right assoc)
#   logical-or    ||
#   logical-and   &&
#   in            (e in arr)
#   match         ~ !~
#   relational    < <= > >= == !=
#   concat        (juxtaposition)
#   add/sub       + -
#   mul/div/mod   * / %
#   exponent      ^                       (right assoc)
#   unary         ! -
#   incr/decr     ++ --
#   field         $
#   primary       num, str, regex, var, var[..], func(..), (expr)

# Parser state
Parser: adt {
	lex:	ref Lex;
	infunc:	int;		# parsing inside function body?
	localnames:	array of string;  # local parameter names for current function
	funcs:	ref ATab;	# function name -> Cell{ISFUNC,fnidx}
	funcdefs:	array of ref FuncDef;
};

FuncDef: adt {
	name:	string;
	params:	array of string;
	body:	ref Node;
};

Program: adt {
	begins:	array of ref Node;	# BEGIN blocks
	ends:	array of ref Node;	# END blocks
	rules:	array of ref Node;	# (pat, act) pairs as NRULE nodes
	funcs:	array of ref FuncDef;
	funcsym:	ref ATab;	# name -> Cell
};

parseerror(p: ref Parser, msg: string)
{
	sys->fprint(sys->fildes(2), "awk: parse error line %d: %s\n", p.lex.line, msg);
	raise "fail:awkparse";
}

newparser(src: string): ref Parser
{
	p := ref Parser;
	p.lex = newlex(src);
	p.infunc = 0;
	p.localnames = nil;
	p.funcs = newtab();
	p.funcdefs = nil;
	return p;
}

parseprogram(p: ref Parser): ref Program
{
	prog := ref Program;
	prog.begins = nil;
	prog.ends = nil;
	prog.rules = nil;
	prog.funcs = nil;
	prog.funcsym = nil;
	begs, ends, rules: list of ref Node;
	for(;;){
		lskipnl(p.lex);
		t := lpeek(p.lex);
		if(t.typ == TEOF)
			break;
		if(t.typ == TFUNCTION){
			parsefunc(p);
			continue;
		}
		(pat, act) := parsepatact(p);
		if(pat != nil && pat.kind == NBEGIN){
			begs = act :: begs;
		} else if(pat != nil && pat.kind == NEND){
			ends = act :: ends;
		} else {
			r := newnode();
			r.kind = NRULE;
			r.kids = array[2] of ref Node;
			r.kids[0] = pat;	# may be nil
			r.kids[1] = act;	# may be nil
			rules = r :: rules;
		}
	}
	prog.begins = listtoarr(reverse(begs));
	prog.ends = listtoarr(reverse(ends));
	prog.rules = listtoarr(reverse(rules));
	prog.funcs = p.funcdefs;
	prog.funcsym = p.funcs;
	return prog;
}

reverse(l: list of ref Node): list of ref Node
{
	r: list of ref Node;
	for(; l != nil; l = tl l)
		r = hd l :: r;
	return r;
}

listtoarr(l: list of ref Node): array of ref Node
{
	n := 0;
	for(x := l; x != nil; x = tl x)
		n++;
	a := array[n] of ref Node;
	i := 0;
	for(; l != nil; l = tl l)
		a[i++] = hd l;
	return a;
}

# parse function definition
parsefunc(p: ref Parser)
{
	lexpect(p.lex, TFUNCTION, "function");
	nt := lexpect(p.lex, TVAR, "function name");
	name := nt.sval;
	lexpect(p.lex, TLPAREN, "(");
	pars: list of string;
	t := lpeek(p.lex);
	if(t.typ != TRPAREN){
		for(;;){
			pn := lexpect(p.lex, TVAR, "parameter name");
			pars = pn.sval :: pars;
			tt := lpeek(p.lex);
			if(tt.typ == TCOMMA){ lnext(p.lex); continue; }
			break;
		}
	}
	lexpect(p.lex, TRPAREN, ")");
	# function name registered now so the body can recurse
	fc := newcell();
	fc.flags = ISFUNC;
	fc.fnidx = len p.funcdefs;
	tabput(p.funcs, name, fc);
	fd := ref FuncDef;
	fd.name = name;
	fd.params = nil;
	fd.body = nil;
	# reverse pars
	np := 0;
	for(x := pars; x != nil; x = tl x) np++;
	fd.params = array[np] of string;
	i := np-1;
	for(y := pars; y != nil; y = tl y)
		fd.params[i--] = hd y;
	# grow array
	od := p.funcdefs;
	p.funcdefs = array[len od + 1] of ref FuncDef;
	for(j := 0; j < len od; j++)
		p.funcdefs[j] = od[j];
	p.funcdefs[len od] = fd;
	# parse body in function context
	saveloc := p.localnames;
	savein := p.infunc;
	p.infunc = 1;
	p.localnames = fd.params;
	lskipnl(p.lex);
	fd.body = parseblock(p);
	p.infunc = savein;
	p.localnames = saveloc;
}

# parse pattern-action
parsepatact(p: ref Parser): (ref Node, ref Node)
{
	pat: ref Node;
	act: ref Node;
	t := lpeek(p.lex);
	if(t.typ == TBEGIN){
		lnext(p.lex);
		pat = newnode(); pat.kind = NBEGIN;
		lskipnl(p.lex);
		act = parseblock(p);
		return (pat, act);
	}
	if(t.typ == TEND){
		lnext(p.lex);
		pat = newnode(); pat.kind = NEND;
		lskipnl(p.lex);
		act = parseblock(p);
		return (pat, act);
	}
	if(t.typ == TLBRACE){
		# pattern omitted — action only
		act = parseblock(p);
		return (nil, act);
	}
	# expression pattern (possibly range)
	pat = parseexpr(p);
	t = lpeek(p.lex);
	if(t.typ == TCOMMA){
		lnext(p.lex);
		p2 := parseexpr(p);
		# represent as NPATACT with both
		r := newnode();
		r.kind = NPATACT;
		r.kids = array[2] of ref Node;
		r.kids[0] = pat;
		r.kids[1] = p2;
		pat = r;
	}
	t = lpeek(p.lex);
	if(t.typ == TLBRACE){
		act = parseblock(p);
	} else {
		# default action is { print }
		# build implicitly
		act = newnode();
		act.kind = NBLOCK;
		stmt := newnode();
		stmt.kind = NPRINT;
		stmt.kids = array[1] of ref Node;
		stmt.kids[0] = nil;	# no args -> print $0
		stmt.iv = RNONE;
		act.kids = array[1] of ref Node;
		act.kids[0] = stmt;
	}
	return (pat, act);
}

# parse '{' stmts '}'
parseblock(p: ref Parser): ref Node
{
	lexpect(p.lex, TLBRACE, "{");
	stmts: list of ref Node;
	for(;;){
		lskipnl(p.lex);
		t := lpeek(p.lex);
		if(t.typ == TRBRACE) break;
		if(t.typ == TEOF) parseerror(p, "unexpected EOF in block");
		s := parsestmt(p);
		if(s != nil)
			stmts = s :: stmts;
	}
	lexpect(p.lex, TRBRACE, "}");
	n := newnode();
	n.kind = NBLOCK;
	stmts = reverse(stmts);
	n.kids = listtoarr(stmts);
	return n;
}

parsestmt(p: ref Parser): ref Node
{
	t := lpeek(p.lex);
	case t.typ {
	TLBRACE => return parseblock(p);
	TSEMI or TNL =>
		lnext(p.lex);
		return nil;
	TIF =>
		lnext(p.lex);
		lexpect(p.lex, TLPAREN, "(");
		cond := parseexpr(p);
		lexpect(p.lex, TRPAREN, ")");
		lskipnl(p.lex);
		thn := parsestmt(p);
		lskipnl(p.lex);
		els: ref Node;
		if(lpeek(p.lex).typ == TELSE){
			lnext(p.lex);
			lskipnl(p.lex);
			els = parsestmt(p);
		}
		n := newnode();
		n.kind = NIF;
		n.kids = array[3] of ref Node;
		n.kids[0] = cond;
		n.kids[1] = thn;
		n.kids[2] = els;
		return n;
	TWHILE =>
		lnext(p.lex);
		lexpect(p.lex, TLPAREN, "(");
		cond := parseexpr(p);
		lexpect(p.lex, TRPAREN, ")");
		lskipnl(p.lex);
		body := parsestmt(p);
		n := newnode(); n.kind = NWHILE;
		n.kids = array[2] of ref Node;
		n.kids[0] = cond; n.kids[1] = body;
		return n;
	TDO =>
		lnext(p.lex);
		lskipnl(p.lex);
		body := parsestmt(p);
		lskipnl(p.lex);
		lexpect(p.lex, TWHILE, "while");
		lexpect(p.lex, TLPAREN, "(");
		cond := parseexpr(p);
		lexpect(p.lex, TRPAREN, ")");
		n := newnode(); n.kind = NDO;
		n.kids = array[2] of ref Node;
		n.kids[0] = body; n.kids[1] = cond;
		return n;
	TFOR =>
		return parsefor(p);
	TBREAK =>
		lnext(p.lex);
		n := newnode(); n.kind = NBREAK; return n;
	TCONTINUE =>
		lnext(p.lex);
		n := newnode(); n.kind = NCONTINUE; return n;
	TNEXT =>
		lnext(p.lex);
		n := newnode(); n.kind = NNEXT; return n;
	TEXIT =>
		lnext(p.lex);
		n := newnode(); n.kind = NEXIT;
		n.kids = array[1] of ref Node;
		tt := lpeek(p.lex);
		if(tt.typ != TSEMI && tt.typ != TNL && tt.typ != TRBRACE && tt.typ != TEOF)
			n.kids[0] = parseexpr(p);
		return n;
	TRETURN =>
		lnext(p.lex);
		n := newnode(); n.kind = NRETURN;
		n.kids = array[1] of ref Node;
		tt := lpeek(p.lex);
		if(tt.typ != TSEMI && tt.typ != TNL && tt.typ != TRBRACE && tt.typ != TEOF)
			n.kids[0] = parseexpr(p);
		return n;
	TDELETE =>
		lnext(p.lex);
		nt := lexpect(p.lex, TVAR, "array name");
		n := newnode(); n.kind = NDELETE;
		n.sval = nt.sval;
		# delete arr[i] or delete arr
		tt := lpeek(p.lex);
		if(tt.typ == TLBRACK){
			lnext(p.lex);
			idx := parseidxexpr(p);
			lexpect(p.lex, TRBRACK, "]");
			n.kids = array[1] of ref Node;
			n.kids[0] = idx;
		}
		return n;
	TPRINT =>
		return parseprint(p, NPRINT);
	TPRINTF =>
		return parseprint(p, NPRINTF);
	}
	# expression statement
	e := parseexpr(p);
	n := newnode(); n.kind = NEXPR;
	n.kids = array[1] of ref Node; n.kids[0] = e;
	return n;
}

parsefor(p: ref Parser): ref Node
{
	lnext(p.lex);	# 'for'
	lexpect(p.lex, TLPAREN, "(");
	# detect 'for (var in arr)'
	t := lpeek(p.lex);
	if(t.typ == TLPAREN){
		# could be (v1,v2,...) in arr — rare; treat normally as expr
	}
	if(t.typ == TVAR){
		# Distinguish `for (var in arr) ...` from `for (var = expr; ...; ...)`.
		# Use two-token lookahead so we don't have to consume and re-push.
		t2 := lpeek2(p.lex);
		if(t2.typ == TIN){
			v := lnext(p.lex);	# consume var
			lnext(p.lex);	# 'in'
			at := lexpect(p.lex, TVAR, "array name");
			lexpect(p.lex, TRPAREN, ")");
			lskipnl(p.lex);
			body := parsestmt(p);
			n := newnode(); n.kind = NFORIN;
			n.sval = v.sval;	# loop variable
			# use a dummy NVAR child to remember array name in kids[0]
			arrn := newnode(); arrn.kind = NVAR; arrn.sval = at.sval;
			n.kids = array[2] of ref Node;
			n.kids[0] = arrn;
			n.kids[1] = body;
			return n;
		}
		# Not for-in — fall through to regular for(e1;e2;e3). The two tokens
		# we peeked stay in the buffers; parseexpr will consume them.
	}
	# regular for(e1;e2;e3) — any of them may be empty
	e1, e2, e3, body: ref Node;
	if(lpeek(p.lex).typ != TSEMI)
		e1 = parseexpr(p);
	lexpect(p.lex, TSEMI, ";");
	if(lpeek(p.lex).typ != TSEMI)
		e2 = parseexpr(p);
	lexpect(p.lex, TSEMI, ";");
	if(lpeek(p.lex).typ != TRPAREN)
		e3 = parseexpr(p);
	lexpect(p.lex, TRPAREN, ")");
	lskipnl(p.lex);
	body = parsestmt(p);
	n := newnode(); n.kind = NFOR;
	n.kids = array[4] of ref Node;
	n.kids[0] = e1; n.kids[1] = e2; n.kids[2] = e3; n.kids[3] = body;
	return n;
}

# parse 'print' or 'printf' — possibly with redirection
parseprint(p: ref Parser, kind: int): ref Node
{
	lnext(p.lex);
	args: list of ref Node;
	t := lpeek(p.lex);
	if(t.typ != TSEMI && t.typ != TNL && t.typ != TRBRACE && t.typ != TEOF
	    && t.typ != TGT && t.typ != TAPPEND && t.typ != TPIPE){
		# parse comma-separated expression list — note: GT here means redirection,
		# but only at top-level (not inside parentheses), so we parse a non-
		# comparison-of-print list. Simplest: parse each expr without consuming
		# top-level '>' as comparison: handled by parseprintexpr.
		args = parseprintexpr(p) :: args;
		for(;;){
			tt := lpeek(p.lex);
			if(tt.typ != TCOMMA) break;
			lnext(p.lex);
			args = parseprintexpr(p) :: args;
		}
	}
	# optional redirection
	rkind := RNONE;
	rexpr: ref Node;
	t = lpeek(p.lex);
	if(t.typ == TGT){ lnext(p.lex); rkind = RFILE; rexpr = parseexpr(p); }
	else if(t.typ == TAPPEND){ lnext(p.lex); rkind = RAPP; rexpr = parseexpr(p); }
	else if(t.typ == TPIPE){ lnext(p.lex); rkind = RPIPE; rexpr = parseexpr(p); }
	n := newnode(); n.kind = kind;
	args = reverse(args);
	nargs := 0;
	for(x := args; x != nil; x = tl x) nargs++;
	n.kids = array[nargs + 1] of ref Node;
	i := 0;
	for(y := args; y != nil; y = tl y)
		n.kids[i++] = hd y;
	n.kids[nargs] = rexpr;
	n.iv = rkind;
	return n;
}

# expression but without top-level '>' as comparison (used in print arg list).
# Simplest implementation: parse a ternary; if the next token after the ternary
# is '>' or '>>' or '|' and we're in a print context, the caller decides.
parseprintexpr(p: ref Parser): ref Node
{
	# An assignment expression that doesn't gobble '>' as comparison.
	# We use a flag "noGT" by simply calling parseassign with that.
	return parseassign_p(p, 1);
}

parseexpr(p: ref Parser): ref Node
{
	return parseassign_p(p, 0);
}

parseassign_p(p: ref Parser, noGT: int): ref Node
{
	# assignment is right-assoc; left side must be an lvalue, but we'll
	# accept any expression and detect lvalue later.
	left := parseternary(p, noGT);
	t := lpeek(p.lex);
	case t.typ {
	TASSIGN or TADDEQ or TSUBEQ or TMULEQ or TDIVEQ or TMODEQ or TEXPEQ =>
		lnext(p.lex);
		right := parseassign_p(p, noGT);
		if(!islvalue(left))
			parseerror(p, "non-lvalue on left of assignment");
		n := newnode();
		if(t.typ == TASSIGN){
			n.kind = NASSIGN;
		} else {
			n.kind = NOPASSIGN;
			case t.typ {
			TADDEQ => n.iv = NADD;
			TSUBEQ => n.iv = NSUB;
			TMULEQ => n.iv = NMUL;
			TDIVEQ => n.iv = NDIV;
			TMODEQ => n.iv = NMOD;
			TEXPEQ => n.iv = NEXP;
			}
		}
		n.kids = array[2] of ref Node;
		n.kids[0] = left;
		n.kids[1] = right;
		return n;
	}
	return left;
}

islvalue(n: ref Node): int
{
	if(n == nil) return 0;
	case n.kind {
	NVAR or NIDX or NFIELD => return 1;
	}
	return 0;
}

parseternary(p: ref Parser, noGT: int): ref Node
{
	c := parselor(p, noGT);
	t := lpeek(p.lex);
	if(t.typ == TQUESTION){
		lnext(p.lex);
		a := parseassign_p(p, noGT);
		lexpect(p.lex, TCOLON, ":");
		b := parseassign_p(p, noGT);
		n := newnode(); n.kind = NCOND;
		n.kids = array[3] of ref Node;
		n.kids[0] = c; n.kids[1] = a; n.kids[2] = b;
		return n;
	}
	return c;
}

parselor(p: ref Parser, noGT: int): ref Node
{
	l := parseland(p, noGT);
	for(;;){
		t := lpeek(p.lex);
		if(t.typ != TOR) break;
		lnext(p.lex);
		lskipnl(p.lex);
		r := parseland(p, noGT);
		n := newnode(); n.kind = NLOR;
		n.kids = array[2] of ref Node; n.kids[0] = l; n.kids[1] = r;
		l = n;
	}
	return l;
}

parseland(p: ref Parser, noGT: int): ref Node
{
	l := parsein(p, noGT);
	for(;;){
		t := lpeek(p.lex);
		if(t.typ != TAND) break;
		lnext(p.lex);
		lskipnl(p.lex);
		r := parsein(p, noGT);
		n := newnode(); n.kind = NLAND;
		n.kids = array[2] of ref Node; n.kids[0] = l; n.kids[1] = r;
		l = n;
	}
	return l;
}

parsein(p: ref Parser, noGT: int): ref Node
{
	l := parsematch(p, noGT);
	t := lpeek(p.lex);
	if(t.typ == TIN){
		lnext(p.lex);
		at := lexpect(p.lex, TVAR, "array name");
		n := newnode(); n.kind = NIN;
		n.sval = at.sval;
		n.kids = array[1] of ref Node; n.kids[0] = l;
		return n;
	}
	# cmd | getline [var] — rewrite as an NGETLINE with the command as kids[1].
	# We test two tokens (`|` followed by `getline`); use lpeek2 so we don't
	# consume the `|` if it isn't followed by getline (it might be a print
	# redirection consumed by the caller, though normal expressions don't have
	# bare `|`).
	if(t.typ == TPIPE){
		t2 := lpeek2(p.lex);
		if(t2.typ == TGETLINE){
			lnext(p.lex);	# '|'
			lnext(p.lex);	# 'getline'
			n := newnode(); n.kind = NGETLINE;
			n.kids = array[2] of ref Node;
			n.iv = 2;	# from command pipe
			n.kids[1] = l;	# command expression
			tv := lpeek(p.lex);
			if(tv.typ == TVAR){
				lnext(p.lex);
				vn := newnode(); vn.kind = NVAR; vn.sval = tv.sval;
				n.kids[0] = vn;
			}
			return n;
		}
	}
	return l;
}

parsematch(p: ref Parser, noGT: int): ref Node
{
	l := parserel(p, noGT);
	for(;;){
		t := lpeek(p.lex);
		if(t.typ != TMATCH && t.typ != TNOMATCH) break;
		lnext(p.lex);
		r := parserel(p, noGT);
		n := newnode();
		if(t.typ == TMATCH) n.kind = NMATCH; else n.kind = NNOMATCH;
		n.kids = array[2] of ref Node; n.kids[0] = l; n.kids[1] = r;
		l = n;
	}
	return l;
}

parserel(p: ref Parser, noGT: int): ref Node
{
	l := parsecat(p, noGT);
	t := lpeek(p.lex);
	op := -1;
	case t.typ {
	TLT => op = RELLT;
	TLE => op = RELLE;
	TGT => if(!noGT) op = RELGT;
	TGE => op = RELGE;
	TEQ => op = RELEQ;
	TNE => op = RELNE;
	}
	if(op >= 0){
		lnext(p.lex);
		r := parsecat(p, noGT);
		n := newnode(); n.kind = NREL; n.iv = op;
		n.kids = array[2] of ref Node; n.kids[0] = l; n.kids[1] = r;
		return n;
	}
	return l;
}

# string concatenation has higher precedence than rel, lower than add.
# Concat is invoked between two expressions with no operator between them.
parsecat(p: ref Parser, noGT: int): ref Node
{
	l := parseadd(p, noGT);
	for(;;){
		t := lpeek(p.lex);
		if(!startsterm(t.typ, noGT)) break;
		r := parseadd(p, noGT);
		n := newnode(); n.kind = NCAT;
		n.kids = array[2] of ref Node; n.kids[0] = l; n.kids[1] = r;
		l = n;
	}
	return l;
}

# Does this token start a primary/unary expression (used to detect concat)?
startsterm(typ: int, noGT: int): int
{
	noGT = noGT;	# suppress unused warning
	case typ {
	TNUM or TSTRING or TVAR or TLPAREN or TDOLLAR or TBUILTIN or TGETLINE
	or TNOT or TSUB =>
		return 1;
	# regex too — /.../ as right operand of concat is unusual but legal as bool
	TREGEX => return 1;
	}
	return 0;
}

parseadd(p: ref Parser, noGT: int): ref Node
{
	l := parsemul(p, noGT);
	for(;;){
		t := lpeek(p.lex);
		if(t.typ != TADD && t.typ != TSUB) break;
		lnext(p.lex);
		r := parsemul(p, noGT);
		n := newnode();
		if(t.typ == TADD) n.kind = NADD; else n.kind = NSUB;
		n.kids = array[2] of ref Node; n.kids[0] = l; n.kids[1] = r;
		l = n;
	}
	return l;
}

parsemul(p: ref Parser, noGT: int): ref Node
{
	l := parseexp(p, noGT);
	for(;;){
		t := lpeek(p.lex);
		op := -1;
		case t.typ {
		TMUL => op = NMUL;
		TDIV => op = NDIV;
		TMOD => op = NMOD;
		}
		if(op < 0) break;
		lnext(p.lex);
		r := parseexp(p, noGT);
		n := newnode(); n.kind = op;
		n.kids = array[2] of ref Node; n.kids[0] = l; n.kids[1] = r;
		l = n;
	}
	return l;
}

# exponent is right-associative
parseexp(p: ref Parser, noGT: int): ref Node
{
	l := parseunary(p, noGT);
	t := lpeek(p.lex);
	if(t.typ == TEXP){
		lnext(p.lex);
		r := parseexp(p, noGT);
		n := newnode(); n.kind = NEXP;
		n.kids = array[2] of ref Node; n.kids[0] = l; n.kids[1] = r;
		return n;
	}
	return l;
}

parseunary(p: ref Parser, noGT: int): ref Node
{
	t := lpeek(p.lex);
	case t.typ {
	TNOT =>
		lnext(p.lex);
		e := parseunary(p, noGT);
		n := newnode(); n.kind = NNOT;
		n.kids = array[1] of ref Node; n.kids[0] = e;
		return n;
	TSUB =>
		lnext(p.lex);
		e := parseunary(p, noGT);
		n := newnode(); n.kind = NNEG;
		n.kids = array[1] of ref Node; n.kids[0] = e;
		return n;
	TADD =>
		lnext(p.lex);
		e := parseunary(p, noGT);
		n := newnode(); n.kind = NUPLUS;
		n.kids = array[1] of ref Node; n.kids[0] = e;
		return n;
	TINCR or TDECR =>
		lnext(p.lex);
		e := parseunary(p, noGT);
		n := newnode();
		if(t.typ == TINCR) n.kind = NPREINCR; else n.kind = NPREDECR;
		n.kids = array[1] of ref Node; n.kids[0] = e;
		return n;
	}
	return parsepostfix(p, noGT);
}

parsepostfix(p: ref Parser, noGT: int): ref Node
{
	e := parsefield(p, noGT);
	t := lpeek(p.lex);
	if(t.typ == TINCR){
		lnext(p.lex);
		n := newnode(); n.kind = NPOSTINCR;
		n.kids = array[1] of ref Node; n.kids[0] = e;
		return n;
	}
	if(t.typ == TDECR){
		lnext(p.lex);
		n := newnode(); n.kind = NPOSTDECR;
		n.kids = array[1] of ref Node; n.kids[0] = e;
		return n;
	}
	return e;
}

parsefield(p: ref Parser, noGT: int): ref Node
{
	t := lpeek(p.lex);
	if(t.typ == TDOLLAR){
		lnext(p.lex);
		e := parsefield(p, noGT);
		n := newnode(); n.kind = NFIELD;
		n.kids = array[1] of ref Node; n.kids[0] = e;
		return n;
	}
	return parseprimary(p, noGT);
}

parseprimary(p: ref Parser, noGT: int): ref Node
{
	t := lnext(p.lex);
	case t.typ {
	TNUM =>
		n := newnode(); n.kind = NNUM; n.nval = t.nval; n.sval = t.sval;
		return n;
	TSTRING =>
		n := newnode(); n.kind = NSTR; n.sval = t.sval;
		return n;
	TREGEX =>
		n := newnode(); n.kind = NREGEX; n.sval = t.sval;
		n.re = recompile(t.sval);
		return n;
	TLPAREN =>
		e := parseexpr(p);
		# parenthesized list? — only used for (e1,e2,...) in arr
		t2 := lpeek(p.lex);
		if(t2.typ == TCOMMA){
			# build a synthetic concatenated index (SUBSEP-separated)
			kids: list of ref Node;
			kids = e :: kids;
			while(lpeek(p.lex).typ == TCOMMA){
				lnext(p.lex);
				kids = parseexpr(p) :: kids;
			}
			lexpect(p.lex, TRPAREN, ")");
			# represent as NCAT-chain glued by SUBSEP — caller (subscript)
			# will handle. We piggy-back on NCAT with an intervening NSTR(SUBSEP).
			kids = reverse(kids);
			joined := hd kids;
			for(x := tl kids; x != nil; x = tl x){
				sep := newnode(); sep.kind = NVAR; sep.sval = "SUBSEP";
				cat1 := newnode(); cat1.kind = NCAT;
				cat1.kids = array[2] of ref Node;
				cat1.kids[0] = joined; cat1.kids[1] = sep;
				cat2 := newnode(); cat2.kind = NCAT;
				cat2.kids = array[2] of ref Node;
				cat2.kids[0] = cat1; cat2.kids[1] = hd x;
				joined = cat2;
			}
			# But wait: after (e1,e2,...) we need an 'in' next for it to be valid.
			# We pass it back as a single expression. The caller of parsein
			# expects an lvalue/expr; the join is fine.
			return joined;
		}
		lexpect(p.lex, TRPAREN, ")");
		return e;
	TVAR =>
		# might be: var, var[idx], func(args)
		t2 := lpeek(p.lex);
		if(t2.typ == TLPAREN){
			# user-defined function call — no space allowed in real awk, but
			# we accept it always: if not a known function, still treat as call,
			# the evaluator will error.
			lnext(p.lex);
			args: list of ref Node;
			if(lpeek(p.lex).typ != TRPAREN){
				args = parseexpr(p) :: args;
				while(lpeek(p.lex).typ == TCOMMA){
					lnext(p.lex);
					args = parseexpr(p) :: args;
				}
			}
			lexpect(p.lex, TRPAREN, ")");
			n := newnode(); n.kind = NCALL;
			n.sval = t.sval;
			args = reverse(args);
			n.kids = listtoarr(args);
			return n;
		}
		if(t2.typ == TLBRACK){
			lnext(p.lex);
			idx := parseidxexpr(p);
			lexpect(p.lex, TRBRACK, "]");
			n := newnode(); n.kind = NIDX; n.sval = t.sval;
			n.kids = array[1] of ref Node; n.kids[0] = idx;
			return n;
		}
		n := newnode(); n.kind = NVAR; n.sval = t.sval;
		return n;
	TBUILTIN =>
		# builtin(args)
		n := newnode(); n.kind = NBUILTIN; n.iv = t.bval; n.sval = t.sval;
		t2 := lpeek(p.lex);
		if(t2.typ == TLPAREN){
			lnext(p.lex);
			args: list of ref Node;
			if(lpeek(p.lex).typ != TRPAREN){
				args = parseexpr(p) :: args;
				while(lpeek(p.lex).typ == TCOMMA){
					lnext(p.lex);
					args = parseexpr(p) :: args;
				}
			}
			lexpect(p.lex, TRPAREN, ")");
			args = reverse(args);
			n.kids = listtoarr(args);
		} else {
			# zero-arg call (e.g. length without parens)
			n.kids = array[0] of ref Node;
		}
		return n;
	TGETLINE =>
		# getline [var] [< file] — also "cmd" | getline [var] handled earlier
		# Here we only handle the prefix form: getline [var] [< file]
		n := newnode(); n.kind = NGETLINE;
		n.kids = array[2] of ref Node;
		# var
		t2 := lpeek(p.lex);
		if(t2.typ == TVAR){
			# but be careful: getline followed by a regular token could be an expr
			# We accept only TVAR followed by either '<' or end-of-expr.
			# In True AWK 'getline' has very tricky grammar; we support common forms.
			lnext(p.lex);
			vn := newnode(); vn.kind = NVAR; vn.sval = t2.sval;
			n.kids[0] = vn;
		}
		t2 = lpeek(p.lex);
		if(t2.typ == TLT){
			lnext(p.lex);
			n.kids[1] = parseunary(p, noGT);
			n.iv = 1;	# from file
		} else
			n.iv = 0;	# from current input
		return n;
	* =>
		parseerror(p, sys->sprint("unexpected token %d", t.typ));
	}
	return nil;
}

# parse an index expression — comma-separated joined with SUBSEP
parseidxexpr(p: ref Parser): ref Node
{
	e := parseexpr(p);
	if(lpeek(p.lex).typ != TCOMMA)
		return e;
	# join
	cur := e;
	while(lpeek(p.lex).typ == TCOMMA){
		lnext(p.lex);
		rhs := parseexpr(p);
		sep := newnode(); sep.kind = NVAR; sep.sval = "SUBSEP";
		c1 := newnode(); c1.kind = NCAT;
		c1.kids = array[2] of ref Node; c1.kids[0] = cur; c1.kids[1] = sep;
		c2 := newnode(); c2.kind = NCAT;
		c2.kids = array[2] of ref Node; c2.kids[0] = c1; c2.kids[1] = rhs;
		cur = c2;
	}
	return cur;
}

# -------------- Regex engine --------------
# We implement a small NFA-based regex engine supporting:
#   .   any char (except \n)
#   *   zero or more
#   +   one or more
#   ?   zero or one
#   |   alternation
#   ()  grouping
#   []  character class with ranges; leading ^ for negation
#   ^,$ anchors
#   \d \D \s \S \w \W \n \t \r \\ \. etc.

# NFA states
SCHAR, SDOT, SCCLASS, SBOL, SEOL, SMATCH, SSPLIT: con iota;

ReState: adt {
	op:	int;
	c:	int;	# character for SCHAR
	cls:	array of int;	# pairs (lo,hi); for SCCLASS; len 0 means none; iv bit
	clsneg:	int;
	out:	int;	# next state index (or -1)
	out1:	int;	# for SSPLIT
};

Regex: adt {
	states:	array of ref ReState;
	start:	int;
};

# Build with a Thompson construction over a simple recursive-descent parser.


Rgx: adt {
	states:	array of ref ReState;
	start:	int;
};

RgxP: adt {
	src:	string;
	pos:	int;
	states:	array of ref ReState;
};

rgx_new(p: ref RgxP, op: int): int
{
	s := ref ReState;
	s.op = op;
	s.c = 0;
	s.cls = nil;
	s.clsneg = 0;
	s.out = -1;
	s.out1 = -1;
	na := array[len p.states + 1] of ref ReState;
	for(i := 0; i < len p.states; i++) na[i] = p.states[i];
	na[len p.states] = s;
	id := len p.states;
	p.states = na;
	return id;
}

rgx_patch(p: ref RgxP, outs: array of (int, int), target: int)
{
	for(i := 0; i < len outs; i++){
		(sid, which) := outs[i];
		if(which == 0) p.states[sid].out = target;
		else p.states[sid].out1 = target;
	}
}

joinouts(a, b: array of (int, int)): array of (int, int)
{
	r := array[len a + len b] of (int, int);
	for(i := 0; i < len a; i++) r[i] = a[i];
	for(i = 0; i < len b; i++) r[len a + i] = b[i];
	return r;
}

# parse alt
rgx_alt(p: ref RgxP): (int, array of (int, int))
{
	(s1, o1) := rgx_concat(p);
	if(p.pos < len p.src && p.src[p.pos] == '|'){
		p.pos++;
		(s2, o2) := rgx_alt(p);
		split := rgx_new(p, SSPLIT);
		p.states[split].out = s1;
		p.states[split].out1 = s2;
		return (split, joinouts(o1, o2));
	}
	return (s1, o1);
}

# parse concatenation
rgx_concat(p: ref RgxP): (int, array of (int, int))
{
	if(p.pos >= len p.src || p.src[p.pos] == '|' || p.src[p.pos] == ')'){
		# empty — produce an SSPLIT to nowhere; in NFA, an "epsilon" is an
		# SSPLIT with both outs dangling? Easier: a no-op via a single SSPLIT
		s := rgx_new(p, SSPLIT);
		p.states[s].out = -1;
		# treat both arrows as dangling
		o := array[2] of (int, int);
		o[0] = (s, 0);
		o[1] = (s, 1);
		return (s, o);
	}
	(s1, o1) := rgx_repeat(p);
	while(p.pos < len p.src && p.src[p.pos] != '|' && p.src[p.pos] != ')'){
		(s2, o2) := rgx_repeat(p);
		rgx_patch(p, o1, s2);
		o1 = o2;
	}
	return (s1, o1);
}

# parse one atom followed by * + ? ?
rgx_repeat(p: ref RgxP): (int, array of (int, int))
{
	(s, o) := rgx_atom(p);
	if(p.pos >= len p.src){
		return (s, o);
	}
	c := p.src[p.pos];
	if(c == '*'){
		p.pos++;
		split := rgx_new(p, SSPLIT);
		p.states[split].out = s;
		rgx_patch(p, o, split);
		o2 := array[1] of (int, int); o2[0] = (split, 1);
		return (split, o2);
	}
	if(c == '+'){
		p.pos++;
		split := rgx_new(p, SSPLIT);
		p.states[split].out = s;
		rgx_patch(p, o, split);
		o2 := array[1] of (int, int); o2[0] = (split, 1);
		return (s, o2);
	}
	if(c == '?'){
		p.pos++;
		split := rgx_new(p, SSPLIT);
		p.states[split].out = s;
		o1 := array[1] of (int, int); o1[0] = (split, 1);
		return (split, joinouts(o, o1));
	}
	return (s, o);
}

re_escape(c: int): int
{
	case c {
	'n' => return '\n';
	't' => return '\t';
	'r' => return '\r';
	'a' => return '\a';
	'b' => return '\b';
	'f' => return '\f';
	'v' => return '\v';
	'0' => return 0;
	}
	return c;	# literal
}

# class: parse "[...]" contents; build cls array (pairs) and clsneg flag.
rgx_class(p: ref RgxP): (array of int, int)
{
	neg := 0;
	if(p.pos < len p.src && p.src[p.pos] == '^'){
		neg = 1;
		p.pos++;
	}
	pairs: list of (int, int);
	# first char may be ']' literal
	first := 1;
	while(p.pos < len p.src){
		c := p.src[p.pos];
		if(c == ']' && !first) break;
		first = 0;
		p.pos++;
		if(c == '\\' && p.pos < len p.src){
			c = re_escape(p.src[p.pos]);
			# special class escapes
			case p.src[p.pos] {
			'd' =>
				pairs = ('0','9') :: pairs;
				p.pos++;
				continue;
			'w' =>
				pairs = ('a','z') :: pairs;
				pairs = ('A','Z') :: pairs;
				pairs = ('0','9') :: pairs;
				pairs = ('_','_') :: pairs;
				p.pos++;
				continue;
			's' =>
				pairs = (' ',' ') :: pairs;
				pairs = ('\t','\t') :: pairs;
				pairs = ('\n','\n') :: pairs;
				pairs = ('\r','\r') :: pairs;
				pairs = ('\f','\f') :: pairs;
				p.pos++;
				continue;
			}
			p.pos++;
		}
		# possibly a range
		if(p.pos+1 < len p.src && p.src[p.pos] == '-' && p.src[p.pos+1] != ']'){
			p.pos++;	# consume '-'
			lo := c;
			hi := p.src[p.pos];
			p.pos++;
			if(hi == '\\' && p.pos < len p.src){
				hi = re_escape(p.src[p.pos]);
				p.pos++;
			}
			pairs = (lo, hi) :: pairs;
		} else {
			pairs = (c, c) :: pairs;
		}
	}
	if(p.pos < len p.src && p.src[p.pos] == ']')
		p.pos++;
	# convert list to flat int array
	n := 0;
	for(x := pairs; x != nil; x = tl x) n++;
	arr := array[n*2] of int;
	i := n - 1;
	for(y := pairs; y != nil; y = tl y){
		(lo, hi) := hd y;
		arr[i*2] = lo;
		arr[i*2+1] = hi;
		i--;
	}
	return (arr, neg);
}

rgx_atom(p: ref RgxP): (int, array of (int, int))
{
	if(p.pos >= len p.src){
		# empty
		s := rgx_new(p, SSPLIT);
		o := array[2] of (int, int);
		o[0] = (s, 0); o[1] = (s, 1);
		return (s, o);
	}
	c := p.src[p.pos];
	if(c == '('){
		p.pos++;
		(s, o) := rgx_alt(p);
		if(p.pos < len p.src && p.src[p.pos] == ')')
			p.pos++;
		return (s, o);
	}
	if(c == '['){
		p.pos++;
		(cls, neg) := rgx_class(p);
		s := rgx_new(p, SCCLASS);
		p.states[s].cls = cls;
		p.states[s].clsneg = neg;
		o := array[1] of (int, int); o[0] = (s, 0);
		return (s, o);
	}
	if(c == '.'){
		p.pos++;
		s := rgx_new(p, SDOT);
		o := array[1] of (int, int); o[0] = (s, 0);
		return (s, o);
	}
	if(c == '^'){
		p.pos++;
		s := rgx_new(p, SBOL);
		o := array[1] of (int, int); o[0] = (s, 0);
		return (s, o);
	}
	if(c == '$'){
		p.pos++;
		s := rgx_new(p, SEOL);
		o := array[1] of (int, int); o[0] = (s, 0);
		return (s, o);
	}
	if(c == '\\'){
		p.pos++;
		if(p.pos < len p.src){
			ec := p.src[p.pos];
			p.pos++;
			# class escapes \d \s \w become SCCLASS
			case ec {
			'd' =>
				s := rgx_new(p, SCCLASS);
				cls := array[2] of int; cls[0] = '0'; cls[1] = '9';
				p.states[s].cls = cls;
				o := array[1] of (int, int); o[0] = (s, 0);
				return (s, o);
			's' =>
				s := rgx_new(p, SCCLASS);
				cls := array[10] of int;
				cls[0]=' '; cls[1]=' ';
				cls[2]='\t'; cls[3]='\t';
				cls[4]='\n'; cls[5]='\n';
				cls[6]='\r'; cls[7]='\r';
				cls[8]='\f'; cls[9]='\f';
				p.states[s].cls = cls;
				o := array[1] of (int, int); o[0] = (s, 0);
				return (s, o);
			'w' =>
				s := rgx_new(p, SCCLASS);
				cls := array[8] of int;
				cls[0]='a'; cls[1]='z';
				cls[2]='A'; cls[3]='Z';
				cls[4]='0'; cls[5]='9';
				cls[6]='_'; cls[7]='_';
				p.states[s].cls = cls;
				o := array[1] of (int, int); o[0] = (s, 0);
				return (s, o);
			}
			s := rgx_new(p, SCHAR);
			p.states[s].c = re_escape(ec);
			o := array[1] of (int, int); o[0] = (s, 0);
			return (s, o);
		}
	}
	# literal
	p.pos++;
	s := rgx_new(p, SCHAR);
	p.states[s].c = c;
	o := array[1] of (int, int); o[0] = (s, 0);
	return (s, o);
}

recompile(src: string): ref Regex
{
	p := ref RgxP;
	p.src = src;
	p.pos = 0;
	p.states = array[0] of ref ReState;
	(start, outs) := rgx_alt(p);
	matchst := rgx_new(p, SMATCH);
	rgx_patch(p, outs, matchst);
	r := ref Regex;
	r.states = p.states;
	r.start = start;
	return r;
}

# Run the NFA on text starting at 'from'. If anchored, only try at 'from';
# otherwise try every start position. Returns (start, end) match positions
# in chars (Unicode), or (-1, -1) if no match.

# Set operations
addst(curr: array of int, n: int, sid: int, st: array of ref ReState, mark: array of int, gen: int): int
{
	if(sid < 0) return n;
	if(mark[sid] == gen) return n;
	mark[sid] = gen;
	s := st[sid];
	if(s.op == SSPLIT){
		n = addst(curr, n, s.out, st, mark, gen);
		n = addst(curr, n, s.out1, st, mark, gen);
		return n;
	}
	curr[n++] = sid;
	return n;
}

# Try to match the regex starting at position 'pos' in text. Return end pos
# of longest match, or -1 if no match starting here.
rematchat(r: ref Regex, text: string, pos: int): int
{
	nst := len r.states;
	cur := array[nst] of int;
	nxt := array[nst] of int;
	mark := array[nst] of int;
	gen := 1;
	nc := addst(cur, 0, r.start, r.states, mark, gen);
	if(nc == 0) return -1;
	last := -1;
	# check for match in initial set
	for(i := 0; i < nc; i++)
		if(r.states[cur[i]].op == SMATCH){ last = pos; break; }
	# also handle initial anchors
	# We need to advance through chars
	p := pos;
	for(;;){
		# expand SBOL/SEOL transitions at current p
		# Anchors are consumed without character consumption — but we modeled them
		# as their own state, so they act on each char step. To handle properly,
		# we do a fixpoint: while any active state is SBOL/SEOL and matches at p,
		# move to its .out via epsilon.
		# Simpler: process anchors before consuming char.
		for(;;){
			changed := 0;
			gen2 := ++gen;
			nn := 0;
			for(k := 0; k < nc; k++){
				sid := cur[k];
				s := r.states[sid];
				if(s.op == SBOL){
					if(p == 0 || text[p-1] == '\n'){
						nn = addst(nxt, nn, s.out, r.states, mark, gen2);
						changed = 1;
						continue;
					}
				} else if(s.op == SEOL){
					if(p == len text || text[p] == '\n'){
						nn = addst(nxt, nn, s.out, r.states, mark, gen2);
						changed = 1;
						continue;
					}
				}
				nn = addst(nxt, nn, sid, r.states, mark, gen2);
			}
			tmp := cur; cur = nxt; nxt = tmp;
			nc = nn;
			# check matches
			for(m := 0; m < nc; m++)
				if(r.states[cur[m]].op == SMATCH){
					if(p > last) last = p;
					break;
				}
			if(!changed) break;
		}
		if(p >= len text) break;
		ch := text[p];
		# step
		gen3 := ++gen;
		nn := 0;
		for(i2 := 0; i2 < nc; i2++){
			sid := cur[i2];
			s := r.states[sid];
			matched := 0;
			case s.op {
			SCHAR =>
				if(ch == s.c) matched = 1;
			SDOT =>
				if(ch != '\n') matched = 1;
			SCCLASS =>
				inset := 0;
				for(j := 0; j < len s.cls; j += 2)
					if(ch >= s.cls[j] && ch <= s.cls[j+1]){ inset = 1; break; }
				if(s.clsneg) matched = !inset; else matched = inset;
			}
			if(matched)
				nn = addst(nxt, nn, s.out, r.states, mark, gen3);
		}
		tmp := cur; cur = nxt; nxt = tmp;
		nc = nn;
		p++;
		if(nc == 0) break;
		# check match
		for(i3 := 0; i3 < nc; i3++)
			if(r.states[cur[i3]].op == SMATCH){
				if(p > last) last = p;
				break;
			}
	}
	return last;
}

# Search the regex in text; return (start, end) of leftmost-longest match
# (start inclusive, end exclusive), or (-1, -1) if none.
research(r: ref Regex, text: string): (int, int)
{
	if(r == nil) return (-1, -1);
	for(i := 0; i <= len text; i++){
		e := rematchat(r, text, i);
		if(e >= 0)
			return (i, e);
	}
	return (-1, -1);
}

# Test full-text match (used for pattern-only patterns like /foo/).
rematch(r: ref Regex, text: string): int
{
	(s, nil) := research(r, text);
	return s >= 0;
}

# -------------- Runtime --------------

Interp: adt {
	prog:	ref Program;
	globals:	ref ATab;	# global variables
	# call stack for locals
	callstack:	list of ref ATab;
	# current record/fields
	record:	string;
	fields:	array of string;
	nf:	int;
	# control flow flags (set by stmts, cleared by callers)
	cf_break:	int;
	cf_continue:	int;
	cf_next:	int;
	cf_exit:	int;
	exitcode:	int;
	cf_return:	int;
	retval:	ref Cell;
	# RNG state
	rseed:	int;
	# I/O caches
	openfiles:	list of (string, ref FD, int);	# (name, fd, mode: 0=read,1=write,2=app)
	openpipes:	list of (string, ref FD, int, chan of int);	# (name, fd, mode, done)
	inpipes:	list of (string, ref FD, chan of int);		# input pipes from getline cmd|
	# input
	curfile:	string;
	curfd:	ref FD;
	filelist:	list of string;
	stdinfd:	ref FD;
	inbuf:	string;	# unread input
	atend:	int;
};

newinterp(prog: ref Program): ref Interp
{
	I := ref Interp;
	I.prog = prog;
	I.globals = newtab();
	I.callstack = nil;
	I.record = "";
	I.fields = array[0] of string;
	I.nf = 0;
	I.cf_break = 0;
	I.cf_continue = 0;
	I.cf_next = 0;
	I.cf_exit = 0;
	I.exitcode = 0;
	I.cf_return = 0;
	I.retval = nil;
	I.rseed = 1;
	I.openfiles = nil;
	I.openpipes = nil;
	I.inpipes = nil;
	I.curfile = "";
	I.curfd = nil;
	I.filelist = nil;
	I.stdinfd = nil;
	I.inbuf = "";
	I.atend = 0;
	# initialize built-ins
	setvarstr(I, "FS", " ");
	setvarstr(I, "OFS", " ");
	setvarstr(I, "ORS", "\n");
	setvarstr(I, "RS", "\n");
	setvarstr(I, "SUBSEP", "\034");
	setvarnum(I, "NR", 0.0);
	setvarnum(I, "NF", 0.0);
	setvarnum(I, "FNR", 0.0);
	setvarstr(I, "FILENAME", "");
	setvarnum(I, "RSTART", 0.0);
	setvarnum(I, "RLENGTH", -1.0);
	return I;
}

# -------------- Cell helpers --------------

# Allocate a freshly zeroed Cell. The 64-bit Inferno runtime does NOT
# guarantee that fields of a newly-allocated `ref X` are zeroed: stale
# memory may surface in `flags`/`nval`/`fnidx`. Always go through here.
newcell(): ref Cell
{
	c := ref Cell;
	c.sval = "";
	c.nval = 0.0;
	c.flags = 0;
	c.arr = nil;
	c.fnidx = 0;
	return c;
}

newcellstr(s: string): ref Cell
{
	c := newcell();
	c.sval = s;
	c.flags = HASSTR;
	return c;
}

newcellnum(n: real): ref Cell
{
	c := newcell();
	c.nval = n;
	c.flags = HASNUM;
	return c;
}

newcellnumstr(s: string): ref Cell
{
	# value read from input — is both a numeric string AND a string
	c := newcell();
	c.sval = s;
	c.flags = HASSTR | STRINGOF;
	(ok, v) := strtoreal(s);
	if(ok){
		c.nval = v;
		c.flags |= HASNUM;
	}
	return c;
}

# Try to parse a string as a real; return (ok, value).
# A string is "numeric" if it consists entirely of (possibly leading
# whitespace, then) a valid number, with only trailing whitespace.
strtoreal(s: string): (int, real)
{
	# trim leading whitespace
	i := 0;
	while(i < len s && (s[i] == ' ' || s[i] == '\t')) i++;
	if(i >= len s) return (0, 0.0);
	start := i;
	if(s[i] == '+' || s[i] == '-') i++;
	hasdig := 0;
	while(i < len s && s[i] >= '0' && s[i] <= '9'){ i++; hasdig = 1; }
	if(i < len s && s[i] == '.'){
		i++;
		while(i < len s && s[i] >= '0' && s[i] <= '9'){ i++; hasdig = 1; }
	}
	if(!hasdig) return (0, 0.0);
	if(i < len s && (s[i] == 'e' || s[i] == 'E')){
		i++;
		if(i < len s && (s[i] == '+' || s[i] == '-')) i++;
		hexp := 0;
		while(i < len s && s[i] >= '0' && s[i] <= '9'){ i++; hexp = 1; }
		if(!hexp) return (0, 0.0);
	}
	end := i;
	# trailing whitespace OK
	while(i < len s && (s[i] == ' ' || s[i] == '\t')) i++;
	if(i != len s) return (0, 0.0);
	v := real s[start:end];
	return (1, v);
}

# Force-convert cell to number
celltoint(c: ref Cell): int
{
	return int realtrunc(celltonum(c));
}

celltonum(c: ref Cell): real
{
	if(c == nil) return 0.0;
	if(c.flags & HASNUM) return c.nval;
	if(c.flags & HASSTR){
		(ok, v) := strtoreal(c.sval);
		if(ok){
			c.nval = v;
			c.flags |= HASNUM;
			return v;
		}
		# any non-numeric string is 0 in arithmetic context (but not as STRINGOF)
		c.nval = 0.0;
		c.flags |= HASNUM;
		return 0.0;
	}
	return 0.0;
}

# Force-convert cell to string
celltostr(c: ref Cell): string
{
	if(c == nil) return "";
	if(c.flags & HASSTR) return c.sval;
	if(c.flags & HASNUM){
		c.sval = numtostr(c.nval);
		c.flags |= HASSTR;
		return c.sval;
	}
	return "";
}

# Convert a real to AWK's default string form.
# Integers display without decimal point; otherwise %.6g.
numtostr(v: real): string
{
	# Are we exactly an integer in safe range?
	if(v == real (big v) && v > -1e16 && v < 1e16){
		bi := big v;
		return sys->sprint("%bd", bi);
	}
	return sys->sprint("%.6g", v);
}

# OFMT-driven formatter for print output. The default is %.6g.
numtostrofmt(I: ref Interp, v: real): string
{
	if(v == real (big v) && v > -1e16 && v < 1e16){
		bi := big v;
		return sys->sprint("%bd", bi);
	}
	ofmt := getvarstr(I, "OFMT");
	if(ofmt == "") ofmt = "%.6g";
	a := array[1] of ref Cell;
	a[0] = newcellnum(v);
	return awksprintf(I, ofmt, a);
}

# Is the cell "numeric" for comparison purposes?
isnumeric(c: ref Cell): int
{
	if(c == nil) return 0;
	if(c.flags & STRINGOF){
		# numeric string?
		return (c.flags & HASNUM) != 0;
	}
	# pure HASNUM (from arithmetic) is numeric
	if((c.flags & HASNUM) && !(c.flags & HASSTR)) return 1;
	return 0;
}

# truthy?
celltrue(c: ref Cell): int
{
	if(c == nil) return 0;
	if(isnumeric(c) || ((c.flags & HASNUM) && !(c.flags & HASSTR)))
		return c.nval != 0.0;
	# string truthiness: nonempty
	return celltostr(c) != "";
}

# -------------- Variable access --------------

getvarcell(I: ref Interp, name: string): ref Cell
{
	# locals first
	if(I.callstack != nil){
		lt := hd I.callstack;
		c := tabget(lt, name);
		if(c != nil) return c;
	}
	# field
	if(name == "NF"){
		# always-current
		c := newcellnum(real I.nf);
		return c;
	}
	c := tabget(I.globals, name);
	if(c == nil){
		c = newcell();
		tabput(I.globals, name, c);
	}
	return c;
}

# Get an lvalue cell — ensure scalar (not array). For locals, set in local
# scope; otherwise global.
getlvaluecell(I: ref Interp, name: string): ref Cell
{
	if(I.callstack != nil){
		lt := hd I.callstack;
		c := tabget(lt, name);
		if(c != nil){
			if(c.flags & ISARR)
				runerr(I, "scalar/array conflict for "+name);
			return c;
		}
	}
	if(name == "NF"){
		# special handling done at assignment site
	}
	c := tabget(I.globals, name);
	if(c == nil){
		c = newcell();
		tabput(I.globals, name, c);
	}
	if(c.flags & ISARR)
		runerr(I, "scalar/array conflict for "+name);
	return c;
}

# Get/create an array cell.
getarrcell(I: ref Interp, name: string): ref Cell
{
	if(I.callstack != nil){
		lt := hd I.callstack;
		c := tabget(lt, name);
		if(c != nil){
			if(!(c.flags & ISARR)){
				if(c.flags & (HASSTR|HASNUM))
					runerr(I, "scalar/array conflict for "+name);
				c.flags |= ISARR;
				c.arr = newtab();
			}
			return c;
		}
	}
	c := tabget(I.globals, name);
	if(c == nil){
		c = newcell();
		c.flags = ISARR;
		c.arr = newtab();
		tabput(I.globals, name, c);
		return c;
	}
	if(!(c.flags & ISARR)){
		if(c.flags & (HASSTR|HASNUM))
			runerr(I, "scalar/array conflict for "+name);
		c.flags |= ISARR;
		c.arr = newtab();
	}
	return c;
}

setvarstr(I: ref Interp, name: string, val: string)
{
	c := getlvaluecell(I, name);
	c.sval = val;
	c.flags = HASSTR;
	# special: setting NF rebuilds record
	if(name == "NF") setnf(I, int (real val));
	if(name == "FS" || name == "RS" || name == "OFS" || name == "ORS"
	   || name == "SUBSEP" || name == "FILENAME" || name == "OFMT")
		{}	# nothing extra
}

setvarnum(I: ref Interp, name: string, val: real)
{
	c := getlvaluecell(I, name);
	c.nval = val;
	c.flags = HASNUM;
	if(name == "NF") setnf(I, int val);
}

setvarcell(I: ref Interp, name: string, v: ref Cell)
{
	c := getlvaluecell(I, name);
	c.sval = v.sval;
	c.nval = v.nval;
	c.flags = v.flags & ~ISARR;
	if(name == "NF") setnf(I, celltoint(c));
}

getvarstr(I: ref Interp, name: string): string
{
	return celltostr(getvarcell(I, name));
}

getvarnum(I: ref Interp, name: string): real
{
	return celltonum(getvarcell(I, name));
}

# -------------- Fields --------------

# Split current record into fields by FS.
splitfields(I: ref Interp)
{
	fs := getvarstr(I, "FS");
	I.fields = splitbyfs(I.record, fs);
	I.nf = len I.fields;
	setvarnum(I, "NF", real I.nf);
}

splitbyfs(rec: string, fs: string): array of string
{
	if(rec == "") return array[0] of string;
	# Default FS=" ": split on runs of whitespace, skipping leading/trailing.
	if(fs == " "){
		flds: list of string;
		i := 0;
		while(i < len rec){
			while(i < len rec && (rec[i] == ' ' || rec[i] == '\t' || rec[i] == '\n')) i++;
			if(i >= len rec) break;
			s := i;
			while(i < len rec && rec[i] != ' ' && rec[i] != '\t' && rec[i] != '\n') i++;
			flds = rec[s:i] :: flds;
		}
		n := 0;
		for(x := flds; x != nil; x = tl x) n++;
		a := array[n] of string;
		j := n - 1;
		for(y := flds; y != nil; y = tl y) a[j--] = hd y;
		return a;
	}
	# Single-char FS
	if(len fs == 1){
		ch := fs[0];
		flds: list of string;
		s := 0;
		for(i := 0; i <= len rec; i++){
			if(i == len rec || rec[i] == ch){
				flds = rec[s:i] :: flds;
				s = i + 1;
			}
		}
		n := 0;
		for(x := flds; x != nil; x = tl x) n++;
		a := array[n] of string;
		j := n - 1;
		for(y := flds; y != nil; y = tl y) a[j--] = hd y;
		return a;
	}
	# Multi-char FS: treat as regex
	r := recompile(fs);
	flds: list of string;
	s := 0;
	for(i := 0; i <= len rec;){
		(ms, me) := researchfrom(r, rec, i);
		if(ms < 0){
			flds = rec[s:] :: flds;
			break;
		}
		flds = rec[s:ms] :: flds;
		s = me;
		if(me == ms) me++;	# avoid infinite loop on zero-length
		i = me;
	}
	n := 0;
	for(x := flds; x != nil; x = tl x) n++;
	a := array[n] of string;
	j := n - 1;
	for(y := flds; y != nil; y = tl y) a[j--] = hd y;
	return a;
}

researchfrom(r: ref Regex, text: string, from: int): (int, int)
{
	for(i := from; i <= len text; i++){
		e := rematchat(r, text, i);
		if(e >= 0) return (i, e);
	}
	return (-1, -1);
}

# Get field i (1-based). 0 returns whole record.
getfield(I: ref Interp, i: int): string
{
	if(i == 0) return I.record;
	if(i < 0) runerr(I, "negative field index");
	if(i > I.nf) return "";
	return I.fields[i-1];
}

# Set field i (1-based); rebuilds record if needed.
setfield(I: ref Interp, i: int, v: string)
{
	if(i < 0) runerr(I, "negative field index");
	if(i == 0){
		I.record = v;
		splitfields(I);
		return;
	}
	# extend fields if necessary
	if(i > I.nf){
		na := array[i] of string;
		for(j := 0; j < I.nf; j++) na[j] = I.fields[j];
		for(j = I.nf; j < i; j++) na[j] = "";
		I.fields = na;
		I.nf = i;
		setvarnum(I, "NF", real I.nf);
	}
	I.fields[i-1] = v;
	rebuildrecord(I);
}

# Set NF via the user's NF=
setnf(I: ref Interp, newn: int)
{
	if(newn < 0) newn = 0;
	if(newn == I.nf) return;
	if(newn < I.nf){
		na := array[newn] of string;
		for(j := 0; j < newn; j++) na[j] = I.fields[j];
		I.fields = na;
		I.nf = newn;
	} else {
		na := array[newn] of string;
		for(j := 0; j < I.nf; j++) na[j] = I.fields[j];
		for(j = I.nf; j < newn; j++) na[j] = "";
		I.fields = na;
		I.nf = newn;
	}
	rebuildrecord(I);
}

rebuildrecord(I: ref Interp)
{
	ofs := getvarstr(I, "OFS");
	s := "";
	for(i := 0; i < I.nf; i++){
		if(i > 0) s += ofs;
		s += I.fields[i];
	}
	I.record = s;
}

# -------------- Errors --------------

runerr(I: ref Interp, msg: string)
{
	I = I;
	sys->fprint(sys->fildes(2), "awk: %s\n", msg);
	raise "fail:awkrun";
}

# -------------- Evaluator --------------

# Evaluate an expression node to a Cell.
eval(I: ref Interp, n: ref Node): ref Cell
{
	if(n == nil) return newcellstr("");
	case n.kind {
	NNUM => return newcellnum(n.nval);
	NSTR => return newcellstr(n.sval);
	NREGEX =>
		# bare regex as expression: matches against $0
		if(n.re == nil) n.re = recompile(n.sval);
		if(rematch(n.re, I.record))
			return newcellnum(1.0);
		return newcellnum(0.0);
	NVAR =>
		# return the cell directly so assignments see lvalue identity
		c := getvarcell(I, n.sval);
		# return a copy for safety in expressions — but for assignments,
		# we use a separate path (assignlvalue).
		nc := newcell();
		nc.sval = c.sval; nc.nval = c.nval; nc.flags = c.flags;
		nc.arr = c.arr;
		return nc;
	NIDX =>
		idx := celltostr(eval(I, n.kids[0]));
		arr := getarrcell(I, n.sval);
		c := tabget(arr.arr, idx);
		if(c == nil){
			# AWK semantics: referencing creates the element
			c = newcell();
			tabput(arr.arr, idx, c);
		}
		nc := newcell();
		nc.sval = c.sval; nc.nval = c.nval; nc.flags = c.flags;
		return nc;
	NFIELD =>
		i := celltoint(eval(I, n.kids[0]));
		return newcellnumstr(getfield(I, i));
	NCAT =>
		a := celltostr(eval(I, n.kids[0]));
		b := celltostr(eval(I, n.kids[1]));
		return newcellstr(a + b);
	NADD =>
		a := celltonum(eval(I, n.kids[0]));
		b := celltonum(eval(I, n.kids[1]));
		return newcellnum(a + b);
	NSUB =>
		a := celltonum(eval(I, n.kids[0]));
		b := celltonum(eval(I, n.kids[1]));
		return newcellnum(a - b);
	NMUL =>
		a := celltonum(eval(I, n.kids[0]));
		b := celltonum(eval(I, n.kids[1]));
		return newcellnum(a * b);
	NDIV =>
		a := celltonum(eval(I, n.kids[0]));
		b := celltonum(eval(I, n.kids[1]));
		if(b == 0.0) runerr(I, "division by zero");
		return newcellnum(a / b);
	NMOD =>
		a := celltonum(eval(I, n.kids[0]));
		b := celltonum(eval(I, n.kids[1]));
		if(b == 0.0) runerr(I, "modulo by zero");
		# fmod via integer truncation
		q := a / b;
		ti := real (big q);
		return newcellnum(a - ti * b);
	NEXP =>
		a := celltonum(eval(I, n.kids[0]));
		b := celltonum(eval(I, n.kids[1]));
		return newcellnum(realpow(a, b));
	NNEG =>
		a := celltonum(eval(I, n.kids[0]));
		return newcellnum(-a);
	NUPLUS =>
		return newcellnum(celltonum(eval(I, n.kids[0])));
	NNOT =>
		if(celltrue(eval(I, n.kids[0]))) return newcellnum(0.0);
		return newcellnum(1.0);
	NLOR =>
		if(celltrue(eval(I, n.kids[0]))) return newcellnum(1.0);
		if(celltrue(eval(I, n.kids[1]))) return newcellnum(1.0);
		return newcellnum(0.0);
	NLAND =>
		if(!celltrue(eval(I, n.kids[0]))) return newcellnum(0.0);
		if(!celltrue(eval(I, n.kids[1]))) return newcellnum(0.0);
		return newcellnum(1.0);
	NCOND =>
		if(celltrue(eval(I, n.kids[0])))
			return eval(I, n.kids[1]);
		return eval(I, n.kids[2]);
	NREL =>
		return evalrel(I, n);
	NMATCH =>
		return evalmatch(I, n, 1);
	NNOMATCH =>
		return evalmatch(I, n, 0);
	NIN =>
		idx := celltostr(eval(I, n.kids[0]));
		arr := tabget(I.globals, n.sval);
		# also check locals
		if(I.callstack != nil){
			lt := hd I.callstack;
			lc := tabget(lt, n.sval);
			if(lc != nil) arr = lc;
		}
		if(arr == nil || !(arr.flags & ISARR))
			return newcellnum(0.0);
		if(tabget(arr.arr, idx) != nil) return newcellnum(1.0);
		return newcellnum(0.0);
	NASSIGN =>
		v := eval(I, n.kids[1]);
		return assignto(I, n.kids[0], v);
	NOPASSIGN =>
		# compute right, fetch current left, combine, assign
		lhsv := eval(I, n.kids[0]);
		rhsv := eval(I, n.kids[1]);
		a := celltonum(lhsv);
		b := celltonum(rhsv);
		nv: real;
		case n.iv {
		NADD => nv = a + b;
		NSUB => nv = a - b;
		NMUL => nv = a * b;
		NDIV => if(b == 0.0) runerr(I, "division by zero"); nv = a / b;
		NMOD =>
			if(b == 0.0) runerr(I, "modulo by zero");
			q := a / b;
			ti := real (big q);
			nv = a - ti * b;
		NEXP => nv = realpow(a, b);
		}
		nc := newcellnum(nv);
		return assignto(I, n.kids[0], nc);
	NPREINCR =>
		v := celltonum(eval(I, n.kids[0])) + 1.0;
		nc := newcellnum(v);
		assignto(I, n.kids[0], nc);
		return nc;
	NPREDECR =>
		v := celltonum(eval(I, n.kids[0])) - 1.0;
		nc := newcellnum(v);
		assignto(I, n.kids[0], nc);
		return nc;
	NPOSTINCR =>
		oldn := celltonum(eval(I, n.kids[0]));
		nc := newcellnum(oldn + 1.0);
		assignto(I, n.kids[0], nc);
		return newcellnum(oldn);
	NPOSTDECR =>
		oldn := celltonum(eval(I, n.kids[0]));
		nc := newcellnum(oldn - 1.0);
		assignto(I, n.kids[0], nc);
		return newcellnum(oldn);
	NCALL =>
		return docall(I, n);
	NBUILTIN =>
		return dobuiltin(I, n);
	NGETLINE =>
		return dogetline(I, n);
	}
	runerr(I, sys->sprint("eval: unhandled node kind %d", n.kind));
	return nil;
}

# x ** y (integer-aware fast path)
realpow(x, y: real): real
{
	# special cases
	if(y == 0.0) return 1.0;
	if(x == 0.0) return 0.0;
	# integer exponent fast path
	yi := int y;
	if(real yi == y){
		r := 1.0;
		base := x;
		n := yi;
		if(n < 0){
			base = 1.0 / base;
			n = -n;
		}
		while(n > 0){
			if(n & 1) r = r * base;
			base = base * base;
			n >>= 1;
		}
		return r;
	}
	# generic: exp(y * log x); only meaningful for x > 0
	if(x < 0.0) return 0.0;	# undefined; awk just returns nan
	return realexp_(y * reallog_(x));
}

# small math routines (no Math module import to keep self-contained)

# Truncate toward zero, ceiling, floor — implemented in pure Limbo because
# the 64-bit Inferno runtime's `big real` conversion does not give floor.
# Strategy: scale into a range where the int conversion is precise, do the
# coarse step, then refine.
realfloor(x: real): real
{
	# convert to big and back via repeated subtraction of 1 if we overshot
	bi := big x;
	r := real bi;
	if(r > x) r -= 1.0;	# went up (negative overshoot or rounding-up)
	return r;
}

realceil(x: real): real
{
	bi := big x;
	r := real bi;
	if(r < x) r += 1.0;
	return r;
}

realtrunc(x: real): real
{
	if(x >= 0.0) return realfloor(x);
	return realceil(x);
}

realexp_(x: real): real
{
	# rough exp via series; sufficient for typical scripts.
	# For larger |x| we use exp(x) = (exp(x/2))^2 splitting.
	if(x > 40.0) return 2.3538526683702e17 * realexp_(x - 40.0);
	if(x < -40.0) return realexp_(x + 40.0) / 2.3538526683702e17;
	# range reduce to [-1,1]
	n := 0;
	while(x > 1.0){ x = x / 2.0; n++; }
	while(x < -1.0){ x = x / 2.0; n++; }
	# Taylor series at 0
	term := 1.0;
	sum := 1.0;
	for(k := 1; k < 30; k++){
		term = term * x / real k;
		sum = sum + term;
	}
	while(n > 0){ sum = sum * sum; n--; }
	return sum;
}

reallog_(x: real): real
{
	if(x <= 0.0) return 0.0;
	# Use range reduction: log(x) = k*log(2) + log(m), x = 2^k * m, m in [1,2)
	# ln 2
	ln2 := 0.6931471805599453;
	k := 0;
	while(x >= 2.0){ x = x / 2.0; k++; }
	while(x < 1.0){ x = x * 2.0; k--; }
	# now x in [1,2). use ln(1+y) series, y = x-1 in [0,1)
	y := x - 1.0;
	term := y;
	sum := 0.0;
	sgn := 1.0;
	for(i := 1; i < 100; i++){
		sum = sum + sgn * term / real i;
		term = term * y;
		sgn = -sgn;
	}
	return sum + real k * ln2;
}

realsqrt_(x: real): real
{
	if(x <= 0.0) return 0.0;
	# Newton iteration
	g := x;
	for(i := 0; i < 60; i++){
		ng := (g + x/g) / 2.0;
		if(ng == g) break;
		g = ng;
	}
	return g;
}

# crude sin/cos via range reduction + Taylor
realsin_(x: real): real
{
	pi := 3.141592653589793;
	# reduce to [-pi, pi]
	while(x > pi) x = x - 2.0*pi;
	while(x < -pi) x = x + 2.0*pi;
	# Taylor
	term := x;
	sum := x;
	x2 := x * x;
	for(k := 1; k < 25; k++){
		term = -term * x2 / real ((2*k)*(2*k+1));
		sum = sum + term;
	}
	return sum;
}

realcos_(x: real): real
{
	pi := 3.141592653589793;
	while(x > pi) x = x - 2.0*pi;
	while(x < -pi) x = x + 2.0*pi;
	term := 1.0;
	sum := 1.0;
	x2 := x * x;
	for(k := 1; k < 25; k++){
		term = -term * x2 / real ((2*k-1)*(2*k));
		sum = sum + term;
	}
	return sum;
}

realatan_(x: real): real
{
	# atan(x). Series converges slowly near |x|=1, so reduce the argument
	# repeatedly using atan(x) = 2*atan(x/(1+sqrt(1+x*x))) until |x| < 0.2.
	pi := 3.141592653589793;
	if(x > 1.0) return pi/2.0 - realatan_(1.0/x);
	if(x < -1.0) return -pi/2.0 - realatan_(1.0/x);
	# Reduce |x| via half-angle: atan(x) = 2*atan(x/(1+sqrt(1+x^2)))
	reductions := 0;
	t := x;
	while(t > 0.2 || t < -0.2){
		t = t / (1.0 + realsqrt_(1.0 + t*t));
		reductions++;
		if(reductions > 10) break;
	}
	# Now |t| is small; Taylor converges fast.
	term := t;
	sum := t;
	t2 := t * t;
	for(k := 1; k < 30; k++){
		term = -term * t2;
		sum = sum + term / real (2*k+1);
	}
	# Undo the reductions
	for(r := 0; r < reductions; r++) sum = sum * 2.0;
	return sum;
}

realatan2_(y, x: real): real
{
	pi := 3.141592653589793;
	if(x > 0.0) return realatan_(y / x);
	if(x < 0.0){
		if(y >= 0.0) return realatan_(y / x) + pi;
		return realatan_(y / x) - pi;
	}
	# x == 0
	if(y > 0.0) return pi / 2.0;
	if(y < 0.0) return -pi / 2.0;
	return 0.0;
}

# Comparison: numeric if both look numeric, else string (POSIX rule).
evalrel(I: ref Interp, n: ref Node): ref Cell
{
	a := eval(I, n.kids[0]);
	b := eval(I, n.kids[1]);
	# Decide numeric vs string
	useNum := 0;
	# from AST: if either operand is a number literal, compare numerically.
	if(n.kids[0].kind == NNUM || n.kids[1].kind == NNUM) useNum = 1;
	# pure HASNUM (no string) on either side -> numeric
	if(((a.flags & HASNUM) && !(a.flags & HASSTR)) ||
	   ((b.flags & HASNUM) && !(b.flags & HASSTR))) useNum = 1;
	# both look like numeric strings -> numeric
	if(isnumeric(a) && isnumeric(b)) useNum = 1;
	res := 0;
	if(useNum){
		av := celltonum(a);
		bv := celltonum(b);
		case n.iv {
		RELLT => res = av < bv;
		RELLE => res = av <= bv;
		RELGT => res = av > bv;
		RELGE => res = av >= bv;
		RELEQ => res = av == bv;
		RELNE => res = av != bv;
		}
	} else {
		as := celltostr(a);
		bs := celltostr(b);
		case n.iv {
		RELLT => res = as < bs;
		RELLE => res = as <= bs;
		RELGT => res = as > bs;
		RELGE => res = as >= bs;
		RELEQ => res = as == bs;
		RELNE => res = as != bs;
		}
	}
	if(res) return newcellnum(1.0);
	return newcellnum(0.0);
}

evalmatch(I: ref Interp, n: ref Node, pos: int): ref Cell
{
	s := celltostr(eval(I, n.kids[0]));
	r := getregex(n.kids[1], I);
	m := rematch(r, s);
	if((pos && m) || (!pos && !m)) return newcellnum(1.0);
	return newcellnum(0.0);
}

# Get a compiled regex from an AST node — either an NREGEX literal or
# any other expr (treated as string and compiled).
getregex(n: ref Node, I: ref Interp): ref Regex
{
	if(n.kind == NREGEX){
		if(n.re == nil) n.re = recompile(n.sval);
		return n.re;
	}
	s := celltostr(eval(I, n));
	return recompile(s);
}

# Assign rhs cell to lvalue node.
assignto(I: ref Interp, n: ref Node, v: ref Cell): ref Cell
{
	case n.kind {
	NVAR =>
		# locals first
		if(I.callstack != nil){
			lt := hd I.callstack;
			lc := tabget(lt, n.sval);
			if(lc != nil){
				if(lc.flags & ISARR)
					runerr(I, "scalar/array conflict for "+n.sval);
				lc.sval = v.sval; lc.nval = v.nval;
				lc.flags = v.flags & ~ISARR;
				return v;
			}
		}
		c := getlvaluecell(I, n.sval);
		c.sval = v.sval; c.nval = v.nval;
		c.flags = v.flags & ~ISARR;
		if(n.sval == "NF") setnf(I, celltoint(c));
		# FS/OFS/RS/ORS etc don't need explicit triggers — they're read on demand
		return v;
	NIDX =>
		idx := celltostr(eval(I, n.kids[0]));
		arr := getarrcell(I, n.sval);
		nc := newcell();
		nc.sval = v.sval; nc.nval = v.nval; nc.flags = v.flags & ~ISARR;
		tabput(arr.arr, idx, nc);
		return v;
	NFIELD =>
		i := celltoint(eval(I, n.kids[0]));
		setfield(I, i, celltostr(v));
		return v;
	}
	runerr(I, "non-lvalue in assignment");
	return v;
}

# -------------- Statements --------------

execstmt(I: ref Interp, n: ref Node)
{
	if(n == nil) return;
	if(I.cf_break || I.cf_continue || I.cf_next || I.cf_exit || I.cf_return)
		return;
	case n.kind {
	NBLOCK =>
		for(i := 0; i < len n.kids; i++){
			execstmt(I, n.kids[i]);
			if(I.cf_break || I.cf_continue || I.cf_next || I.cf_exit || I.cf_return)
				return;
		}
	NEXPR =>
		eval(I, n.kids[0]);
	NIF =>
		if(celltrue(eval(I, n.kids[0])))
			execstmt(I, n.kids[1]);
		else
			execstmt(I, n.kids[2]);
	NWHILE =>
		while(celltrue(eval(I, n.kids[0]))){
			execstmt(I, n.kids[1]);
			if(I.cf_break){ I.cf_break = 0; break; }
			if(I.cf_continue){ I.cf_continue = 0; continue; }
			if(I.cf_next || I.cf_exit || I.cf_return) return;
		}
	NDO =>
		do {
			execstmt(I, n.kids[0]);
			if(I.cf_break){ I.cf_break = 0; break; }
			if(I.cf_continue){ I.cf_continue = 0; }
			if(I.cf_next || I.cf_exit || I.cf_return) return;
		} while(celltrue(eval(I, n.kids[1])));
	NFOR =>
		if(n.kids[0] != nil) eval(I, n.kids[0]);
		for(;;){
			if(n.kids[1] != nil && !celltrue(eval(I, n.kids[1]))) break;
			execstmt(I, n.kids[3]);
			if(I.cf_break){ I.cf_break = 0; break; }
			if(I.cf_continue){ I.cf_continue = 0; }
			if(I.cf_next || I.cf_exit || I.cf_return) return;
			if(n.kids[2] != nil) eval(I, n.kids[2]);
		}
	NFORIN =>
		# iterate over array's keys (snapshot)
		arrname := n.kids[0].sval;
		var := n.sval;
		# resolve array (locals first)
		arr: ref Cell;
		if(I.callstack != nil){
			lt := hd I.callstack;
			arr = tabget(lt, arrname);
		}
		if(arr == nil)
			arr = tabget(I.globals, arrname);
		if(arr == nil || !(arr.flags & ISARR))
			break;
		keys := tabkeys(arr.arr);
		for(; keys != nil; keys = tl keys){
			k := hd keys;
			c := newcellstr(k);
			# assign to var (treat as scalar local/global)
			vn := newnode(); vn.kind = NVAR; vn.sval = var;
			assignto(I, vn, c);
			execstmt(I, n.kids[1]);
			if(I.cf_break){ I.cf_break = 0; return; }
			if(I.cf_continue){ I.cf_continue = 0; continue; }
			if(I.cf_next || I.cf_exit || I.cf_return) return;
		}
	NBREAK => I.cf_break = 1;
	NCONTINUE => I.cf_continue = 1;
	NNEXT => I.cf_next = 1;
	NEXIT =>
		if(n.kids[0] != nil)
			I.exitcode = celltoint(eval(I, n.kids[0]));
		I.cf_exit = 1;
	NRETURN =>
		if(n.kids[0] != nil)
			I.retval = eval(I, n.kids[0]);
		else
			I.retval = newcellstr("");
		I.cf_return = 1;
	NDELETE =>
		# resolve array
		arr: ref Cell;
		if(I.callstack != nil){
			lt := hd I.callstack;
			arr = tabget(lt, n.sval);
		}
		if(arr == nil)
			arr = tabget(I.globals, n.sval);
		if(arr == nil) break;
		if(!(arr.flags & ISARR)) runerr(I, "delete: not an array: "+n.sval);
		if(len n.kids == 0){
			arr.arr = newtab();
		} else {
			idx := celltostr(eval(I, n.kids[0]));
			tabdel(arr.arr, idx);
		}
	NPRINT =>
		doprint(I, n);
	NPRINTF =>
		doprintf(I, n);
	* =>
		# expression at stmt level
		eval(I, n);
	}
}

# -------------- print / printf --------------

# Resolve a print redirection — returns an FD or nil for stdout.
# kind: RNONE/RFILE/RAPP/RPIPE
resolveredir(I: ref Interp, rkind: int, rexpr: ref Node): ref FD
{
	if(rkind == RNONE) return nil;
	name := celltostr(eval(I, rexpr));
	if(rkind == RFILE || rkind == RAPP){
		mode := 1;
		if(rkind == RAPP) mode = 2;
		# search openfiles
		for(l := I.openfiles; l != nil; l = tl l){
			(nm, fd, mo) := hd l;
			if(nm == name && mo == mode) return fd;
		}
		fd: ref FD;
		if(rkind == RFILE){
			fd = sys->create(name, Sys->OWRITE, 8r644);
		} else {
			fd = sys->open(name, Sys->OWRITE);
			if(fd == nil)
				fd = sys->create(name, Sys->OWRITE, 8r644);
			else {
				# seek to end
				sys->seek(fd, big 0, Sys->SEEKEND);
			}
		}
		if(fd == nil) runerr(I, "cannot open "+name);
		I.openfiles = (name, fd, mode) :: I.openfiles;
		return fd;
	}
	if(rkind == RPIPE){
		# search openpipes
		for(l := I.openpipes; l != nil; l = tl l){
			(nm, fd, nil, nil) := hd l;
			if(nm == name) return fd;
		}
		(fd, done) := popencmd(I, name, 1);
		if(fd == nil) runerr(I, "cannot popen "+name);
		I.openpipes = (name, fd, 1, done) :: I.openpipes;
		return fd;
	}
	return nil;
}

loadsh(): int
{
	if(sh != nil) return 1;
	sh = load Sh Sh->PATH;
	return sh != nil;
}

# Spawned worker for output pipes (print x | cmd).
# Reads stdin from rfd; runs `sh -c cmd`; sync channel signals when fds are
# dup'd into place so the parent can safely close its copy. The done
# channel is signalled once the command finishes, so we can wait for child
# completion when closing the pipe.

popen_read_worker(wfd: ref FD, cmd: string, sync: chan of int, done: chan of int)
{
	sys->pctl(Sys->FORKFD, nil);
	sys->dup(wfd.fd, 1);
	wfd = nil;
	sync <-= 0;
	if(sh != nil)
		sh->system(nil, cmd);
	done <-= 0;
}

# Open a pipe to a command. forwrite=1 → we write, command reads later.
# For write-mode we buffer to a tmp file and run the command on close; we
# avoid spawning a sh coroutine that keeps emu alive after awk exits.
# For read-mode we use a real pipe + spawn.
popencmd(I: ref Interp, cmd: string, forwrite: int): (ref FD, chan of int)
{
	I = I;
	if(!loadsh()){
		sys->fprint(sys->fildes(2), "awk: cannot load %s: %r\n", Sh->PATH);
		return (nil, nil);
	}
	if(forwrite){
		# Open a temp file; later, at close, run `sh -c "cmd < tmpfile"`.
		# Tmp filename based on millisec + cmd hash for uniqueness.
		nm := "/tmp/awkpipe." + string sys->millisec();
		fd := sys->create(nm, Sys->ORDWR, 8r644);
		if(fd == nil){
			sys->fprint(sys->fildes(2), "awk: cannot create %s: %r\n", nm);
			return (nil, nil);
		}
		# Track the tmp path so we can clean up. Encode it in the done
		# channel's first message: we abuse the channel by passing nil here
		# and store path separately via the openpipes tuple convention.
		# Simpler: tag the FD object alone is enough; we keep cmd+path in a
		# side list. For now: keep a tiny global map.
		writepipe_register(nm, cmd);
		return (fd, nil);
	}
	# Read mode: real pipe + spawn.
	fds := array[2] of ref FD;
	if(sys->pipe(fds) < 0){
		sys->fprint(sys->fildes(2), "awk: pipe failed: %r\n");
		return (nil, nil);
	}
	sync := chan of int;
	done := chan[1] of int;
	spawn popen_read_worker(fds[1], cmd, sync, done);
	<-sync;
	fds[1] = nil;
	return (fds[0], done);
}

# Side map for write-pipes: tmp path → command to run at close.
writepipes: list of (string, string);

writepipe_register(path: string, cmd: string)
{
	writepipes = (path, cmd) :: writepipes;
}

# Called at the very end of run() to flush all buffered write-pipes.
flush_write_pipes()
{
	if(sh == nil) return;
	for(l := writepipes; l != nil; l = tl l){
		(path, cmd) := hd l;
		# Build a sub-command that pipes the tmp file into the user's command.
		full := "cat " + path + " | (" + cmd + ")";
		sh->system(nil, full);
		sys->remove(path);
	}
	writepipes = nil;
}

writefd(fd: ref FD, s: string)
{
	if(fd == nil)
		sys->print("%s", s);
	else {
		a := array of byte s;
		sys->write(fd, a, len a);
	}
}

doprint(I: ref Interp, n: ref Node)
{
	# n.kids[0..len-2] are args; n.kids[len-1] is redir expr (may be nil)
	nargs := len n.kids - 1;
	rexpr := n.kids[nargs];
	fd := resolveredir(I, n.iv, rexpr);
	ofs := getvarstr(I, "OFS");
	ors := getvarstr(I, "ORS");
	if(nargs == 0 || (nargs == 1 && n.kids[0] == nil)){
		writefd(fd, I.record);
		writefd(fd, ors);
		return;
	}
	out := "";
	for(i := 0; i < nargs; i++){
		if(i > 0) out += ofs;
		c := eval(I, n.kids[i]);
		# numeric-only cells get OFMT treatment (otherwise their string form)
		if((c.flags & HASNUM) && !(c.flags & HASSTR))
			out += numtostrofmt(I, c.nval);
		else
			out += celltostr(c);
	}
	out += ors;
	writefd(fd, out);
}

doprintf(I: ref Interp, n: ref Node)
{
	nargs := len n.kids - 1;
	rexpr := n.kids[nargs];
	fd := resolveredir(I, n.iv, rexpr);
	if(nargs < 1) runerr(I, "printf with no format");
	fmt := celltostr(eval(I, n.kids[0]));
	args := array[nargs - 1] of ref Cell;
	for(i := 1; i < nargs; i++)
		args[i-1] = eval(I, n.kids[i]);
	s := awksprintf(I, fmt, args);
	writefd(fd, s);
}

# -------------- AWK printf-style formatting --------------
# Supports: %d, %i, %o, %x, %X, %u, %c, %s, %e, %E, %f, %g, %G, %%
# Flags: - + space # 0
# Width and precision (including *)

hasflag(flags: string, f: int): int
{
	for(i := 0; i < len flags; i++)
		if(flags[i] == f) return 1;
	return 0;
}

strtoupper(s: string): string
{
	r := s;
	for(i := 0; i < len r; i++)
		if(r[i] >= 'a' && r[i] <= 'z') r[i] = r[i] - 'a' + 'A';
	return r;
}

# right- or left-pad s to width using ch (' ' default).
padstr(s: string, flags: string, width: int): string
{
	if(width < 0 || len s >= width) return s;
	pad := width - len s;
	p := "";
	for(i := 0; i < pad; i++) p[len p] = ' ';
	if(hasflag(flags, '-')) return s + p;
	return p + s;
}

# pad a string field, applying precision (max length).
fmtstr(s: string, flags: string, width: int, prec: int): string
{
	if(prec >= 0 && prec < len s) s = s[0:prec];
	return padstr(s, flags, width);
}

# Format unsigned-int-like with given base. Negative values are treated as 2's-complement bit pattern.
# But awk integers are real-derived, so we just print the bit pattern in given base for negatives.
fmtuint(v: int, flags: string, width: int, prec: int, base: int): string
{
	# For unsigned, treat v as bit pattern.
	# Build digit string.
	digits := "0123456789abcdef";
	body := "";
	uv := v;	# already 32-bit
	if(uv == 0){
		body = "0";
	} else {
		# extract digits without sign issues: use unsigned shift for binary bases.
		# For base 8 and 16, we can do bitwise. For base 10, more complex.
		if(base == 16){
			while(uv != 0){
				d := uv & 16rF;
				body = digits[d:d+1] + body;
				uv = (uv >> 4) & 16r0FFFFFFF;
			}
		} else if(base == 8){
			while(uv != 0){
				d := uv & 7;
				body = digits[d:d+1] + body;
				uv = (uv >> 3) & 16r1FFFFFFF;
			}
		} else {
			# base 10 unsigned: if negative, convert via big
			if(uv >= 0){
				while(uv != 0){
					d := uv % 10;
					body = digits[d:d+1] + body;
					uv = uv / 10;
				}
			} else {
				bv := big uv & big 16rFFFFFFFF;
				while(bv != big 0){
					d := int (bv % big 10);
					body = digits[d:d+1] + body;
					bv = bv / big 10;
				}
			}
		}
	}
	# # flag adds 0x/0X for hex, 0 for octal
	prefix := "";
	if(hasflag(flags, '#') && v != 0){
		if(base == 16) prefix = "0x";
		else if(base == 8 && (len body == 0 || body[0] != '0')) prefix = "0";
	}
	# precision: minimum digits
	if(prec >= 0){
		while(len body < prec){
			body = "0" + body;
		}
		# precision forbids zero-padding via 0-flag
	} else if(hasflag(flags, '0') && !hasflag(flags, '-') && width > len body + len prefix){
		pad := width - len body - len prefix;
		for(i := 0; i < pad; i++) body = "0" + body;
	}
	r := prefix + body;
	return padstr(r, flags, width);
}

# Format signed int in base 10.
fmtint(v: int, flags: string, width: int, prec: int, base: int, unused: int): string
{
	unused = unused;
	base = base;
	neg := 0;
	if(v < 0){ neg = 1; v = -v; }
	digits := "0123456789";
	body := "";
	if(v == 0){
		body = "0";
	} else {
		while(v != 0){
			d := v % 10;
			body = digits[d:d+1] + body;
			v = v / 10;
		}
	}
	# precision: minimum digits
	if(prec >= 0){
		while(len body < prec) body = "0" + body;
		# if precision=0 and value=0, body should be empty
		if(prec == 0 && body == "0") body = "";
	}
	sign := "";
	if(neg) sign = "-";
	else if(hasflag(flags, '+')) sign = "+";
	else if(hasflag(flags, ' ')) sign = " ";
	# 0-flag padding (no precision)
	if(prec < 0 && hasflag(flags, '0') && !hasflag(flags, '-') && width > len body + len sign){
		pad := width - len body - len sign;
		for(i := 0; i < pad; i++) body = "0" + body;
	}
	r := sign + body;
	return padstr(r, flags, width);
}

# Convert a non-negative real to a decimal string with given digit precision (n digits after decimal).
real_to_fixed(v: real, prec: int): string
{
	if(prec < 0) prec = 6;
	# multiply by 10^prec, round to nearest, then floor to get an exact integer
	mult := 1.0;
	for(i := 0; i < prec; i++) mult = mult * 10.0;
	scaled := v * mult;
	neg := 0;
	if(scaled < 0.0){ neg = 1; scaled = -scaled; }
	scaled += 0.5;
	floored := realfloor(scaled);
	# Convert exact-integer-valued real to its digit string. We can't use
	# `big floored` because that runtime path applies a rounding mode that
	# differs from truncate/floor on this 64-bit Inferno port.
	# Strategy: use sys->sprint("%.0f", floored), which gives the correct
	# unsigned integer literal (Sys formats reals correctly).
	s := sys->sprint("%.0f", floored);
	# pad with leading zeros if needed
	if(prec > 0){
		while(len s <= prec) s = "0" + s;
		whole := s[0:len s - prec];
		frac := s[len s - prec:];
		s = whole + "." + frac;
	}
	if(neg) s = "-" + s;
	return s;
}

# %f
fmtreal_f(v: real, prec: int): string
{
	if(prec < 0) prec = 6;
	if(v != v){ return "nan"; }	# NaN
	# Infinity check: comparing to large value
	if(v > 1e308 || v < -1e308){
		if(v > 0.0) return "inf";
		return "-inf";
	}
	return real_to_fixed(v, prec);
}

# %e/%E: m.dddde±xx
fmtreal_e(v: real, prec: int, upcase: int): string
{
	if(prec < 0) prec = 6;
	if(v != v) return "nan";
	if(v == 0.0){
		body := "0";
		if(prec > 0){
			body += ".";
			for(i := 0; i < prec; i++) body += "0";
		}
		if(upcase) body += "E+00";
		else body += "e+00";
		return body;
	}
	neg := 0;
	if(v < 0.0){ neg = 1; v = -v; }
	# normalize: find exponent
	exp := 0;
	while(v >= 10.0){ v = v / 10.0; exp++; }
	while(v < 1.0){ v = v * 10.0; exp--; }
	# now 1 <= v < 10
	mant := real_to_fixed(v, prec);
	# It might round up to 10.000... -> re-normalize
	if(len mant > 0 && mant[0] == '1' && len mant > 1 && mant[1] == '0' && (len mant == 2 || mant[2] == '.')){
		# was 10.000... after rounding? Actually mant starts with single digit; check.
	}
	# Simpler: if mant >= "10", shift.
	# Check first digit
	intpart := mant;
	dot := -1;
	for(i := 0; i < len mant; i++) if(mant[i] == '.'){ dot = i; break; }
	if(dot >= 0) intpart = mant[0:dot];
	if(len intpart >= 2){
		# rounding bumped to 10 — shift decimal
		exp++;
		# move decimal left by one
		if(dot < 0){
			# no dot, mant is like "10"
			mant = mant[0:1] + "." + mant[1:];
			# trim trailing if needed
		} else {
			mant = mant[0:1] + "." + mant[1:dot] + mant[dot+1:];
		}
		# ensure prec digits
		# (approximate; close enough for awk)
	}
	esign := "+";
	aexp := exp;
	if(aexp < 0){ esign = "-"; aexp = -aexp; }
	estr := "";
	if(aexp < 10) estr = "0" + sys->sprint("%d", aexp);
	else estr = sys->sprint("%d", aexp);
	r := mant;
	if(upcase) r += "E" + esign + estr;
	else r += "e" + esign + estr;
	if(neg) r = "-" + r;
	return r;
}

# %g/%G: shortest of %e and %f
fmtreal_g(v: real, prec: int, upcase: int): string
{
	if(prec < 0) prec = 6;
	if(prec == 0) prec = 1;
	if(v != v) return "nan";
	# Determine exponent
	av := v;
	if(av < 0.0) av = -av;
	exp := 0;
	if(av != 0.0){
		t := av;
		while(t >= 10.0){ t = t / 10.0; exp++; }
		while(t < 1.0){ t = t * 10.0; exp--; }
	}
	s: string;
	if(exp < -4 || exp >= prec){
		s = fmtreal_e(v, prec - 1, upcase);
		# trim trailing zeros from mantissa before 'e'/'E'
		ep := -1;
		for(i := 0; i < len s; i++)
			if(s[i] == 'e' || s[i] == 'E'){ ep = i; break; }
		if(ep > 0){
			mant := s[0:ep];
			erest := s[ep:];
			# trim if it has a dot
			hasdot := 0;
			for(j := 0; j < len mant; j++) if(mant[j] == '.'){ hasdot = 1; break; }
			if(hasdot){
				end := len mant;
				while(end > 0 && mant[end-1] == '0') end--;
				if(end > 0 && mant[end-1] == '.') end--;
				mant = mant[0:end];
			}
			s = mant + erest;
		}
		return s;
	}
	# use %f with prec - 1 - exp digits after decimal
	digafter := prec - 1 - exp;
	if(digafter < 0) digafter = 0;
	s = fmtreal_f(v, digafter);
	# trim trailing zeros after a dot (unless # flag — not handled here)
	if(s != ""){
		hasdot := 0;
		for(i := 0; i < len s; i++) if(s[i] == '.'){ hasdot = 1; break; }
		if(hasdot){
			end := len s;
			while(end > 0 && s[end-1] == '0') end--;
			if(end > 0 && s[end-1] == '.') end--;
			s = s[0:end];
		}
	}
	return s;
}

awksprintf(I: ref Interp, fmt: string, args: array of ref Cell): string
{
	I = I;
	out := "";
	ai := 0;
	i := 0;
	while(i < len fmt){
		c := fmt[i];
		if(c != '%'){
			out[len out] = c;
			i++;
			continue;
		}
		# parse flags, width, precision
		i++;
		flags := "";
		while(i < len fmt){
			f := fmt[i];
			if(f == '-' || f == '+' || f == ' ' || f == '#' || f == '0'){
				flags[len flags] = f;
				i++;
			} else break;
		}
		width := -1;
		if(i < len fmt && fmt[i] == '*'){
			i++;
			if(ai < len args) width = celltoint(args[ai++]);
		} else {
			if(i < len fmt && fmt[i] >= '0' && fmt[i] <= '9'){
				width = 0;
				while(i < len fmt && fmt[i] >= '0' && fmt[i] <= '9'){
					width = width * 10 + (fmt[i] - '0');
					i++;
				}
			}
		}
		prec := -1;
		if(i < len fmt && fmt[i] == '.'){
			i++;
			if(i < len fmt && fmt[i] == '*'){
				i++;
				if(ai < len args) prec = celltoint(args[ai++]);
			} else {
				prec = 0;
				while(i < len fmt && fmt[i] >= '0' && fmt[i] <= '9'){
					prec = prec * 10 + (fmt[i] - '0');
					i++;
				}
			}
		}
		if(i >= len fmt) break;
		conv := fmt[i];
		i++;
		# build a sys->sprint format and use it where possible
		# (Inferno's sprint supports many of these.)
		fspec := "%" + flags;
		if(width >= 0) fspec += sys->sprint("%d", width);
		if(prec >= 0) fspec += "." + sys->sprint("%d", prec);
		case conv {
		'%' => out[len out] = '%';
		's' =>
			s := "";
			if(ai < len args) s = celltostr(args[ai++]);
			out += fmtstr(s, flags, width, prec);
		'c' =>
			cc := 0;
			if(ai < len args){
				a := args[ai++];
				if((a.flags & HASSTR) && !(a.flags & HASNUM)){
					if(len a.sval > 0) cc = a.sval[0];
				} else {
					cc = celltoint(a);
				}
			}
			ss := ""; ss[0] = cc;
			out += fmtstr(ss, flags, width, prec);
		'd' or 'i' =>
			v := 0;
			if(ai < len args) v = celltoint(args[ai++]);
			out += fmtint(v, flags, width, prec, 10, 0);
		'o' =>
			v := 0;
			if(ai < len args) v = celltoint(args[ai++]);
			out += fmtuint(v, flags, width, prec, 8);
		'x' =>
			v := 0;
			if(ai < len args) v = celltoint(args[ai++]);
			out += fmtuint(v, flags, width, prec, 16);
		'X' =>
			v := 0;
			if(ai < len args) v = celltoint(args[ai++]);
			out += strtoupper(fmtuint(v, flags, width, prec, 16));
		'u' =>
			v := 0;
			if(ai < len args) v = celltoint(args[ai++]);
			out += fmtuint(v, flags, width, prec, 10);
		'e' or 'E' =>
			v := 0.0;
			if(ai < len args) v = celltonum(args[ai++]);
			s := fmtreal_e(v, prec, conv == 'E');
			out += padstr(s, flags, width);
		'f' =>
			v := 0.0;
			if(ai < len args) v = celltonum(args[ai++]);
			s := fmtreal_f(v, prec);
			out += padstr(s, flags, width);
		'g' or 'G' =>
			v := 0.0;
			if(ai < len args) v = celltonum(args[ai++]);
			s := fmtreal_g(v, prec, conv == 'G');
			out += padstr(s, flags, width);
		* =>
			# unknown: copy verbatim
			out[len out] = '%';
			out[len out] = conv;
		}
		# fspec was only here for old logic; reference to silence unused var
		fspec = fspec;
	}
	return out;
}

# -------------- Function call --------------

docall(I: ref Interp, n: ref Node): ref Cell
{
	fc := tabget(I.prog.funcsym, n.sval);
	if(fc == nil || !(fc.flags & ISFUNC))
		runerr(I, "call to undefined function "+n.sval);
	fd := I.prog.funcs[fc.fnidx];
	# evaluate args
	# For array args (var that names an array), pass by reference.
	nact := len n.kids;
	npar := len fd.params;
	loctab := newtab();
	for(i := 0; i < npar; i++){
		nc := newcell();
		if(i < nact){
			a := n.kids[i];
			# Array pass-by-reference. If actual is a plain var that:
			#   - already exists as an array → share the same Cell
			#   - doesn't exist yet → create a fresh array in the caller's
			#     scope and share it (so the callee's modifications persist).
			#   - exists as scalar → fall through to value semantics.
			if(a.kind == NVAR){
				ec: ref Cell;
				inlocal := 0;
				if(I.callstack != nil){
					lt := hd I.callstack;
					ec = tabget(lt, a.sval);
					if(ec != nil) inlocal = 1;
				}
				if(ec == nil) ec = tabget(I.globals, a.sval);
				if(ec != nil && (ec.flags & ISARR)){
					tabput(loctab, fd.params[i], ec);
					continue;
				}
				if(ec == nil || !(ec.flags & (HASSTR|HASNUM))){
					# Uninitialized (or freshly-created empty) var: promote
					# to an array and share with the callee. Create it in
					# whichever caller scope is active.
					arrcell := newcell();
					arrcell.flags = ISARR;
					arrcell.arr = newtab();
					if(inlocal){
						lt := hd I.callstack;
						tabput(lt, a.sval, arrcell);
					} else {
						tabput(I.globals, a.sval, arrcell);
					}
					tabput(loctab, fd.params[i], arrcell);
					continue;
				}
				# exists as scalar — value semantics below
			}
			# value semantics
			v := eval(I, a);
			nc.sval = v.sval;
			nc.nval = v.nval;
			nc.flags = v.flags & ~ISARR;
		}
		tabput(loctab, fd.params[i], nc);
	}
	I.callstack = loctab :: I.callstack;
	saveret := I.retval;
	I.retval = nil;
	execstmt(I, fd.body);
	I.cf_return = 0;
	rv := I.retval;
	I.retval = saveret;
	I.callstack = tl I.callstack;
	if(rv == nil) rv = newcellstr("");
	return rv;
}

# -------------- Built-in functions --------------

dobuiltin(I: ref Interp, n: ref Node): ref Cell
{
	case n.iv {
	BLEN =>
		if(len n.kids == 0)
			return newcellnum(real len I.record);
		c := eval(I, n.kids[0]);
		if(c.flags & ISARR)
			return newcellnum(real c.arr.n);
		return newcellnum(real len celltostr(c));
	BSUBSTR =>
		if(len n.kids < 2) runerr(I, "substr: too few args");
		s := celltostr(eval(I, n.kids[0]));
		m := celltoint(eval(I, n.kids[1]));
		# AWK substr is 1-based; clamps
		nch := -1;
		if(len n.kids >= 3) nch = celltoint(eval(I, n.kids[2]));
		# compute start/end as in awk:
		if(m < 1){
			if(nch >= 0) nch = nch + m - 1;
			m = 1;
		}
		if(m > len s) return newcellstr("");
		start := m - 1;
		end: int;
		if(nch < 0)
			end = len s;
		else {
			end = start + nch;
			if(end > len s) end = len s;
			if(end < start) end = start;
		}
		return newcellstr(s[start:end]);
	BINDEX =>
		if(len n.kids < 2) return newcellnum(0.0);
		s := celltostr(eval(I, n.kids[0]));
		t := celltostr(eval(I, n.kids[1]));
		if(t == "") return newcellnum(0.0);
		for(i := 0; i + len t <= len s; i++)
			if(s[i:i+len t] == t)
				return newcellnum(real (i + 1));
		return newcellnum(0.0);
	BSPLIT =>
		if(len n.kids < 2) runerr(I, "split: too few args");
		s := celltostr(eval(I, n.kids[0]));
		# arg 1 must be array
		if(n.kids[1].kind != NVAR) runerr(I, "split: second arg must be array name");
		arrname := n.kids[1].sval;
		arr := getarrcell(I, arrname);
		arr.arr = newtab();
		fs := getvarstr(I, "FS");
		if(len n.kids >= 3){
			# if it's a regex literal, use its text; else convert to string
			fs = celltostr(eval(I, n.kids[2]));
		}
		flds := splitbyfs(s, fs);
		for(i := 0; i < len flds; i++)
			tabput(arr.arr, sys->sprint("%d", i+1), newcellnumstr(flds[i]));
		return newcellnum(real len flds);
	BSPRINTF =>
		if(len n.kids < 1) return newcellstr("");
		fmt := celltostr(eval(I, n.kids[0]));
		ar := array[len n.kids - 1] of ref Cell;
		for(i := 1; i < len n.kids; i++)
			ar[i-1] = eval(I, n.kids[i]);
		return newcellstr(awksprintf(I, fmt, ar));
	BSUB or BGSUB =>
		# sub(r, repl [, target]) -- target defaults to $0
		if(len n.kids < 2) runerr(I, "sub/gsub: too few args");
		r := getregex(n.kids[0], I);
		repl := celltostr(eval(I, n.kids[1]));
		tgt := n.kids[0];	# placeholder
		isgsub := (n.iv == BGSUB);
		# target node
		tnode: ref Node;
		if(len n.kids >= 3) tnode = n.kids[2];
		else { tnode = newnode(); tnode.kind = NFIELD;
			tnode.kids = array[1] of ref Node;
			zn := newnode(); zn.kind = NNUM; zn.nval = 0.0;
			tnode.kids[0] = zn;
		}
		oldstr := celltostr(eval(I, tnode));
		(newstr, nsubs) := dosubst(r, repl, oldstr, isgsub);
		assignto(I, tnode, newcellstr(newstr));
		tgt = tgt;
		return newcellnum(real nsubs);
	BMATCH =>
		if(len n.kids < 2) runerr(I, "match: too few args");
		s := celltostr(eval(I, n.kids[0]));
		r := getregex(n.kids[1], I);
		(ms, me) := research(r, s);
		if(ms < 0){
			setvarnum(I, "RSTART", 0.0);
			setvarnum(I, "RLENGTH", -1.0);
			return newcellnum(0.0);
		}
		setvarnum(I, "RSTART", real (ms + 1));
		setvarnum(I, "RLENGTH", real (me - ms));
		return newcellnum(real (ms + 1));
	BSIN =>
		v := 0.0; if(len n.kids > 0) v = celltonum(eval(I, n.kids[0]));
		return newcellnum(realsin_(v));
	BCOS =>
		v := 0.0; if(len n.kids > 0) v = celltonum(eval(I, n.kids[0]));
		return newcellnum(realcos_(v));
	BATAN2 =>
		y := 0.0; x := 0.0;
		if(len n.kids > 0) y = celltonum(eval(I, n.kids[0]));
		if(len n.kids > 1) x = celltonum(eval(I, n.kids[1]));
		return newcellnum(realatan2_(y, x));
	BEXP =>
		v := 0.0; if(len n.kids > 0) v = celltonum(eval(I, n.kids[0]));
		return newcellnum(realexp_(v));
	BLOG =>
		v := 0.0; if(len n.kids > 0) v = celltonum(eval(I, n.kids[0]));
		return newcellnum(reallog_(v));
	BSQRT =>
		v := 0.0; if(len n.kids > 0) v = celltonum(eval(I, n.kids[0]));
		return newcellnum(realsqrt_(v));
	BINT =>
		v := 0.0; if(len n.kids > 0) v = celltonum(eval(I, n.kids[0]));
		# AWK int() truncates toward zero. The 64-bit Inferno runtime's
		# `big real` conversion uses a rounding mode that is neither floor
		# nor truncate (0.5 -> 1, -0.5 -> -4), so we do it ourselves:
		# subtract the fractional part.
		return newcellnum(realtrunc(v));
	BRAND =>
		# LCG
		I.rseed = I.rseed * 1103515245 + 12345;
		x := (I.rseed >> 16) & 16r7fff;
		return newcellnum(real x / 32768.0);
	BSRAND =>
		old := I.rseed;
		if(len n.kids == 0)
			I.rseed = sys->millisec();
		else
			I.rseed = celltoint(eval(I, n.kids[0]));
		return newcellnum(real old);
	BTOLOWER =>
		if(len n.kids == 0) return newcellstr("");
		s := celltostr(eval(I, n.kids[0]));
		out := s;
		for(i := 0; i < len out; i++)
			if(out[i] >= 'A' && out[i] <= 'Z')
				out[i] = out[i] + ('a' - 'A');
		return newcellstr(out);
	BTOUPPER =>
		if(len n.kids == 0) return newcellstr("");
		s := celltostr(eval(I, n.kids[0]));
		out := s;
		for(i := 0; i < len out; i++)
			if(out[i] >= 'a' && out[i] <= 'z')
				out[i] = out[i] - ('a' - 'A');
		return newcellstr(out);
	BSYSTEM =>
		if(len n.kids == 0) return newcellnum(0.0);
		cmd := celltostr(eval(I, n.kids[0]));
		if(!loadsh()){
			sys->fprint(sys->fildes(2), "awk: cannot load %s for system(): %r\n", Sh->PATH);
			return newcellnum(-1.0);
		}
		# sh->system runs the command synchronously and returns nil on success
		# (or an error string). We map nil → 0, anything else → 1 so callers
		# can branch on truthiness; AWK has no portable convention for the
		# precise exit code.
		err := sh->system(nil, cmd);
		if(err == nil) return newcellnum(0.0);
		return newcellnum(1.0);
	}
	runerr(I, "unknown builtin");
	return nil;
}

# Perform sub/gsub substitution. Repl may contain '&' (whole match) and
# '\&' (literal &).
dosubst(r: ref Regex, repl: string, src: string, global: int): (string, int)
{
	if(r == nil) return (src, 0);
	out := "";
	count := 0;
	i := 0;
	while(i <= len src){
		e := rematchat(r, src, i);
		if(e < 0){
			# step
			if(i < len src){
				out[len out] = src[i];
				i++;
				continue;
			}
			break;
		}
		matched := src[i:e];
		# emit replacement
		j := 0;
		while(j < len repl){
			c := repl[j];
			if(c == '\\' && j+1 < len repl){
				nc := repl[j+1];
				if(nc == '&'){
					out[len out] = '&';
					j += 2;
					continue;
				}
				if(nc == '\\'){
					out[len out] = '\\';
					j += 2;
					continue;
				}
				out[len out] = c;
				j++;
				continue;
			}
			if(c == '&'){
				out += matched;
				j++;
				continue;
			}
			out[len out] = c;
			j++;
		}
		count++;
		if(e == i){
			# zero-length match: emit current char to avoid infinite loop
			if(i < len src){
				out[len out] = src[i];
				i++;
			} else break;
		} else {
			i = e;
		}
		if(!global){
			# emit rest as-is
			if(i < len src) out += src[i:];
			return (out, count);
		}
	}
	return (out, count);
}

# -------------- getline --------------

dogetline(I: ref Interp, n: ref Node): ref Cell
{
	# Forms:
	#   getline                     — read next line from current input into $0
	#   getline var                 — into var
	#   getline < file              — from file into $0
	#   getline var < file          — from file into var
	#   cmd | getline [var]         — not parsed here (would require LHS form)
	# n.iv == 1 means from file (n.kids[1] is file expr)
	var := n.kids[0];	# may be nil
	fileexpr := n.kids[1];
	line: string;
	gotline := 0;
	bumpNR := 1;
	if(n.iv == 1 && fileexpr != nil){
		fname := celltostr(eval(I, fileexpr));
		fd := openfileforread(I, fname);
		if(fd == nil) return newcellnum(-1.0);
		(ok, s) := readlinefd(fd, getvarstr(I, "RS"));
		if(!ok) return newcellnum(0.0);
		line = s;
		gotline = 1;
		bumpNR = 0;	# from file, NR not bumped (FNR not maintained for these)
	} else if(n.iv == 2 && fileexpr != nil){
		# cmd | getline: spawn the command once and cache the pipe by cmd string
		cmd := celltostr(eval(I, fileexpr));
		fd: ref FD;
		for(pl := I.inpipes; pl != nil; pl = tl pl){
			(pnm, pf, nil) := hd pl;
			if(pnm == cmd){ fd = pf; break; }
		}
		if(fd == nil){
			(nfd, done) := popencmd(I, cmd, 0);
			if(nfd == nil) return newcellnum(-1.0);
			fd = nfd;
			I.inpipes = (cmd, fd, done) :: I.inpipes;
		}
		(ok, s) := readlinefd(fd, getvarstr(I, "RS"));
		if(!ok) return newcellnum(0.0);
		line = s;
		gotline = 1;
		bumpNR = 0;
	} else {
		# read from main input
		(ok, s) := readmainline(I);
		if(!ok) return newcellnum(0.0);
		line = s;
		gotline = 1;
	}
	if(!gotline) return newcellnum(0.0);
	if(bumpNR){
		nr := getvarnum(I, "NR") + 1.0;
		setvarnum(I, "NR", nr);
		fnr := getvarnum(I, "FNR") + 1.0;
		setvarnum(I, "FNR", fnr);
	}
	if(var == nil){
		I.record = line;
		splitfields(I);
	} else {
		# assign to var; if var is treated as numeric string, fine
		assignto(I, var, newcellnumstr(line));
	}
	return newcellnum(1.0);
}

# -------------- File / input helpers --------------

openfileforread(I: ref Interp, name: string): ref FD
{
	for(l := I.openfiles; l != nil; l = tl l){
		(nm, fd, mode) := hd l;
		if(nm == name && mode == 0) return fd;
	}
	fd := sys->open(name, Sys->OREAD);
	if(fd == nil) return nil;
	I.openfiles = (name, fd, 0) :: I.openfiles;
	return fd;
}

# Simple line reader: reads up to and including RS (single char or "\n").
# Doesn't aggressively buffer — adequate for typical scripts.
ReadBufs: adt {
	bufs:	list of (ref FD, string);
};

readBufs: ref ReadBufs;

getbuf(fd: ref FD): string
{
	if(readBufs == nil){ readBufs = ref ReadBufs; readBufs.bufs = nil; }
	for(l := readBufs.bufs; l != nil; l = tl l){
		(f, b) := hd l;
		if(f == fd) return b;
	}
	return "";
}

setbuf(fd: ref FD, s: string)
{
	if(readBufs == nil){ readBufs = ref ReadBufs; readBufs.bufs = nil; }
	nl: list of (ref FD, string);
	found := 0;
	for(l := readBufs.bufs; l != nil; l = tl l){
		(f, b) := hd l;
		if(f == fd){ nl = (f, s) :: nl; found = 1; }
		else nl = (f, b) :: nl;
	}
	if(!found) nl = (fd, s) :: nl;
	readBufs.bufs = nl;
}

readlinefd(fd: ref FD, rs: string): (int, string)
{
	# refill buffer until we find RS or hit EOF
	buf := getbuf(fd);
	sep := '\n';
	if(len rs > 0) sep = rs[0];
	chunk := array[4096] of byte;
	for(;;){
		# look for separator
		for(i := 0; i < len buf; i++){
			if(buf[i] == sep){
				line := buf[0:i];
				rest := buf[i+1:];
				setbuf(fd, rest);
				return (1, line);
			}
		}
		# need more
		n := sys->read(fd, chunk, len chunk);
		if(n <= 0){
			# EOF: emit remaining buffer as final line
			if(len buf > 0){
				setbuf(fd, "");
				return (1, buf);
			}
			return (0, "");
		}
		buf += string chunk[0:n];
	}
	# unreachable
	# return (0, "");
}

# Read next line from main input — advances through filelist.
readmainline(I: ref Interp): (int, string)
{
	rs := getvarstr(I, "RS");
	for(;;){
		if(I.curfd == nil){
			# advance to next file (or stdin)
			if(I.filelist == nil){
				if(I.curfile == "" && I.stdinfd == nil){
					# first time: use stdin
					I.stdinfd = sys->fildes(0);
					I.curfd = I.stdinfd;
					I.curfile = "";
					setvarstr(I, "FILENAME", "");
					setvarnum(I, "FNR", 0.0);
				} else {
					return (0, "");
				}
			} else {
				name := hd I.filelist;
				I.filelist = tl I.filelist;
				if(name == "-"){
					I.curfd = sys->fildes(0);
					I.curfile = "";
				} else {
					I.curfd = sys->open(name, Sys->OREAD);
					if(I.curfd == nil){
						sys->fprint(sys->fildes(2), "awk: cannot open %s\n", name);
						continue;
					}
					I.curfile = name;
				}
				setvarstr(I, "FILENAME", I.curfile);
				setvarnum(I, "FNR", 0.0);
			}
		}
		(ok, s) := readlinefd(I.curfd, rs);
		if(!ok){
			# close (don't close stdin) and try next
			if(I.curfd != I.stdinfd){
				# don't try to keep cached
			}
			I.curfd = nil;
			continue;
		}
		return (1, s);
	}
	# return (0, "");
}

# -------------- Main run loop --------------

run(I: ref Interp, files: list of string)
{
	I.filelist = files;
	# BEGIN
	for(i := 0; i < len I.prog.begins; i++){
		execstmt(I, I.prog.begins[i]);
		if(I.cf_exit) break;
	}
	if(!I.cf_exit && len I.prog.rules > 0){
		# main loop
		# track range-pattern state for each rule
		rangestate := array[len I.prog.rules] of int;
		for(;;){
			(ok, line) := readmainline(I);
			if(!ok) break;
			nr := getvarnum(I, "NR") + 1.0;
			setvarnum(I, "NR", nr);
			fnr := getvarnum(I, "FNR") + 1.0;
			setvarnum(I, "FNR", fnr);
			I.record = line;
			splitfields(I);
			for(j := 0; j < len I.prog.rules; j++){
				r := I.prog.rules[j];
				pat := r.kids[0];
				act := r.kids[1];
				matched := 0;
				if(pat == nil){
					matched = 1;
				} else if(pat.kind == NPATACT){
					# range pattern: state[j]==0 not in range; ==1 in range
					if(rangestate[j] == 0){
						if(celltrue(eval(I, pat.kids[0]))){
							rangestate[j] = 1;
							matched = 1;
							# also test end on same record
							if(celltrue(eval(I, pat.kids[1])))
								rangestate[j] = 0;
						}
					} else {
						matched = 1;
						if(celltrue(eval(I, pat.kids[1])))
							rangestate[j] = 0;
					}
				} else {
					matched = celltrue(eval(I, pat));
				}
				if(matched && act != nil)
					execstmt(I, act);
				if(I.cf_next){ I.cf_next = 0; break; }
				if(I.cf_exit) break;
			}
			if(I.cf_exit) break;
		}
	}
	# END
	I.cf_exit = 0;
	for(k := 0; k < len I.prog.ends; k++){
		execstmt(I, I.prog.ends[k]);
		if(I.cf_exit) break;
	}
	# Close output pipes: drop our write end so the command sees EOF.
	# We don't wait for the child sh to finish - that can deadlock under
	# the 64-bit emu when sh->system spawns additional coroutines. The
	# parent shell can wait on awk's own exit, and ordering of stdout
	# is preserved because the command's output arrives via the pipe.
	for(pl := I.openpipes; pl != nil; pl = tl pl){
		(nil, fd, nil, nil) := hd pl;
		fd = nil;
	}
	I.openpipes = nil;
	for(il := I.inpipes; il != nil; il = tl il){
		(nil, fd, nil) := hd il;
		fd = nil;
	}
	I.inpipes = nil;
	I.openfiles = nil;
	# Flush buffered output pipes through sh now (this runs synchronously
	# in the same process; commands appear in order in stdout).
	flush_write_pipes();
}

# -------------- Entry point --------------

usage()
{
	sys->fprint(sys->fildes(2), "usage: awk [-F fs] [-v var=val] [-f file | 'program'] [file ...]\n");
	raise "fail:awkusage";
}

init(nil: ref Draw->Context, argv: list of string)
{
	sys = load Sys Sys->PATH;
	if(sys == nil){
		# can't even report properly
		return;
	}

	# Reset module-level state. awk.dis lives in the shell as a long-running
	# 64-bit module: each invocation must start with a clean slate, otherwise
	# read buffers from a previous run leak into this one.
	readBufs = nil;
	sh = nil;
	writepipes = nil;

	# skip the command name (conventional in Inferno argv)
	if(argv != nil)
		argv = tl argv;

	progtext := "";
	files: list of string;
	fsopt := "";
	vassigns: list of (string, string);

	# parse args
	while(argv != nil){
		a := hd argv;
		argv = tl argv;
		if(a == "-F"){
			if(argv == nil) usage();
			fsopt = hd argv;
			argv = tl argv;
			continue;
		}
		if(len a > 2 && a[0:2] == "-F"){
			fsopt = a[2:];
			continue;
		}
		if(a == "-v"){
			if(argv == nil) usage();
			va := hd argv;
			argv = tl argv;
			(nm, val) := splitassign(va);
			vassigns = (nm, val) :: vassigns;
			continue;
		}
		if(a == "-f"){
			if(argv == nil) usage();
			fname := hd argv;
			argv = tl argv;
			t := readfileall(fname);
			if(progtext != "") progtext += "\n";
			progtext += t;
			continue;
		}
		if(a == "--"){
			# rest are files
			for(; argv != nil; argv = tl argv)
				files = hd argv :: files;
			break;
		}
		if(len a > 0 && a[0] == '-' && a != "-"){
			# unknown flag
			sys->fprint(sys->fildes(2), "awk: unknown flag %s\n", a);
			usage();
		}
		# first non-flag is program text (if not yet set), rest are files
		if(progtext == ""){
			progtext = a;
		} else {
			files = a :: files;
		}
	}

	if(progtext == ""){
		usage();
	}

	# reverse files list
	rfiles: list of string;
	for(l := files; l != nil; l = tl l)
		rfiles = hd l :: rfiles;

	# parse
	p := newparser(progtext);
	prog: ref Program;
	{
		prog = parseprogram(p);
	} exception e {
	"fail:*" =>
		sys->fprint(sys->fildes(2), "awk: parse failed: %s\n", e);
		return;
	}

	I := newinterp(prog);
	# apply -v assignments BEFORE BEGIN
	for(va := vassigns; va != nil; va = tl va){
		(nm, val) := hd va;
		setvarcell(I, nm, newcellnumstr(val));
	}
	if(fsopt != "")
		setvarstr(I, "FS", fsopt);

	{
		run(I, rfiles);
	} exception e {
	"fail:*" =>
		sys->fprint(sys->fildes(2), "awk: run-time error: %s\n", e);
		return;
	}
	# exit code is in I.exitcode but Inferno init doesn't have a clean way
	# to return it from here; the program ends with whatever status.
}

splitassign(s: string): (string, string)
{
	for(i := 0; i < len s; i++)
		if(s[i] == '='){
			return (s[0:i], s[i+1:]);
		}
	return (s, "");
}

readfileall(name: string): string
{
	fd := sys->open(name, Sys->OREAD);
	if(fd == nil){
		sys->fprint(sys->fildes(2), "awk: cannot open %s\n", name);
		raise "fail:awkopen";
	}
	out := "";
	buf := array[4096] of byte;
	for(;;){
		n := sys->read(fd, buf, len buf);
		if(n <= 0) break;
		out += string buf[0:n];
	}
	return out;
}
