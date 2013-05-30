module ui.tables;
import ui.ui;
import ui.dialogs;
import ui.input;
import ui.help;
import main;
import com.fb;
import ct.base;
import derelict.sdl.sdl;
import std.string;

bool shortTitles = true;
bool displayHelp = true;

abstract class Table : Window {
	const int columns, rows, visibleRows;
	protected {
		ubyte[] data;
		int column, row, cursorOffset, viewOffset;
	}
	this(Rectangle a, ubyte[] tbl, int c, int r) {
		super(a);
		columns = c;
		rows = r;
		data = tbl;
		input = new InputByte(tbl[0..1]);
		visibleRows = a.height - 1;
	}

	override void refresh() {
		update();
	}

protected:
	void adjustView();
}

class HexTable : Table {
	this(Rectangle a, ubyte[] tbl, int c, int r) {
		super(a,tbl,c,r);
	}

	void activate() {
		initializeInput();
	}

	void initializeInput() {
		input.setCoord(area.x + 3 + column * 3, area.y + cursorOffset + 1);
	}
	alias initializeInput set;

	override protected void adjustView() {
		if(column >= columns) {
			column -= columns;
		}
		else if(column < 0) {
			column += columns;
		}
		if(row >= rows) {
			row = row - rows;
		}
		else if(row < 0) {
			row = rows + row;
		}
		assert(row >= 0);
		if(cursorOffset >= visibleRows) {
			int i = cursorOffset - visibleRows + 1;
			viewOffset += i;
			if(viewOffset >= rows) {
				viewOffset -= rows;
			}
			cursorOffset -= i;
		}
		if(cursorOffset < 0) {
			int i = -cursorOffset;
			viewOffset -= i;
			if(viewOffset < 0)
				viewOffset += rows;
			cursorOffset += i;
		}
		initializeInput();
	}

	void stepColumn(int n) {
		column += n;
		adjustView();
		showByteDescription();
	}

	void setColumn(int n) {
		column = n;
		adjustView();
	}

	void stepColumnWrap(int n) {
		column += n;
		if(column >= columns) {
			stepRow(1);
		}
		adjustView();
	}

	void stepRow(int n) {
		seekRow(n + row);
	}

	void setCursorOffset(int r) {
		row += r - cursorOffset;
		cursorOffset = r;
		adjustView();
	}

	void seekRow(int r) {
		cursorOffset += r - row;
		row = r;
		adjustView();
	}

	void seekTableEnd() {
	}

	void deleteRow() {
	}

	void insertRow() {
	}

	void seekColumn(int c) {
		column = c;
	}

	int keypress(Keyinfo key) {
		if(key.mods & KMOD_CTRL || key.mods & KMOD_ALT ||
		   key.mods & KMOD_META) return OK;

		switch(key.raw)
		{
		case SDLK_LEFT:
			if(input.step(-1) == WRAP) {
				stepColumn(-1);
			}
			break;
		case SDLK_RIGHT:
			if(input.step(1) == WRAP) {
				stepColumn(1);
			}
			break;
		case SDLK_INSERT, SDLK_HASH:
			insertRow();
			break;
		case SDLK_DELETE:
			deleteRow();
			break;
		case SDLK_DOWN:
			stepRow(1);
			break;
		case SDLK_UP:
			stepRow(-1);
			break;
		case SDLK_PAGEUP:
			stepRow(-PAGESTEP / 2);
			break;
		case SDLK_PAGEDOWN:
			stepRow(PAGESTEP / 2);
			break;
		case SDLK_HOME:
			if(cursorOffset > 0)
				setCursorOffset(0);
			else seekRow(0);
			break;
		case SDLK_END:
			if(cursorOffset < visibleRows - 1)
				setCursorOffset(visibleRows - 1);
			else seekTableEnd();
			break;
		case SDLK_h:
			showByteDescription();
			break;

		default:
			if(input.keypress(key) == WRAP) {
				stepColumnWrap(1);
			}
			break;
		}
		initializeInput();
		return OK;
	}

	override void clickedAt(int x, int y, int button) {
		int rx = x - area.x;
		int ry = y - area.y;
		int c = (rx - 3) / 3;
		setCursorOffset(ry - 1);
		if(c >= columns) c = columns - 1;
		setColumn(c);
	}

protected:

