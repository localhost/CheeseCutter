module seq.sequencer;
import main;
import com.fb;
import ui.ui;
import ct.base;
import ui.input;
import ui.dialogs;
private {
	import seq.fplay;
	import seq.tracktable;
	import seq.seqtable;
	import seq.trackmap;
}
import derelict.sdl.sdl;
import std.string;

const PAGESTEP = 2;
enum Jump { ToBeginning = 0, ToMark = -1, ToEnd = -2, ToWrapMark = -3 };

const int playbackBarColor = 6;
const int wrapBarColor = 4;

bool displaySequenceRowcounter = true;
PosinfoTable fpPos, tPos;
int stepValue = 1;
int highlight = 4;
int highlighOffset;
int activeVoiceNum;
int stepCounter;

int tableTop = 15, tableBot = -16, tableScrMid = 0;
int anchor = 16;

static this() {
	tPos = new PosinfoTable();
	fpPos = new PosinfoTable();
	for(int i = 0; i < 3; i++) {
		tPos[i].tracks = song.tracks[i];
		fpPos[i].tracks = song.tracks[i];
	}
}

private {
	bool useRelativeNotes = true;
}

struct SequenceRowData {
	// track number
	Track trk; 
	alias trk track;
	// offset in tracklist, checked against endmark
	int trkOffset; 
	// offset in tracklist, not checked
	int trkOffset2;
	int seqOffset;
	Sequence seq; // full sequence, cursor is at seq[seqOffset]
	//Sequence clipped; // clipped sequence, from cursor downwards
	int clippedRows;
	Element element; // data entry under cursor
}

struct VoiceInit {
	Tracklist t;
	Rectangle a;
	Posinfo p;
}

private struct 	Clip {
	int trans, no;
}

protected class Posinfo {
	int _pointerOffset = 0;
	int pointerOffset() { return _pointerOffset - anchor; }
	int pointerOffset(int i) { return _pointerOffset = i + anchor; }
	int trkOffset = 0;
	int seqOffset;
	int mark; 
	int rowCounter;
	Tracklist tracks;
	int getRowCounter() {
		int counter = 0;
		// for(int i = 0; i <= trkOffset; i++) 
		// TODO... find out why the following doesn't cause problems
		for(int i = 0; i <= trkOffset; i++) {
			Track t = tracks[i];
			//seq = t.sequence();
			//counter += seq.rows;
			counter += .sequence(t).rows;
		}
		return counter + seqOffset;
	}
}

protected class PosinfoTable {
	Posinfo[] pos;
	this() {
		pos.length = 3;
		foreach(ref p; pos) p = new Posinfo;
	}
	Posinfo opIndex(int idx) {
		return pos[idx];
	}
	int pointerOffset(int o) { 
		foreach(ref p; pos) { p.pointerOffset = o; }
		return 0;
	}
	int pointerOffset() { return pos[0].pointerOffset; }
	int normalPointerOffset() { 
		int r = tableTop + pos[0].pointerOffset;
		return r;
	}
			
	int rowCounter() { 
		return pos[0].rowCounter; 
	}
	int rowCounter(int o) { 
		foreach(ref p; pos) { p.rowCounter = o; }
		return 0;
	}
	//int anchor() { return pos[0].anchor; }
	void dup(PosinfoTable pt) {
		for(int i = 0 ; i < 3; i++) {
			Posinfo p = pos[i];
			Posinfo t = pt[i];
			p.pointerOffset = t.pointerOffset;
			p.seqOffset = t.seqOffset;
			p.trkOffset = t.trkOffset;
			p.rowCounter = t.rowCounter;
			p.mark = t.mark;
		}
	}
}

// ------------------------------------------------------------------------

abstract protected class Voice : Window {
	protected {
		Tracklist tracks;
	}
	Posinfo pos;
	SequenceRowData activeRow;
	Input input;
	alias input activeInput;
	
	this(ref VoiceInit v) {
		super(v.a);
		tracks = v.t; pos = v.p;
		assert(pos !is null);
	}

public:

