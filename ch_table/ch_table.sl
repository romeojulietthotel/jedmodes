% A "popup_buffer" with a table of characters
%
% Copyright (c) 2003 G�nter Milde
% Released under the terms of the GNU General Public License (ver. 2 or later)
%
% with additions by Dino Leonardo Sangoi.
%
% Version     1.0 first public version
%  	      1.1 standardization: abandonment of helper-function custom
% 2003-04-16  2.0 use readonly-map from bufutils (some new bindings)
%                 code cleanup
% 2003-03-07  2.1 ch_table calls ch_table_mode_hook instead of ct_mode_hook
% 2004-11-27  2.2 new format of the INITIALIZATION block allows 
% 	          auto-initialisation with make-ini >= 2.2
%
% Functions and Functionality
%
%   ch_table()        characters 000...255
%   ch_table(num)     characters num...255
%   special_chars()   characters 160...255
%
%   - Arrow keys     move by collumn and mark the character
%   - <Enter> 	     copy the character to the calling buffer and close
%   - Mouse click    goto character and mark
%   - Double-click   goto character, copy to calling buffer and close
%   - q   	     close
%
% USAGE:
% put in the jed_library_path and make available e.g. by a keybinding or
% via the following menu entry (make-ini >= 2.2 will do this for you)
% 
#iffalse %<INITIALIZATION>
define ct_load_popup_hook (menubar)
{
   menu_insert_item ("&Rectangles", "Global.&Edit",
                       "&Special Chars", "special_chars");
}
append_to_hook ("load_popup_hooks", &ct_load_popup_hook);

autoload("ch_table", "ch_table.sl");
autoload("special_chars", "ch_table.sl");
add_completion("special_chars");
#endif %</INITIALIZATION>

% TODO:
%
% + get a list of codes and names  via
%      recode --list=full latin1
%   (or what the actual encoding is) and give iso-name of actual char
%   (in status line or bottom line(s) of buffer)

static variable mode = "ch_table";
implements(mode);

% --- requirements
require("view"); %  readonly-keymap
autoload("fit_window", "bufutils");
autoload("popup_buffer", "bufutils");
autoload("close_buffer", "bufutils");
autoload("set_help_message", "bufutils");
autoload("get_blocal", "sl_utils");

% --- custom variables

custom_variable("ChartableStartChar", 0);
custom_variable("ChartableNumBase", 10);
custom_variable("ChartableCharsPerLine", ChartableNumBase);
custom_variable("ChartableTabSpacing", 4);

% --- static variables -------------------------------------------

% initialized in function ch_table
static variable StartChar = ChartableStartChar;
static variable NumBase = ChartableNumBase;
static variable CharsPerLine = ChartableCharsPerLine;

% quasi constants
static variable Digits ="0123456789abcdef";

% --- Helper functions --------------------------------------------

% Functions to revert a positive  integer to a string representation
% and vice versa

static define int2string(i, base)
{
   variable j, s = "";
   variable digits = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ";

   while (i) {
      j = i mod base;
      s = char(digits[j]) + s;
      i = (i - j) / base;
   }
   if (s == "")
     s = "0";
   return s;
}

static define string2int(s, base)
{
   variable v, r = 0, i = 0, c;

   while (s[i] > ' ') {
      c = toupper(s[i]);
      if (c >= 'A')
	v = c - 'A' + 10;
      else v = c - '0';
      if ((v < 0) or (v >= base))
	error("Invalid input (" + s + ")");
      r = r * base + v;
      i++;
   }
   return r;
}

% give the ASCII-number of the current char in the status line
static define ct_status_line()
{
   variable  cs;

   if (looking_at("TAB"))
     cs = "'TAB'=9/0x9/011";
   else if (looking_at("ESC"))
     cs = "'ESC'=27/0x1b/033";
   else if (looking_at("NL"))
     cs = "'NL'=10/0xa/012";
   else
     {
        cs = count_chars();
        cs = substr(cs, 1, string_match(cs, ",", 1)-1);
     }
   set_status_line(" Character Table:  "+ cs + "  ---- press '?' for help ", 0);
}

