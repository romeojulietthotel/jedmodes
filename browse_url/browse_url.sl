% browse_url	-*- mode: Slang; mode: Fold -*-
% 
% $Id$
% Keywords: WWW, processes, unix
%
% Copyright (c) 2003 Paul Boekholt, Günter Milde.
% Released under the terms of the GNU GPL (version 2 or later).
% 
% Functions for display of web pages from within JED. 
% Like Emacs' links.el and browse-url.el. Unix only.
% see also uri.sl
% 
% Versions
% 1.0 first public version (outsourced from jedscape by PB
%     and modified by GM)
% 1.1 changed the Browse_Url_Viewer default, as html2txt has problems
%     downloading "complicated" URLs (no negotiating with the server)
%     that can be avoided by using a text mode browser with --dump
% 1.2 made SLang2 proof
% 1.2.1 2005-10-13 bugfix in find_program()
% 1.2.1 2005-11-18 correct bugfix in find_program() (changed order of redirections)
% 1.3   2006-05-23 dropped implementing of a named namespace
% 1.3.1 2006-05-26 documentation update, added curl to list of download commands
%                  added missing autoloads (J. Sommer)
% 1.4   2009-01-27 added "www-browser" to Browse_Url_Browser defaults list
%                  code cleanup in find_program()
%                  
% TODO: use the curl module 
% There is code for downloading functions using the curl module in
% http://ruptured-duck.com/jed-users/msg01757.html

% _debug_info=1;

autoload("push_defaults", "slutils");
autoload("popup_buffer", "bufutils");
autoload("close_buffer", "bufutils");

provide("browse_url");
% implements("browse_url");


%{{{ finding the programs    
% This should be in a separate library (say sl-utils?)

%!%+
%\function{find_program}
%\synopsis{Check a list of program names for the first installed one}
%\usage{String = find_program(String programs)}
%\description
% Take a comma-separated list of command lines and return the first
% for which the program is in the path, or ""
% If a list element is a program with options, these options will be
% omitted for the availability test but turn up in the return value.
%\example
%#v+
%   find_program("wget -O -, w3c -n, dog")
%#v-
% returs "w3c -n", if w3c is in the PATH but wget not
%\notes
%   Uses the Unix system command 'which'. 
%   (Simply returns "" if the call to `which` fails)
%   Newer versions of jed (or slang?) come with a similar function 
%   (but what is its name?)
%\seealso{}
%!%-
static define find_program(programs)
{
   variable program;
   foreach program (strtok(programs, ",")) {
      program = strtrim(program);
      program = extract_element(program, 0, ' ');
      !if(system(sprintf("which %s > /dev/null 2>&1", program)))
	 return program;
   }
   return "";
}

%}}}