	void showByteDescription() {
	}

	void showByteDescription(PetString pet) {
		if(song.ver < 9 || !displayHelp) return;
		string[] s = com.fb.petscii2D(pet).splitlines();
		string outstr = s[0];
		if(s.length > 1)
			outstr ~= " `01[F12 for more]";
		UI.statusline.display(format("Byte %d: %s", column + 1, outstr));
	}
}

class InsValueTable : HexTable {
	static ubyte[8] instrBuffer;
	static char[32] instrName;
	int mark = -1;
	int width;
	this(Rectangle a) {
		width = com.fb.mode ? 32 : 16;
		super(a, song.instrumentTable, 8, 48);
	}

	override void refresh() {
		data = song.instrumentTable;
	}

	int keypress(Keyinfo key) {
		if(key.mods & KMOD_ALT) return OK;
		if(key.mods & KMOD_CTRL) {
			switch(key.raw)  {
			case SDLK_c:
				foreach(i, ref buf; instrBuffer) {
					buf = data[row + i * 48];
				}
				instrName[0..32] = insName(row)[];
				UI.statusline.display("Instrument copied to buffer.");
				break;
			case SDLK_v:
				foreach(i, ref buf; instrBuffer) {
					data[i * 48 + row] = buf;
				}
				song.insLabels[row][] = instrName[];
				initializeInput();
				break;
				/+
			case SDLK_SPACE:
				mark = row;
				break;
				+/
			case SDLK_x:
				break;
			default: break;
			}
		}
		int r = super.keypress(key);
		if(r  == WRAP) {
			stepColumn(1);
		}
		return OK;
	}

	string insName(int row) {
		assert(row >= 0 && row < 48);
		return format(song.insLabels[row % 48][0..32]);
	}

	override void stepColumn(int n) {
		super.stepColumn(n);
	}

	override void stepColumnWrap(int n) {
		stepColumn(-7);
		adjustView();
	}

	override void activate() {
		super.activate();
	}

	void update() {
		int b = 0;
		int i, j, ofs;
		int myrow = row;

		if(myrow > 48) myrow -= 48;
		screen.fprint(area.x,area.y, "`b1I`01nstruments");
		for(i = 0; i < visibleRows; i++) {
			int p = (i + viewOffset);
			if(p > 47) p -= 48;
			assert(p >= 0 && p < 48);

			int c = (ui.ui.activeInstrument >= 0 && row == p) ? 15 : 12;
			screen.cprint(area.x,area.y + i + 1, c, 0, format("%02X:", p));
			for(j=0; j<8; j++) {
				ofs = p + j * 48;
				int hl = p == mark ? 13 : 5;
				screen.cprint(area.x+3+j*3,area.y + i + 1,hl,0, format("%02X ", data[ofs]));
			}
			string label = insName(p)[0..width];
			if(paddedStringLength(label, 32) == 0)
				screen.cprint(area.x + 27, area.y + 1 + i, 11, 0,
						  format("No description" ~ repeat(" ", width-14)));
			else
				screen.cprint(area.x + 27, area.y + 1 + i, 15, 0,
						  label);
		}
	}

	void initializeInput() {
		super.set();
		assert(row < 48);
		int ofs = column * 48 + row;
		input.setOutput(data[ofs .. ofs+1]);
	}

	void stepRow(int n) {
		super.stepRow(n);
		UI.activateInstrument(row);
	}

	override void showByteDescription() {
		if(song.ver > 8) {
			super.showByteDescription(song.instrumentByteDescriptions[column]);
		}
	}
}

class InsTable : Window {
	private {
		FileSelectorDialogString insdesc;
		InsValueTable insinput;
	}
	Window active;
	this(Rectangle a) {
		super(a);
		insdesc = new FileSelectorDialogString(a, com.fb.mode ? 32 : 16);
		insinput = new InsValueTable(a);
		refresh();
		activateInsValueTable();
	}

	override const ContextHelp contextHelp() {
		if(song.ver > 8)
			return genPlayerContextHelp("Instrument table",
										song.instrumentByteDescriptions);
		return ui.help.HELPMAIN;
	}

