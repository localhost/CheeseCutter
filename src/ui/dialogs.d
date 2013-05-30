module ui.dialogs;
import derelict.sdl.sdl;
import main;
import com.fb;
import ui.help;
import ui.ui;
import ct.base;
import ui.input;
import std.string;
import std.file;
import std.stdio;
import std.math;
import std.utf;
import std.array;

protected class QueryDialog : Window {
	string query;
	static ubyte[1] byt;
	alias void delegate(int) Callback;
	Callback callback;
	const int _maxValue;
	this(string s,Callback fp, int m) {
		query = s;
		callback = fp;
		input = new InputBoundedByte(byt);
		this(Rectangle(0,0, 1), m);
	}

	this(Rectangle a, int m) {
		_maxValue = m;
		super(a);
    }
	
	int keypress(Keyinfo key) {
		if(key.mods & KMOD_ALT) return OK;
		int r = input.keypress(key);
		if(r == WRAP &&
		   (cast(InputBoundedByte)input).value >= _maxValue) {
			input.setOutput(cast(ubyte[])[_maxValue-1]);
			return OK;
		}
		else if(r == RETURN) {
			input.nibble = 0;
			callback(input.toInt());
		}
		else if(r == CANCEL) { // no callback
		}
		else r = OK;
		if(input.value >= _maxValue)
			input.setOutput(cast(ubyte[])[_maxValue-1]);
		return r;
	}

	void update() {
		int x = cast(int)(screen.width / 2 - (query.length + 6 )/2);
		int y = cast(int)(screen.height / 2 - 11);
		drawFrame(Rectangle(x, y, 5, cast(int)(query.length + 9)));
		screen.cprint(x + 4, y + 2, 15, 0, query);
		input.setCoord(cast(int)(x + 4 + query.length), cast(int)( y + 2));
	}

	void activate() { return; }
}

class HelpDialog : Window {
	const MAX_LINE_LENGTH = 80;
	string[][] pages;
	const string title;
	int numpages;
	int page = 1;
	int txt_x;
	this(Rectangle a, ContextHelp ctx) {
		super(a);
		pages.length = ctx.text.length;
		foreach(i,page; ctx.text) {
			pages[i] = page.splitlines();
		}
		numpages = cast(int)pages.length; // deprecate
		title = ctx.title;
		txt_x = area.x + (area.width / 2 - MAX_LINE_LENGTH / 2);
	}

	void update() {
		int ypos = area.y + 2;
		drawFrame(area);
		screen.cprint(area.x + 2, area.y, 1, 0, format(" %s %d/%d (press SPACE for more) ", title,
											   page,numpages));
		screen.cprint(area.x + 1, area.y + 2, 1, 0, repeat(" ",area.width-3));
		foreach(line; pages[page-1]) {
			screen.cprint(area.x+1, ypos, 1, 0,repeat(" ",area.width-3));
			screen.fprint(txt_x, ypos, "`0f" ~ line);
			ypos++;
		}
		for(; ypos < 36; ypos++) {
			screen.cprint(area.x+1, ypos, 1, 0, repeat(" ",area.width-2));
		}
		
	}

	int keypress(Keyinfo key) {
		int k = key.unicode;
		if(k == SDLK_SPACE ||
		   k == SDLK_PLUS ||
			k == SDLK_RIGHT ||
			k == SDLK_PAGEDOWN)
			if(page++ >= numpages) page = 1;
		if(key.unicode == SDLK_RETURN ||
			key.unicode == SDLK_ESCAPE) return RETURN;
		return OK;
	}
}

class DebugDialog : Window {
	Sequence seq;
	this(Sequence s) {
		super(Rectangle(screen.width / 2 - 24,
				   screen.height / 2 - 10,
				   20, 55));
		seq = s;
	}
	
	this(Rectangle a) {
		super(a);
	}

