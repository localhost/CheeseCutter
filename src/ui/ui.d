module ui.ui;
import derelict.sdl.sdl;
import main;
import ct.base;
import ct.purge;
import ui.help;
import ui.input;
import audio.player;
import ui.tables;
import ui.dialogs;
import seq.fplay;
import std.string;
import std.file;
import std.stdio;
import std.math;
import std.utf;
import std.array;
import com.fb;
import seq.sequencer;
import ct.purge;

alias writefln w;
const PAGESTEP = 16;
const CONFIRM_TIMEOUT = 90;
const UPDATE_RATE = 2; // 50 / n times per second

bool keyjamStatus = false;
string filename;
int tickcounter1, tickcounter3 = -1;
int clearcounter, optimizecounter, escapecounter, restartcounter;
int activeInstrument;

struct Rectangle {
	int x, y;
	int height, width;
	alias height h;
	alias width w;
	string toString() {
		return format("%d %d %d %d",x, y, h, w);
	}
	bool overlaps(int cx, int cy) {
		return cx >= x && cx < x + width && cy >= y && cy < y + height;
	}
	Rectangle relativeTo(int scrx, int scry) {
		return Rectangle(scrx - x, scry - y);
	}
}

abstract class Window {
	Rectangle area;
	Input input;
	protected ContextHelp help;
	this(Rectangle a) {
		this(a, ui.help.HELPMAIN);
	}

	this(Rectangle a, ContextHelp ctx) {
		contextHelp = ctx;
		area = a;
	}

	abstract void update();
	int keypress(Keyinfo key) { return 0; }
	int keyrelease(Keyinfo key) { return 0; }
	void refresh() {}
	void deactivate() {}
	void activate() { refresh(); }
	void clickedAt(int scrx, int scry, int button) {}

protected:

	final void drawFrame() { drawFrame(area); }
	static void drawFrame(Rectangle a) {
		int x,y;
		for(y=a.y;y<a.y+a.height;y++) {
			screen.setChar(a.x-1,y,0);
			screen.setChar(a.x,y, 0x500|216);
			screen.setChar(a.x+a.width-1,y, 0x500|216);
			screen.setChar(a.x+a.width,y,0);
			screen.data[a.x+1 + y * screen.width .. a.x + a.width - 1 + y * screen.width] = 0x00;
			screen.setColor(a.x+a.width+1,y+1,11,0);
		}
		for(x=a.x;x<a.x+a.width;x++) {
			screen.setChar(x,a.y, 0x0500|192);
			screen.setChar(x,a.y+a.height-1, 0x0500|192);
			screen.setColor(x+2,a.y+a.height, 11, 0);
		}

		screen.setChar(a.x,a.y,0x500 | 201);
		screen.setChar(a.x+a.width-1,a.y,0x500 | 215);
		screen.setChar(a.x,a.y+a.height-1,0x500 | 195);
		screen.setChar(a.x+a.width-1,a.y+a.height-1,0x500 | 212);
	}

	final void drawRuler(int y) {
		for(int x = area.x;x < area.x + area.width; x++) {
			screen.setChar(x, area.y + y, 0x0500|192);
		}
	}

 	void contextHelp(ContextHelp h) { help = h; }
	ContextHelp contextHelp() { return help; }
}

struct Hotspot {
	Rectangle area;
	void delegate(int) callback;
}

class WindowSwitcher : Window {
	Window[] windows;
	char[] hotkeys;
	Window activeWindow;
	int activeWindowNum;
	this(Rectangle s, Window[] w) {
		super(s);
		windows = w;
		activeWindowNum = 0;
		activateWindow();
	}
	this(Rectangle s, Window[] w, string h) {
		this(s, w);
		hotkeys = cast(char[])h;
	}
	this(Rectangle s, Window[] w, char[] h) {
		this(s, w);
		hotkeys = h;
	}

	this(Rectangle s, Window[] w, char[] h, int mk) {
		this(s, w);
		hotkeys = h;
	}

	void activateWindow() {
		activateWindow(activeWindowNum);
	}
	void activateWindow(ulong n){
		activateWindow(cast(int)n);
	}
	void activateWindow(int n) {
		if(activeWindow !is null)
			activeWindow.deactivate();
		activeWindow = windows[n];
		activeWindow.activate();
		activeWindowNum = n;
		input = activeWindow.input;
		refresh();
	}

