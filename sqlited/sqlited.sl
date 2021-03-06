% sqlited.sl
% 
% $Id: sqlited.sl,v 1.5 2008/12/14 13:16:30 paul Exp paul $
%
% Copyright (c) 2006,2007 Paul Boekholt.
% Released under the terms of the GNU GPL (version 2 or later).
% 
% SQLite administration utility.  Sqlited prompts for a database to open.  The
% tables and views in the database are shown in an index buffer.  From there
% you can open open tables, views, SQL commands and SQL query results in other
% buffers.  The database handle is passed to the table and sql buffers in a
% blocal var, so it's possible to open multiple SQLite files and open multiple
% tables in those files, as long as the files have different names.  Get the
% SQLite module from http://www.cheesit.com/downloads/slang/slsqlite

provide("sqlited");
require("sqlite");
require("bufutils");
require("csvutils");
require("listing");
autoload("add_keyword_n", "syntax");
private variable mode = "sqlited";

%{{{ prototypes
define sqlited();
%}}}

%{{{ table viewer

private define extract_rowid(line)
{
   return strtok(line)[0];
}

private define list_tagged_records()
{
   variable tag_lines = listing_list_tags(2);
   tag_lines = array_map(String_Type, &extract_rowid, tag_lines);
   return strjoin(tag_lines, ",");
}

private define delete_tagged_line()
{
   return 2;
}

private define delete_tagged()
{
   % make sure the first line is not tagged
   push_spot_bob();
   listing->tag(0);
   pop_spot();
   variable db = get_blocal_var("db"),
   tablename = get_blocal_var("tablename");
   sqlite_exec(db, sprintf("delete from '%s' where _ROWID_  in (%s)",
			   tablename, list_tagged_records()));
   listing_map(2, &delete_tagged_line);
}

private define edit()
{
   variable column = read_with_completion(get_blocal_var("columns"), "column", "", "", 's');
   variable db = get_blocal_var("db"),
   tablename = get_blocal_var("tablename"),
   rowid = extract_rowid(line_as_string());
   variable default = sqlite_get_array(db, String_Type, 
				       sprintf("select \"%s\" from '%s' where _ROWID_ = ?",
					       column, tablename),
				       rowid);
   default = default[0,0];
   variable new_value = read_mini("new value", "", default);
   sqlite_exec(db, sprintf("update '%s' set '%s'= ? where _ROWID_ = ?",
			   tablename, column),
	       new_value, rowid);
   % Todo: update the line in the buffer.
}

private define index()
{
   variable db = get_blocal_var("db"),
   filename = get_blocal_var("filename");
   variable indexbuf = sprintf("*sqlited:%s*", filename);
   if (bufferp(indexbuf)) sw2buf (indexbuf);
   else sqlited(filename, db);
}
   
ifnot (keymap_p(mode))
  copy_keymap(mode, "listing");

definekey(&delete_tagged, "x", mode);
definekey(&edit, "e", mode);
definekey(&index, "i", mode);

%!%+
%\function{sqlite_table_mode}
%\synopsis{mode for editing SQLite tables}
%\usage{sqlite_table_mode()}
%\description
%  This is a mode for editing tables in a SQLite database.  The following
%  keys are defined:
%  \var{d}  Mark record for deletion
%  \var{x}  Delete marked records
%  \var{e}  Edit the record at point.  Prompts for a field to change and a
%       value to change it to.  The change is not reflected in the buffer.
%  \var{i}  Return to the index buffer
%\seealso{sqlited, sqlite_table}
%!%-
private define sqlite_table_mode()
{
   listing_mode();
   use_keymap(mode);
   set_mode("sqlite_table", 0);
}

private define popup_view_or_table(db, filename, table, tablename, align)
{  
   table[where(_isnull(table))] = "";
   % trim multiline fields - maybe csvutils should do this
   table = array_map(String_Type, &extract_element, table, 0, '\n');
   % truncate to 50 chars
   table = array_map(String_Type, &substr, table, 1, 50);
   popup_buffer(sprintf("*sqlited:%s/%s*", path_basename(filename), tablename));
   set_readonly(0);
   erase_buffer();
   variable columns="", column, type;
   foreach (db) using (sprintf("PRAGMA table_info('%s')", tablename))
     {
	(,column,type,,,) = ();
	if (type == "INTEGER") align += "r";
	else align += "l";
	columns = sprintf("%s,%s", columns, column);
     }
   insert_table(table, align, " ");
   eob();
   push_mark();
   bskip_chars("\n");
   del_region();
   bob();
   define_blocal_var("db", db);
   define_blocal_var("columns", columns);
   define_blocal_var("tablename", tablename);
   define_blocal_var("filename", filename);
}

%!%+
%\function{sqlited_table}
%\synopsis{edit a SQLite database table}
%\usage{sqlited_table(db, filename, tablename)}
%\description
%  This opens a table of an open SQLite database in the \var{sqlited} table
%  editing mode.
%\notes
%  
%\seealso{sqlited, sqlite_mode, sqlited_view}
%!%-
public define sqlited_table(db, filename, tablename)
{
   variable table;
   table = sqlite_get_table(db, sprintf("select _ROWID_, * from '%s'", tablename));
   ifnot (length(table)) return message("table is empty");
   popup_view_or_table(db, filename, table, tablename, "l");
   sqlite_table_mode();
}

%!%+
%\function{sqlited_view}
%\synopsis{open a SQLite database view}
%\usage{sqlited_view(db, filename, tablename)}
%\description
%  This  a view of an open SQLite database in view_mode.
%\seealso{sqlited, sqlite_mode, sqlited_table}
%!%-
public define sqlited_view(db, filename, tablename)
{
   variable table;
   table = sqlite_get_table(db, sprintf("select * from '%s'", tablename));
   ifnot (length(table)) return message("view is empty");
   popup_view_or_table(db, filename, table, tablename, "");
   view_mode();
}

private define view_table()
{
   variable db = get_blocal_var("db");
   variable indexbuf=whatbuf();
   variable tabletype, tablename, align = "", table;
   (tabletype, tablename) = str_split(line_as_string(), 9);
   variable filename=get_blocal_var("filename");
   if (tabletype == "table:  ")
     {
	sqlited_table(db, filename, tablename);
     }
   else if (tabletype == "view:   ")
     {
	sqlited_view(db, filename, tablename);
     }
}


%}}}