	override void refresh() {
		super.refresh();
		insdesc.refresh();
		insinput.refresh();
	}

	int row() {
		return insinput.row;
	}

	void stepRow(int n) { insinput.stepRow(n); }
	void seekRow(int r) { insinput.seekRow(r); }

	void activate() {
		activateInsValueTable();
	}

	void deactivate() {
		if(active == insdesc) {
			string s = insdesc.toString(false);
			song.insLabels[insinput.row][0..s.length] = s;
		}
		activateInsValueTable();
		active.update();
	}

	void activateDescInput() {
		update();
		active = insdesc;
		input = insdesc.input;
		input.setCoord(area.x + 9 * 3, 1 + area.y + insinput.cursorOffset);
		insdesc.setString(format(song.insLabels[insinput.row]));
		initializeInput();
	}

	void activateInsValueTable() {
		active = insinput;
		input = insinput.input;
		active.activate();
		initializeInput();
	}

	int keypress(Keyinfo key) {
		if(key.mods & KMOD_ALT) return OK;
		if(key.unicode == SDLK_RETURN || key.unicode == SDLK_TAB) {
			if(active == insinput) {
				activateDescInput();
			}
			else {
				string s = insdesc.toString(true);
				song.insLabels[insinput.row][0..s.length] = s;
				activateInsValueTable();
			}
			return OK;
		}
		int r;
		r = active.keypress(key);
		return r;
	}

	void update() {
		active.update();
	}

	void initializeInput() {
		if(active == insinput) insinput.initializeInput();
	}
	alias initializeInput set;

	override void clickedAt(int x, int y, int button) {
		insinput.clickedAt(x,y,button);
		if((x - area.x) > 3 + 8 * 3)
			activateDescInput();
	}
}


class CmdTable : HexTable {
	alias row position;
	this(Rectangle a) {
		super(a, song.superTable, 1, 64);
		input = new InputSpecial(song.superTable);
	}

	void update() {
		int i;
		if(shortTitles)
			screen.fprint(area.x,area.y, "`01Co`b1m`01mand");
		else
			screen.fprint(area.x,area.y, "`01Cmd (Alt-S)");
		for(i = 0; i < visibleRows; i++) {
			int ofs = (viewOffset + i) & 0x3f;
			screen.fprint(area.x,area.y + i + 1,
						  format("`0c%02X:`0d%01X-`05%02X %02X", ofs,
								 song.superTable[ofs] & 15,
								 song.superTable[ofs+64],
								 song.superTable[ofs+128]));
		}
	}

	int keypress(Keyinfo key) {
		if(key.mods & KMOD_ALT) return OK;
		switch(key.raw) {
		case SDLK_LEFT:
			input.step(-1);
			break;
		case SDLK_RIGHT:
			input.step(1);
			break;
		case SDLK_DOWN:
			stepRow(1);
			break;
		case SDLK_UP:
			stepRow(-1);
			break;
		case SDLK_PAGEUP:
			stepRow(-(PAGESTEP/2));
			break;
		case SDLK_PAGEDOWN:
			stepRow((PAGESTEP/2));
			break;
		case SDLK_HOME:
			seekRow(0);
			break;
		case SDLK_END:
			seekTableEnd();
			break;
		default:
			break;
		}
		int r = input.keypress(key);
		song.superTable[position] = input.inarray[0];
		song.superTable[position+64] = cast(ubyte)input.toInt(1, 3);
		song.superTable[position+128] = cast(ubyte)input.toInt(3, 5);
		if(r == WRAP) {
			stepRow(1);
		}
		return OK;
	}

	void initializeInput() {
		super.initializeInput();
		input.inarray[0] = song.superTable[position];
		input.inarray[1] = song.superTable[position+64] >> 4;
		input.inarray[2] = song.superTable[position+64] & 15;
		input.inarray[3] = song.superTable[position+128] >> 4;
		input.inarray[4] = song.superTable[position+128] & 15;
	}

	void seekTableEnd() {
		for(int i = 63; i >= 1; i--) {
			if(data[i-1] > 0) {
				seekRow(i);
				return;
			}
		}
	}

	override ContextHelp contextHelp() {
		if(song.ver > 9)
			return genPlayerContextHelp("Command table",
										song.cmdDescriptions);
		return ui.help.HELPMAIN;
	}