	void update() {
		activeWindow.update();
	}

	void activate() {
		activeWindow.activate();
	}

	void deactivate() {
		activeWindow.deactivate();
	}

	override void refresh() {
		foreach(w; windows) w.refresh();
	}
	
	int keypress(Keyinfo key) {
		if(key.mods & KMOD_ALT) {
			foreach(i, hk; hotkeys) {
				if(key.raw == hk) {
					activeWindowNum = cast(int)i;
					activateWindow();
					return OK;
				}
			}
		}
		switch(key.raw) {
		case SDLK_TAB:
			key.mods & KMOD_SHIFT ? activeWindowNum-- : activeWindowNum++ ;
			if(activeWindowNum < 0) activeWindowNum = cast(int)(windows.length - 1);
			if(activeWindowNum >= windows.length)
				activeWindowNum %= windows.length;
			activateWindow();
			return OK;
		default: 
			return activeWindow.keypress(key);
		}
		assert(0);
	}

	override ContextHelp contextHelp() { 
		return activeWindow.contextHelp();
	}

	override void clickedAt(int scrx, int scry, int button) {
		//	activateAt(scrx - activeWindow.area.x, scry - activeWindow.area.y);
	}
}

class Infobar : Window {
	private {
		const int x1, x2;
		int idx;
	}
	InputString inputTitle, inputAuthor, inputReleased;
	this(Rectangle a) {
		super(a);
		x1 = area.x;
		x2 = x1 + (com.fb.mode > 0 ? 64 : 48);
	}

	override void update() {
		int c = (escapecounter ? 7 : 12);
	  
		screen.clrtoeol(0,c);
		
		screen.cprint(4, 0, 1, c, "CheeseCutter 2.5.0");
		screen.cprint(screen.width - 14, 0, 1, c, "F12 = Help");
		int c1 = audio.player.isPlaying ? 13 : 12;
		screen.fprint(x1,area.y,format("`05Time: `0%x%02d:%02d / $%02x",
									c1,audio.timer.min, audio.timer.sec, audio.callback.linesPerFrame));
		
		screen.fprint(x1 + 19,area.y,
				   format("`05Oct: `0d%d  `05Spd: `0d%X  `05St: `0d%d ",
						  octave, song.speed, seq.sequencer.stepValue));
		screen.fprint(x2+3, area.y+1,
				   format("`05Rate: `0d%-1d*%dhz  `05SID: `0d%s%s    ",
						  song.multiplier, audio.player.ntsc ? 60 : 50,
						  audio.player.usefp ? audio.player.curfp.id : audio.player.sidtype ? "8580" : "6581",
						  audio.player.badline ? "&0fb" : " "));
		screen.fprint(x1,area.y+1,format("`05Filename: `0d%s", filename.ljustify(38)));
		//screen.fprint(x2,area.y,format("`05  `b1T`01itle: `0d%-32s", std.string.toString(cast(char *)song.title))); 
		screen.fprint(x2,area.y,format("`05%s `0d%-32s", (["  `b1T`01itle:", " `01Author:", "`01Release:" ])[idx],
									song.title));
		screen.fprint(x2,area.y+2,format("`05 Player: `0d%s", song.playerID));
	}

	override void refresh() {
		inputTitle = new InputString(cast(string)(song.title), cast(int)(song.title.length));
		inputReleased = new InputString(cast(string)(song.release), cast(int)( song.release.length));
		inputAuthor = new InputString(cast(string)(song.author), cast(int)(song.author.length));
		input = ([ inputTitle, inputAuthor, inputReleased ])[idx];
		input.setCoord(x2 + 9,area.y);
	}
	
	override void activate() {
		idx = 0;
		refresh();
	}

	override void deactivate() {
		outputStrings();
	}

	private void outputStrings() {
		song.title[0..32] = (cast(InputString)inputTitle).toString(true)[0..32];
		song.release[0..32] = (cast(InputString)inputReleased).toString(true)[0..32];
		song.author[0..32] = (cast(InputString)inputAuthor).toString(true)[0..32];
	}
	
	override int keypress(Keyinfo key) {
		int r = input.keypress(key);
		if(r == RETURN) {
			idx++; 
			if(idx > 2) {
				idx = 0;
				return RETURN;
			}
			outputStrings();
			refresh();
		}
		else if(r == CANCEL) {
			idx = 0; update();
			return RETURN;
		}
		return OK;
	}
}

