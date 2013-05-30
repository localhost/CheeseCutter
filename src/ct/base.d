module ct.base;

import std.stdio;
import std.string;
import std.file;
import std.zlib;
import com.cpu;

enum Offsets {
	Features, Volume, Editorflag, 
	Songsets, PlaySpeed, Subnoteplay, Submplayplay, InstrumentDescriptionsHeader,
		PulseDescriptionsHeader, FilterDescriptionsHeader, WaveDescriptionsHeader,
		CmdDescriptionsHeader, FREQTABLE, FINETUNE, Arp1, Arp2,
	FILTTAB, PULSTAB, Inst, Track1, Track2, Track3, SeqLO, SeqHI,
	CMD1, S00, SPEED, TRACKLO, VOICE, GATE, ChordTable, TRANS, ChordIndexTable, 
	SHTRANS, FOO3, NEXT, CURINST, GEED, NEWSEQ
}

const string[] NOTES =
	[ "C-0", "C#0", "D-0", "D#0", "E-0", "F-0",
	  "F#0", "G-0", "G#0", "A-0", "A#0", "B-0",
	  "C-1", "C#1", "D-1", "D#1", "E-1", "F-1",
	  "F#1", "G-1", "G#1", "A-1", "A#1", "B-1",
	  "C-2", "C#2", "D-2", "D#2", "E-2", "F-2",
	  "F#2", "G-2", "G#2", "A-2", "A#2", "B-2",
	  "C-3", "C#3", "D-3", "D#3", "E-3", "F-3",
	  "F#3", "G-3", "G#3", "A-3", "A#3", "B-3",
	  "C-4", "C#4", "D-4", "D#4", "E-4", "F-4",
	  "F#4", "G-4", "G#4", "A-4", "A#4", "B-4",
	  "C-5", "C#5", "D-5", "D#5", "E-5", "F-5",
	  "F#5", "G-5", "G#5", "A-5", "A#5", "B-5",
	  "C-6", "C#6", "D-6", "D#6", "E-6", "F-6",
	  "F#6", "G-6", "G#6", "A-6", "A#6", "B-6",
	  "C-7", "C#7", "D-7", "D#7", "E-7", "F-7",
	  "F#7", "G-7", "G#7", "A-7", "A#7", "B-7" ];

enum {
	MAX_SEQ_ROWS = 0x40,
	MAX_SEQ_NUM = 0x80,
	TRACK_LIST_LENGTH = 0x200,
	OFFSETTAB_LENGTH = 16 * 6,
	SEQ_END_MARK = 0xbf,
	SONG_REVISION = 10,
	NOTE_KEYOFF = 1,
	NOTE_KEYON = 2,
}

const ubyte[] CLEAR = [0xf0, 0xf0, 0x60, 0x00];

alias char*[] ByteDescription;

ByteDescription bt;

struct Cmd {
	private ubyte[] data;
	static Cmd opCall() {
		Cmd cmd;
		return cmd;
	}

	static Cmd opCall(ubyte[] d) {
		Cmd cmd;
		cmd.data = d;
		return cmd;
	}
	
	void opAssign(ubyte cmd) {
		data[3] = cmd;
		if(cmd >= 0 && data[2] < 0x60) data[2] += 0x60;
	}

	ubyte value() { return data[3]; }
	alias value rawValue;

	string toString() {
		return toString(true);
	}

	string toString(bool colors) {
		ubyte v = data[3];
		if(v > 0) 
			return format("`+f%02X", v);
		else return "`+b--";
	}

	string toPlainString() {
		ubyte v = data[3];
		if(v > 0) 
			return format("%02X", v);
		else return "--"; 
	}
}

struct Ins {
	private ubyte[] data;
	static Ins opCall() {
		Ins ins;
		return ins;
	}
	static Ins opCall(ubyte[] d) {
		Ins ins;
		ins.data = d;
		return ins;
	}

	void opAssign(ubyte newins) {
		if(newins < 0x30)
			data[0] = cast(ubyte) (newins + 0xc0);
		else data[0] = cast(ubyte)0xf0;
	}
	ubyte rawValue() { return data[0]; }
	ubyte value() { return cast(ubyte)(data[0] - 0xc0); }
	private alias value v;

	bool hasValue() { return value() < 0x30; }
	
	string toString() {
		if(v >= 0 && v < 0x30) 
			return format("`+f%02X", v);
		else return "`+b--";
	}

	string toPlainString() {
		alias value v;
		if(v >= 0 && v < 0x30) 
			return format("%02X", v);
		else return "--";
	}
}

struct Note {
	private ubyte[] data;
	static Note opCall(ubyte[] d) {
		Note no;
		no.data = d;
		return no;
	}

	void opAssign(ubyte newnote) {
		if(newnote > 0x5e) newnote = 0x5e;
		data[2] = cast(ubyte)(newnote + 0x60);
	}
	
	ubyte rawValue() {
		return data[2];
	}
	
	ubyte value() {
		return data[2] % 0x60;
	}
	
	void setTied(bool t) {
		if(t) 
			data[1] = 0x5f;
		else data[1] = 0xf0;
	}

	bool isTied() {	return data[1] == 0x5f;	}
	private alias value v;