	override void showByteDescription() {
		if(song.ver > 9) {
			super.showByteDescription(song.cmdDescriptions[column]);
		}
	}

}

class ChordTable : HexTable {
	this(Rectangle a) {
		super(a, song.chordTable, 1, 128);
	}

	override void refresh() {
		super.refresh();
		data = song.chordTable;
	}

	void seekTableEnd() {
		for(int i = 127; i >= 1; i--) {
			if(data[i-1] > 0) {
				seekRow(i);
				return;
			}
		}
	}

	void update() {
		int i;
		if(shortTitles)
			screen.fprint(area.x,area.y, "`01Chor`b1d`01");
		else
			screen.fprint(area.x,area.y, "`01Chd (A-D)");

		for(i = 0; i < visibleRows; i++) {
			int row = (i + viewOffset) & 127;
			string col = "`05";
			if(data[row] >= 0x80) col = "`0d";
			screen.fprint(area.x, area.y + i + 1, format("`0c%02X:%s%02X", (i + viewOffset) & 0x7f, col, data[row]));
		}

		for(i = 0; i < visibleRows; i++) {
			screen.fprint(area.x + 5, area.y + i + 1, "  ");
		}

		int[] chordno = getHighestChordIndex();

		{
			int ct;
			for(i = 0; i < viewOffset; i++) {
				if(data[i] >= 0x80) ct++;
			}
			bool doPrint = true;
			int row = viewOffset & 127;
			for(i = 0; i < visibleRows; i++,row++) {
				if(row > 127) {
					row -= 128;
					ct = 0;
					doPrint = true;
				}

				if(doPrint) {
					screen.fprint(area.x + 5, area.y + i + 1, format("`0c%X ", ct));
					doPrint = false;
				}

				if(data[row] >= 0x80) {
					if(ct >= chordno[0]) break;
					ct++;
					doPrint = true;
					if(row >= chordno[1]) {
						doPrint = false;
					}
				}
			}
		}
	}

	void initializeInput() {
		super.initializeInput();
		input.setOutput(data[row .. row + 1]);
		song.generateChordIndex();
	}

	void insertRow() {
		ubyte[] tmp = data[row .. $-1].dup;
		foreach(i, c; tmp) {
			if(c >= (0x80 + row) && ++c < 0x100)
				tmp[i] = c;
		}
		data[row+1 .. $] = tmp;
		data[row] = 0;
		initializeInput();
	}

	void deleteRow() {
		ubyte[] tmp = data[row + 1 .. $].dup;
		foreach(i, c; tmp) {
			if(c >= (0x80 + row) && --c >= 0x80)
				tmp[i] = c;
		}
		data[row .. $ - 1] = tmp;
		data[$-1] = 0;
		initializeInput();
	}

private:

	// returns number of chords and the offset of the last chord
	int[] getHighestChordIndex() {
		foreach_reverse(counter, idx; song.chordIndexTable) {
			if(idx == 0) continue;
			return cast(int[])[counter, idx];
		}
		return [-1, -1];
	}
}

class WaveTable : HexTable {
	this(Rectangle a) {
		super(a, song.waveTable, 2, 256);
	}

	override void refresh() {
		super.refresh();
		data = song.waveTable;
	}

	void seekTableEnd() {
		for(int i = 255; i >= 1; i--) {
			if(data[i-1] > 0) {
				seekRow(i);
				return;
			}
		}
	}

	void seekCurWave() {
		seekRow(song.instrumentTable[ui.ui.activeInstrument + 7 * 48]);
	}

	int keypress(Keyinfo key) {
		if(key.mods & KMOD_SHIFT) {
			switch(key.raw)
			{
			case SDLK_HOME:
				seekRow(0);
				return OK;
			case SDLK_END:
				seekTableEnd();
				return OK;
			default:
				break;
			}
		}
		else if(key.mods & KMOD_CTRL) {
			switch(key.raw) {
			case SDLK_g:
				seekCurWave();
				return OK;
			default:
				break;
			}
		}
		else switch(key.raw) {
			case SDLK_g:
				seekCurWave();
				return OK;
			case SDLK_DELETE:
				song.wavetableRemove(row);
				refresh();
				set();
				return OK;
			case SDLK_INSERT, SDLK_HASH:
				song.wavetableInsert(row);
				refresh();
				set();
				return OK;
			case '.':
				data[column ? (256 + row) : row] = 0;
				stepColumnWrap(1);
				return OK;
			default:
				break;
			}
		return super.keypress(key);
	}