static define ct_update ()
{
   bskip_chars ("^\t");
   % update status line
   ct_status_line ();
   % write again to minibuffer (as messages don't persist)
      % if ressources are a topic, we could compute the message in
      % ch_table and store to a static variable GotoMessage
   vmessage("Goto char (%s ... %s, base: %d): ___",
        int2string(StartChar, NumBase), int2string(255, NumBase),  NumBase);
   % mark character
   pop_mark(0);
   push_visible_mark;
   skip_chars ("^\t");
}

%move only in the ch_table, skipping the tabs
static define ct_up ()
{
   if (what_line < 4)
     error("Top Of Buffer");
   call ("previous_line_cmd");
   ct_update;
}

static define ct_down ()
{
   call ("next_line_cmd");
   ct_update;
}

static define ct_right ()
{
   () = fsearch("\t");
   call ("next_char_cmd");
   ct_update;
}

static define ct_left ()
{
   bskip_chars ("^\t");
   call ("previous_char_cmd");
   bskip_chars ("^\t");
   if(bolp)
     call ("previous_char_cmd");
   if (what_line < 3)
     {
	ct_right;
	error("Top Of Buffer");
     }
   ct_update;
}

static define ct_bol ()   { bol; ct_right;}

static define ct_eol ()   { eol; ct_update;}

static define ct_bob ()   { goto_line(3); ct_right;}

static define ct_eob ()   { eob; ct_update;}

static define ct_insert_and_close ()
{
   variable str = bufsubstr();
   close_buffer();
   switch(str)
     { case "TAB": insert("\t"); }
     { case "NL" : insert("\n"); }
     { case "ESC": insert("\e"); }
     { insert(str); }
}

static define ct_mouse_up_hook (line, col, but, shift)
{
   % if (but == 1)
   if (what_line < 3)
     ct_bob;
   ct_right;
   ct_left;
%   ct_update;   error if click in first (number) collumn
   return (1);
}

static define ct_mouse_2click_hook (line, col, but, shift)
{
   ct_insert_and_close();
   return (0);
}

% goto character by input of ASCII-Nr.
static define ct_goto_char ()
{
   variable goto_message =  sprintf("Goto char (%s ... %s, base: %d): ",
        int2string(StartChar, NumBase), int2string(255, NumBase),  NumBase);
   variable GotoCharStr = read_mini(goto_message, "", char(LAST_CHAR));

   variable GotoChar = string2int(GotoCharStr, NumBase);

   if( (GotoChar<StartChar) or (GotoChar>255) )
     verror("%s not in range (%s ... %s)",
	        GotoCharStr,
	        int2string(StartChar, NumBase) , int2string(255, NumBase));
   ct_bob;
   loop(GotoChar - (StartChar - (StartChar mod CharsPerLine)))
     ct_right;
   % give feedback
   vmessage("Goto char: %s -> %c", GotoCharStr, GotoChar);
}

% insert the table into the buffer and fit window size
static define insert_ch_table ()
{
   variable i, j;
   TAB = ChartableTabSpacing;    % Set TAB for buffer
   % j = lengt of number on first column
   j = strlen(int2string(256-CharsPerLine, NumBase))+1;
   if (j < TAB)
      j = TAB;
   % heading
    vinsert("[% *d]\t", j-2, NumBase);
    for (i=0; i<CharsPerLine; i++)
      insert(int2string(i, NumBase) + "\t");
    newline;
   % now construct/insert the table
   for (i = StartChar - (StartChar mod CharsPerLine) ; i<256; i++)
     {
	if ((i) mod CharsPerLine == 0)
	    vinsert("\n% *s", j, int2string(i, NumBase)); % first column with number
	insert_char('\t');
	% insert characters, symbolic notation for TAB, Newline and Escape
	switch (i)
	  { i < StartChar: ;}
	  { case '\t': insert("TAB");}
	  { case '\n': insert ("NL");}
	  { case '\e': insert ("ESC");}
	  { insert_char(i);}
     }
   fit_window(get_blocal("is_popup", 0));
   set_buffer_modified_flag (0);
   ct_bob;
   ct_update();
}

% set static variables and define keys to use specified number base
static define use_base (numbase)
{
   variable i;
   % (un)bind keys
   for (i=numbase; i<=NumBase; i++)
	undefinekey(char(Digits[i]), mode);
   for (i=0; i<numbase; i++)
	definekey("ch_table->ct_goto_char", char(Digits[i]), mode);
   % adapt CharsPerLine, if it matched NumBase
   if (CharsPerLine == NumBase)
     CharsPerLine = numbase;
   % set static variable
   NumBase = numbase;
}

% change the number base
static define ct_change_base ()
{
   variable Base;
   if (_NARGS)                  % optional argument present
     Base = ();
   else
     Base = integer(read_mini("New number base (2..16):", "", ""));
   use_base(Base);
   set_readonly(0);
   erase_buffer ();
   insert_ch_table();
   set_readonly(1);
}

% --- main function  ------------------------------------------------------

% a function that displays all chars of the current font
% in a table with indizes that give the "ASCII-value"
% skipping the first ones until optional argument Int "StartChar"
public define ch_table () % ch_table(StartChar = 0)
{
   % (re) set options
   if (_NARGS)                  % optional argument present
     StartChar = ();
   else
     StartChar    = ChartableStartChar;
   use_base(NumBase);
   CharsPerLine = ChartableCharsPerLine;
   popup_buffer("*ch_table*");
   erase_buffer ();
   insert_ch_table();
   set_readonly(1);
   set_mode(mode, 0);
   use_keymap (mode);
   use_syntax_table (mode);
   set_buffer_hook ( "mouse_up", &ct_mouse_up_hook);
   set_buffer_hook ( "mouse_2click", &ct_mouse_2click_hook);
   run_mode_hooks(mode + "_mode_hook");
}

% a function that displays the special chars of the current font
% (i.e. the chars with the high bit set)
% in a table with indizes that give the "ASCII-value"
public define special_chars ()
{
   ch_table(160);
}

% colorize numbers

create_syntax_table (mode);
define_syntax ("0-9", '0', mode);
set_syntax_flags (mode, 0);

#ifdef HAS_DFA_SYNTAX
%%% DFA_CACHE_BEGIN %%%
static define setup_dfa_callback (mode)
{
   dfa_enable_highlight_cache("ch_table.dfa", mode);
   dfa_define_highlight_rule("^ *[0-9A-Z]+\t", "number", mode);
   dfa_define_highlight_rule("^\\[.*$", "number", mode);
   dfa_build_highlight_table(mode);
}
dfa_set_init_callback (&setup_dfa_callback, mode);
%%% DFA_CACHE_END %%%
enable_dfa_syntax_for_mode(mode);
#endif

% --- Keybindings
require("keydefs");

!if (keymap_p (mode)) 
  copy_keymap (mode, "view");

% numerical input for goto_char is dynamically defined by function ct_use_base
definekey("ch_table->ct_up",              Key_Up,    mode);
definekey("ch_table->ct_down",            Key_Down,  mode);
definekey("ch_table->ct_right",           Key_Right, mode);
definekey("ch_table->ct_left",            Key_Left,  mode);
definekey("ch_table->ct_bol",             Key_Home,  mode);
definekey("ch_table->ct_eol",             Key_End,   mode);
definekey("ch_table->ct_bob",             Key_PgUp,  mode);
definekey("ch_table->ct_eob",             Key_PgDn,  mode);
definekey("ch_table->ct_change_base()",   "N",       mode);  % generic case
definekey("ch_table->ct_change_base(2)",  "B",       mode);
definekey("ch_table->ct_change_base(8)",  "O",       mode);
definekey("ch_table->ct_change_base(10)", "D",       mode);
definekey("ch_table->ct_change_base(16)", "H",       mode);
definekey("ch_table->ct_insert_and_close", "^M",     mode);  % Return

set_help_message(
   "<RET>:Insert q:Quit, B:Binary, O:Octal, D:Decimal, H:hex N:Number_Base",
		 mode);

provide(mode);