	bool atBeg() { 
		return pos.trkOffset <= 0 && (pos.seqOffset + pos.pointerOffset) <= 0;
	}

	bool atEnd() {
		SequenceRowData s = getRowData(pos.trkOffset, 
									   pos.seqOffset + pos.pointerOffset);
		return (s.trk.trans >= 0xf0);
	}
	
	bool pastEnd() { return pastEnd(0); }
	bool pastEnd(int y) {
		SequenceRowData s = getRowData(pos.trkOffset,
									   pos.seqOffset + y);
		int t = s.trkOffset2 - 1;
		if(t < 0) return false;
		Track trk = tracks[t];
		return (trk.trans >= 0xf0);
	}

	int getVoiceEnd() {
		for(int i = 0; i < TRACK_LIST_LENGTH; i++) {
			if(tracks[i].trans >= 0xf0) return i;
		}
		assert(0);
	}

	void trackFlush(int y) { return; }

	override void refresh() { refreshPointer(0); }

	SequenceRowData getSequenceData(int trkofs, int seqofs) {
		static SequenceRowData s;
		int trkofs2 = trkofs;
		Sequence seq;
		int lasttrk = tracks.getListLength();
		Sequence getSeq(Track t) {
			if(t.trans >= 0xf0) return song.seqs[0];
			else return song.seqs[t.no];
		}
		int getRows() {
			Sequence seq;
			seq = getSeq(tracks[trkofs2]);
			int r = seq.rows;
			if(tracks[trkofs2].trans >= 0xf0)
				r = 1;
			return r;
		}

		if(trkofs > lasttrk) trkofs = lasttrk;
		s.trk = tracks[trkofs];

		seq = getSeq(s.trk);

		while (seqofs < 0)  {
			seqofs += getRows();
			if(--trkofs < 0) {
				trkofs = 0;
				seqofs = 0;
				break;
			}
			--trkofs2;
			s.trk = tracks[trkofs];
			seq = song.seqs[s.trk.no];
		} 
		assert(seqofs >= 0);

		while(seqofs >= getRows()) {
			seqofs -= getRows();
			if(trkofs < lasttrk)
				trkofs++;
			trkofs2++;
			s.trk = tracks[trkofs2];
			seq = getSeq(s.trk);
		}
		s.seqOffset = seqofs;
		s.clippedRows = seq.rows - seqofs;
		s.trkOffset = trkofs;
		s.trkOffset2 = trkofs2;
		s.element = seq.data[seqofs];
		if(useRelativeNotes) {
			int t = trkofs;
			while(t >= 0 && tracks[t].trans == 0x80) t--;
			if(t >= 0)
				s.element.transpose = tracks[t].trans - 0xa0;
		}
		s.seq = seq;
		return s;
	}
	
	SequenceRowData getRowData(int trkofs, int seqofs) {
		return getSequenceData(trkofs, seqofs);
	}

	SequenceRowData getRowData(int tofs) { return getRowData(tofs, 0); }

	void scroll(int steps) {
		scroll(steps, true);
	}

 	void scroll(int steps, bool canWrap) {
		int oldRowcounter;
		SequenceRowData s = getRowData(pos.trkOffset);
		assert(s.seq.rows == s.clippedRows);
		with(pos) {
			seqOffset = seqOffset + steps;
			oldRowcounter = rowCounter;
			rowCounter += steps;
			while(seqOffset + pointerOffset < 0) {
				if(--trkOffset < 0) {
					if(canWrap) {
						trkOffset = getVoiceEnd() - 1;
						rowCounter = getRowCounter();
					}
					else trkOffset = 0;
				} 
				s = getRowData(trkOffset);
				seqOffset += s.clippedRows;
				steps += s.clippedRows;
			}
			while(seqOffset + pointerOffset >= s.clippedRows) {
				seqOffset -= s.clippedRows;
				steps -= s.clippedRows;
				if(++trkOffset >= getVoiceEnd()) {
					if(canWrap) {
						trkOffset = 0;
						rowCounter = seqOffset;
					}
					else { 
						trkOffset = getVoiceEnd()-1; 
						rowCounter = oldRowcounter;
					}
				}
				s = getRowData(trkOffset);
				
			}
		}
	}