	string toString(int trns) {
		string col, colh;
		if(isTied()) {
			col = "`4f";
			colh = "`4b";
		}
		else {
			col = "`0f";
			colh = "`0b";
		}
		switch(v) {
		case 0:
			return format("%s---", colh );
		case 1:
			return format("%s===", col );
		case 2:
			return format("%s+++", col );
		default:
			if((v + trns) > 0x5e || (v + trns) < 0)
				return format("%s???", col);
			else return format("%s%s", col, 
							   NOTES[v + trns]);
		}
	}

	string toPlainString(int trns) {
		switch(v) {
		case 0:
			return "---"; 
		case 1:
			return "==="; 
		case 2:
			return "+++"; 
		default:
			if((v + trns) > 0x5e)
				return "???";
			else return NOTES[v + trns];
		}
	}
}

struct Element {
	Ins instr;
	alias instr instrument;
	Cmd cmd;
	Note note;
	int transpose;
	private ubyte[] data;

	static Element opCall(ubyte[] chunk) {
		static Element e;
		e.cmd = Cmd(chunk);
		e.instr = Ins(chunk);
		e.note = Note(chunk);
		e.data = chunk;
		return e;
	}

	string toString() {
		return toString(transpose);
	}
	
	string toString(int trans) {
		return format("%s`+0 %s %s", note.toString(trans), 
					  instr.toString(), cmd.toString());
	}
	
	string toPlainString() {
		return format("%s %s %s", note.toPlainString(transpose), 
					  instr.toPlainString(), cmd.toPlainString());
	}
}

struct Tracklist {
	private Track[] list; // rename
	int length() { return cast(int) list.length; }
	void length(size_t il) {
		list.length = il;
	}

	Track opIndex(int i) {
		if(i >= 0x400) i = 0;
		return list[i];
	}

	static Tracklist opCall(Tracklist tl) {
		Tracklist t;
		t = tl;
		return t;
	}

	int _dollar() {
		return cast(int)list.length;
	}

	static Tracklist opCall(Track[] t) {
		Tracklist tl;
		tl.list = t;
		return tl;
	}

	Track last() { return list[getListLength()]; }

	void opIndexAssign(Track t, size_t il) {
		list[il] = t;
	}

	Track[] opSlice() { return list; }

	Tracklist opSlice(size_t x, size_t y) {
		return Tracklist(list[x..y]);
	}

	int opApply(int delegate(ref Track) dg) {
		int result;
		for(int i = 0; i < getListLength(); i++) {
			result = dg(list[i]);
			if(result) break;
		}
		return result;
	}

	int opApplyReverse(int delegate(ref Track) dg) {
		int result;
		for(int i = cast(int)(list.length - 1); i >= 0; i--) {
			result = dg(list[i]);
			if(result) break;
		}
		return result;
	}

	int getListLength() {
		int i;
		for(i = 0; i < length; i++) {
			Track t = list[i];
			if(t.trans >= 0xf0) return i;
		}
		assert(0);
	}
	
	int getHighestTrackNo(int voice) {
		int i, highest;
		for(i = 0; i < length; i++) {
			Track t = list[i];
			if(t.no > highest) highest = t.no;
		}
		return highest;
	}

	void expand() {
		insertAt(getListLength());
	}

	void shrink() {
		deleteAt(getListLength()-1);
	}

	void insertAt(int offset) {
		assert(offset >= 0 && offset < list.length);
		for(int i = cast(int)(list.length - 2); i >= offset; i--) {
			list[i+1] = list[i].dup;
		}
		list[offset].setTrans(0x80);
		list[offset].setNo(0);
		if(wrapOffset() >= offset) {
			wrapOffset( cast(address)(wrapOffset() + 1));
		}
	}

	void deleteAt(int offset) {
		if(list[1].trans >= 0xf0) return;
		for(int i = offset; i < list.length - 2; i++) {
			list[i] = list[i+1].dup;
		}		
		if(wrapOffset() >= offset) {
			wrapOffset( cast(address)(wrapOffset() - 1));
		}
	}

	void transposeAt(int s, int e, int t) {
		foreach(trk; list[s..e]) trk.transpose(t);
	}

	address wrapOffset() {
		return (last.getValue2() / 2) & 0x7ff;
	}

	void wrapOffset(address offset) {
		if(song.ver < 6) return;
		if((offset & 0xff00) >= 0xfe00) return;
		assert(offset >= 0 && offset < 0x400);
		if(offset >= getListLength())
			offset = cast(ushort)(getListLength() - 1);
		offset *= 2;
		offset |= 0xf000;
		last() = [(offset & 0xff00) >> 8, offset & 0x00ff];
	}

	ubyte[] compact() {
		ubyte[] arr;
		int p, trans = -1, wrapptr = wrapOffset() * 2;

		arr.length = 1024;
		foreach(idx, track; list) {
			if(track.trans >= 0xf0) {
				wrapptr |= 0xf000;
				arr[p .. p + 2] = [(wrapptr & 0xff00) >> 8, wrapptr & 0x00ff];
				p += 2;
				break;
			}
			if((track.trans != trans && track.trans != 0x80) || idx == wrapOffset()) {
				trans = track.trans;
				arr[p++] = cast(ubyte)trans;
			} 
			else if(idx < wrapOffset() ) {
				wrapptr--;
			}
			arr[p++] = track.no;
		}
		return arr[0..p];
	}
}

