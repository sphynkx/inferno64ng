implement IcCodepage;

include "sys.m";
include "ic/codepage.m";

sys: Sys;

CpUtf8: con 0;
Cp1251: con 1;
Cp866: con 2;
CpKoi8r: con 3;
CpLatin1: con 4;
ReplacementChar: con 16rFFFD;

cpnames: array of string;

lowerascii: fn(c: int): int;
lowerstr: fn(s: string): string;
cpindex: fn(enc: string): int;
mapbyte: fn(cp: int, b: int): int;
decodeutf8: fn(buf: array of byte, n: int): string;
decodesingle: fn(cp: int, buf: array of byte, n: int): string;

init()
{
	sys = load Sys Sys->PATH;
	if(sys == nil)
		raise "fail:load sys";

	cpnames = array[] of {
		"utf-8",
		"cp1251",
		"cp866",
		"koi8-r",
		"iso-8859-1"
	};
}

count(): int
{
	return len cpnames;
}

name(idx: int): string
{
	if(idx < 0 || idx >= len cpnames)
		return "";

	return cpnames[idx];
}

find(enc: string): int
{
	return cpindex(enc);
}

defaultname(): string
{
	return "utf-8";
}

lowerascii(c: int): int
{
	if(c >= 'A' && c <= 'Z')
		return c + ('a' - 'A');

	return c;
}

lowerstr(s: string): string
{
	i: int;
	out: string;

	out = "";
	for(i = 0; i < len s; i++)
		out += sys->sprint("%c", lowerascii(s[i]));

	return out;
}

cpindex(enc: string): int
{
	s: string;

	s = lowerstr(enc);

	if(s == "" || s == "utf8" || s == "utf-8")
		return CpUtf8;

	if(s == "cp1251" || s == "windows-1251" || s == "win1251")
		return Cp1251;

	if(s == "cp866" || s == "ibm866" || s == "866")
		return Cp866;

	if(s == "koi8-r" || s == "koi8r")
		return CpKoi8r;

	if(s == "latin1" || s == "iso-8859-1" || s == "iso8859-1")
		return CpLatin1;

	return -1;
}

decode(enc: string, buf: array of byte, n: int): string
{
	cp: int;

	if(n <= 0)
		return "";

	cp = cpindex(enc);
	if(cp < 0)
		cp = CpUtf8;

	if(cp == CpUtf8)
		return decodeutf8(buf, n);

	return decodesingle(cp, buf, n);
}

decodeutf8(buf: array of byte, n: int): string
{
	i: int;
	b0, b1, b2, b3: int;
	c: int;
	out: string;

	out = "";
	i = 0;

	while(i < n){
		b0 = int buf[i] & 16rFF;

		if(b0 < 16r80){
			out += sys->sprint("%c", b0);
			i++;
			continue;
		}

		if((b0 & 16rE0) == 16rC0 && i + 1 < n){
			b1 = int buf[i + 1] & 16rFF;
			if((b1 & 16rC0) == 16r80){
				c = ((b0 & 16r1F) << 6) | (b1 & 16r3F);
				if(c >= 16r80){
					out += sys->sprint("%c", c);
					i += 2;
					continue;
				}
			}
		}

		if((b0 & 16rF0) == 16rE0 && i + 2 < n){
			b1 = int buf[i + 1] & 16rFF;
			b2 = int buf[i + 2] & 16rFF;
			if((b1 & 16rC0) == 16r80 && (b2 & 16rC0) == 16r80){
				c = ((b0 & 16r0F) << 12) | ((b1 & 16r3F) << 6) | (b2 & 16r3F);
				if(c >= 16r800 && (c < 16rD800 || c > 16rDFFF)){
					out += sys->sprint("%c", c);
					i += 3;
					continue;
				}
			}
		}

		if((b0 & 16rF8) == 16rF0 && i + 3 < n){
			b1 = int buf[i + 1] & 16rFF;
			b2 = int buf[i + 2] & 16rFF;
			b3 = int buf[i + 3] & 16rFF;
			if((b1 & 16rC0) == 16r80 && (b2 & 16rC0) == 16r80 && (b3 & 16rC0) == 16r80){
				c = ((b0 & 16r07) << 18) | ((b1 & 16r3F) << 12) | ((b2 & 16r3F) << 6) | (b3 & 16r3F);
				if(c >= 16r10000 && c <= 16r10FFFF){
					out += sys->sprint("%c", c);
					i += 4;
					continue;
				}
			}
		}

		out += sys->sprint("%c", ReplacementChar);
		i++;
	}

	return out;
}

