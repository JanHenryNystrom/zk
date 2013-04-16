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
%%%   Hadoop record compiler.
%%% @end
%%%
%% @author Jan Henry Nystrom <JanHenryNystrom@gmail.com>
%% @copyright (C) 2013, Jan Henry Nystrom <JanHenryNystrom@gmail.com>
%%%-------------------------------------------------------------------
-module(zk_hadoop_record).
-copyright('Jan Henry Nystrom <JanHenryNystrom@gmail.com>').

%% API
-export([compile/1, compile/2]).

%% Includes

%% Records
-record(opts, {dest_name :: string(),
               include_paths = [] :: [string()],
               src_dir = "." :: string(),
               dest_dir = "." :: string()}).
%% Defines


%% Types
-type opt() :: {dest_name, string()} | {include_paths, [string()]} |
               {src_dir, string()} | {dest_dir, string()}.

%%====================================================================
%% API
%%====================================================================

%%--------------------------------------------------------------------
%% Function: compile(FileName) -> ok | error.
%% @doc
%%   Compiles a .jute file.
%% @end
%%--------------------------------------------------------------------
-spec compile(string()) -> ok | {error, _}.
%%--------------------------------------------------------------------
compile(File) -> compile(File, []).

%%--------------------------------------------------------------------
%% Function: compile(FileName, Options) -> ok | error.
%% @doc
%%   Compiles a .jute file.
%% @end
%%--------------------------------------------------------------------
-spec compile(atom() | string(), [opt()]) -> ok | error.
%%--------------------------------------------------------------------
compile(Atom, Opts) when is_atom(Atom) -> compile(atom_to_list(Atom), Opts);
compile(File, Opts) ->
    OptsRec = #opts{src_dir = Dir} = parse_opts(Opts, #opts{}),
    FileName = case filename:extension(File) of
                   [] -> filename:join(Dir, File ++ ".jute");
                   ".jute" -> filename:join(Dir, File)
               end,
    case zk_hadoop_record_parse:file(FileName) of
        {ok, Tree} -> Tree;
        {error, {Line, Module, Message}} ->
            format_error(Module, Message, Line),
            error
    end.

%% ===================================================================
%% Internal functions.
%% ===================================================================

format_error(Module, Message, Line) ->
    io:format("Error Line ~p:~s~n", [Line, Module:format_error(Message)]).


parse_opts([], Rec) -> Rec;
parse_opts(Opts, Rec) -> lists:foldl(fun parse_opt/2, Rec, Opts).

parse_opt({dest_name, Name}, Opts) -> Opts#opts{dest_name = Name};
parse_opt({src_dir, Dir}, Opts) -> Opts#opts{src_dir = Dir};
parse_opt({dest_dir, Dir}, Opts) -> Opts#opts{dest_dir = Dir};
parse_opt({include_paths, Paths}, Opts = #opts{include_paths = Paths1}) ->
    Opts#opts{include_paths = Paths1 ++ Paths}.