struct Track {
	private ubyte[] data;

	static Track opCall(ubyte[] tr) {
		Track t;
		t.data = tr;
		assert(t.data.length == 2);
		return t;
	}

	static Track opCall(Track trk) {
		assert(0); //!
		Track t;
		return t;
	}	

	static Track opApply(Track trk) {
		assert(0); //!
		Track t;
		return t;
	}

	void opAssign(ushort s) { 
		data[0] = s & 255;
		data[1] = s >> 8;
	}	

	void opAssign(ubyte[] d) { 
		data[] = d[];
	}

	void setNo(ubyte no) {
		data[1] = no;
	}

	void setTrans(ubyte t) {
		data[0] = t;
	}

	ushort dup() {
		return trans | (no << 8);
	}

	ushort getValue2() { // "real" int value, trans = highbyte
		return no | (trans << 8);
	}
	
	void setValue(Track t) {
		data = t.data;
	}

	void setValue(int tr, int no) {
		if(tr < 0x80) tr = 0x80;
		if(tr > 0xf3) tr = 0xf3;
		if(no < 0) no = 0;
		if(no >= MAX_SEQ_NUM) no = MAX_SEQ_NUM-1;
		data[0] = tr & 255;
		data[1] = no & 255;
	}
	
	ubyte trans() {
		return data[0];
	}
	alias trans getTrans;
	ubyte no() {
		return data[1];
	}
	alias no getNo;

	string toString() {
		string s = format("%02X%02X", trans, no);
		return s;
	}
	/+
	Sequence sequence() {
		return song.seqs[this.no()];
	}
	+/
	void transpose(int val) {
		if(trans == 0x80 || trans >= 0xf0) return;
		int t = trans + val;
		if(t > 0xbf) setTrans(0xbf);
		else if(t < 0x80) setTrans(0x80);
		else setTrans(cast(ubyte)t);
	}
}


class Sequence {
	ElementArray data;
	int rows;

	static struct ElementArray {
		ubyte[] raw;
		int length() { return cast(int)raw.length; }

		Element opIndex(int i) {
			assert(i < MAX_SEQ_ROWS * 4);
			assert(i < (raw.length * 4));
			ubyte[] chunk = raw[i * 4 .. i * 4 + 4];
			return Element(chunk);
		}

		void opIndexAssign(int value, size_t il) { 
			raw[il] = cast(ubyte)value;
		}
		
		int opApply(int delegate(Element) dg) {
			int result;
			for(int i = 0; i < length()/4; i++) {
				result = dg(opIndex(i));
				if(result) break;
			}
			return result;
		}
	}
	
	this(ubyte[] d) {
		// FIX: most of it should only be done on song.open
		data = ElementArray(d);
		refresh();
		if(rows*4+4 < 254)
			data.raw[rows*4 + 4 .. 254] = 0;
	}

	this(ubyte[] rd, int r) {
		data = ElementArray(rd);
		rows = r;
	}

	void refresh() {
		int p, r;
		// find seq length
		while(p < data.length) {
			ubyte b;
			b = data.raw[p+0];
			if(b == SEQ_END_MARK)
				break;
			p += 4; r++;
		}
		rows = r;
	}
	
 	override bool opEquals(Object o) const {
        
		auto rhs = cast(const Sequence)o;
        	return (rhs && (data.raw[] == rhs.data.raw[]));
    	}

	void clear() {
		data.raw[] = 0;
		data.raw[0..5] = [0xf0,0xf0,0x60,0x00,0xbf];
		refresh();
	}

	void expand(int pos, int r) {
		expand(pos, r, true);
	}	

	void expand(int pos, int r, bool doInsert) {
		int i, len;
		int j;

		if(rows >= MAX_SEQ_ROWS) return;
		for(j=0;j<r;j++) {
			if(rows >= MAX_SEQ_ROWS) break;
			rows++;
			if(doInsert)
				insert(pos);
			else data.raw[(rows-1) * 4..(rows-1) * 4 + 4] = cast(ubyte[])CLEAR;
		}
		if(rows < 64)
			data.raw[rows*4] = SEQ_END_MARK;
	}

	void shrink(int pos, int r, bool doRemove) {
		if(rows <= 1 || pos >= rows - 1) return;
		for(int j = 0; j < r; j++) {
			if(doRemove)
				remove(pos);
			// clear endmark
			data.raw[rows * 4 .. $] = 0;
			rows--;
			data.raw[rows * 4 .. rows * 4 + 4] = cast(ubyte[])[ SEQ_END_MARK, 0, 0, 0 ];
		}
	}

	void transpose(int r, int n) {
		for(int i = r; i < rows;i++) {
			Note note = data[i].note;
			int v = note.value;
			if(v < 3) continue;
			if(n >= 0 && (v+n) < 0x60)
				v += n;
			if(n < 0 && (v+n) >= 3) v += n;
			note = cast(ubyte) v;
		}
	}	