	// TODO: move to vpos!
	int getRowcounter(int trkofs) {
		int counter = 0;
		for(int i = 0; i < trkofs; i++) {
			Track t = tracks[i];
			counter += sequence(t).rows;
		}
		return counter;
	}


protected:
	void update();
	void refreshPointer()  {
		refreshPointer(pos.pointerOffset);
	}
	void refreshPointer(int y);

	void jump(int jumpto) {
		if(jumpto == Jump.ToMark) jumpto = pos.mark;
		else if(jumpto == Jump.ToWrapMark) jumpto = tracks.wrapOffset();
		assert(jumpto >= 0);
		pos.trkOffset = jumpto;
		pos.seqOffset = 0;
		pos.rowCounter = getRowcounter(jumpto);
	}    

	void setMark() {
		setMark(1);
	}
	
	// when m == 1, sets mark to current trkOffsets
	// when m == 0, zeroes it out
	void setMark(int m) {
		pos.mark = m ? activeRow.trkOffset : 0;
	}
	alias setMark setPositionMark;

	void setWrapMark() {
		tracks.wrapOffset = cast(ushort) (activeRow.trkOffset);
	}

	string formatTrackValue(int trknum) {
		if(trknum >= 0xf000)
			return "LOOP";
		return format("%04X", trknum);
	}
}

protected abstract class VoiceTable : Window {
protected:
	Voice[3] voices;
	Voice active;
	alias active activeVoice;
	PosinfoTable posTable;

	this(Rectangle a, PosinfoTable pi) {
		super(a);
		posTable = pi;
		activeVoice = voices[0];
	}

	override void activate() {
		activeVoice = voices[activeVoiceNum];
		input = activeVoice.activeInput;
		refresh();
	}

	override void deactivate() {
		activeVoice.trackFlush(posTable.pointerOffset);
	}

	override void refresh() {
		foreach(v; voices) {
			v.refresh(); 
		}
	}

	void centralize() {
		jump(activeVoice.activeRow.trkOffset,true);
	}

	override int keypress(Keyinfo key) {
		if(key.mods & KMOD_SHIFT) {
			switch(key.raw)
			{
			case SDLK_HOME:
				jump(Jump.ToBeginning,true);
				break;
			case SDLK_END:
				jump(Jump.ToEnd,true);
				break;
			case SDLK_PAGEUP:
				step(-PAGESTEP * 2 * highlight);
				break;
			case SDLK_PAGEDOWN:
				step(PAGESTEP * 2 * highlight);
				break;
			default:
				break;
			}
		}
		else if(key.mods & KMOD_CTRL) {
			switch(key.raw)
			{
			case SDLK_h, SDLK_HOME:
				jump(Jump.ToMark,true);
				break;
			case SDLK_l:
				centralize();
				break;
			case SDLK_m:
				if(highlight < 16) 
					highlight++;
				break;
			case SDLK_n:
				if(highlight > 1)
					highlight--;
				break;
			case SDLK_0:
				highlighOffset = posTable.rowCounter+posTable.pointerOffset;
				break;
			case SDLK_r:
				displaySequenceRowcounter ^= 1;
				break;
			case SDLK_t:
				useRelativeNotes ^= 1;
				UI.statusline.display(format("Relative notes %s.", useRelativeNotes ?  "enabled" : "disabled"));
				break;
			case SDLK_F1:
				setPositionMark();
				break;
			case SDLK_BACKSPACE:
				setWrapMark();
				break;
			default:
				break;
			}
		}
		else switch(key.raw)
			 {
			 case SDLK_KP_ENTER, SDLK_KP0, SDLK_BACKSPACE, SDLK_PLUS:
				 setPositionMark();
				 break;
			 default:
				 break;
			 }

		// we don't care about mods with these keys
		switch(key.raw)
		{
		case SDLK_DOWN:
			if(key.mods & KMOD_SHIFT)
				step(stepValue);
			if(key.mods & KMOD_CTRL) {
				scroll(1);
				step(-1);
			}
			else step(1);
			break;
		case SDLK_UP:
			if(key.mods & KMOD_SHIFT)
				step(-stepValue);
			else if(key.mods & KMOD_CTRL) {
				scroll(-1);
				step(1);
			}
			else step(-1);
			break;
		case SDLK_PAGEUP:
			step(-PAGESTEP * highlight);
			break;
		case SDLK_PAGEDOWN:
			step(PAGESTEP * highlight);
			break;
		case SDLK_TAB:
			foreach(v; voices) { v.input.nibble = 0; }
			if(key.mods & KMOD_SHIFT)
				stepVoice(-1);
			else stepVoice();
			break;
		default:
			break;
		}
		return OK;
	}

