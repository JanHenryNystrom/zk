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

%% Defines

-define(COPYRIGHT_PREAMBLE,
        "2013 Jan Henry Nystrom <JanHenryNystrom@gmail.com>"
       ).

-define(LICENSE_PREAMBLE,
        "%% Licensed under the Apache License, Version 2.0 (the \"License\");\n"
        "%% you may not use this file except in compliance with the License.\n"
        "%% You may obtain a copy of the License at\n"
        "%%\n"
        "%% http://www.apache.org/licenses/LICENSE-2.0\n"
        "%%\n"
        "%% Unless required by applicable law or agreed to in writing,"
        " software\n"
        "%% distributed under the License is distributed on an \"AS IS\""
        " BASIS,\n"
        "%% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or"
        " implied.\n"
        "%% See the License for the specific language governing permissions"
        " and\n"
        "%% limitations under the License."
        ).

%% Records
-record(opts, {dest_name :: string(),
               include_paths = [] :: [string()],
               src_dir = "." :: string(),
               dest_dir = "." :: string(),
               license = ?LICENSE_PREAMBLE :: string(),
               copyright = ?COPYRIGHT_PREAMBLE :: string()
              }).

-record(attr, {type ::atom(),
               new_name :: string(),
               id :: reference()
              }).

-define(TYPE_PREAMBLE,
        "%% Types\n\n"
        "%% Primitive\n"
        "-type int()     :: integer() %% :32/integer-big-signed\n"
        "-type long()    :: integer() %% :64/integer-big-signed\n"
        "-type float()   :: float()   %% :32/float\n"
        "-type double()  :: float()   %% :64/float\n"
        "-type ustring() :: binary()  %% :X/bytes in unicode\n"
        "-type buffer()  :: binary()  %% :X/bytes"
        ).