	void insert(int pos) {
		int p1 = pos * 4;
		int p2 = rows * 4;
		if(p2 > 256) return;
		ubyte[] c = data.raw[p1 .. p2];
		ubyte[] n = c.dup;
		c[4..$] = n[0..$-4].dup;
		// clear cursor pos
		c[0..4] = cast(ubyte[])CLEAR;
	}
	
	void remove(int pos) {
		ubyte[] tmp;
		int start = pos * 4;
		int end = rows * 4;

		tmp = data.raw[start + 4 .. end].dup;
		data.raw[start .. end - 4] = tmp;
		data.raw[end - 4 .. end] = cast(ubyte[])CLEAR;
	}
	
	void copyFrom(Sequence f) {
		rows = f.rows;
		data.raw[] = f.data.raw[].dup;
	}

	// insert seq f to offset ofs
	void insertFrom(Sequence f, int ofs) {
		// make temporary copy so that seq can be appended over itself
		Sequence copy = new Sequence(f.data.raw.dup);
		expand(ofs, f.rows);

		int max = MAX_SEQ_ROWS*4;
		int st = ofs * 4;
		int len = copy.rows * 4;
		int end = st + len;
		if(end >= max) {
			end = max;
			len = end - st;
		}
		data.raw[st .. end] = copy.data.raw[0..len];
	}
	
	ubyte[] compact() {
		ubyte[] outarr;
		outarr.length = 256;
		int i, outp, olddel, oldins = -1, 
			olddelay = -1, delay;
		for(i = 0; i < rows;) {
			Element e = data[i];
			bool cmd = false;
			int note = e.note.rawValue;

			if(note >= 0x60 && e.cmd.rawValue > 0) 
				cmd = true;
			else {
				if(note >= 0x60) note -= 0x60;
			}
			
			if(e.instr.value < 0x30 && oldins != e.instr.value) {
				oldins = e.instr.value;
				outarr[outp++] = cast(ubyte)(e.instr.value + 0xc0);
			}

			// calc delay
			delay = 0;
			for(int j = i + 1; j < rows; j++) {
				Element ee = data[j];
				if((ee.note.rawValue % 0x60) == 0 &&
				   ee.cmd.rawValue == 0 &&
				   !ee.instr.hasValue()) {
					delay++; i++;
				}
				else break;
			}

			if(olddelay != delay) {
				olddelay = delay & 15;
				outarr[outp++] = cast(ubyte)(delay | 0xf0);
				olddelay = delay & 15;
				delay -= delay & 15;
			}

			if(e.note.isTied()) outarr[outp++] = 0x5f;
			outarr[outp++] = cast(ubyte)note;
			if(cmd)
				outarr[outp++] = cast(ubyte)(e.cmd.rawValue);
			
			while(delay > 15) {
				int d = delay;
				if(d > 15) d = 15;
				if(olddelay != d) {
					outarr[outp++] = cast(ubyte)(d | 0xf0);
					olddelay = d;
				}
				outarr[outp++] = cast(ubyte)0;
				delay -= 16;
			}
			
			i++;
		}
		outarr[outp++] = cast(ubyte)SEQ_END_MARK;
		outarr.length = outp;
		return outarr;
	}
	
}

class Song {
	class PlayerError : Error {
		this(string msg) { super(msg); }
	}

	enum DatafileOffsets {
		Binary, Header = 65536, 
			Title = Header + 256 + 5, Author = Title + 32, Release = Author + 32,
			Insnames = Title + 40 * 4,
			Subtunes = Insnames + 1024 * 2
	}
	
	private {
		struct Features {
			ubyte requestedTables;
			ubyte[8] instrumentFlags;
			ubyte[16] cmdFlags;
		}
	}

	struct Table {
		ubyte[] data;
		int offset;
		int size() {
			foreach_reverse(idx, val; data) {
				if(val != 0) return cast(int)(idx + 1);
			}
			return 0;
		}
		int length() { return cast(int)data.length; }
	}

	class Subtunes {
		ubyte[1024][3][32] subtunes;
		private int active;
		this() {
			initArray();
		}
		
		this(ubyte[] arr) {
			ubyte[] subts;
			this();
			subts = cast(ubyte[])(&subtunes)[0..1];
			subts[] = arr;
		}

		private void initArray() {
			foreach(ref tune; subtunes) {
				foreach(ref voice; tune) {
					voice[0 .. 2] = cast(ubyte[])[0xa0, 0x00];
					for(int i = 2; i < voice.length; i += 2) {
						voice[i .. i+2] = cast(ubyte[])[0xf0, 0x00];
					}
				}
			}
		}

		void clear() {
			initArray();
			syncFromBuffer();
		}

		void syncFromBuffer() {
			for(int i = 0; i < 3; i++) {
				data[offsets[Offsets.Track1 + i] .. offsets[Offsets.Track1 + i] + 0x400] =
					subtunes[active][i][0..0x400];
			}
		}

