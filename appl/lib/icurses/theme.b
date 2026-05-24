implement IcTheme;

include "icurses/theme.m";

_colorcount: int;
_truecolor: int;
_codes: array of string;

MaxAttr: con 32;

init(ci: Icurses->ConsInfo)
{
	_colorcount = 16;
	_truecolor = 0;

	if(ci.colors > 0)
		_colorcount = ci.colors;

	if(ci.truecolor != 0)
		_truecolor = 1;

	if(_codes == nil)
		reset();
}

reset()
{
	_codes = array[MaxAttr] of string;

	if(_truecolor){
		_codes[AttrNormal] = "0";
		_codes[AttrWindow] = "38;2;220;230;255;48;2;20;45;90";
		_codes[AttrFrame] = "38;2;230;240;255;48;2;20;45;90";
		_codes[AttrTitle] = "1;38;2;255;230;120;48;2;20;45;90";
		_codes[AttrButton] = "38;2;10;25;35;48;2;70;210;230";
		_codes[AttrFocus] = "1;38;2;0;0;0;48;2;170;225;255";
		_codes[AttrStatus] = "38;2;20;25;30;48;2;225;225;225";
		_codes[AttrScroll] = "38;2;255;220;80;48;2;20;45;90";
		_codes[AttrShadow] = "38;2;170;180;190;48;2;45;45;45";
		_codes[AttrMarked] = "1;38;2;255;120;210;48;2;20;45;90";
		_codes[AttrMarkedFocus] = "1;38;2;220;0;0;48;2;170;225;255";

		_codes[AttrEffectHead] = "38;2;220;255;220;40";
		_codes[AttrEffectBright] = "38;2;100;255;140;40";
		_codes[AttrEffectMid] = "38;2;0;230;80;40";
		_codes[AttrEffectDim] = "38;2;0;155;50;40";
		_codes[AttrEffectDark] = "38;2;0;55;18;40";
		return;
	}

	_codes[AttrNormal] = "0";
	_codes[AttrWindow] = "0;37;44";
	_codes[AttrFrame] = "1;37;44";
	_codes[AttrTitle] = "1;33;44";
	_codes[AttrButton] = "1;30;46";
	_codes[AttrFocus] = "1;30;106";
	_codes[AttrStatus] = "1;30;47";
	_codes[AttrScroll] = "1;33;44";
	_codes[AttrShadow] = "0;37;100";
	_codes[AttrMarked] = "1;31;44";
	_codes[AttrMarkedFocus] = "1;31;106";

	_codes[AttrEffectHead] = "1;37;40";
	_codes[AttrEffectBright] = "1;32;40";
	_codes[AttrEffectMid] = "1;32;40";
	_codes[AttrEffectDim] = "0;32;40";
	_codes[AttrEffectDark] = "0;30;40";
}

setcode(attr: int, code: string): int
{
	if(attr < 0 || attr >= MaxAttr)
		return -1;

	if(_codes == nil)
		reset();

	if(code == "")
		return -1;

	_codes[attr] = code;
	return 0;
}

colors(): int
{
	return _colorcount;
}

truecolor(): int
{
	return _truecolor;
}

sgr(attr: int): string
{
	if(_codes == nil)
		reset();

	if(attr < 0 || attr >= len _codes)
		return "0";

	if(_codes[attr] == "")
		return "0";

	return _codes[attr];
}