%{{{ custom variables

% Helper programs

%!%+
%\variable{Browse_Url_Browser}
%\synopsis{Text-mode browser}
%\description
%  Text mode browser called from browse_url
%\note
%  On Debian, www-browser is a symlink to the preferred browser on the
%  system.
%\seealso{browse_url, Browse_Url_Viewer}
%!%-
custom_variable("Browse_Url_Browser", 
   find_program("www-browser, links, lynx, w3m"));

%!%+
%\variable{Browse_Url_Download_Cmd}
%\synopsis{Download app}
%\description
%   Helper app for web downloads via find_url().
%   Must take a URL and dump it to stdout.
%\seealso{find_url, Browse_Url_Browser}
%!%-
custom_variable("Browse_Url_Download_Cmd", 
   find_program("wget --output-document=-, curl, w3c -n, dog"));
if (Browse_Url_Download_Cmd == "")
   Browse_Url_Download_Cmd = Browse_Url_Browser + " -source";
   
%!%+
%\variable{Browse_Url_Viewer}
%\synopsis{Web viewer}
%\description
%  Helper app for viewing an URL-s ASCII rendering with view_url().
%  Must dump an ASCII-rendering of the given URL to stdout.
%\notes
%  While html2txt accepts URLs as input, it has problems
%  downloading "redirected" URLs (no negotiating with the server)
%  that can be avoided by using a text mode browser with --dump
%\seealso{view_url, Browse_Url_Browser}
%!%-
custom_variable("Browse_Url_Viewer", Browse_Url_Browser + " -dump");

%!%+
%\variable{Browse_Url_X_Browser}
%\synopsis{X-windows browser}
%\description
%   Web browser called from browse_url (if jed runs under X-Windows)
%\notes
%  * Set to "", if you want the Browse_Url_Browser in a x-terminal.
%  * Browsers, that understand the -remote option could be "reused"
%    with gnome-moz-remote. It can be configured to open any browser 
%    and (other than netscape-remote) fires up a browser
%    if none is open (as does galeon -x) or firefox.
%\seealso{browse_url, browse_url_x, Browse_Url_Browser}
%!%-
custom_variable("Browse_Url_X_Browser", 
   find_program("firefox, galeon -x, gnome-moz-remote, opera, dillo, mozilla, netscape"));


% ------------------- Functions ------------------------------


%!%+
%\function{find_url}
%\synopsis{Find a file by URL}
%\usage{ find_url(url="", cmd = Browse_Url_Download_Cmd)}
%\description
%   Fetch a file from the web and put in a buffer as-is. Needs a 
%   helper application like wget or lynx to do the actual work.
%   If the url is not given, it will be asked for in the minibuffer.
%   If the helper app is not given, it defaults to the value of the 
%   custom variable Browse_Url_Download_Cmd.
%\seealso{view_url, find_file, Browse_Url_Download_Cmd}
%!%-
public define find_url() %(url="", cmd = Browse_Url_Download_Cmd)
{
   variable status, url, cmd;
   (url, cmd) = push_defaults(, Browse_Url_Download_Cmd, _NARGS);
   if (url == NULL)  
     url = read_mini("url: ", "", "");

   popup_buffer(url);
   erase_buffer();
   flush(sprintf("calling %s %s", cmd, url));
   status = run_shell_cmd(sprintf("%s %s", cmd, url));
   if (status)
     {
	close_buffer();
	verror("%s returned %d, %s", cmd, status, errno_string(status));
     }
   set_buffer_modified_flag(0);
   bob();
}

%!%+
%\function{view_url}
%\synopsis{View an ASCII rendering of a URL}
%\usage{ view_url(String url="", String cmd= Browse_Url_Viewer)}
%\description
%   View the ASCII-rendering of a URL in a buffer.
%   Depends on a suitable helper app
%   If the url is not given, it will be asked for in the minibuffer.
%   If the helper app is not given, it defaults to the value of the 
%   custom variable Browse_Url_Viewer
%\seealso{find_url, Browse_Url_Viewer}
%!%-
public define view_url() %(url="", cmd= Browse_Url_Viewer)
{
   variable status, url, cmd;
   (url, cmd) = push_defaults(, Browse_Url_Viewer, _NARGS);
   if (url == NULL)  
     url = read_mini("url: ", "", "");
   
   popup_buffer("*"+url+"*");
   erase_buffer;

   flush(sprintf("calling %s %s", cmd, url));
   status = run_shell_cmd(sprintf("%s %s", cmd, url));
   if (status)
     {
	close_buffer();
	verror("%s returned %d, %s", cmd, status, errno_string(status));
     }
   set_buffer_modified_flag(0);
   bob;
   view_mode();
}

%{{{ X-windows

%!%+
%\function{browse_url_x}
%\synopsis{Open a URL in a browser}
%\usage{browse_url_x(String url=ask, String cmd=Browse_Url_X_Browser)}
%\description
%   Open the url in a browser (defaulting to Browse_Url_X_Browser)
%   as background process in a separate window.
%\seealso{browse_url, find_url, view_url, Browse_Url_X_Browser}
%!%-
public  define browse_url_x() %(url, cmd=Browse_Url_X_Browser)
{
   variable status, url, cmd;
   (url, cmd) = push_defaults(, Browse_Url_X_Browser, _NARGS);
   if (url == NULL)  
     url = read_mini("url: ", "", "");

   flush(sprintf("calling %s %s", cmd, url));
   cmd = strcat(cmd, " ", url);
#ifdef UNIX
   cmd += " &> /dev/null &"; % run cmd in background
#endif
   status = system(cmd);
   if (status)
     verror("%s returned %d, %s", cmd, status, errno_string(status));
}

%}}}

%!%+
%\function{browse_url}
%\synopsis{Open the url in a browser}
%\usage{ browse_url() %(url="", cmd=Browse_Url_Browser)}
%\description
% Open the url in a browser (default Browse_Url_Browser/Browse_Url_X_Browser)
% Without X-windows running, jed is suspended as long as the browser runs,
% otherwise run the browser as background process in a separate window.
%\seealso{browse_url_x, view_url, find_url, Browse_Url_Browser}
%!%-
public define browse_url() %(url="", cmd=Browse_Url_Browser)
{
   variable status, url, cmd;
   (url, cmd) = push_defaults(, Browse_Url_Browser, _NARGS);
   if (url == NULL)  
     url = read_mini("url: ", "", "");
   
   % use the X-Browser only with xjed
   % if (is_defined("x_server_vendor") and Browse_Url_X_Browser != "")
   % check for a running X-Win via the DISPLAY variable
   if (getenv("DISPLAY") != NULL and Browse_Url_X_Browser != "")
     {
	if (_NARGS == 2)
	  browse_url_x(url, cmd);
	else
	  browse_url_x(url);
     }
   else
     {
	flush(sprintf("calling %s %s", cmd, url));
	status = run_program(sprintf("%s %s", cmd, url));
	if (status)
	  verror("%s returned %d, %s", cmd, status, errno_string(status));
     }
}