		Tracklist[] opIndex(int n) {
			static Tracklist[] tr;

			tr.length = 3;
			for(int i=0;i<3;i++) { 
				tr[i].length = TRACK_LIST_LENGTH;
			}
			for(int i = 0; i < 3 ; i++) {
				
				ubyte[] b;
				// use array from c64 memory if getting current subtune
				if(n == active)
					b = buffer[offsets[Offsets.Track1 + i] .. offsets[Offsets.Track1 + i] + 0x400];
				else b = subtunes[n][i][0..0x400];
				for(int j = 0; j < b.length / 2; j++) {
					tr[i][j] = Track(b[j * 2 .. j * 2 + 2]);
				}
			}
			return tr;
		}

		void activate(int n) { activate(n, true); }
		void activate(int n, bool dosync) {
			if(n > 0x1f || n < 0) return;
			if(dosync)
				sync();
			active = n;
			for(int i = 0; i < 3; i++) {
				buffer[offsets[Offsets.Track1 + i] .. offsets[Offsets.Track1 + i] + 0x400] =
					subtunes[active][i][0..0x400];
			}
			if(ver >= 6)
				speed = songspeeds[active];
		}	

		/* sync "external" subtune array to active one (stored in c64s mem)
		 * the correct way would be to let trackinput also update the external array */
		void sync() {
			for(int i = 0; i < 3; i++) {
				subtunes[active][i][0..0x400] =
					buffer[offsets[Offsets.Track1 + i] .. offsets[Offsets.Track1 + i] + 0x400];
			}
		}

		int numOf() {
			foreach_reverse(idx, ref tune; subtunes) {
				foreach(ref voice; tune) {
					if(voice[1 .. 4] != cast(ubyte[])[0x00, 0xf0, 0x00])
						return cast(int)(idx + 1);
				}
			}
			return 0;
		}

		ubyte[][][] compact() {
			ubyte[][][] arr;
			
			arr.length = numOf();
			
			foreach(ref subarr; arr) {
				subarr.length = 3;
			}
			
			for(int i = 0; i < numOf(); i++) {
				ubyte[][] subarr = arr[i];
				activate(i);
				foreach(idx, ref voice; subarr) {
					voice = tracks[idx].compact().dup;
				}
			}
			return arr;
		}
	}

	int ver = SONG_REVISION, clock, multiplier = 1, sidModel, fppres;
	char[32] title = ' ', author = ' ', release = ' ', message = ' ';
	char[32][48] insLabels;
	Features features;
	CPU cpu;
	ubyte[] sidbuf;
	ubyte[65536] data;
	alias data buffer;
	alias data memspace;
	Tracklist[] tracks;
	Sequence[] seqs;
	alias seqs sequences;
	address[] offsets;
	ubyte[] pparams; // filttab bytes 0-3
	ubyte[32] songspeeds;
	ubyte[] songsets;
	ubyte[] wave1Table, wave2Table, waveTable;
	ubyte[] instrumentTable, pulseTable, filterTable, superTable, chordTable, chordIndexTable;
	ubyte[] seqlo, seqhi;
	ByteDescription instrumentByteDescriptions,
		pulseDescriptions, filterDescriptions,
		waveDescriptions, cmdDescriptions;

	// dupes of raw tables above, will eventually update all code to use these 
	Table tSongsets, tWave1, tWave2, tWave, tInstr, tPulse, tFilter, tSuper, tChord, tChordIndex, tSeqlo, tSeqhi;
	Table tTrack1, tTrack2, tTrack3;
	Table[string] tables;
	char[] playerID;
	int subtune;
	Subtunes subtunes;

	this() {
		this(cast(ubyte[])import("player.bin"));
	}

	this(ubyte[] player) {
		cpu = new CPU(buffer);
		subtunes = new Subtunes();
		foreach(ref desc; insLabels) {
			desc[] = 0x20;
		}
		ver = SONG_REVISION;
		ubyte[] bin;
		bin.length = 65536;
		bin[0xdfe .. 0xdfe + player.length] = player;
		if(bin[0xdfe .. 0xe00] != cast(ubyte[])[ 0x00, 0x0e ])
			throw new PlayerError("Illegal loading address.");
		songspeeds[] = 5;
		open(bin);
		sidbuf = memspace[0xd400 .. 0xd419];
	}

	void open(string fn) {
		ubyte[] inbuf = cast(ubyte[])read(fn);
		if(inbuf[0..3] != cast(ubyte[])"CC2"[0..3]) {
			throw new Exception("Incorrect filetype.");
		}

		ubyte[] debuf = cast(ubyte[])std.zlib.uncompress(inbuf[3..$],167832);
		int offset = 65536;
		ver = debuf[offset++];
		clock = debuf[offset++];
		multiplier = debuf[offset++];
		sidModel = debuf[offset++];
		fppres = debuf[offset++];
		if(ver >= 6) {
			songspeeds[0..32] = debuf[offset .. offset+32];
			offset += 32;
		}
		offset = DatafileOffsets.Title;
		title[0..32] = cast(char[])debuf[offset .. offset + 32];
		author[0..32] = cast(char[])debuf[offset + 32 .. offset + 64];
		release[0..32] = cast(char[])debuf[offset + 64 .. offset + 96];
		offset += 40 * 4;
		assert(DatafileOffsets.Insnames == offset);
		offset = DatafileOffsets.Insnames;

		ubyte[] insnames = 
			cast(ubyte[])(&insLabels)[0..1];
		insnames[] = debuf[offset .. offset + 48*32];
		
		assert(DatafileOffsets.Subtunes == offset + 1024 * 2);
		offset += 1024 * 2;
		int len = 1024*3*32;
		subtunes = new Subtunes(debuf[offset .. offset + len]);
		offset += len;
		open(debuf[0..65536]);
	}

