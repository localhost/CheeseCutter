module seq.trackmap;
import main;
import com.fb;
import ui.ui;
import seq.sequencer;
import seq.tracktable;
import ui.input;
import derelict.sdl.sdl;
import std.string;
import ct.base;


protected class TrackmapVoice : TrackVoice {
	this(VoiceInit v) {		
		super(v);
	}

	override void update() {
		SequenceRowData wseq, cseq;
		int h = area.y + area.h + 1;
		int y,i;
		int trkofs = pos.trkOffset;
		int lasttrk = tracks.getListLength();
 		int counter;
		int scry = area.y + 1;

		void printEmpty() {
			screen.cprint(area.x - 1, scry, 1, 0, repeat(" ",16));
		}
		
		void printTrack() {
			int fpCounter = fpPos.rowCounter;
			int delta = fpCounter - counter; 
			int fgcol = (delta >= 0 && delta < wseq.seq.rows) ? 13 : 5;
			int trk = wseq.trk.getValue2();
			int rows = wseq.seq.rows;
			int c = counter;
			if(scry == area.y + 1 + anchor) fgcol = 1;
			if(wseq.trk.trans >= 0xf0) {
				rows = 0;
				c = 0;
			}
			screen.fprint(area.x-1, scry, 
					   format(" `01%s `0%x%02X %04X  ", 
							  formatTrackValue(trk), fgcol,
							  rows, c));
			if(trkofs == pos.mark) {
				for(int i = 0; i < 13; i++) {
					int xpos = area.x + i;
					if(screen.getbg(xpos, scry) == 0)
						screen.setbg(xpos, scry, playbackBarColor);
				}
			}
			if(trkofs == tracks.wrapOffset) {
				for(int i = 0; i < 15; i++) {
					int xpos = area.x + i - 1;
					if(screen.getbg(xpos, scry) == 0)
						screen.setbg(xpos, scry, wrapBarColor);
				}
			}
		}
		trkofs -= seq.sequencer.anchor;
		counter = getRowcounter(trkofs);

		if(trkofs >= 0)
			wseq = getRowData(trkofs);
		y = area.y + 1;

		while(scry <= area.y + area.height) {
			if(trkofs < 0) {
				printEmpty();
				scry++;
			}
			else if(trkofs >= lasttrk+1) {
				printEmpty();
				scry++; trkofs++;
				continue;
			}
			else {
				printTrack(); 
				counter += wseq.seq.rows;
				scry++;
			}
			trkofs++;
			if(trkofs >= 0 && trkofs <= lasttrk) {
				wseq = getRowData(trkofs, 0);
			}
		}
	}
}

protected class TrackmapTable : BaseTrackTable {
	this(Rectangle a, PosinfoTable pi) {
		int x = 5 + com.fb.border + a.x;
		for(int v=0;v<3;v++) {
			Rectangle na = Rectangle(x, a.y, a.height, 13 + com.fb.border);
			x += 13 + com.fb.border;
			voices[v] = new TrackmapVoice(VoiceInit(song.tracks[v],
				na, pi.pos[v]));
		}
		super(a, pi); 
	}

	override void activate() {
		super.activate();
		// FIX: scroll the screen to center, don't just set the offset vars
		centralize();
	}

	// centerTo() & jump() (?) do not work with this!
	override void step(int st) { step(st,0); }
	override void step(int st, int extra) {
		int steps, rows;
		SequenceRowData s;
		activeVoice.trackFlush(posTable.pointerOffset);
		if(st > 0) {
			if(activeVoice.atEnd()) return;
			rows = activeVoice.activeRow.seq.rows;
			foreach(v; voices) {
				v.scroll(rows, true);
			}
		}
		else if(st < 0) {
			int t = activeVoice.pos.trkOffset-1;
			if(t < 0) t = activeVoice.getVoiceEnd()-1;
			
			s = activeVoice.getRowData(t,0);
			rows = s.seq.rows;
			foreach(v; voices) {
				v.scroll(-rows);
			}
		}
		super.refresh();
	}
	override void toSeqStart() { return; }
}