%{{{ sqlite buffer

% adapted from sql.sl
create_syntax_table("sqlite");
define_syntax("--", "", '%', "sqlite");
define_syntax("/*", "*/", '%', "sqlite");
define_syntax('"', '"', "sqlite");
define_syntax('\'', '"', "sqlite");
define_syntax("(", ")", '(', "sqlite");
define_syntax("0-9a-zA-Z_", 'w', "sqlite");  % words
define_syntax("-+0-9.", '0', "sqlite");      % Numbers
define_syntax(",;", ',', "sqlite");
define_syntax("|*/%+-<>&=!~", '+', "sqlite");
set_syntax_flags ("sqlite", 0x01 | 0x20); % case insensitive

% define_keywords_n("sqlite", "asbyifinisofonorto", 2, 0);
()=define_keywords_n("sqlite", "addallandascendforkeynotrowset", 3, 0);
()=define_keywords_n("sqlite", "casecastdescdropeachelsefailfromfullglobintojoinleftlikenullplantempthenviewwhen", 4, 0);
()=define_keywords_n("sqlite", "abortafteralterbegincheckcrossgroupindexinnerlimitmatchorderouterqueryraiserighttableunionusingwhere", 5, 0);
()=define_keywords_n("sqlite", "attachbeforecolumncommitcreatedeletedetachescapeexceptexistshavingignoreinsertisnulloffsetpragmaregexprenameselectuniqueupdatevacuumvalues", 6, 0);
()=define_keywords_n("sqlite", "analyzebetweencascadecollatedefaultexplainforeigninsteadnaturalnotnullprimaryreindexreplacetrigger", 7, 0);
()=define_keywords_n("sqlite", "conflictdatabasedeferreddistinctrestrictrollback", 8, 0);
()=define_keywords_n("sqlite", "exclusiveimmediateinitiallyintersectstatementtemporary", 9, 0);
()=define_keywords_n("sqlite", "constraintdeferrablereferences", 10, 0);
()=define_keywords_n("sqlite", "transaction", 11, 0);
()=define_keywords_n("sqlite", "current_datecurrent_time", 12, 0);
()=define_keywords_n("sqlite", "autoincrement", 13, 0);
()=define_keywords_n("sqlite", "current_timestamp", 17, 0);

()=define_keywords_n("sqlite", "absavgmaxminsum", 3, 1);
()=define_keywords_n("sqlite", "countlowerquoteroundtotalupper", 5, 1);
()=define_keywords_n("sqlite", "ifnulllengthnullifrandomsubstrtypeof", 6, 1);
()=define_keywords_n("sqlite", "changessoundex", 7, 1);
()=define_keywords_n("sqlite", "coalesce", 8, 1);
()=define_keywords_n("sqlite", "total_changes", 13, 1);
()=define_keywords_n("sqlite", "sqlite_version", 14, 1);
()=define_keywords_n("sqlite", "last_insert_rowid", 17, 1);

%!%+
%\function{sqlite_mode}
%\synopsis{sql mode for sqlite}
%\usage{sqlite_mode()}
%\description
%  This is a mode for the SQLite dialect of SQL.  If the buffer was opened
%  from \sfun{sqlited}, \sfun{run_buffer} executes the buffer's contents on
%  the database.  Table and column names of files opened with \sfun{sqlited}
%  are added to the keyword2 syntax table, though you may not see this in your
%  color scheme.
%\seealso{sqlited, run_buffer}
%!%-
define sqlite_mode()
{
   use_syntax_table("sqlite");
   set_mode("sqlite", 4);
}

private define sqlite_run()
{
   variable e, db = get_blocal_var("db");
   mark_buffer();
   sqlite_exec(db, "begin");
   try (e)
     sqlite_exec(db, bufsubstr());
   catch SqliteError:
     {
	sqlite_exec(db, "rollback");
	throw;
     }
   sqlite_exec(db, "commit");
   vmessage("%d rows affected", sqlite_changes(db));
}

%}}}