	void setMultiplier(int m) {
		assert(m > 0 && m < 16);
		multiplier = m;
		memspace[Offsets.Volume + 1] = cast(ubyte)m;
	}

	void open(ubyte[] buf) {
		int i, voi;
		//int lastused;
		data[] = buf;

		offsets.length = 0x60;
		seqs.length = MAX_SEQ_NUM;
		tracks.length = 3;
		for(i=0;i<3;i++) { 
			tracks[i].length = TRACK_LIST_LENGTH;
		}

		for(i = 0;i < OFFSETTAB_LENGTH; i++) {
			offsets[i] = data[0xfa0+i*2] | (data[0xfa1+i*2] << 8);
		}

		for(int no=0;no<MAX_SEQ_NUM;no++) {
			int p, lo, hi;
			int lobyt = offsets[Offsets.SeqLO] + no, hibyt = offsets[Offsets.SeqHI] + no;
			p = data[lobyt] + (data[hibyt] << 8);

			ubyte[] raw_seq_data = data[p .. p+256];
			seqs[no] = new Sequence(raw_seq_data);
		}

		for(voi = 0; voi < 3; voi++) {
			ubyte[] b; 
			int t;
			int offset = offsets[Offsets.Track1 + voi];
			b = data[offset .. offset + 0x400];
			for(i = 0; i < b.length/2; i++) {
				//int tr = b[i * 2 + 1];
				//if(tr > lastused) lastused = tr;
				tracks[voi][i] = Track(memspace[offset + i * 2 .. offset + i * 2 + 2]);
			}
		}

		i = offsets[Offsets.Songsets];
		songsets = data[i .. i + 256];
		tSongsets = Table(songsets, i);

		i = offsets[Offsets.Arp1];
		wave1Table = data[i .. i + 256];
		wave2Table = data[i + 256 .. i + 512];
		waveTable = data[i .. i + 512];
		tWave1 = Table(wave1Table, i);
		tWave2 = Table(wave2Table, i + 256);
		tWave = Table(waveTable, i);

		i = offsets[Offsets.Inst];
		instrumentTable = data[i .. i + 512];
		tInstr = Table(instrumentTable, i);

		i = offsets[Offsets.CMD1];
		superTable = data[i .. i + 256];
		tSuper = Table(superTable, i);

		i = offsets[Offsets.PULSTAB];
		pulseTable = data[i .. i + 256];
		tPulse = Table(pulseTable, i);

		i = offsets[Offsets.FILTTAB];
		pparams = memspace[i .. i + 4]; 
		filterTable = data[i .. i + 256];
		tFilter = Table(filterTable, i);

		i = offsets[Offsets.SeqLO];
		seqlo = data[i .. i + 256];
		tSeqlo = Table(seqlo, i);

		i = offsets[Offsets.SeqHI];
		seqhi = data[i ..i + 256];
		tSeqhi = Table(seqlo, i);


		i = offsets[Offsets.ChordTable];
		chordTable = data[i .. i + 128];
		tChord = Table(chordTable, i);

		i = offsets[Offsets.ChordIndexTable];
		chordIndexTable = data[i .. i + 32];
		tChordIndex = Table(chordIndexTable, i);

		generateChordIndex();

		i = offsets[Offsets.Track1];
		tTrack1 = Table(data[i .. i + 0x400], i);
		i = offsets[Offsets.Track2];
		tTrack2 = Table(data[i .. i + 0x400], i);
		i = offsets[Offsets.Track3];
		tTrack3 = Table(data[i .. i + 0x400], i);
		
		playerID = cast(char[])data[0xfee .. 0xff5];
   		subtune = 0;

		i = offsets[Offsets.Features];
		ubyte[] b = memspace[i .. i + 64];
		features.requestedTables = b[0];
		features.instrumentFlags[] = b[1..9];

		/*
		ubyte* b = cast(ubyte*)&features;
		b[0..features.sizeof] = memspace[i .. i + features.sizeof];
		*/

		if(ver > 7) {
			instrumentByteDescriptions.length = 8;
			i = offsets[Offsets.InstrumentDescriptionsHeader];
			for(int j = 0; j < 8; j++) {
				int ioffset = memspace[i] | (memspace[i+1] << 8);
				instrumentByteDescriptions[j] = cast(char*)&memspace[ioffset];
				i += 2;
			}
		}

		if(ver > 8) {
			int offset;
			filterDescriptions.length = 4;
			offset = offsets[Offsets.FilterDescriptionsHeader];
			foreach(idx, ref descr; filterDescriptions) {
				int soffset = memspace[offset + idx * 2] | (memspace[offset + idx * 2 + 1] << 8);
				descr = cast(char*)&memspace[soffset];
			}
			pulseDescriptions.length = 4;
			offset = offsets[Offsets.PulseDescriptionsHeader];
			foreach(idx, ref descr; pulseDescriptions) {
				int soffset = memspace[offset + idx * 2] | (memspace[offset + idx * 2 + 1] << 8);
				descr = cast(char*)&memspace[soffset];
			}
			waveDescriptions.length = 2;
			offset = offsets[Offsets.WaveDescriptionsHeader];
			foreach(idx, ref descr; waveDescriptions) {
				int soffset = memspace[offset + idx * 2] | (memspace[offset + idx * 2 + 1] << 8);
				descr = cast(char*)&memspace[soffset];
			}

			cmdDescriptions.length = 2;
			offset = offsets[Offsets.CmdDescriptionsHeader];
			foreach(idx, ref descr; cmdDescriptions) {
				int soffset = memspace[offset + idx * 2] | (memspace[offset + idx * 2 + 1] << 8);
				descr = cast(char*)&memspace[soffset];
			}

		}
		
		subtunes.syncFromBuffer();
		cpu.reset();
		cpu.execute(0x1000);
		tables = [ cast(string)"songsets":tSongsets, "wave1":tWave1, "wave2":tWave2,
				   "instr":tInstr, "pulse":tPulse, "filter":tFilter, "cmd":tSuper,
				   "chord":tChord, "chordidx":tChordIndex, "seqlo":tSeqlo, "seqhi":tSeqhi ];
	}
	