class Statusline : Window {
	int counter;
	string message;
	this(Rectangle a) {
		super(a);
	}

	void display(string msg) {
		message = msg;
		counter = CONFIRM_TIMEOUT;
		screen.clrtoeol(2, 0);
		update();
	}
	
	void deactivate() {
		counter = 0;
		update();
	}

	void update() {
		if(counter)
			screen.fprint(4, 2, "`0f " ~ message);
		else screen.clrtoeol(2, 0);
	}

	void timerEvent() {
		if(counter > 0) {
			--counter;
			if(!counter) update();
		}
	}
}

final private class RootWindow : WindowSwitcher {
	private  {
		InputKeyjam inputKeyjam;
		InsTable instable;
		CmdTable cmdtable;
		WindowSwitcher bottomTabSwitcher;
		WaveTable wavetable;
		PulseTable pulsetable;
		FilterTable filtertable;
		ChordTable chordtable;
		Sequencer sequencer;
		Fplay fplay;
		UI ui;
		Hotspot[] hotspots;
	}

	struct Clip {
		int trans, no;
	}
	Clip[] clip;
	bool followplay;

 	this(UI pui) {
		ui = pui;
		int zone1x = 0;
		int zone2x = screen.width / 2 + zone1x - 1;
		int zone1y = 4;
		int zone1h = screen.height / 2 - 5;
		int zone2y = screen.height / 2;
		int zone2h = screen.height - zone2y - 5;

		inputKeyjam = new InputKeyjam();
		sequencer = new Sequencer(Rectangle(zone1x, zone1y, screen.height - 10, zone2x - zone1x), ui);
		fplay = new Fplay(Rectangle(zone1x, zone1y, screen.height - 10, zone2x - zone1x));
		instable = new InsTable(Rectangle(zone2x, zone1y, zone1h, 3 + 8 * 3 + 12));

		int tx = zone2x;
		wavetable = new WaveTable(Rectangle(tx, zone2y, zone2h, 8));
		tx += com.fb.border + 8;
		pulsetable = new PulseTable(Rectangle(tx, zone2y, zone2h, 14));
		tx += com.fb.border + 14;
		filtertable = new FilterTable(Rectangle(tx, zone2y, zone2h, 14));
		tx += com.fb.border + 14;
		cmdtable = new CmdTable(Rectangle(tx, zone2y, zone2h, 10));
		tx += com.fb.border + 10;

		Rectangle ca;

		if(com.fb.mode == 0) {
			ca = Rectangle(tx - 6, zone1y, zone1h, 6);
		}
		else ca = Rectangle(tx, zone2y, zone2h, 6);
		chordtable = new ChordTable(ca);
		bottomTabSwitcher = new WindowSwitcher(Rectangle(zone2x, zone2y, zone2h, tx + com.fb.border + 10),
											   [cast(Window)wavetable, pulsetable, filtertable, cmdtable, chordtable],
											   "wpfmd");

		/+
		super(Rectangle(), [cast(Window)sequencer, instable, 
							wavetable, pulsetable, filtertable, 
							cmdtable, chordtable], null);
		+/

		super(Rectangle(), [cast(Window)sequencer, instable, 
					   bottomTabSwitcher]);
		{
			int x1 = 4;
			int x2 = x1 + (com.fb.mode > 0 ? 64 : 48);
			int y1 = screen.height - 4;
			
			hotspots = [ 
				/+
				Hotspot(Rectangle(x2 + 3, y1, 1, 30), (int b){ 
						ui.activateDialog(UI.infobar); 
					}),
					+/
				Hotspot(Rectangle(x2 + 18, y1 + 1, 1, 10), (int b){ 
						b > 1 ? audio.player.toggleSIDModel() : audio.player.nextFP(); 
					}),
				Hotspot(Rectangle(x2 + 3, y1 + 1, 1, 14), (int b) {
						b == 1 ? audio.player.incMultiplier() : audio.player.decMultiplier(); 
					}) 
				];
		}
		refresh();
	}

	bool fplayEnabled() { return followplay; }

	void activateByCoord(int x, int y) {
		foreach(idx, win; windows) { 
			if(win.area.overlaps(x, y)) {
				activateWindow(idx);
			}
		}
		foreach(idx, win; bottomTabSwitcher.windows) {
			if(win.area.overlaps(x, y)) {
				bottomTabSwitcher.activateWindow(idx);
				break;
			}
		}
	}

