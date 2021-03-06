% fileview.sl	-*- mode: Slang; mode: Fold -*-
% configurable file viewing function
% 
% $Id: fileview.sl,v 1.1 2004/02/25 21:41:57 paul Exp paul $
% Keywords: slang
%
% Copyright (c) 1997 Francesc Rocher; (c) 2004, 2005 Paul Boekholt.
% Released under the terms of the GNU GPL (version 2 or later).
% 
% This is a simplified version of the treepipe filtered viewer from
% tree.sl. It should also be useful with dired or filelist.
% This version requires the wildcard module.
provide("fileview");
require("wildcard");
implements("fileview");


variable fileview_pipe = String_Type[100, 3],
  fileview_pipe_last = 0;

private variable in_x = (NULL != getenv("DISPLAY"));

%!%+
%\function{fileview_add_pipe}
%\synopsis{add an entry to the fileview table}
%\usage{fileview_add_pipe(mode, wildcard, command)}
%\description
%  Adds an entry to the fileview table which associates wildcard
%  patterns with viewers. The parameters are:
%  
%  \var{mode} values:
%                'b' View results in a buffer
%                'f' Use a function and view results in a buffer
%                'X' Use an external program, requires X
%                'T' Requires a terminal - use run_program
%
%  \var{wildcard} the pattern to match
%    This should be a lowercase glob pattern.  The filename is lowercased
%    before being matched.
%  
%  \var{command}
%     the command to view the file. 
%       If \var{mode} is 'f' this is the name of a S-Lang function. Should look
%       like "tar (\"%s\")". The filename will be substituted for the %s.
%       
%       Otherwise it's a program name. If there is a "%s" in the command,
%       the filename is substituted, otherwise it is appended to the
%       command.
%     
%\seealso{fileview_view_pipe}
%
%!%-
define fileview_add_pipe(mode, wildcard, command)
{
   if (mode == "X" and not in_x) return;
   if (3 * fileview_pipe_last >= length(fileview_pipe))
     {
	fileview_pipe = [fileview_pipe, @String_Type[99]];
	reshape (fileview_pipe, [length(fileview_pipe) / 3, 3]);
     }
   fileview_pipe[fileview_pipe_last, *] = 
     [mode, wildcard, command];
   fileview_pipe_last++;
}

     
%!%+
%\function{fileview_view_pipe}
%
%\synopsis{view a file through a pipe}
%
%\usage{fileview_view_pipe(String file)}
%
%\description
%  Tries to match the filename \var{file} with a table of wildcard
%  patterns. When a match is found, the associated action is taken.
%  
%\seealso{add_to_fileview_pipe}
%
%!%-
public  define fileview_view_pipe (file)
{
   % Show a file through a pipe.
   variable i, m = 0;

   _for (0, fileview_pipe_last, 1)
     {
        i = ();
	if (fileview_pipe[i,0]==NULL) break;
        m = wildcard_match (strlow(path_basename(file)), fileview_pipe[i,1]);
        if (m)
	  break;
     }

   !if (m)
     return message ("no viewer found");

   if (fileview_pipe[i,0] == "b")
     {
        pop2buf ("*fileview*");
     }

   flush ("Processing file "+file+" ...");


   % --- Command ------------------------------------------------
   switch (fileview_pipe[i,0])
     {
      case "b": % Send output to buffer
	if (is_substr(fileview_pipe[i,2], "%"))
	  () = run_shell_cmd (sprintf(fileview_pipe[i,2], file) + " 2> /dev/null");
	else
	  () = run_shell_cmd (fileview_pipe[i,2]+" "+file+" 2> /dev/null");
     }
     {
      case "f": % Use a function
        eval (sprintf(fileview_pipe[i,2],file));
     }
     {
      case "X": % Use an X-windows program
	if (is_substr(fileview_pipe[i,2], "%"))
	  () = system (sprintf(fileview_pipe[i,2], file) + " 2> /dev/null");
	else
	  () = system (fileview_pipe[i,2]+" "+file+" 2> /dev/null &");
     }
     {
      case "T": % terminal program
	if (is_substr(fileview_pipe[i,2], "%"))
	  () = run_program (sprintf(fileview_pipe[i,2], file));
	else
	  () = run_program(fileview_pipe[i,2]+" "+file);
	call("redraw");
     }
   

   % --- Finally ------------------------------------------------
   if (fileview_pipe[i,0] == "b")
     {
        bob ();
        set_buffer_modified_flag (0);
        most_mode ();
     }
   flush ("Processing file "+file+" ... done");
}

% edit fileview_cmds.sl to define your own pipe commands
require("fileview_cmds");