	void save(string fn) {
		// get tracks from the c64 memory to subtunes-array
		subtunes.sync();
		ubyte[] b;
		int offset;
		b.length = 300000;

		b[0..65536] = memspace;
		offset += 65536;

		foreach(val; [ver, clock, multiplier, sidModel, fppres]) {
			b[offset++] = val & 255;
		}
		
		b[offset .. offset+32] = songspeeds[];
		offset = DatafileOffsets.Title;

		foreach(str; [title, author, release, message]) {
			b[offset .. offset + 32] = cast(ubyte[])str[];
			offset += 32;
		}

		ubyte[] arr;
		offset = DatafileOffsets.Insnames;

		arr = cast(ubyte[])(&insLabels)[0..1]; 
		b[offset .. offset + arr.length] = arr[];
		offset += arr.length;
		offset += 32 * 32 - 0x200;

		arr = cast(ubyte[])(&subtunes.subtunes)[0..1]; 
		b[offset .. offset + arr.length] = arr[];
		offset += arr.length;
		std.file.write(fn, "CC2");
		append(fn, std.zlib.compress(b));
	}

	void splitSequence(int seqno, int seqofs) {
		if(seqno == 0) return;
		if(seqofs == 0) return;
		int suborig = subtune;
		int newseqno = getFreeSequence(0);
		Sequence s = seqs[seqno];
		if(seqofs == s.rows - 1) return;
		Sequence copy = new Sequence(s.data.raw.dup);
		Sequence ns = seqs[newseqno];
		ns.copyFrom(s);
		ns.shrink(0, seqofs, true);
		s.shrink(seqofs, s.rows - seqofs, true);
		subtunes.sync();
		foreach(sIdx, st; subtunes.subtunes) {
			subtunes.activate(cast(int)sIdx);
			foreach(vIdx, voice; tracks) {
				for(int tIdx = voice.length - 1; tIdx >= 0; tIdx--) {
					Track t = voice[tIdx];
					if(t.no == seqno) {
						tracks[vIdx].insertAt(tIdx+1);
						Track t2 = tracks[vIdx][tIdx+1];
						t2.setTrans(0x80);
						t2.setNo(cast(ubyte)newseqno);
					}
					
				}
			}
		}
		subtunes.activate(suborig);
	}

	private int getTablepointer(ubyte[] table, ubyte[] flags, int requestedFlag, int insno) {
		foreach(i, flag; flags) {
			if(flag != requestedFlag) continue;
			return table[insno + i * 48];
		}
		throw new Exception(format("Missing tablepointer %d.", requestedFlag));
	}
	
	int getWavetablePointer(int insno) {
		return getTablepointer(instrumentTable, features.instrumentFlags, 1, insno);
	}

	int getPulsetablePointer(int insno) {
		return getTablepointer(instrumentTable, features.instrumentFlags, 3, insno);
	}

	int getFiltertablePointer(int insno) {
		return getTablepointer(instrumentTable, features.instrumentFlags, 4, insno);
	}

	void saveDump(string fn) {
		subtunes.sync();
		int upto = numOfSeqs() - 1;
	
		int lobyt = offsets[Offsets.SeqLO] + upto, hibyt = offsets[Offsets.SeqHI] + upto;
		int lastaddr = memspace[lobyt] | (memspace[hibyt] << 8) + 256;

		// w(format("saving up to $%X ($%04X)", upto, lastaddr));
		std.file.write(fn, cast(ubyte[])[0x00, 0x10] ~ memspace[0x1000 .. lastaddr]);
	}

	void seqIterator(void delegate(Sequence s, Element e) dg) {
		foreach(i, s; seqs) {
			for(int j = 0; j < s.rows; j++) {
				Element e = s.data[j];
				dg(s, e);
			}
		}
	}