	void stepVoice() { stepVoice(1); }
	void stepVoice(int i) {
		// safety check - if we're past endmark on all voices,
		// exit the method -- can happen if all tracklists
		// contain only FF00
		bool pastAll = true;
		foreach(voice; voices) {
			if(!voice.pastEnd(posTable.pointerOffset))
				pastAll = false;
		}
		if(pastAll) return;
		int nv = activeVoiceNum + i;
		//int column_reset = (nv - activeVoiceNum) > 0 ? 0 : 1;
		if(nv > 2) nv = 0;
		else if(nv < 0) nv = 2;
        
		while(voices[nv].pastEnd(posTable.pointerOffset)) {
			nv += i;
			if(nv > 2) nv = 0;
			else if(nv < 0) nv = 2;
		}
		activateVoice(nv);
	}

	void scroll(int st) {
		foreach(v; voices) { v.scroll(st); }
	}

	void activateVoice(int voice) {
		assert(voice >= 0 && voice < 3);
		deactivate();
		activeVoiceNum = voice;
		activate();
		voices[voice].refreshPointer();
		step(0);
	}

	void jumpToVoice(int voice) {
		deactivate();
		activeVoiceNum = voice;
		activate();
		// making sure cursor is not past endmark
		step(0);
	}
	
	override void update() {
		input = activeVoice.activeInput; 
		foreach(v; voices) { 
			v.refreshPointer(posTable.pointerOffset);
			v.update(); 
			
		}
		// statusline
		screen.cprint(area.x + 1, area.y, 1, 0, format("#%02X",song.subtune));
		for(int i = 0, x = area.x + 5 + com.fb.border; i < 3; i++) {
			Voice v = voices[i];
			SequenceRowData c = v.activeRow;
			screen.cprint(x, area.y, 1, 0,
				format("+%03X %02X %s", c.trkOffset, c.trk.no,
					   audio.player.muted[i] ? "Off" : "   ") );
			x += 13 + com.fb.border;
		}
		// row counter
		int r = activeVoice.pos.rowCounter - anchor;
		for(int y = 0; y < area.height; y++) {
			string s = repeat(" ", 4);
			if(r >= 0) s = format("%+4X", r);
			r++;
			screen.cprint(area.x, area.y + y + 1, 12, 0, s);
		}

	}
	
	void setPositionMark() {
		foreach(v; voices) { v.setPositionMark(); }
	}

	void setWrapMark() {
		foreach(v; voices) { v.setWrapMark(); }
	}

