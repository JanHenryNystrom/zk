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
%%%   Hadoop record lexer.
%%% @end
%%%
%% @author Jan Henry Nystrom <JanHenryNystrom@gmail.com>
%% @copyright (C) 2013, Jan Henry Nystrom <JanHenryNystrom@gmail.com>
%%%-------------------------------------------------------------------

%% ===================================================================
%% Definitions.
%% ===================================================================
Definitions.

Whitespace = [\s\n\t\r\v\f]
WhitespaceNoNewline = [\s\n\t\r\v\f]
Letter = [A-Za-z_]
Alphanumeric = [A-Za-z_0-9]
Symbol = [;\{\}\,\<\>]
Dot = \.

BLOCK_COMMENT = (/\*([^*]|[\s\t\r\n]|(\*+([^*/]|[\s\t\r\n])))*\*+/)|(//.*)
LINE_COMMENT = (#[^\n]*)|(////[^\n]*)

Name = {Letter}{Alphanumeric}*
Identifier = {Letter}{Alphanumeric}*
DecInt = [-]?[1-9]{Digit}*
HexInt = [-]?0[xX]{HexDigit}+
OctInt = [-]?0{OctalDigit}*

String = (\"([\\\\"]|[^\"\n])*\")|(\'([\\\\']|[^\'\n])*\')
%% "

%% ===================================================================
%% Erlang code.
%% ===================================================================
Rules.

{Whitespace} : skip_token.
{BLOCK_COMMENT} : skip_token.
{LINE_COMMENT} : skip_token.

{Symbol} : {token, {list_to_atom(TokenChars), TokenLine}}.

include : {token, {t_include, TokenLine}}.
module : {token, {t_module, TokenLine}}.
class : {token, {t_class, TokenLine}}.
vector : {token, {t_vector, TokenLine}}.
map : {token, {t_map, TokenLine}}.
byte : {token, {t_byte, TokenLine, byte}}.
boolean : {token, {t_boolean, TokenLine, boolean}}.
int : {token, {t_int, TokenLine, int}}.
long : {token, {t_long, TokenLine, long}}.
float : {token, {t_float, TokenLine, float}}.
double : {token, {t_double, TokenLine, double}}.
ustring : {token, {t_ustring, TokenLine, ustring}}.
buffer : {token, {t_buffer, TokenLine, buffer}}.

{Name}  : {token, {t_name, TokenLine, list_to_atom(TokenChars)}}.

{String} : {token, {t_string, TokenLine, TokenChars}}.

{Dot} : {token, {t_dot, TokenLine}}.

%% ===================================================================
%% Erlang code.
%% ===================================================================
Erlang code.

%% API
-export([file/1]).

%%====================================================================
%% API
%%====================================================================

%%--------------------------------------------------------------------
%% Function: file(FileName) -> Tokens.
%% @doc
%%   Tokenizes a .jute file.
%% @end
%%--------------------------------------------------------------------
-spec file(string()) -> [_].
%%--------------------------------------------------------------------
file(File) ->
    {ok, Bin} = file:read_file(File),
    case string(binary_to_list(Bin)) of
        {ok, Tokens, _} -> {ok, Tokens};
        Error -> Error
    end.

%%====================================================================
%% Internal functions
%%====================================================================
