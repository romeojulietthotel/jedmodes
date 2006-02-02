% JED interface to the grep command
%
% Copyright (c) 2006 G�nter Milde
% Released under the terms of the GNU General Public License (ver. 2 or later)
%
% Versions
% 0.9.1  2003/01/15
%   * A total remake of Dino Sangois jedgrep under use of the new listing
%     and filelist modes. (Which are inspired by the old jedgrep by Dino!)
%   * grep_replace_command: Replace in the grep results
%     (both, result display and source files!)
% 0.9.2 2003/07/09
%   * bugfix contract_filename did not work properly (needs chdir() first)
% 0.9.3 2004-01-30
%   * solved bug with only one file (using -H option) [Peter Bengtson]
%   * recursive grep with special filename bang (!) (analog to kpathsea),
%     i.e. grep("pat" "dir/!") gets translated to `grep -r "pat" "dir/"`
% 0.9.4 2004-04-28
%   * close grep buffer, if the return value of the grep cmd is not 0
% 0.9.5 2005-11-07
%   * change _implements() to implements() (this will only affect re-evaluating
%     sl_utils.sl in a JED < 0.99.17, so if you are not a developer on an older
%     jed version, it will not harm).
% 0.9.6 2006-02-02 bugfix and code cleanup in grep_replace_*
%                  (using POINT instead of what_column(), as TAB expansion
%                   might differ between grep output and referenced buffer)
%
% USAGE
%
% From jed:              M-x grep
% From the command line: fgrep -nH "sometext" * | jed -f grep_mode
% (You should have grep_mode in your autoload list for this to work.)
% The second approach doesnot work for xjed, use
%   xjed -f "grep(\"sometext\", \"*\")"
%
% Go to a line looking promising and press ENTER or double click on
% the line.
%
% CUSTOMIZATION
%
% You can set the grep command with e.g in your .jedrc
%   variable GrepCommand = "rgrep -nH";
%
% Optionally customize the jedgrep_mode using the "grep_mode_hook", e.g.
%   % give the result-buffer a number
%   autoload("number_buffer", "numbuf"); % look for numbuf at jedmodes.sf.net
%   define grep_mode_hook(mode)
%   {
%      number_buffer();
%   }
%
% TODO: use search_file and list_dir if grep is not available
%       take current word as default (optional)
%       make it Windows-secure (filename might contain ":")

% _debug_info=1;

% --- Requirements --------------------------------------------- %{{{
% standard modes
require("keydefs");
autoload("replace_with_query", "srchmisc");
% nonstandard modes (from jedmodes.sf.net)
require("filelist"); % which does require "listing" and "datutils"
autoload("popup_buffer", "bufutils");
autoload("close_buffer", "bufutils");
autoload("buffer_dirname", "bufutils");
autoload("rebind", "bufutils");
autoload("contract_filename", "sl_utils");
autoload("get_word", "txtutils");
%}}}

% --- name it
provide("grep");
implements("grep");
private variable mode = "grep";


% --- Variables -------------------------------------------------%{{{

% the grep command
custom_variable("GrepCommand", "grep -nH"); % print filename and linenumbers

% remember the string to grep (as default for the next run) (cf. LAST_SEARCH)
static variable LAST_GREP = "";

%}}}

% --- Replace across files ------------------------------------- %{{{

% Return the number of open buffers
static define count_buffers()
{
   variable n = buffer_list();  % returns names and number of buffers
   _pop_n(n);                   % pop the buffer names
   return n;
}   


% Compute the length of the statistical data in the current line
% (... as we have to skip spurious search results in this area)
static define grep_prefix_length()
{
   push_spot_bol();
   EXIT_BLOCK { pop_spot(); }
   loop(2)
     {
	() = ffind_char(get_blocal("delimiter", ':'));
	go_right_1();
     }
   return POINT; % POINT starts with 0, this offsets the go_right_1
}

% fsearch in the grep results, skipping grep's statistical data
% return the length of the pattern found or -1
static define grep_fsearch(pat)
{
   variable pat_len;
   do
     {
	pat_len = fsearch(pat);
	!if(pat_len)
	  break;
	if (POINT > grep_prefix_length())
	  return pat_len;
     }
   while(right(1));
   return -1;
}


% The actual replace function 
% (replace in both, the grep output and the referenced file)
define grep_replace(new, len)
{
   variable buf = whatbuf(),
   no_of_bufs = count_buffers(),
   pos = POINT - grep_prefix_length(), 
   old;

   % get (and delete) the string to be replaced
   push_mark(); () = right(len);
   old = bufsubstr_delete();
   push_spot();
   
   ERROR_BLOCK
     {
	% close referenced buffer, if it was not open before
	if (count_buffers > no_of_bufs)
	  {
	     save_buffer();
	     delbuf(whatbuf);
	  }
	% insert the replacement into the grep buffer
	sw2buf(buf);
	pop_spot();
        set_readonly(0);
        insert(old);
     }
   
   % open the referenced file and goto the right line and pos
   filelist_open_file();
   bol;
   go_right(pos);
   
   % abort if looking at something different
   !if (looking_at(old))
     {
	push_mark(); () = right(len);
	verror("File differs from grep output (looking at %s)", bufsubstr());
     }
   
   len = replace_chars(len, new);

   old = new;
   EXECUTE_ERROR_BLOCK; % close newly opened buffer, return to grep results

   return len; 
}

% Replace across files found by grep (interactive function)
define grep_replace_cmd()
{
   variable old, new;

   % find default value (region or word under cursor) 
   % and set point to begin of region
   if (is_visible_mark)
     check_region(0);
   else
     mark_word();
   exchange_point_and_mark; % set point to begin of region

   old = read_mini("Grep-Replace:", "", bufsubstr());
   !if (strlen (old)) 
     return;
   new = read_mini(sprintf("Grep-Replace '%s' with:", old), "", "");

   ERROR_BLOCK
     {
	REPLACE_PRESERVE_CASE_INTERNAL = 0;
	set_readonly(1);
	set_buffer_modified_flag(0);
     }

   set_readonly(0);
   REPLACE_PRESERVE_CASE_INTERNAL = REPLACE_PRESERVE_CASE;
   replace_with_query (&grep_fsearch, old, new, 1, &grep_replace);

   EXECUTE_ERROR_BLOCK;
   message ("done.");
}
%}}}