%{{{ index buffer

private define sqlite_query()
{
   variable db = get_blocal_var("db");
   variable query = read_mini("query", "", "");
   variable table = sqlite_get_table(db, query);
   ifnot(length(table)) return message("no matching records");
   popup_buffer("*sqlite result*");
   set_readonly(0);
   erase_buffer();
   vinsert ("results of \"%s\"\n", query);
   table[where(_isnull(table))] = "";
   table = array_map(String_Type, &extract_element, table, 0, '\n');
   table = array_map(String_Type, &substr, table, 1, 50);
   insert_table(table);
   view_mode();
}

private define sqlite_command()
{
   variable db = get_blocal_var("db");
   pop2buf(sprintf("*sqlite:%s*", path_basename(get_blocal_var("filename"))));
   sqlite_mode();
   define_blocal_var("db", db);
   define_blocal_var("run_buffer_hook", &sqlite_run);
}

private define edit_view()
{
   variable db = get_blocal_var("db"), type, table;
   (type, table) = str_split(line_as_string(), 9);
   if (type != "view:   " && type != "trigger:")
     throw RunTimeError, "not looking at a view or trigger";
   pop2buf(sprintf("*sqlite:%s/%s*", path_basename(get_blocal_var("filename"), table)));
   erase_buffer();
   if (type == "view:  ")
     vinsert("drop view '%s';\n", table);
   else
     vinsert("drop trigger '%s';\n", table);
   insert(sqlite_get_row(db, "select sql from sqlite_master where name = ?", table));
   set_buffer_modified_flag(0);
   sqlite_mode();
   define_blocal_var("db", db);
   define_blocal_var("view", table);
   define_blocal_var("run_buffer_hook", &sqlite_run);
}

private define drop_table()
{
   variable db = get_blocal_var("db"),
   table, type;
   (type, table)= str_split(line_as_string(), 9);
   if (type == "table:  ")
     {
	ifnot (get_y_or_n(sprintf("really drop table %s", table))) return;
	sqlite_exec(db, sprintf("drop table '%s'", table));
     }
   else if (type == "view:   ")
     {
	ifnot (get_y_or_n(sprintf("really drop view %s", table))) return;
	sqlite_exec(db, sprintf("drop view '%s'", table));
     }
   else if (type == "trigger:")
     {
	ifnot (get_y_or_n(sprintf("really drop trigger %s", table))) return;
	sqlite_exec(db, sprintf("drop trigger '%s'", table));
     }
   else throw RunTimeError, "not looking at a view or table";
   set_readonly(0);
   delete_line();
   set_buffer_modified_flag(0);
   set_readonly(1);
}

private define rename_table()
{
   variable db = get_blocal_var("db"),
   table, type;
   (type, table) = str_split(line_as_string(), 9);
   if (type != "table:  ")
     throw RunTimeError, "not looking at a table";
   variable name = read_mini("rename to ", "", "");
   sqlite_exec(db, sprintf("alter table '%s' rename to '%s';", table, name));
   set_readonly(0);
   bol;
   go_right(8);
   del_eol();
   insert(name);
   set_buffer_modified_flag(0);
   set_readonly(1);
}

private define read_index()
{
   variable db = get_blocal_var("db");
   create_syntax_table("sqlite");
   set_readonly(0);
   erase_buffer();
   variable name, type, column;
   foreach name, type (db) using ("SELECT name, type FROM sqlite_master WHERE type in ('table', 'view', 'trigger')"
		       +" AND name NOT LIKE 'sqlite_%' ORDER BY 1")
     {
	add_keyword_n("sqlite", name, 2);
	if (type == "table")
	  {
	     foreach (db) using (sprintf("PRAGMA table_info('%s')", name))
	       {
		  (,column,,,,) = ();
		  add_keyword_n("sqlite", column, 2);
	       }
	     vinsert("table:  %s\n", name);
	  }
	else if (type == "trigger")
	  vinsert("trigger:%s\n", name);
	else
	  vinsert("view:   %s\n", name);
     }
   set_buffer_modified_flag(0);
   set_readonly(1);
}

ifnot (keymap_p("sqlite_index"))
  copy_keymap("sqlite_index", "view");
definekey(&sqlite_command, "c", "sqlite_index");
definekey(&edit_view, "e", "sqlite_index");
definekey(&sqlite_query, "?", "sqlite_index");
definekey(&drop_table, Key_Del, "sqlite_index");
definekey(&rename_table, "r", "sqlite_index");
definekey(&read_index, "^r", "sqlite_index");
definekey(&view_table, "^M", "sqlite_index");

%!%+
%\function{sqlited}
%\synopsis{SQLite database viewer and editor}
%\usage{sqlited()}
%\description
% Mode for SQLite database administration.  Sqlited prompts for a database
% filename and shows the tables and views in sqlited mode.  The following keys
% are defined:
% 
% \var{c}      opens a sql buffer in \sfun{sqlite_mode}.
% \var{delete} drop the table or view at point
% \var{e}      edit the view at point.  \var{sqlited} inserts the drop view
%          statement for you, to update the view just call \sfun{run_buffer}.
% \var{?}      prompts for a query in the minibuffer, and shows the result of the
%          query in its own buffer.
% \var{C-r}    reread the index
% \var{enter}  open the table at point in \var{sqlite_table_mode}.
%\seealso{sqlite_table_mode, sqlite_mode}
%!%-
define sqlited()
{
   variable filename, db;
   if (_NARGS == 2)
     {
	(filename, db) = ();
     }
   else
   {
      filename = read_file_from_mini("sqlite file");
      db = sqlite_open(filename);
   }
   variable bufname = sprintf("*sqlited:%s*", path_basename(filename));
   pop2buf(bufname);
   setbuf_info(path_basename(filename), path_dirname(filename), bufname, 0);
   define_blocal_var("db", db);
   define_blocal_var("filename", filename);
   read_index();
   use_keymap("sqlite_index");
   set_mode("sqlited", 0);
   set_buffer_hook("newline_indent_hook", &view_table);
}

%}}}