	ubyte[] getDump(int s) {
		subtunes.activate(s);
		int upto;
	
		int lobyt = offsets[Offsets.SeqLO] + upto, hibyt = offsets[Offsets.SeqHI] + upto;
		int lastaddr = memspace[lobyt] | (memspace[hibyt] << 8) + 256;
		return memspace[0x1000 .. 0xbfff];
	}

	// deprecate
	int numOfSeqs() {
		int upto;
		foreach(int i, s; seqs) {
			if(s != seqs[0]) upto = i;
		}
		return upto + 1;
	}
	
	int speed() {
		return memspace[offsets[Offsets.SPEED]];
	}

	void speed(int spd) {
		memspace[offsets[Offsets.Songsets] + 6] = cast(ubyte)spd;
		memspace[offsets[Offsets.SPEED]] = cast(ubyte)spd;
		songspeeds[subtune] = cast(ubyte)spd;
		if(ver >= 5 && spd >= 2)
			memspace[offsets[Offsets.PlaySpeed]] = cast(ubyte)spd;
	}

	int playSpeed() {
		return memspace[offsets[Offsets.PlaySpeed]];
	}

	private void arpPointerUpdate(int pos, int val) {
		foreach(i, flag; features.instrumentFlags) {
			if(flag != 1) continue;
			for(int j = 0; j < 48; j++) {
				ubyte b7 = instrumentTable[j + i * 48];
				if(b7 > pos) {
					int v = b7 + val;
					if(v < 0) v = 0;
					instrumentTable[j + i * 48] = cast(ubyte)v;
				}
			}
			
		}
	}

	void wavetableInsert(int pos) {
		int i;
		for(i = 254; i >= pos; i--) {
			wave1Table[i + 1] = wave1Table[i];
			wave2Table[i + 1] = wave2Table[i];
		}
		for(i=0;i<256;i++) {
			if(wave1Table[i] == 0x7f &&
			   wave2Table[i] >= pos)
				wave2Table[i]++;
		}
		wave1Table[pos] = 0;
		wave2Table[pos] = 0;
		arpPointerUpdate(pos, 1);
	}

	void setVoicon(int m1, int m2, int m3) {
		buffer[offsets[Offsets.VOICE]+0] = m1 ? 0x19 : 0x00;
		buffer[offsets[Offsets.VOICE]+1] = m2 ? 0x19 : 0x07;
		buffer[offsets[Offsets.VOICE]+2] = m3 ? 0x19 : 0x0e;
	}

	void setVoicon(shared int[] m) {
		setVoicon(m[0], m[1], m[2]);
	}
	
	int getFreeSequence(int start) {
  		bool flag;
		subtunes.sync();
		for(int s = start; s < MAX_SEQ_NUM; s++) {
			flag = false;
			foreach(ist, st; subtunes.subtunes) {
				foreach(voice; st) {
					foreach(t; voice) {
						if(t == s)
							flag = true;
					}
				}
			}
			if(!flag) return s;
		}
		return -1;
	}

	// FIX: move to tablecode
	void wavetableRemove(int pos) {
		wavetableRemove(pos, 1);
	}

	void wavetableRemove(int pos, int num) {
		for(int n = 0; n < num; n++) {
			int i;
			assert(pos < 255 && pos >= 0);
			for(i = pos; i < 255; i++) {
				wave1Table[i] = wave1Table[i + 1];
				wave2Table[i] = wave2Table[i + 1];
			}
			for(i=0;i < 256;i++) {
				if((wave1Table[i] == 0x7f || wave1Table[i] == 0x7e) &&
				   wave2Table[i] >= pos)
					wave2Table[i]--;
			}
			arpPointerUpdate(pos, -1);
		}	
	}

	void clearSeqs() {
		for(int i = 1; i < MAX_SEQ_NUM; i++) {
			seqs[i].clear();
		}
		subtunes.clear();
	}
	
	void incSubtune() { 
		if(subtune < 31)
			subtunes.activate(++subtune); 
	}

	void decSubtune() { 
		if(subtune > 0)
			subtunes.activate(--subtune); 
	}

	void generateChordIndex() {
		int crd, p;
		for(int i = 0; i < 128; i++) {
			if(chordTable[i] >= 0x80) {
				chordIndexTable[crd++] = cast(ubyte)p;
				p = i + 1;
			}
		}
	}

	void importData(Song insong) {
		// copy tables
		foreach(idx, table; [ "wave1", "wave2", "cmd", "instr", "chord", "pulse", "filter"]) {
			tables[table].data[] = insong.tables[table].data;
		}
		// sequences
		foreach(idx, ref seq; insong.seqs) {
			seqs[idx].data.raw[] = seq.data.raw;
			seqs[idx].refresh();
			
		}
		// subtunes........
		subtunes.subtunes[][][] = insong.subtunes.subtunes[][][];
		subtunes.syncFromBuffer();
		// labels
		insLabels[] = insong.insLabels[];
		title[] = insong.title[];
		author[] = insong.author[];
		release[] = insong.release[];

		generateChordIndex();
	}
}

/+ vars +/
__gshared Song song;

static this() {
	song = new Song();
}