	void update() {
		assert(seq !is null);
		int y,pos;
		string str;
		drawFrame(area);
		for(y=0;y<area.h-2;y++) {
			screen.fprint(area.x+1,area.y+1+y,repeat(" ",area.width-2));
		}
		for(y=0; y<16; y++) {
			str = format("%02X:",y*16);
			for(int i = 0; i < 16 ; i++) {
				str ~= format("%02X ", seq.data.raw[pos++]);
			}
			screen.fprint(area.x+2,area.y+y+2,"`0f" ~ str);
		}
	}

	int keypress(Keyinfo key) {
		switch(key.unicode) {
		case SDLK_SPACE:
			com.fb.hexdump(seq.compact(),16);
		case 0:
			break;
		default:
			return RETURN;
		}
		return OK;
	}
}

class AboutDialog : Window {
	const string LOGO =
"           ___                                    ___   ___                   
   ______/  /____________________________________\\  \\__\\  \\_______________ 
  /  ___/     /  -__/  -__/__ --/  -__|  ___\\  \\  \\   __\\   __\\  -__\\    _\\
 /_____/__/__/_____/_____/_____/______|______\\_____\\_____\\_____\\_____\\___\\/
\\_____\\__\\__\\_____\\_____\\_____\\______|______/_____/_____/_____/_____/___/

";

	this(Rectangle a) {
		super(a);
	}
  
	void update() {
		string[] logo = LOGO.splitlines();
		int y;

		drawFrame(area);
		y = area.y + 1;
		foreach(line; logo) {
			screen.cprint(area.x + 1, y, 1, 0, repeat(" ",area.width-2));
			screen.fprint(area.x + 1, y, "`01" ~ line.center(area.width-2));
			y++;
		}

		screen.cprint(area.x + 1, y++,15, 0,"(C) 2009-13 Abaddon + contributors".center(area.width-2));
		screen.cprint(area.x + 1, y++,15, 0,"reSID engine by Dag Lem".center(area.width-2));
		screen.cprint(area.x + 1, y++,15, 0,"Released under GNU GPL".center(area.width-2));
		screen.fprint(area.x + 1, y++," ".center(area.width-2));
	}
  
	int keypress(Keyinfo key) {
		if(key.mods) return OK;
		if(key.unicode == SDLK_ESCAPE ||
			key.unicode == SDLK_SPACE ||
			key.unicode == SDLK_RETURN) return RETURN;
		return OK;
	}
}

class FileSelector : Window {
	struct FileSelPos {
		int offset, pos;
	}
	struct File {
		string name;
		int exists, isdir;
	}
	FileSelPos fpos;
	private File[] filelist;
	string directory;
	alias area filearea;
	this(Rectangle a) {
		super(a);
		directory = getcwd();
		refresh();
	}

	void refresh() {
		if(!exists(directory)) {
			UI.statusline.display("Directory not found!");
		}
		else {
			chdir(directory);
			getdir(directory);
		}
	}

	void reset() {
		fpos.offset = fpos.pos = 0;
	}

	void update() { 
		int y, i;
		for(y = area.y, i = 0; i < area.height; y++,i++) {
			int ofs = fpos.offset + i;
			string fs = null;
			int col = 15;
			if(ofs < filelist.length) {
				File f = filelist[ofs];
				auto ind = 1+f.name.lastIndexOf(DIR_SEPARATOR);
				if( ofs < 2 || (f.exists && f.isdir) ) {
					col = 13;
				}
				fs = fstr(format("  %s", f.name[ind..$].ljustify(area.width-2)));
			}
			screen.cprint(area.x+5,y,col,0,fs);
		}
	}

	void blink() {
		int y = area.y + fpos.pos;
		auto ind = 1 + filelist[num].name.lastIndexOf(DIR_SEPARATOR);
		screen.fprint(area.x+5,y,fstr("`b1  " ~ filelist[num].name[ind..$].ljustify(area.width-3)) ~ "  ");
	}
	