	override void clickedAt(int x, int y, int b) {
		foreach(idx, win; windows) { 
			if(win.area.overlaps(x, y)) {
				activateWindow(idx);
				activeWindow.clickedAt(x, y, b);
			}
		}
		foreach(idx, win; bottomTabSwitcher.windows) {
			if(win.area.overlaps(x, y)) {
				bottomTabSwitcher.activateWindow(idx);
				bottomTabSwitcher.activeWindow.clickedAt(x, y, b);
				break;
			}
		}
		foreach(idx, spot; hotspots) {
			if(spot.area.overlaps(x, y))
				spot.callback(b);
		}
	}

	void timerEvent() {
		fplay.timerEvent();
	}

	Window windowByCoord(int x, int y) {
		foreach(idx, win; windows ~ bottomTabSwitcher.windows) {
			if(win.area.overlaps(x, y))
				return win;
		}
		return null;
	}

	int keypress(Keyinfo key) {
		switch(key.unicode) {
		case ']':
			if(song.speed < 32) 
				song.speed = song.speed + 1;
			return OK;
		case '[':
			if(song.speed > 0) 
				song.speed = song.speed - 1;
			return OK;
		case '{':
			audio.player.setMultiplier(song.multiplier - 1);
			return OK;
		case '}':
			audio.player.setMultiplier(song.multiplier + 1);
			return OK;
		default:
			break;
		}

		if(key.mods & KMOD_ALT) {
			switch(key.raw)
			{
			case SDLK_v:
				activateWindow(0);
				break;
			case SDLK_1:
				if(!(key.mods & KMOD_CTRL)) {
					activateWindow(0);
					sequencer.activateVoice(0);
				}
				break;
			case SDLK_2:
				if(!(key.mods & KMOD_CTRL)) {
					activateWindow(0);
					sequencer.activateVoice(1);
				}
				break;
			case SDLK_3:
				if(!(key.mods & KMOD_CTRL)) {
					activateWindow(0);
					sequencer.activateVoice(2);
				}
				break;
			case SDLK_4:
			case SDLK_i:
				activateWindow(1);
				break;
			case SDLK_5:
			case SDLK_w:
			case SDLK_6:
			case SDLK_p:
			case SDLK_7:
			case SDLK_f:
			case SDLK_8:
			case SDLK_m:
			case SDLK_9:
			case SDLK_d:
				activateWindow(2);
				break;
			case SDLK_t:
				ui.activateDialog(UI.infobar);
				return OK;
			case SDLK_KP0:
				clearSeqs();
				return OK;
			case SDLK_KP_PERIOD:
				optimizeSong();
				return OK;
			case SDLK_o:
				if(key.mods & KMOD_CTRL) {
					optimizeSong();
					return OK;
				}
				break;
			case SDLK_n:
				if(key.mods & KMOD_CTRL) {
					return OK;
				}
				break;
			case SDLK_c:
				if(key.mods & KMOD_CTRL) {
					clearSeqs();
					return OK;
				}
				break;
			case SDLK_h:
				.ui.tables.displayHelp ^= 1;
				UI.statusline.display("Help texts " ~ (.ui.tables.displayHelp ? "enabled." : "disabled."));
			default:
				break;
			}
		}
		else if(key.mods & KMOD_CTRL) {
			switch(key.raw)
			{
			 case SDLK_PLUS:
			 case SDLK_KP_PLUS:
				 if(song.speed < 32) 
					 song.speed = song.speed + 1;
				 break;
			 case SDLK_MINUS:
			 case SDLK_KP_MINUS:
				 if(song.speed > 0) 
					 song.speed = song.speed - 1; 
				 break;
			case SDLK_TAB:
				key.mods & KMOD_SHIFT ? activeWindowNum-- : activeWindowNum++ ;
				if(activeWindowNum < 0) activeWindowNum = cast(int)( windows.length - 1);
				if(activeWindowNum >= windows.length)
					activeWindowNum %= windows.length;
				activateWindow();
				return OK;
			default:
				break;
			}
		}
		else if(!key.mods & KMOD_SHIFT) {
			switch(key.raw)
			 {
			 case SDLK_LEFTPAREN:
			 case SDLK_KP_DIVIDE:
				 if(octave > 0)
					 octave--;
				 break;
			 case SDLK_RIGHTPAREN:
			 case SDLK_KP_MULTIPLY:
				 if(octave < 6)
					 octave++;
				 break;
			case SDLK_PLUS:
			case SDLK_KP_PLUS:
				instable.stepRow(1);
				activeInstrument = instable.row;
				break;
			case SDLK_MINUS:
			case SDLK_KP_MINUS:
				instable.stepRow(-1);
				activeInstrument = instable.row;
				break;
			 default:
				 break;
			 }
		}
		if(keyjamStatus == true || key.mods & KMOD_CAPS) {
			inputKeyjam.keypress(key);
		}
		else {
			int r = activeWindow.keypress(key);
			if(r == RETURN || r == CANCEL) {
				assert(0);
			}
		}
		return OK;
	}	