% --- The grep-mode ----------------------------------------------- %{{{

create_syntax_table(mode);

#ifdef HAS_DFA_SYNTAX
%%% DFA_CACHE_BEGIN %%%
static define setup_dfa_callback(mode)
{
   dfa_enable_highlight_cache("grep.dfa", mode);
   dfa_define_highlight_rule("^[^:]*", "keyword", mode);
   dfa_define_highlight_rule(":[0-9]+:", "number", mode);
   % Uhm, this matches numbers enclosed by ':' anywhere. If this really
   % annoys you, either:
   % 1 - disable dfa highlighting
   % 2 - comment the two dfa_define_highlight_rule above and use instead:
   %       dfa_define_highlight_rule("^[^:]*:[0-9]+:", "keyword", mode);

   dfa_build_highlight_table(mode);
}
dfa_set_init_callback (&setup_dfa_callback, mode);
%%% DFA_CACHE_END %%%
enable_dfa_syntax_for_mode(mode);
#endif

!if(keymap_p(mode))
{
   copy_keymap(mode, "filelist");
   rebind("replace_cmd", "grep->grep_replace_cmd", mode);
}
%}}}

% Interface: %{{{


%!%+
%\function{grep_mode}
%\synopsis{Mode for results of the grep command}
%\usage{ grep_mode()}
%\description
%   A mode for the file listing as returned by the "grep -Hn" command.
%   Provides highlighting and convenience functions.
%   Open the file(s) and go to the hit(s) pressing Enter. Do a 
%   find-and-replace accross the files.
%\seealso{grep, grep_replace}
%!%-
public define grep_mode()
{
   define_blocal_var("delimiter", ':');
   define_blocal_var("line_no_position", 1);
   filelist_mode();
   set_mode(mode, 0);
   use_syntax_table (mode);
   use_keymap(mode);
   run_mode_hooks("grep_mode_hook");
}


% TODO: What does gnu grep expect on DOS, What should this be on VMS and OS2 ?
%!%+
%\function{grep}
%\synopsis{Grep wizard}
%\usage{grep(String what=NULL, String files=NULL)}
%\description
%  Grep for "what" in the file(s) "files" (use shell wildcards).
%  If the optional arguments are missing, they will be asked for in the 
%  minibuffer. The grep command can be set with the custom variable 
%  \var{GrepCommand}.
%  
%  The buffer is set to grep_mode, so you can go to the matching lines 
%  or find-and-replace accross the matches.
%  
%  grep adds one extension to the shell pattern replacement mechanism
%  the special filename bang (!) indicates a recursive grep in subdirs
%  (analog to kpathsea), i.e. grep("pat" "dir/!") translates to 
%  `grep -r "pat" "dir/"`
%\notes
%  In order to go to the file and line-number, grep_mode assumes the 
%  -n and -H argument set.
%\seealso{grep_mode, grep_replace, GrepCommand}
%!%-
public define grep() % ([what], [files])
{
   % optional arguments, ask if not given
   variable what, files;
   (what, files) = push_defaults( , , _NARGS);
   if (what == NULL)
     {
	what = read_mini("(Flags and) String to grep: ", LAST_GREP, "");
	LAST_GREP = what;
     }
   if (files == NULL)
     files = read_with_completion ("Where to grep: ", "", "", 'f');

   variable cmd, dir = buffer_dirname(), allfiles = "", status;

   % set the working directory
   () = chdir(dir);

   % Build the command string:

   % The output buffer will be set to the active buffer's dir
   % If the path starts with dir, we can strip it.
   % (Note: this maight fail on case insensitive filesystems).
   files = contract_filename(files);

   % recursive grep with special filename bang (!) (analog to kpathsea)
   if (path_basename(files) == "!")
     {
	what = "-r " + what;
	files = path_dirname(files);
     }
   % append wildcard, if no filename (or pattern) is given
#ifdef UNIX
   allfiles = "*";
#elifdef IBMPC_SYSTEM
   allfiles = "*.*";
#endif
   if (path_basename(files) == "")
     files = path_concat(files, allfiles);

   cmd = GrepCommand + " " + what + " " + files;

   % Prepare the output buffer
   popup_buffer("*grep_output*", FileList_max_window_size);
   setbuf_info("", dir, "*grep_output*", 0);
   erase_buffer();
   set_buffer_modified_flag(0);

   % call the grep command
   flush("calling " + cmd);
   status = run_shell_cmd(cmd);

   % handle result
   switch (status)
     { case 1:
	close_buffer();
	message("No results for " + cmd);
	return;
     }
     { case 2:
	message("Error (or file not found) in " + cmd);
     }
   % remove empty last line (if present)
   if (bolp() and eolp())
     call("backward_delete_char");
   fit_window(get_blocal("is_popup", 0));
   bob();
   set_status_line("Grep: " + cmd + " (%p)", 0);
   grep_mode();
}

%}}}

provide(mode);