	int fileHandler() {
		if(isDir(selected)) {
			string s;
			if(selected == ".." ) {
				int i = cast(int) directory.lastIndexOf(DIR_SEPARATOR);
				if(i >= 0) {
					s = directory[0..i];
					if(s.lastIndexOf(DIR_SEPARATOR) < 0) {
						s ~= DIR_SEPARATOR;
					}
					directory = s;
				}
			}
			else if(selected != ".") {
				directory = cast(string)(selected.dup);
			}   
			reset();
			refresh();
			return OK;
		}
		return RETURN;
	}

	int keypress(Keyinfo key) {
		switch(key.raw) 
		{
		case SDLK_UP:
			step(-1);
			return WRAP;
		case SDLK_DOWN:
			step(1);
			return WRAP;
		case SDLK_PAGEUP:
			step(-area.height);
			return WRAP;
		case SDLK_PAGEDOWN:
			step(area.height);
			return WRAP;
		case SDLK_HOME:
			reset();
			return WRAP;
		case SDLK_END:
			cursorEnd();
			return WRAP;
		default:
			break;
		}
		return OK;
	}
	
	char[][] listdir(string udir) {
		char[][] ret;
		auto app = appender(ret);
		foreach (DirEntry e; dirEntries(udir, SpanMode.shallow)){
			app.put( e.name.dup );	
		}

		return app.data;
	}

	void getdir(string udir) {
		char[][] dir;
		char[][] dirs, files;
		dir = listdir(udir);
		dirs.length = dir.length+2;
		files.length = dir.length;

		int idxd, idxf;

		foreach(i, d; dir) {
			char[] first = d[0..1];
			// skip hidden / temp files
			if(first == "." || first == "#" || !d.exists())
				continue;
			if(d.isDir()) {
				dirs[idxd++] = d;
			} else {
				 files[idxf++] = d;
			}
		}

		dirs.length = idxd;
 		dirs.sort;
		
		files.length = idxf;
		files.sort;

		string[] all = cast(string[])(dirs ~ files);
		
		filelist.length = all.length + 2;
		filelist[0] = File(".", true, true);
                filelist[1] = File("..",true, true);
		for(int i = 0; i < all.length; i++) {
			filelist[i+2] = File(all[i], all[i].exists(), all[i].isDir());
		}
	}

	// move the cursor to last entry & set scroll window pos
	void cursorEnd() {
		if(filelist.length >= area.height) {
			fpos.offset = cast(int)(filelist.length - area.height);
			fpos.pos = cast(int)(area.height-1);
		}
		else {
			fpos.offset = 0;
			fpos.pos = cast(int)(filelist.length - 1);
		}
	}

	void step(int st) {
		fpos.pos += st;
		if(fpos.pos >= filearea.height) {
			int r = fpos.pos-filearea.height;
			fpos.offset += r+1;
			fpos.pos -= r+1;
			if(num >= filelist.length && filelist.length > filearea.height) {
				fpos.offset = cast(int)(filelist.length - filearea.height);
				fpos.pos = cast(int)(filearea.height-1);
			}
		}
		else if(fpos.pos < 0) {
			int r = -fpos.pos;
			fpos.offset -= r;
			if(fpos.offset < 0) fpos.offset=0;
			fpos.pos += r;
		}
		if(num >= filelist.length)
			cursorEnd();
	}

	string selected() { return filelist[num].name; }
	alias selected getSelected;
  
private:

	int num() { return fpos.offset + fpos.pos; }
	string fstr(string fs) {
		if(fs.length > (area.width))
			fs.length = area.width;
		return fs;
	}
}

// wraps inputstring
class FileSelectorDialogString : Window {
	this(Rectangle a) {
		this(a, 50);
	}

	this(Rectangle a, int len) {
		input = new InputString("", len);
		input.setCoord(a.x, a.y);
		super(a);
	}

	string toString() { return toString(false); }
	string toString(bool p) { return (cast(InputString)input).toString(p); }
	void setString(string s) {
		(cast(InputString)input).setOutput(s);
	}
	alias setString setOutputString;

	void update() {
		input.update();
	}

	int keypress(Keyinfo key) { input.keypress(key); return OK; }
}
		
