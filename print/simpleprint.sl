% print.sl --- a printing mode for jed ---% print.sl
% 
% Copyright (c) 2005 Günter Milde
% Released under the terms of the GNU General Public License (ver. 2 or later)
% 
% very basic, but allows to send the buffer content to the printer 
% with a key shortcut or menu item.
% 
% Versions
% 
% 2004-11-15  0.1   first published version
% 2005-11-21  0.2   no autoload with make_ini() 
%             	    to avoid conflicts with other print modes
% 2009-01-30  0.3   rename to simpleprint.sl, as there is another print.sl
% 	      	    coming with slsh
%
% Usage
% -----
% 
% Example::
% 
%  autoload("print_buffer", "print.sl");
%  setkey("print_buffer", "^P");
%  setkey("print_buffer",	          Key_F9);
% 
%  define print_popup_hook(menubar) {
%    menu_insert_separator(6, "Global.&File");
%    menu_insert_item(7, "Global.&File", "&Print Buffer", "print_buffer");
%  }
%  append_to_hook ("load_popup_hooks", &print_popup_hook);


%!%+
%\function{print_buffer}
%\synopsis{sends the buffer content to the lineprinter}
%\usage{Void print_buffer ()}
%\description
%   The print_buffer command prints the content of the active buffer. 
%   It does not do any formatting except sending an initializating string
%   "PrintInitString" to the printer, if this custom variable is defined.
%\notes
%   print_buffer uses the 'lpr' command on unix and the 'print' command on DOS
%\seealso{shell_perform_cmd}
%!%-
custom_variable("PrintInitString", "");

#ifdef IBMPC_SYSTEM
custom_variable("PrintCommand", "print");
shell_perform_cmd("print /D:PRN", 0); % initialize printer 
#else
custom_variable("PrintCommand", "lpr");
#endif

define print_buffer ()
{
   variable print_command = read_mini("Print the current buffer with:",
				      "", PrintCommand);
   !if (strlen(print_command))
     return;
   
   push_spot ();
#ifdef IBMPC_SYSTEM
   variable dir = getenv ("TMP");
   if (dir == NULL)
     dir = "C:";
   variable printfile = dircat (dir, "print.tmp");
   () = write_string_to_file (PrintInitString, printfile);
   mark_buffer;
   () = append_region_to_file(printfile);
   shell_perform_cmd("print c:\\temp\\print.tmp", 0);
#else
   variable status;
   mark_buffer ();
   status = pipe_region ("lpr");
   if (status) error ("lpr failed.");
#endif
   pop_spot ();
}