	int keyrelease(Keyinfo key) {
		if(keyjamStatus == true) {
			inputKeyjam.keyrelease(key);
		}
		return activeWindow.keyrelease(key);
	}

	void playFromCursor() {
		Voice[] v = sequencer.getVoices();
		auto d1 = v[0].activeRow;
		auto d2 = v[1].activeRow;
		auto d3 = v[2].activeRow;
		audio.player.start([d1.trkOffset,d2.trkOffset,d3.trkOffset],
					  [d1.seqOffset,d2.seqOffset,d3.seqOffset]);
		fplay.startFromCursor();
	}
	
	void reset() {
		sequencer.reset();
		sequencer.resetMark();
	}

	void refresh() {
		foreach(t; windows) {
			t.refresh();
			t.update();
		}
		bottomTabSwitcher.refresh();
		// needed because 'input' might be messed by a subdialog
		activeWindow.activate();
	}
	
	void update() {
		foreach(t; windows) {
			t.update();
		}
	}

	void startFp() {
		followplay = true;
		windows[0] = fplay;
		if(activeWindow == sequencer)
			activateWindow(0);
	}

	void startFp(int mode) {
		startFp();
		if(activeWindow == fplay)
			fplay.start(mode);
	}

	void startPlayback(int j) {
		fplay.start(j);
	}

	private void stopFp() {
		followplay = false;
		windows[0] = sequencer;
		activateWindow(activeWindowNum);
	}

	void stopPlayback() {
		fplay.stop();
		if(followplay) {
			stopFp();
			followplay = false;
			activate();
			sequencer.reset(false);
		}
	}

	private void optimizeSong() {
		if(++optimizecounter > 1) {
			refresh();
			Purger p = new Purger(song,true);
			p.purgeAll();
			refresh();
			UI.statusline.display("Song data optimized.");
			optimizecounter = 0;
		}
		else {
			UI.statusline.display("Press again to confirm song data optimization...");
			tickcounter3 = 0;
		}
	}

	private void clearSong() {
		if(++restartcounter > 1) {
			//song.open(cast(ubyte[])import("player.bin"));
			sequencer.reset();
			refresh();
			clearcounter = 0;
			//savedialog.setFilename("");
			filename = "";
			UI.statusline.display("Editor restarted.");
		}
		else {
			UI.statusline.display("Press again to confirm editor cold start...");
			tickcounter3 = 0;
		}
	}

	private void clearSeqs() {
		if(++clearcounter > 1) {
			song.clearSeqs();
			sequencer.reset();
			clearcounter = 0;
			UI.statusline.display("Sequence data cleared.");
		}
		else {
			UI.statusline.display("Press again to confirm sequence data clearing...");
			tickcounter3 = 0;
		}
	}
}
 
final class UI {
	private {
		Window dialog = null;
		int fullscreen;
		bool printSIDDump = false;
		AboutDialog aboutdialog;
		FileSelectorDialog loaddialog, savedialog;
	}
	static Statusline statusline;
	static Infobar infobar;
	static RootWindow rootwin;