%% Types
-type opt() :: {dest_name, string()} | {include_paths, [string()]} |
               {src_dir, string()} | {dest_dir, string()} |
               {license, string()} | {copyright, string}.

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
    OptsRec =
        case parse_opts(Opts, #opts{}) of
            OptsRec0 = #opts{dest_name = undefined} ->
                OptsRec0#opts{dest_name = filename:basename(File)};
            OptsRec0 ->
                OptsRec0
        end,
    do_compile(File, OptsRec).

%% ===================================================================
%% Internal functions.
%% ===================================================================

do_compile(File, Opts) ->
    chain({ok, File}, Opts,
          [fun read_file/2,
           fun scan/2,
           fun parse/2,
           fun analyse/2,
           fun rename/2,
           fun gen/2
          ]).

chain(Result, _, []) -> Result;
chain({ok, Previous}, Opts, [Fun | T]) -> chain(Fun(Previous, Opts), Opts, T);
chain(Error, _, _) -> {error, Error}.

gen(File, Opts = #opts{dest_name = Name}) when is_atom(Name) ->
    gen(File, Opts#opts{dest_name = atom_to_list(Name)});
gen(#file{modules = Modules, uses = Uses}, Opts) ->
    #opts{dest_name = Name, dest_dir = Dir} = Opts,
    HrlFile = filename:join(Dir, Name ++ ".hrl"),
    {ok, HrlStream} = file:open(HrlFile, [write]),
    gen(hrl, [preamble, Uses | Modules], HrlStream, Opts),
    ok.

gen(_, [], Stream, _) -> file:close(Stream);
gen(hrl, [preamble, Uses | Modules], Stream, Opts) ->
    #opts{copyright = Copyright, license = License} = Opts,
    io:format(Stream, "%%~60c~n%% Copyright ~s~n", [$=, Copyright]),
    io:format(Stream, "%%~n~s~n%%~n%%~60c~n~n", [License, $=]),
    io:format(Stream, "%%~40c~n~s ~p~n%% ~s~n%%~40c~n~n",
              [$-, "%% This module was generated by", ?MODULE,
               "Copyright " ++ ?COPYRIGHT_PREAMBLE, $-]),
    io:format(Stream, "~s~n~n", [?TYPE_PREAMBLE]),
    io:format(Stream, "%% Generated~n", []),
    [gen_type(Use, Stream) || Use <- Uses],
    io:format(Stream, "~n", []),
    gen(hrl, Modules, Stream, Opts);
gen(erl, [preamble, _Uses | Modules], Stream, Opts) ->
    gen(erl, Modules, Stream, Opts);
gen(Type, [H | T], Stream, Opts) ->
    gen_module(Type, H, Stream),
    gen(Type, T, Stream, Opts).

gen_type(Type, Stream) ->
    io:format(Stream, "-type ~p() :: #~p{}.~n", [Type, Type]).


gen_module(Type, #module{name = Name, records = Records}, Stream) ->
    io:format(Stream, "%%~40c~n%% Module ~s~n%%~40c~n", [$-, Name, $-]),
    [gen_record(Type, Record, Stream) || Record <- Records],
    io:format(Stream, "%%~40c~n%% Module ~s~n%%~40c~n~n", [$-, Name, $-]).

gen_record(hrl, #record{name = Name, fields = Fields}, Stream) ->
    io:format(Stream, "-record(~s,~n~8c{~n", [Name, $ ]),
    gen_fields(hrl, Fields, Stream),
    io:format(Stream, "~8c}).~n", [$ ]).

gen_fields(Type, [H], Stream) ->
    gen_field(Type, H, Stream),
    io:format(Stream, "~n", []);
gen_fields(Type, [H | T], Stream) ->
    gen_field(Type, H, Stream),
    io:format(Stream, ",~n", []),
    gen_fields(Type, T, Stream).

gen_field(hrl, #field{name = Name, type = Type}, Stream) ->
    io:format(Stream, "~10c~s :: ", [$ , join([Name], [])]),
    gen_type(hrl, Type, Stream).

gen_type(hrl, #vector{type = Type}, Stream) ->
    io:format(Stream, "[", []),
    gen_type(hrl, Type, Stream),
    io:format(Stream, "]", []);
gen_type(hrl, Type, Stream) ->
    io:format(Stream, "~p()", [Type]).

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

analyse(File = #file{includes = [], modules = Modules, names = Names}, _) ->
    {ok, File#file{names = lists:foldl(fun analyse_module/2, Names, Modules)}}.

analyse_module(#module{name = Name, records = Recs, id = Id}, Names) ->
    Value = value(Name),
    case dict:is_key(Value, Names) of
        true ->
            exit({duplicate_name, Value, line(Name)});
        false ->
            Names0 = dict:store(module,
                                Name,
                                dict:store(Value,
                                           #attr{type = module, id = Id},
                                           Names)),
            Names1 = lists:foldl(fun analyse_record/2, Names0, Recs),
            dict:erase(module, Names1)
    end.

analyse_record(#record{name = Name, line = Line, id = Id}, Names) ->
    Module = dict:fetch(module, Names),
    FullName = fullname(Module, Name),
    case dict:is_key(FullName, Names) of
        true ->
            exit({duplicate_name, Name, Line});
        false ->
            dict:store(FullName, #attr{type = record, id = Id}, Names)
    end.

rename(File = #file{includes = [], modules = Modules, names = Names}, _) ->
    Shrunk = shrink(longest_prefix(Names), Names),
    IdList = [{Id, N} ||
                 {_, #attr{id = Id, new_name = N}} <- dict:to_list(Shrunk)],
    {Modules1, Uses} =
        lists:unzip([rename(Module, Shrunk, IdList, none) ||
                        Module <- Modules]),
    {ok, File#file{modules = Modules1, uses=lists:usort(lists:flatten(Uses))}}.

rename(Module = #module{name = Name, id=Id, records=Recs}, Names, IdList, _) ->
    {_, NewName} = lists:keyfind(Id, 1, IdList),
    {Recs1, Uses} =
        lists:unzip([rename(Rec, Names, IdList, Name) || Rec <- Recs]),
    {Module#module{name = NewName, records = Recs1}, Uses};
rename(Rec = #record{id = Id, fields = Fields}, Names, IdList, Module) ->
    {_, NewName} = lists:keyfind(Id, 1, IdList),
    {Fields1, Uses} =
        lists:unzip([rename(Field, Names, IdList, Module) || Field <- Fields]),
    {Rec#record{name = NewName, fields = Fields1}, Uses};
rename(Field = #field{name = Name, type = Type}, Names, IdList, Module) ->
    {NewType, Uses} = rename(Type, Names, IdList, Module),
    {Field#field{name = value(Name), type = NewType}, Uses};
rename(Vector = #vector{type = Type}, Names, IdList, Module) ->
    {NewType, Uses} = rename(Type, Names, IdList, Module),
    {Vector#vector{type = NewType}, Uses};
rename(Map = #map{key = Key, value = Value}, Names, IdList, Module) ->
    {NewKey, Uses1} = rename(Key, Names, IdList, Module),
    {NewValue, Uses2} = rename(Value, Names, IdList, Module),
    {Map#map{key = NewKey, value = NewValue}, Uses1 ++ Uses2};
rename(#name{type = scoped, value = [Value]}, Names, _, Module) ->
    Name = (dict:fetch(value(Module) ++ [Value], Names))#attr.new_name,
    {Name, [Name]};
rename(#name{type = scoped, value = Value}, Names, _, _) ->
    Name = (dict:fetch(Value, Names))#attr.new_name,
    {Name, [Name]};
rename(#name{value = [Value]}, _, _, _) ->
    {Value, []};
rename(Element, _, _, _) ->
    {Element, []}.

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

remove_fuse([], Key) -> list_to_atom(join(Key, []));
remove_fuse([H | T], [H | Key]) -> remove_fuse(T, Key).

join([], Acc) -> lists:reverse(Acc);
join([H | T], Acc) ->
    case atom_to_list(H) of
        [H1 | T1] when H1 >= $a, H1 =< $z -> join_l(T1, T, [H1 | Acc]);
        [H1 | T1] when H1 >= $A, H1 =< $Z -> join_u(i, T1, T, [down(H1) | Acc]);
        [H1 | T1] -> join_l(T1, T, [H1 | Acc])
    end.

join_l([], [], Acc) -> lists:reverse(Acc);
join_l([], Key, Acc) -> join(Key, [$_ | Acc]);
join_l([H | T], R, Acc) when H >= $a, H =< $z -> join_l(T, R, [H | Acc]);
join_l([H | T], R, Acc) when H >= $A, H =< $Z ->
    join_u(i, T, R, [down(H), $_| Acc]);
join_l([H | T], R, Acc) ->
    join_l(T, R, [H, $_| Acc]).

join_u(_, [], [], Acc) -> lists:reverse(Acc);
join_u(_, [], Key, Acc) -> join(Key, [$_ | Acc]);
join_u(i, [H | T], R, Acc) when H >= $a, H =< $z ->
    join_u(l, T, R, [H | Acc]);
join_u(i, [H | T], R, Acc) when H >= $A, H =< $Z ->
    join_u(u, T, R, [down(H) | Acc]);
join_u(l, [H | T], R, Acc) when H >= $a, H =< $z ->
    join_l(T, R, [H | Acc]);
join_u(l, [H | T], R, Acc) when H >= $A, H =< $Z ->
    join_u(i, T, R, [down(H), $_ | Acc]);
join_u(u, [H | T], R, [H1 | Acc]) when H >= $a, H =< $z ->
    join_l(T, R, [H, H1, $_| Acc]);
join_u(u, [H], R, Acc) when H >= $A, H =< $Z ->
    join(R, [down(H) | Acc]);
join_u(u, [H | T], R, Acc) when H >= $A, H =< $Z ->
    join_u(u, T, R, [down(H) | Acc]);
join_u(_, [H | T], R, Acc) ->
    join_l(T, R, [H, $_| Acc]).

down(U) -> U + 32.

but_last([]) -> [];
but_last([H, _]) -> [H];
but_last([_]) -> [];
but_last([H | T]) -> [H | but_last(T)].

%% format_error(Module, Message, Line) ->
%%     io:format("Error Line ~p:~s~n", [Line, Module:format_error(Message)]).

parse_opts([], Rec) -> Rec;
parse_opts(Opts, Rec) -> lists:foldl(fun parse_opt/2, Rec, Opts).

parse_opt({dest_name, Name}, Opts) -> Opts#opts{dest_name = Name};
parse_opt({src_dir, Dir}, Opts) -> Opts#opts{src_dir = Dir};
parse_opt({dest_dir, Dir}, Opts) -> Opts#opts{dest_dir = Dir};
parse_opt({include_paths, Paths}, Opts = #opts{include_paths = Paths1}) ->
    Opts#opts{include_paths = Paths1 ++ Paths};
parse_opt({license, License}, Opts) ->
    Opts#opts{license = License};
parse_opt({copyright, Copyright}, Opts) ->
    Opts#opts{copyright = Copyright}.



