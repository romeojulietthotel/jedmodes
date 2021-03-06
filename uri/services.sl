% Services, uri_hooks for some common URI schemes.
%
% Copyright (c) 2006 Guenter Milde (milde users.sf.net)
% Released under the terms of the GNU General Public License (ver. 2 or later)
%
% This file provides some basic "*_uri_hook"s for the find|write_uri_hook 
% and the find|write_uri functions provided by uri.sl.
%
% 0.2   2007-10-01
% 0.2.1 2007-10-01  optional extensions with #if ( )

% recommends: mtools; browse_url; filelist; grep

% file:      local file
public define file_uri_hook(path)         {find_file(path);}

% Universal Ressource Locators (URLs)
% http:     hypertext transfer protocoll
% ftp:      file transfer protocoll
#if (expand_jedlib_file("browse_url.sl") != "")
autoload("find_url", "browse_url"); 
public define http_uri_hook(path) { find_url("http:" + path); }
public define ftp_uri_hook(path)  { find_url("ftp:" + path); }
#endif

#ifdef UNIX

% floppy:   access a floppy using mtools
% a:        alternative shortform (used by mtools and familiar from (Win)DOS)
#if (expand_jedlib_file("mtools.sl") != "")
autoload("mtools_find_file", 	"mtools");
autoload("mtools_write", "mtools");
public define floppy_uri_hook(path)       { mtools_find_file("a:"+path); }
public define a_uri_hook(path) 	   { mtools_find_file("a:"+path); }
public define floppy_write_uri_hook(path) { mtools_write("a:"+path); }
public define a_write_uri_hook(path) 	   { mtools_write("a:"+path); }
#endif

% man:      Unix man pages 
public define man_uri_hook(path) {unix_man(path);}

% locate:   locate system command interface
#if (expand_jedlib_file("filelist.sl") != "")
autoload("locate", "filelist");
public define locate_uri_hook(path) {locate(path);}
#endif

% grep:     grep for a pattern
% Problem: how to pass 2 arguments ("what" and "where")?
% public define grep_uri_hook(path) {grep(path);}

#endif  % Unix

provide("services");