class FileSelectorDialog : WindowSwitcher {
	alias void delegate(string) CB;
	const CB callback;
	alias activeWindow active;
	private FileSelectorDialogString sfile, sdir;
	FileSelector fsel;
	private const string header;
	private int active_window_num;
	private char[][] filelist;
	Rectangle filearea;
	this(Rectangle a, string h, CB cb) {
		header = h;
		filearea = Rectangle(a.x + 5, a.y + 2, a.height - 6, a.width - 10);
		fsel = new FileSelector(Rectangle(a.x + 5, a.y + 2, a.height - 6, 
								a.width - 18));
		sfile = new FileSelectorDialogString(Rectangle(a.x+3+11, a.y+a.height-2), 50);
		sdir = new FileSelectorDialogString(Rectangle(a.x+3+11, a.y+a.height-3), 50);
		sdir.setString(getcwd());
		super(a, [cast(Window)fsel, sdir, sfile]);
		activateWindow(0);
		callback = cb;
	}

	void setFilename(string s) {
		sfile.setString(cast(string)s.dup);
	}

	void setDirectory(string s) {
		fsel.directory = cast(string)s.dup;
		sdir.setString(cast(string)s.dup);
	}

	string getFilename() {
		return sfile.toString();
	}

	void activate() {
		refresh();
		fsel.refresh();
	}

	void refresh() { 
		update();
	}
	
	void update() {
		int x,y,i;

		for(y = area.y; y < area.y+area.height; y++) {
			screen.cprint(area.x, y, 1, 0, repeat(" ",area.width));
		}
		drawFrame(area);
		x = area.x + 3;
		y = area.y + 2;
		screen.cprint(x,area.y,1,0," " ~ header ~ " ");

		screen.fprint(x,area.y+area.height-3,format("`0fDirectory: `0d%s",sdir.toString()));
		
		string f = sfile.toString();
		int ind = cast(int) (1+f.lastIndexOf(DIR_SEPARATOR));
		screen.fprint(x,area.y+area.height-2,format("`0f Filename: `0d%s",f[ind..$]));
		
		active.update();
		if(active == fsel) {
			fsel.blink();
		} else {
			fsel.update();
		}
		input = active.input;
	}

	int keypress(Keyinfo key) {
		if(key.mods && !key.mods & KMOD_SHIFT) return OK;
		switch(key.raw)
		{
		case SDLK_TAB:
			return super.keypress(key);
		case SDLK_ESCAPE:
			return RETURN;
		case SDLK_RETURN:
			return returnPressed(callback);
		default:
			int r = active.keypress(key);
			if(r == WRAP){
				int ind = cast(int) (1 + fsel.getSelected().lastIndexOf(DIR_SEPARATOR)); 
				sfile.setString(cast(string)(fsel.getSelected()[ind..$]));
			}
			break;
		}
		return OK;
	}

	protected int returnPressed(CB cb) {
		if(active == fsel) {
			int r = fsel.fileHandler();
			if(r == RETURN)
				cb(cast(string)(fsel.selected));
			sdir.setString(getcwd());
			return r;
		}
		else if(active == sfile) { // pressed RETURN in file dialog
			string filename = getcwd() ~ DIR_SEPARATOR ~ sfile.toString();
			cb(filename);
			return RETURN;
		}
		else {
			fsel.directory = sdir.toString();
			fsel.reset();
			fsel.refresh();
		}
		return OK;
	}
}

class LoadFileDialog : FileSelectorDialog {
	CB cbimport;
	this(Rectangle a, CB cbload, CB cbimp) {
		super(a, "Load Song", cbload);
		cbimport = cbimp;
	}

	int keypress(Keyinfo key) {
		if(key.raw == SDLK_RETURN && (key.mods & KMOD_SHIFT)) {
			return returnPressed(cbimport);
		}
		else return super.keypress(key);
	}
}

class SaveFileDialog : FileSelectorDialog {
	this(Rectangle a, CB cb) {
		super(a, "Save Song", cb);
		activateWindow(2);
	}
}