	this() {
		statusline = new Statusline(Rectangle(0, 2, 1));
		rootwin = new RootWindow(this);

		infobar = new Infobar(Rectangle(4, screen.height - 4, 1, screen.width - 8));
	
		int dialog_width = screen.width - 32;
		int dialog_height = screen.height - 10;
		int dialog_x = screen.width / 2 - dialog_width / 2;
		int dialog_y = screen.height / 2 - dialog_height / 2;

		loaddialog = new LoadFileDialog(Rectangle(dialog_x, dialog_y, dialog_height, dialog_width), &loadCallback, &importCallback);
		savedialog = new SaveFileDialog(Rectangle(dialog_x, dialog_y, dialog_height, dialog_width), &saveCallback);

		int aboutdlg_width = screen.width - 18;
		int aboutdlg_height = 12;
		int aboutdlg_x = screen.width / 2 - aboutdlg_width / 2;
		int aboutdlg_y = screen.height / 2 - aboutdlg_height / 2;

		aboutdialog = new AboutDialog(Rectangle(aboutdlg_x, aboutdlg_y,
												aboutdlg_height,
												aboutdlg_width));

		audio.player.setMultiplier(song.multiplier);

		if(com.fb.mode > 0)
			ui.tables.shortTitles = false;
		rootwin.activate();
		activateDialog(aboutdialog);
		update();
	}

	Window activeWindow() {
		if(dialog) return dialog;
		return rootwin.activeWindow;
	}

	Input activeInput() {
		return activeWindow.input;
	}

	void timerEvent(int n) {
		Exception e = audio.callback.getException;
		if(e !is null) {
			writeln("error" ~ e.toString);
			audio.player.stop();
			statusline.display(e.toString);
		}
		if((tickcounter3 >= 0) && ++tickcounter3 > 20) {
			clearcounter = optimizecounter = escapecounter = restartcounter = 0;
			infobar.update();
			tickcounter3 = -1;
		}
		statusline.timerEvent();
		tickcounter1 += n;
		if(tickcounter1 >= UPDATE_RATE) {
			infobar.update();
			if(dialog) dialog.update();
			tickcounter1 = 0;
			rootwin.timerEvent();

			if(audio.player.isPlaying || audio.player.keyjamEnabled) {
				if(printSIDDump) {
					int x = screen.width - 42;
					screen.cprint(x, 1, 15, 0, "V1:");
					screen.cprint(x, 2, 15, 0, "V2:");
					screen.cprint(x, 3, 15, 0, "V3:");
					screen.cprint(x+26, 1, 15, 0, "$D415 16 17 18");
					for(int i = 0; i < 7; i++) {
						screen.cprint(x+3+i*3, 1, 5,0, format("%02X", audio.audio.sidreg[i]));
						screen.cprint(x+3+i*3, 2, 5,0, format("%02X", audio.audio.sidreg[i+7]));
						screen.cprint(x+3+i*3, 3, 5,0, format("%02X", audio.audio.sidreg[i+14]));
					}
					for(int i = 0; i < 4;i++) {
						screen.cprint(x+8+21+i*3, 2, 5,0, format("%02X", audio.audio.sidreg[i+0x15]));
					}
					/+
					for(int i = 0; i < 16; i++) {
						screen.cprint(8+i*3, 3, 5,0, format("%02X", song.memspace[0xdf00+i]));
					}
					+/
				}
				update();
			
			}
		}
	}

	void update() {
		infobar.update();
		rootwin.update();
		if(dialog)
			dialog.update();
	}

	private void F1orF2(Keyinfo key, bool fromStart) {
		if(audio.player.isPlaying) {
			if(key.mods & KMOD_SHIFT) { // already playing, reinit tracking
				stop(false);
				rootwin.startFp();
				return;
			}
			else if(rootwin.fplayEnabled()) { // drop tracking
				stop(false);
				seq.sequencer.tPos.dup(seq.sequencer.fpPos);
				rootwin.stopFp();
				return;
			}
			// song is playing but plain F1 pressed; restart
		}
		int m1, m2, m3;
		m1 = seq.sequencer.tPos.pos[0].mark;
		m2 = seq.sequencer.tPos.pos[1].mark;
		m3 = seq.sequencer.tPos.pos[2].mark;
		stop();
		if(!fromStart) {
			audio.player.start([m1, m2, m3], [0, 0, 0]);
			if(key.mods & KMOD_SHIFT) {
				rootwin.startFp();
			}
			rootwin.startPlayback(Jump.ToMark);
		}
		else {
			audio.player.start();
			if(key.mods & KMOD_SHIFT) {
				rootwin.startFp(Jump.ToBeginning);
			}
			rootwin.startPlayback(Jump.ToBeginning);
		}
	}