	void jump(int to, bool doCtr) {
		switch(to) {
		case Jump.ToBeginning:
			posTable.pointerOffset = 0;
			foreach(v; voices) {
				v.jump(Jump.ToBeginning);
			}
			if(doCtr) centerTo(0);
			break;
		case Jump.ToMark:
			posTable.pointerOffset = 0;
			foreach(v; voices) {
				v.jump(Jump.ToBeginning);
				v.jump(v.pos.mark);
			}
			if(doCtr) centerTo(0);
			break;
		case Jump.ToWrapMark:
			posTable.pointerOffset = 0;
			foreach(v; voices) {
				v.jump(Jump.ToBeginning);
				v.jump(v.tracks.wrapOffset());
			}
			if(doCtr) centerTo(0);
			break;
		case Jump.ToEnd:
			centralize();
			toSeqStart();

			foreach(v; voices) {
				v.jump(Jump.ToBeginning);
			}

			int e = activeVoice.getVoiceEnd() - 1;
			
			for(int i = 0; i < e; i++) {
				activeVoice.refreshPointer(posTable.pointerOffset);
				SequenceRowData s = activeVoice.getRowData(i);
				step(s.seq.rows);
			}
			activeVoice.refreshPointer(posTable.pointerOffset);
			toSeqEnd();
			break;
		default:
			if(to < 0) {
				to = activeVoice.pos.mark;
			}
			foreach(v; voices) {
				v.jump(Jump.ToBeginning);
			}
			Voice v = activeVoice;
			posTable.pointerOffset = 0;
			for(int i = 0; i < to; i++) {
				activeVoice.refreshPointer(0);
				int trk = v.tracks[i].no;
				Sequence s = song.seqs[trk];
				step(s.rows);
			}
			if(doCtr) centerTo(0);
			break;
		}
		refresh();
	}

	void toSeqStart() {
		int st = -activeVoice.activeRow.seqOffset;
		this.step(st,0);
	}

	void toSeqEnd() {
		int rows = activeVoice.activeRow.seq.rows;
		int seqend = rows -
			activeVoice.activeRow.seqOffset - 1;
		step(seqend);
	}

	void toScreenTop() {
		step(-posTable.normalPointerOffset);
	}
	
	void toScreenBot() {
		int scrend = tableTop - posTable.pointerOffset - 1;
		step(scrend);
	}

	void centerTo(int center) {
		assert(center < tableTop && center >= tableBot);
		int steps = center - posTable.pointerOffset;
		foreach(v; voices) {
			v.scroll(-steps);
		}
		posTable.pointerOffset = center;
		step(0,1,1);
	}

	void step(int s) { step(s, 0); }
	void step(int s, int e) {
		step(s, e, area.height);
	}

	void step(int st, int extra, int height) {
		bool wrapOk = true;
		bool atBeg = activeVoice.atBeg();
		if(st < 0 && atBeg && stepCounter > 0) {
			st = 0;
			wrapOk = false;
		}
	
		posTable.pointerOffset = 
			posTable.pointerOffset + st;

		bool atEnd = activeVoice.atEnd();

		if(atEnd && stepCounter > 1) {
			posTable.pointerOffset = 
				posTable.pointerOffset - st;
			st = 0;
			wrapOk = false;
		}
		int r;
		if(posTable.pointerOffset >= tableTop) {
			r = -(height/2-posTable.pointerOffset-1);
			posTable.pointerOffset = tableTop - 1;
		}
		else if(posTable.pointerOffset < tableBot) {
			r = (posTable.pointerOffset+height/2);
			posTable.pointerOffset = tableBot;

		}

 		stepCounter++;

		int d = r > 0 ? 1 : - 1;
		if(r == 0) d = 0;
		int i;

		doStep(wrapOk,r);

		if(d <= 0) return;
		assert(extra >= 0);
		posTable.pointerOffset = 
			posTable.pointerOffset - extra;

		doStep(true,extra);
	}

	void superSstep(int st, int extra, int height) {
		bool wrapOk = true;
		bool atBeg = activeVoice.atBeg();
		
		if(st < 0 && atBeg && stepCounter > 0) {
			st = 0;
			wrapOk = false;
		}
		
		posTable.pointerOffset = 
			posTable.pointerOffset + st;

		bool atEnd = activeVoice.atEnd();
		if(atEnd && stepCounter > 1) {
			posTable.pointerOffset = 
				posTable.pointerOffset - st;
			st = 0;
			wrapOk = false;
		}

		int r;
		if(posTable.pointerOffset >= tableTop) {
			r = -(height/2-posTable.pointerOffset-1);
			posTable.pointerOffset = tableTop - 1;

		}
		else if(posTable.pointerOffset < tableBot) {
			r = (posTable.pointerOffset+height/2);
			posTable.pointerOffset = tableBot;

		}

 		stepCounter++;

		int d = r > 0 ? 1 : - 1;
		if(r == 0) d = 0;
		int i;

		doStep(wrapOk,r);

		// "extra" 
		if(d <= 0) return;
		assert(extra >= 0);
		posTable.pointerOffset = 
			posTable.pointerOffset - extra;

		foreach(v; voices) { v.scroll(extra); }
	}

