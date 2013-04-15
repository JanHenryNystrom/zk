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
recfile include includes modules module record records path
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
Rootsymbol recfile.

%% ===================================================================
%% Rules.
%% ===================================================================

recfile -> includes modules : [].

includes -> '$empty'.
includes -> include includes.

include -> t_include path.

path -> t_string.

modules -> '$empty'.
modules -> module modules.

module -> t_module dot_name  '{' record records '}'.

dot_name -> name.
dot_name -> name t_dot dot_name.

records -> '$empty'.
records -> record records.

record -> t_class name '{' field fields '}'.

fields -> '$empty'.
fields -> field fields.

field -> type name ';'.

name ->  t_name.

type -> ptype.
type -> ctype.

ptype -> t_byte.
ptype -> t_boolean.
ptype -> t_int.
ptype -> t_long.
ptype -> t_float.
ptype -> t_double.
ptype -> t_ustring.
ptype -> t_buffer.

ctype -> t_vector '<' type '>'.
ctype -> t_map '<' type ',' type '>'.
ctype -> dot_name.


%% ===================================================================
%% Erlang Code.
%% ===================================================================
Erlang code.

%% Includes
%-include_lib("protobuf/include/zk_hadoop_record.hrl").

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
-spec file(string()) -> [_].
%%--------------------------------------------------------------------
file(File) ->
    {ok, Proto} = parse(zk_hadoop_record_scan:file(File)),
    Proto.

%%====================================================================
%% Internal functions
%%====================================================================