	int keypress(Keyinfo key) {
		/+ old buggy coldstart code
		if(key.mods & KMOD_ALT && key.mods & KMOD_CTRL && key.raw == SDLK_KP0) {
			if(++restartcounter > 1) {
				song = new Song();
				rootwin.sequencer.reset();
				refresh();
				clearcounter = 0;
				UI.statusline.display("Editor restarted.");
				savedialog.setFilename("");
				// TODO: find out why tracklist is not erased
				filename = "";
			}
			else {
				UI.statusline.display("Press again to confirm editor cold start...");
				tickcounter3 = 0;
			}
			return OK;
		}
		else+/
		
		bool skip_imm_keypress = false; //workaround for F11 - crapchars in savedialog
		if(key.mods & KMOD_ALT) {
			switch(key.raw) 
			{
			case SDLK_RETURN:
				fullscreen ^= 1;
				video.enableFullscreen(fullscreen > 0 ? true : false);
				update();
				break;
			case SDLK_KP_PLUS:
				audio.player.setMultiplier(song.multiplier + 1);
				break;
			case SDLK_KP_MINUS:
				audio.player.setMultiplier(song.multiplier - 1);
				break;
			case SDLK_F12:
				audio.player.dumpFrame();
				break;
			default:
				break;
			}
		}
		else if(key.mods & KMOD_CTRL) {
			switch(key.raw)
			{
			case SDLK_1:
				audio.player.toggleVoice(0);
				break;
			case SDLK_2:
				audio.player.toggleVoice(1);
				break;
			case SDLK_3:
				audio.player.toggleVoice(2);
				break;
			case SDLK_F11:
				string s = savedialog.getFilename();
				if(s == "")
					statusline.display("Cannot Quicksave; give filename first by doing a regular save.");
				else {
					saveCallback(s);
					statusline.display(format("Saved \"%s\".",s));
				}
				break;
			case SDLK_F12:
				break;
			case SDLK_F2:
				audio.player.interpolate ^= 1;
				audio.player.init();
				break;
			case SDLK_F3:
				song.sidModel ^= 1;
				audio.player.setSidModel(song.sidModel);
				break;
			case SDLK_F4, SDLK_b:
				audio.player.badline ^= 1;
				audio.player.init();
				break;
			case SDLK_F8:
				key.mods & KMOD_SHIFT ? audio.player.prevFP() : audio.player.nextFP();
				break;
			case SDLK_F9:
				if(printSIDDump) {
					screen.clrtoeol(55, 1, 0);
					screen.clrtoeol(55, 2, 0);
					screen.clrtoeol(55, 3, 0);
				}
				printSIDDump ^= 1;
				break;
			case SDLK_SPACE:
				if(song.ver < 7) break;
				keyjamStatus ^= 1;
				enableKeyjamMode(keyjamStatus);
				statusline.display("Keyjam " ~ (keyjamStatus ? "enabled." : "disabled.") ~ " Press Ctrl-Space to toggle.");
				break;
			default:
				break;
			}
		}
		else switch(key.raw) 
			 {
			 case SDLK_ESCAPE:
				 if(dialog || activeWindow == infobar)
					 break;
				 if(++escapecounter > 1) {
					 audio.player.stop();
					 return EXIT;
				 }
				 tickcounter3 = 0;
				 break;
			 case SDLK_PRINT:
			 	 audio.player.dumpFrame();
			 	 break;
			 case SDLK_F1:
				 F1orF2(key, false);
				 break;
			 case SDLK_F2:
				 F1orF2(key, true);
				 break;
			 case SDLK_F3:
				 rootwin.playFromCursor();
				 break;
			 case SDLK_SCROLLOCK:
				 if(!audio.player.isPlaying) break;
				 if(rootwin.fplayEnabled()) {
					 stop(false);
					 tPos.dup(fpPos);
					 rootwin.stopFp();
					 statusline.display("Tracking off.");
					 break;
				 }
				 else {
					 stop(false);
					 rootwin.startFp();
					 statusline.display("Tracking on.");
					 break;
				 }
				 break;
			 case SDLK_F4:
				 if(rootwin.fplayEnabled()) 
					 tPos.dup(fpPos);
				 stop();
				 if(rootwin.fplayEnabled())
					 rootwin.stopFp();
				 break;
			 case SDLK_F8:
				 if(key.mods & KMOD_SHIFT)
					 audio.player.fastForward(25);
				 else
					 audio.player.fastForward(5);
				 break;
			 case SDLK_F9:
				 activateDialog(aboutdialog);
				 break;
			 case SDLK_F10:
				 activateDialog(loaddialog);
				 break;
			 case SDLK_F11:
				 activateDialog(savedialog);
				 skip_imm_keypress = true;
				 break;	
			 case SDLK_F12:
				 int helpdlg_width = screen.width - 10;
				 int helpdlg_height = 36;
				 int helpdlg_x = screen.width / 2 - helpdlg_width / 2;
				 int helpdlg_y = screen.height / 2 - helpdlg_height / 2;
				 HelpDialog helpdialog = 
					 new HelpDialog(Rectangle(helpdlg_x, helpdlg_y,
											  helpdlg_height,
											  helpdlg_width), activeWindow.contextHelp);
				 activateDialog(helpdialog);
				 break;
			 default:
				 break;
			 }
		int r;
		if(dialog && !skip_imm_keypress) {
			if(key.mods & KMOD_ALT) return OK;
			r = dialog.keypress(key);
			if(r != OK) {
				closeDialog();
				return r;
			}
		}
		else {
			rootwin.keypress(key);
		}
		return OK;
	}	