	protected void doStep(bool wrapOk, int r) {
		foreach(v; voices) {
			bool wrap = wrapOk;
			v.scroll(r,wrap);
		}
	}

	// for seq copy/insert/etc 
	SequenceRowData getRowData() {
		return activeVoice.activeRow;
	}

	Sequence getActiveSequence() {
		return activeVoice.activeRow.seq;
	}

	// helper for trackcopy/paste
	Tracklist getTracklist(Voice v) {
		return v.tracks[v.activeRow.trkOffset..v.tracks.length];
//		return v.tracks[activeVoice.activeRow.trkOffset..activeVoice.tracks.length];
	}

	Tracklist getTracklist() {
		return getTracklist(activeVoice);
	}

}

// -------------------------------------------------------------------

final class Sequencer : Window {
	private {
		VoiceTable[] voiceTables;
		TrackmapTable trackmapTable;
		SequenceTable sequenceTable;
		TrackTable trackTable;
		QueryDialog queryCopy, queryClip, queryAppend;
		UI mainUI;
	}
	VoiceTable activeView;
	private Clip[] clip;
	this(Rectangle a, UI m) {
		int h = screen.height - 10;
		super(a,ui.help.HELPSEQUENCER);
		mainUI = m;
		trackmapTable = new TrackmapTable(a, tPos);
		sequenceTable = new SequenceTable(a, tPos);
		trackTable = new TrackTable(a, tPos);
		voiceTables = [cast(VoiceTable)trackmapTable, sequenceTable, trackTable];
		activeView = sequenceTable;
		activeView.activate();
		activateVoice(0);
		
		queryAppend = new QueryDialog("Insert this sequence to cursor pos: $",
								  &insertCallback, 0x80);
								  
		queryCopy = new QueryDialog("Copy this sequence to cursor seq: $",
								&copyCallback, 0x80);
		
		queryClip = new QueryDialog("Copy number of tracks to clipboard: $",
								&clipCallback, 0x40);
		
		// top & bottom
		tableBot = -area.height/2;
		tableTop = area.height/2;
		tableScrMid = area.y + area.height / 2 + 1;
		sequenceTable.centerTo(0);
	}

public:
	void activateVoice(int n) {
		activeView.jumpToVoice(n);
		input = activeView.input;
	}
	void reset() { reset(true); }
	void reset(bool tostart) {
		activeView.deactivate();
		if(tostart) {
			foreach(b; voiceTables) {
				b.toSeqStart();
			}
			sequenceTable.jump(Jump.ToBeginning,true);
		}
		activeView = sequenceTable;
		activeView.activate();
	}

	void resetMark() {
		foreach(v; activeView.voices) {
			v.setPositionMark(0);
		}
	}

	Voice[] getVoices() {
		return activeView.voices;
	}

protected:
	void update() {
		activeView.update();
		input = activeView.input;
	}

	void activate() {}

	void deactivate() {
		activeView.deactivate();
	}

	void refresh() {
	  foreach(b; voiceTables) {
	    b.refresh();
	  }
	}

	void insertCallback(int param) {
		if(param >= MAX_SEQ_NUM) return;
		SequenceRowData s = activeView.getRowData();
		Sequence fr = song.seqs[param];
		Sequence to = s.seq;
		to.insertFrom(fr, s.seqOffset);
		activeView.step(0);
	}

	void copyCallback(int param) {
		if(param >= MAX_SEQ_NUM) return;
		SequenceRowData s = activeView.getRowData();
		Sequence fr = song.seqs[param];
		Sequence to = s.seq; 
		to.copyFrom(fr);
		activeView.step(0);
	}

