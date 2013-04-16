%% -*-erlang-*-
%%==============================================================================
%% Copyright 2013 Jan Henry Nystrom <JanHenryNystrom@gmail.com>
%%
%% Licensed under the Apache License, Version 2.0 (the "License");
%% you may not use this file except in compliance with the License.
%% You may obtain a copy of the License at
%%
%% http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing, software
%% distributed under the License is distributed on an "AS IS" BASIS,
%% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%% See the License for the specific language governing permissions and
%% limitations under the License.
%%==============================================================================

%%%-------------------------------------------------------------------
%%% @doc
%%%   Hadoop record parser.
%%% @end
%%%
%% @author Jan Henry Nystrom <JanHenryNystrom@gmail.com>
%% @copyright (C) 2013, Jan Henry Nystrom <JanHenryNystrom@gmail.com>
%%%-------------------------------------------------------------------

%% ===================================================================
%% Nonterminals.
%% ===================================================================
Nonterminals
file include includes modules module record records path
dot_name name fields field type ptype ctype
.

%% ===================================================================
%% Terminals.
%% ===================================================================
Terminals
%% Symbols
t_include t_string t_module t_class
t_vector t_map
t_byte t_boolean t_int t_long t_float t_double t_ustring t_buffer
t_name t_dot
%% Symbols
'{' '}' '<' '>' ';' ','
.

%% ===================================================================
%% Expected shit/reduce conflicts.
%% ===================================================================
Expect 0.

%% ===================================================================
%% Rootsymbol.
%% ===================================================================
Rootsymbol file.

%% ===================================================================
%% Rules.
%% ===================================================================

file -> includes modules : #file{includes = '$1',
                                 modules = '$2'
                                }.

includes -> '$empty'         : [].
includes -> include includes : ['$1' | '$2'].

include -> t_include path    : value($2).

path -> t_string : '$1'.

modules -> '$empty'       : [].
modules -> module modules : ['$1' | '$2'].

module -> t_module dot_name '{' record records '}' :
          #module{name = name('$2'),
                  records = ['$4' | '$5'],
                  line = line('$1')}.

dot_name -> name                : ['$1'].
dot_name -> name t_dot dot_name : ['$1' | '$3'].

records -> '$empty'       : [].
records -> record records : ['$1' | '$2'].

record -> t_class name '{' field fields '}' :
          #record{name = name('$2'), fields = ['$4' | '$5'], line = line('$1')}.

fields -> '$empty'     : [].
fields -> field fields : ['$1' | '$2'].

field -> type name ';' :
         #field{name = name('$2'),
                type = '$1',
                line = line('$2')}.

name ->  t_name : '$1'.

type -> ptype : value('$1').
type -> ctype : '$1'.

ptype -> t_byte    : '$1'.
ptype -> t_boolean : '$1'.
ptype -> t_int     : '$1'.
ptype -> t_long    : '$1'.
ptype -> t_float   : '$1'.
ptype -> t_double  : '$1'.
ptype -> t_ustring : '$1'.
ptype -> t_buffer  : '$1'.

ctype -> t_vector '<' type '>'       : #vector{type = '$3', line = line('$1')}.
ctype -> t_map '<' type ',' type '>' :
         #map{key = '$3',
              value = '$5',
              line = line('$1')}.
ctype -> dot_name : name('$1').


%% ===================================================================
%% Erlang Code.
%% ===================================================================
Erlang code.

%% Includes
-include_lib("zk/src/zk_hadoop_record.hrl").

%% API
-export([file/1]).

%%====================================================================
%% API
%%====================================================================

%%--------------------------------------------------------------------
%% Function: file(FileName) -> .
%% @doc
%%   Parses a .jute file.
%% @end
%%--------------------------------------------------------------------
-spec file(string()) -> {ok, _} | {error, _}.
%%--------------------------------------------------------------------
file(File) ->
    case zk_hadoop_record_scan:file(File) of
        {ok, Tokens} -> parse(Tokens);
        Error -> Error
    end.

%%====================================================================
%% Internal functions
%%====================================================================

value({_, _, Value}) -> Value.

line({_, Line, _}) -> Line;
line({_, Line}) -> Line.

name({t_name, Line, Value}) -> #name{value = Value, line = Line};
name(Values = [{_, Line, _} | _]) when is_list(Values) ->
    #name{type = scoped,
          value = [Value || {_, _, Value} <- Values],
          line = Line}.
