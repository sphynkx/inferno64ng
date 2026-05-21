implement IcEditCommon;

include "ic/editcommon.m";

init()
{
}

spaces(n: int): string
{
	return repeat(" ", n);
}

repeat(s: string, n: int): string
{
	out: string;
	i: int;

	out = "";
	for(i = 0; i < n; i++)
		out += s;

	return out;
}

fittext(s: string, w: int): string
{
	if(w <= 0)
		return "";

	if(len s > w)
		return s[0:w];

	if(len s < w)
		return s + spaces(w - len s);

	return s;
}

trim(s: string): string
{
	a, b: int;

	a = 0;
	b = len s;

	while(a < b && (s[a] == ' ' || s[a] == '\t' || s[a] == '\n' || s[a] == '\r'))
		a++;

	while(b > a && (s[b - 1] == ' ' || s[b - 1] == '\t' || s[b - 1] == '\n' || s[b - 1] == '\r'))
		b--;

	if(a >= b)
		return "";

	return s[a:b];
}

joinpath(base, name: string): string
{
	if(name == "")
		return base;

	if(len name > 0 && name[0] == '/')
		return name;

	if(base == "" || base == ".")
		return name;

	if(base == "/")
		return "/" + name;

	return base + "/" + name;
}

basename(path: string): string
{
	i: int;

	for(i = len path - 1; i >= 0; i--){
		if(path[i] == '/')
			return path[i + 1:];
	}

	return path;
}

dirname(path: string): string
{
	i: int;

	for(i = len path - 1; i >= 0; i--){
		if(path[i] == '/'){
			if(i == 0)
				return "/";
			return path[0:i];
		}
	}

	return "";
}

expandtabs(s: string): string
{
	i, j: int;
	out: string;

	out = "";

	for(i = 0; i < len s; i++){
		if(s[i] == '\t'){
			for(j = 0; j < TabSpaces; j++)
				out += " ";
		}else
			out += s[i:i + 1];
	}

	return out;
}

bodyh(h: int): int
{
	rows: int;

	rows = h - 2;
	if(rows < 1)
		rows = 1;

	return rows;
}

buttondef(idx: int): EditorButton
{
	b: EditorButton;

	b.fkey = idx + 1;
	b.text = "";
	b.enabled = 1;

	case idx {
	0 =>
		b.text = "Help";
	1 =>
		b.text = "Save";
	2 =>
		b.text = "Select";
	3 =>
		b.text = "View";
	4 =>
		b.text = "Copy";
	5 =>
		b.text = "Move";
	6 =>
		b.text = "Search";
	7 =>
		b.text = "Delete";
	8 =>
		b.text = "Menu";
	9 =>
		b.text = "Quit";
	}

	return b;
}