	void clipCallback(int num) {
		Tracklist tr = activeView.getTracklist()[0..num];
		clip.length = tr.length;
		for(int i = 0; i < tr.length; i++) {
			clip[i].trans = tr[i].trans;
			clip[i].no = tr[i].no;
		}
	}
  
	void pasteCallback() {
		// FIX: ADD .dup operator to Tracklist
		Tracklist vtr = activeView.getTracklist()[0..clip.length];
		for(int i = 0; i < clip.length; i++) {
			vtr[i].setValue(clip[i].trans,clip[i].no);
		}
		// reinitialize trackinput for voices
		refresh();
		// make sure cursor not past track end
		activeView.step(0);
	}

	int keypress(Keyinfo key) {
		if(key.raw >= SDLK_KP1 && key.raw <= SDLK_KP9) {
			stepValue = key.raw - SDLK_KP1 + 1;
			return OK;
		}
		if(key.mods & KMOD_ALT) {
			switch(key.raw) {
			case SDLK_a:
				mainUI.activateDialog(queryAppend);
				break;
			case SDLK_c:
				mainUI.activateDialog(queryCopy);
				break;
			case SDLK_z:
				mainUI.activateDialog(queryClip);
				break;
			case SDLK_b:
				pasteCallback();
				break;
			case SDLK_RIGHT:
				refresh();
				mainUI.stop();
				activeView.jump(0,false);
				resetMark();
				song.incSubtune();
				refresh();
				break;
			case SDLK_LEFT:
				refresh();
				mainUI.stop();
				activeView.jump(0,false);
				resetMark();
				song.decSubtune();
				refresh();
				break;
			default:
				return activeView.keypress(key);
			}
		}
		else if(key.mods & KMOD_CTRL) {
			switch(key.raw) {
			case SDLK_F12:
				mainUI.activateDialog(
					new DebugDialog(activeView.activeVoice.activeRow.seq));
				break;
			default:
				return activeView.keypress(key);
			 }
		}
		else switch(key.raw)
			 {
			 case SDLK_F5:
				 void activateTracktable() {
					 activeView.deactivate();
					 activeView.toSeqStart();
					 activeView = trackTable;
					 activeView.activate();
				 }
				 if(activeView != trackTable) {
					 activateTracktable();
					 trackTable.displayTracklist((key.mods & KMOD_SHIFT) > 0 ? true : false);
					 break;
				 }
				 if(key.mods & KMOD_SHIFT) {
					 activateTracktable();
					 trackTable.displayTracklist(true);
					 break;
				 }
				 goto case SDLK_F6;
			 case SDLK_F6:
				 activeView.deactivate();
				 activeView = sequenceTable;
				 activeView.activate();
				 // making sure cursor is not past endmark
				 activeView.step(0);
				 break;
			 case SDLK_F7:
				 activeView.deactivate();
				 if(activeView == trackmapTable) {
					 activeView.toSeqStart();
					 activeView = trackTable;
				 } 
				 else {
					 activeView.toSeqStart();
					 activeView.centerTo(0); // scroll to upmost pos
					 activeView = trackmapTable;
				 }
				 activeView.activate();
				 break;

			 case SDLK_MINUS:
				 if(octave > 0)
					 octave--;
				 break;
			 case SDLK_PLUS:
				 if(octave < 6)
					 octave++;
				 break;
			 default:
				 return activeView.keypress(key);
			 }
		return OK;
	}

	int keyrelease(Keyinfo key) {
		stepCounter = 0;
		return OK;
	}

	override void clickedAt(int x, int y, int button) {
		foreach(idx, Voice v; activeView.voices) {
			if(v.area.overlaps(x, y)) {
				activateVoice(cast(int)idx);
				activeView.clickedAt(x - area.x, y - area.y, button);
			}
		}
	}

}

// stupid, but... 
Sequence sequence(Track t) {
	return song.seqs[t.no()];
}