decodesingle(cp: int, buf: array of byte, n: int): string
{
	i: int;
	b: int;
	c: int;
	out: string;

	out = "";
	for(i = 0; i < n; i++){
		b = int buf[i] & 16rFF;
		c = mapbyte(cp, b);
		out += sys->sprint("%c", c);
	}

	return out;
}

mapbyte(cp: int, b: int): int
{
	if(b < 16r80)
		return b;

	if(cp == CpLatin1)
		return b;

	if(cp == Cp1251){
		if(b == 16rA8)
			return 16r401;
		if(b == 16rB8)
			return 16r451;
		if(b >= 16rC0 && b <= 16rFF)
			return 16r410 + (b - 16rC0);
		return ReplacementChar;
	}

	if(cp == Cp866){
		if(b >= 16r80 && b <= 16r9F)
			return 16r410 + (b - 16r80);
		if(b >= 16rA0 && b <= 16rAF)
			return 16r430 + (b - 16rA0);
		if(b >= 16rE0 && b <= 16rEF)
			return 16r440 + (b - 16rE0);
		if(b == 16rF0)
			return 16r401;
		if(b == 16rF1)
			return 16r451;
		return ReplacementChar;
	}

	if(cp == CpKoi8r){
		case b {
		16rA3 => return 16r451;
		16rB3 => return 16r401;

		16rC0 => return 16r42E;
		16rC1 => return 16r410;
		16rC2 => return 16r411;
		16rC3 => return 16r426;
		16rC4 => return 16r414;
		16rC5 => return 16r415;
		16rC6 => return 16r424;
		16rC7 => return 16r413;
		16rC8 => return 16r425;
		16rC9 => return 16r418;
		16rCA => return 16r419;
		16rCB => return 16r41A;
		16rCC => return 16r41B;
		16rCD => return 16r41C;
		16rCE => return 16r41D;
		16rCF => return 16r41E;
		16rD0 => return 16r41F;
		16rD1 => return 16r42F;
		16rD2 => return 16r420;
		16rD3 => return 16r421;
		16rD4 => return 16r422;
		16rD5 => return 16r423;
		16rD6 => return 16r416;
		16rD7 => return 16r412;
		16rD8 => return 16r42C;
		16rD9 => return 16r42B;
		16rDA => return 16r417;
		16rDB => return 16r428;
		16rDC => return 16r42D;
		16rDD => return 16r429;
		16rDE => return 16r427;
		16rDF => return 16r42A;

		16rE0 => return 16r44E;
		16rE1 => return 16r430;
		16rE2 => return 16r431;
		16rE3 => return 16r446;
		16rE4 => return 16r434;
		16rE5 => return 16r435;
		16rE6 => return 16r444;
		16rE7 => return 16r433;
		16rE8 => return 16r445;
		16rE9 => return 16r438;
		16rEA => return 16r439;
		16rEB => return 16r43A;
		16rEC => return 16r43B;
		16rED => return 16r43C;
		16rEE => return 16r43D;
		16rEF => return 16r43E;
		16rF0 => return 16r43F;
		16rF1 => return 16r44F;
		16rF2 => return 16r440;
		16rF3 => return 16r441;
		16rF4 => return 16r442;
		16rF5 => return 16r443;
		16rF6 => return 16r436;
		16rF7 => return 16r432;
		16rF8 => return 16r44C;
		16rF9 => return 16r44B;
		16rFA => return 16r437;
		16rFB => return 16r448;
		16rFC => return 16r44D;
		16rFD => return 16r449;
		16rFE => return 16r447;
		16rFF => return 16r44A;
		* => return ReplacementChar;
		}
	}

	return ReplacementChar;
}