	int keyrelease(Keyinfo key) {
		rootwin.keyrelease(key);
		return OK;
	}

	void clickedAt(int x, int y, int b) {
		if(dialog)
			dialog.clickedAt(x, y, b);
		else rootwin.clickedAt(x, y, b);
	}

	static void activateInstrument(int ins) {
		if(ins > 47) ins = 47;
		if(ins < 0) ins = 0;
		rootwin.instable.seekRow(ins % 48);
		activeInstrument = ins % 48;
	}

	private void saveCallback(string s) {
		try {
			song.save(s);
		}
		catch(FileException e) {
			statusline.display(e.toString());
			return;
		}
		// sync load filesel to save filesel
		loaddialog.fsel.fpos = savedialog.fsel.fpos;
		ui.ui.filename = cast(string) s.dup;
	}

	void importCallback(string s) {
		loadCallback(s, true);
	}

	void loadCallback(string s) {
		loadCallback(s, false);
	}

	void loadCallback(string s, bool doImport) {
		stop();
		rootwin.reset();
		if(std.file.exists(s) == 0 || std.file.isDir(s)) {
			statusline.display("File not found! " ~ s);
			return;
		}
		try {
			if(!doImport)
				song.open(s);
			else {
				Song insong = new Song();
				insong.open(s);
				song.importData(insong);
			}
		}
		catch(Exception e) {
			statusline.display("Error: " ~ e.toString());
			return;
		}
		refresh();
		// all voices ON
		audio.player.setVoicon(0,0,0);
		
		string fn = s.strip();
		auto ind = 1 + fn.lastIndexOf(DIR_SEPARATOR);
		fn = fn[ind..$];
		ui.ui.filename = fn;
		infobar.refresh();
		
		// sync save filesel to load filesel in case dir was changed
		foreach(d; [loaddialog, savedialog]) {
			d.setFilename(fn);
			d.setDirectory(getcwd());
		}
		savedialog.fsel.fpos = loaddialog.fsel.fpos;
	
		// set variables
		audio.player.setSidModel(song.sidModel);
		audio.player.setFP(song.fppres);
		audio.player.setMultiplier(song.multiplier);
		
		enableKeyjamMode(false);

		if(doImport) {
			statusline.display("Song data imported.");
		}
	}

	void activateDialog(Window d) {
		enableKeyjamMode(false);
		closeDialog();
		dialog = d;
		d.activate();
	}
	
	void closeDialog() {
		if(dialog) dialog.deactivate();
		dialog = null;
		refresh();
	}

	void enableKeyjamMode(bool enable) {
		if(enable) {
			com.fb.disableKeyRepeat();
		}
		else com.fb.enableKeyRepeat();
		
		keyjamStatus = enable;
	}

	static void stop() {
		stop(true);
	}

	static void stop(bool s) {
		if(s) {
			audio.player.stop();
		}
		infobar.update();
		rootwin.stopPlayback();
	}

	static void refresh() {
		screen.clrscr();
		rootwin.refresh();
		UI.statusline.update();
	}

	void activateInstrumentTable(int ins) {
		UI.activateInstrument(ins);
		// just hacking away.....
		rootwin.activateWindow(2);
		rootwin.keypress(Keyinfo(SDLK_i, KMOD_ALT, 0));
	}
}
