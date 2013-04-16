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
-include_lib("zk/src/zk_hadoop_record.hrl").

%% Records
-record(opts, {dest_name :: string(),
               include_paths = [] :: [string()],
               src_dir = "." :: string(),
               dest_dir = "." :: string()}).

-record(attr, {type ::atom(),
               new_name :: string()
              }).

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
compile(File, Opts) -> do_compile(File, parse_opts(Opts, #opts{})).

%% ===================================================================
%% Internal functions.
%% ===================================================================

do_compile(File, Opts) ->
    chain({ok, File}, Opts,
          [fun read_file/2,
           fun scan/2,
           fun parse/2,
           fun analyse/2]).

chain(Result, _, []) -> Result;
chain({ok, Previous}, Opts, [Fun | T]) -> chain(Fun(Previous, Opts), Opts, T);
chain(Error, _, _) -> Error.

read_file(File, #opts{src_dir = Dir}) ->
    FileName = case filename:extension(File) of
                   [] -> filename:join(Dir, File ++ ".jute");
                   ".jute" -> filename:join(Dir, File)
               end,
    file:read_file(FileName).

scan(Bin, _) ->
    case zk_hadoop_record_scan:string(binary_to_list(Bin)) of
        {ok, Tokens, _} -> {ok, Tokens};
        Error -> Error
    end.

parse(Tokens, _) -> zk_hadoop_record_parse:parse(Tokens).

analyse(Tree, Opts) -> analyse(Tree, dict:new(), Opts).

analyse(#file{includes = [], modules = Modules}, Names, _) ->
    Names1 = lists:foldl(fun analyse_module/2, Names, Modules),
    [rename(Module, shrink(longest_prefix(Names1), Names1)) ||
        Module <- Modules].

rename(Module, _) -> Module.

analyse_module(#module{name = Name, records = Recs}, Names) ->
    Value = value(Name),
    case dict:is_key(Value, Names) of
        true ->
            exit({duplicate_name, Value, line(Name)});
        false ->
            Names0 = dict:store(module,
                                Name,
                                dict:store(Value,
                                           #attr{type = module},
                                           Names)),
            Names1 = lists:foldl(fun analyse_record/2, Names0, Recs),
            dict:erase(module, Names1)
    end.

analyse_record(#record{name = Name, line = Line}, Names) ->
    Module = dict:fetch(module, Names),
    FullName = fullname(Module, Name),
    case dict:is_key(FullName, Names) of
        true ->
            exit({duplicate_name, Name, Line});
        false ->
            dict:store(FullName, #attr{type = record}, Names)
    end.

line(#name{line = Line}) -> Line.

value(#name{value = Value}) -> Value.

fullname(#name{type = simple, value  = Value1}, #name{value = Value2}) ->
    [Value1, Value2];
fullname(#name{value  = Value1}, #name{value = Value2}) ->
    Value1 ++ [Value2].

longest_prefix(Names) ->
    Modules = [First | _] =
        dict:fold(fun(K, V, Acc) ->
                          case type(V) of
                              module -> [K | Acc];
                              _ -> Acc
                          end
                  end,
                  [],
                  Names),
    lists:foldl(fun longest_prefix/2, but_last(First), Modules).

type(#attr{type = Type}) -> Type;
type(_) -> none.

longest_prefix([_], _) -> [];
longest_prefix([H | T], [H | T1]) -> [H | longest_prefix(T, T1)];
longest_prefix(_, _) -> [].

shrink([], Names) -> Names;
shrink(Prefix, Names) ->
    dict:fold(fun(K, V, A) ->  shrink(Prefix, K, V, A) end, Names, Names).

shrink(Prefix, K, V = #attr{}, Names) ->
    dict:store(K, V#attr{new_name = remove_fuse(Prefix, K)}, Names);
shrink(_, _, _, Names) -> Names.

remove_fuse([], Key) ->
    list_to_atom(string:join([atom_to_list(K) || K <- Key], "_"));
remove_fuse([H | T], [H | Key]) ->
    remove_fuse(T, Key).


but_last([]) -> [];
but_last([H, _]) -> [H];
but_last([_]) -> [];
but_last([H | T]) -> [H | but_last(T)].

format_error(Module, Message, Line) ->
    io:format("Error Line ~p:~s~n", [Line, Module:format_error(Message)]).

parse_opts([], Rec) -> Rec;
parse_opts(Opts, Rec) -> lists:foldl(fun parse_opt/2, Rec, Opts).

parse_opt({dest_name, Name}, Opts) -> Opts#opts{dest_name = Name};
parse_opt({src_dir, Dir}, Opts) -> Opts#opts{src_dir = Dir};
parse_opt({dest_dir, Dir}, Opts) -> Opts#opts{dest_dir = Dir};
parse_opt({include_paths, Paths}, Opts = #opts{include_paths = Paths1}) ->
    Opts#opts{include_paths = Paths1 ++ Paths}.