	void update() {
		int i;
		int t1, t2;
		if(shortTitles)
			screen.fprint(area.x,area.y, "`b1W`01ave");
		else
			screen.fprint(area.x,area.y, "`01Wave (A-W)");
		for(i = 0; i < visibleRows; i++) {
			int row = (i + viewOffset) & 255;
			t1 = data[row];
			t2 = data[row+256];
			int col = (t1 == 0x7e || t1 == 0x7f) ?  0x0d : 0x05;
			screen.fprint(area.x,area.y + i + 1, format("`0c%02X:`%02x%02X %02X",
														(i + viewOffset)&255, col, t1, t2));

		}
	}

	void initializeInput() {
		int offset = column ? (256 + row) : row;
		(cast(InputByte)input).setOutput(data[offset..offset+1]);
		super.set();
	}

	void stepColumnWrap(int n) {
		stepRow(1);
		adjustView();
	}


	override void showByteDescription() {
		if(song.ver > 9) {
			super.showByteDescription(song.waveDescriptions[column]);
		}
	}

	override ContextHelp contextHelp() {
		if(song.ver > 9)
			return genPlayerContextHelp("Wave table",
										song.waveDescriptions);
		return ui.help.HELPMAIN;
	}
}

class SweepTable : HexTable {
	this(Rectangle a, ubyte[] d) {
		super(a, d, 4, 64);
	}

	void update() {
		for(int i=0; i < visibleRows; i++) {
			int p = ((i + viewOffset) & 63) * 4;
			string col = "`05";
			if(data[p+3] > 0) col = "`0d";
			screen.fprint(area.x,area.y + i + 1,
						  format("`0c%02X:`05%02X %02X %02X %s%02X",
								 (i + viewOffset) & 63,
								 data[p], data[p+1], data[p+2], col, data[p+3]));
		}
	}

	void initializeInput() {
		InputByte i = cast(InputByte)input;
		int ofs = row * 4 + column;
		i.setOutput(data[ofs..ofs+1]);
		super.initializeInput();

	}

	void seekTableEnd() {
		for(int i = 63; i >= 0; i--) {
			ubyte[] arr = data[i * 3 .. i * 3 + 3];
			bool flag;
			foreach(a; arr) {
				if(a) {
					int row = i + 1;
					if(row > 63) row = 63;
					seekRow(row);
					return;
				}
			}
		}
	}
}

class PulseTable : SweepTable {
	this(Rectangle a) {
		super(a, song.pulseTable);
	}

	override void refresh() {
		super.refresh();
		data = song.pulseTable;
	}

	void update() {
		if(shortTitles)
			screen.fprint(area.x, area.y, "`b1P`01ulse");
		else
			screen.fprint(area.x, area.y, "`01Pulse (Alt-P)");
		super.update();
	}

	override void showByteDescription() {
		if(song.ver > 8) {
			super.showByteDescription(song.pulseDescriptions[column]);
		}
	}

	override ContextHelp contextHelp() {
		if(song.ver > 8)
			return genPlayerContextHelp("Pulse table",
										song.pulseDescriptions);
		return ui.help.HELPMAIN;
	}
}

class FilterTable : SweepTable {
	this(Rectangle a) {
		super(a, song.filterTable);
		refresh();
	}

	override void refresh() {
		super.refresh();
		data = song.filterTable;
	}

	void update() {
		if(shortTitles)
			screen.fprint(area.x, area.y, "`b1F`01ilter");
		else
			screen.fprint(area.x, area.y, "`01Filter (Alt-F)");
		super.update();
	}

	override ContextHelp contextHelp() {
		if(song.ver > 8)
			return genPlayerContextHelp("Filter table",
										song.filterDescriptions);
		return ui.help.HELPMAIN;
	}

	override void showByteDescription() {
		if(song.ver > 8) {
			super.showByteDescription(song.filterDescriptions[column]);
		}
	}
}

