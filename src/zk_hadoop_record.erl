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

-define(TYPE_PREAMBLE,
        "%% Primitive\n"
        "-type int()     :: integer(). %% :32/integer-big-signed\n"
        "-type long()    :: integer(). %% :64/integer-big-signed\n"
        "-type double()  :: float().   %% :64/float\n"
        "-type ustring() :: binary().  %% :X/bytes in utf8\n"
        "-type buffer()  :: binary().  %% :X/bytes"
        ).

-define(ERL_PREAMBLE,
        "%% Types\n"
        "-type opt() :: binary. %% Encode generates binaries\n"
        "-type lazy_binary() :: lazy:data(binary()).\n\n"
        "%% Records\n"
        "-record(opts, {return_type = iolist :: iolist | binary}).\n\n"
        "%% Defines\n"
        "-define(LAZY_WAIT, 1000).\n\n"
        "%% ===========================================================\n"
        "%% API functions.\n"
        "%% ===========================================================\n"
        "\n"
        "%%------------------------------------------------------------\n"
        "%% Function: encode(Term) -> HadoopRecord.\n"
        "%% @doc\n"
        "%%   Encodes the structured Erlang term as an iolist.\n"
        "%%   Equivalent of encode(Term, []) -> HadoopRecord.\n"
        "%% @end\n"
        "%%------------------------------------------------------------\n"
        "-spec encode(_) -> iolist().\n"
        "%%------------------------------------------------------------\n"
        "encode(Term) -> encode(Term, []).\n"
        "\n"
        "%%------------------------------------------------------------\n"
        "%% Function: encode(Term, Options) -> HadoopRecord.\n"
        "%% @doc\n"
        "%%   Encodes the structured Erlang term as an iolist or binary.\n"
        "%%   Encode will give an exception if the erlang term is not"
        " well formed.\n"
        "%%   Options are:\n"
        "%%     binary -> a binary is returned\n"
        "%%     iolist -> a iolist is returned\n"
        "%% @end\n"
        "%%------------------------------------------------------------\n"
        "-spec encode(_, [opt()]) -> iolist() | binary().\n"
        "%%------------------------------------------------------------\n"
        "encode(Term, Opts) ->\n"
        "    case (parse_opts(Opts, #opts{}))#opts.return_type of\n"
        "        iolist -> do_encode(Term);\n"
        "        binary -> iolist_to_binary(do_encode(Term))\n"
        "    end.\n"
        "\n"
        "%%------------------------------------------------------------\n"
        "%% Function: decode(Type, HadoopRecord, Lazy) -> Term.\n"
        "%% @doc\n"
        "%%   Decodes the binary into a structured Erlang term.\n"
        "%% @end\n"
        "%%------------------------------------------------------------\n"
        "-spec decode(atom(), binary(), lazy_binary()) ->\n"
        "          {_, binary(), lazy_binary()}.\n"
        "%%------------------------------------------------------------\n"
        "decode(Type, Binary, Lazy) -> do_decode(Type, Binary, Lazy)."
       ).

-define(BASE_TYPES, [byte, boolean, int, long, float, double, ustring, buffer]).

-define(ERL_ENCODE_POSTAMBLE,
        "do_encode(Map = [{_, _} | _]) ->\n"
        "    encode_int(length(Map)),\n"
        "    [begin do_encode(Key),  do_encode(Value) end ||"
        " {Key, Value} <- Map];\n"
        "do_encode(List) when is_list(List) ->\n"
        "    encode_int(length(List)),\n"
        "    [do_encode(Elt) || Elt <- List].").

-define(ERL_ENCODE_MAP,
        [{byte, "encode_byte(Byte) -> <<Byte>>.\n\n"},
         {boolean,
          "encode_boolean(true) -> <<1>>;\n"
          "encode_boolean(false) -> <<0>>.\n\n"},
         {int,
          "encode_int(Integer) when Integer >= -120, Integer < 128 ->"
          "<<Integer/signed>>;\n"
          "encode_int(I) -> I.\n\n"},
         {long,
          "encode_long(Integer) when Integer >= -120, Integer < 128 ->"
          " <<Integer/signed>>;\n"
          "encode_long(I) -> I.\n\n"},
         {float, "encode_float(Float) -> <<Float:32/float>>.\n\n"},
         {double, "encode_double(Float) -> <<Float:64/float>>.\n\n"},
         {ustring,
          "encode_ustring(String) ->"
          " [encode_int(byte_size(String)), String].\n\n"},
         {buffer,
          "encode_buffer(Buffer) -> [encode_int(byte_size(Buffer)), Buffer]."}
        ]).

-define(ERL_DECODE_POSTAMBLE,
        "do_decode({Key, Value}, Bin, Lazy) ->\n"
        "    {Size, Bin1, Lazy1} = decode_int(Bin, Lazy),\n"
        "    do_decode_map(Size, Key, Value, Bin1, Lazy1);\n"
        "do_decode(Type, Bin, Lazy) when is_list(Type) ->\n"
        "    {Size, Bin1, Lazy1} = decode_int(Bin, Lazy),\n"
        "    do_decode_vector(Size, Type, Bin1, Lazy1).").


-define(ERL_DECODE_MAP,
        [{byte,
          "decode_byte(<<Byte, T/binary>>, Lazy) -> {<<Byte>>, T, Lazy};\n"
          "decode_byte(<<>>, Lazy) ->\n"
          "    case Lazy(?LAZY_WAIT) of\n"
          "        {<<>>, _} -> exit(truncated_byte);\n"
          "        {Bin, Lazy1} -> decode_byte(Bin, Lazy1)\n"
          "    end.\n\n" },
         {boolean,
          "decode_boolean(<<0/signed, T/binary>>, Lazy) -> {false, T, Lazy};\n"
          "decode_boolean(<<_, T/binary>>, Lazy) -> {true, T, Lazy};\n"
          "decode_boolean(<<>>, Lazy) ->\n"
          "    case Lazy(?LAZY_WAIT) of\n"
          "        {<<>>, _} -> exit(truncated_boolean);\n"
          "        {Bin, Lazy1} -> decode_boolean(Bin, Lazy1)\n"
          "    end.\n\n"},
         {int,
          "decode_int(<<I/signed, T/binary>>, Lazy) when I >= -120, "
          "I < 128 ->\n"
          "    {I, T, Lazy};\n"
          "decode_int(<<S/signed, T/binary>>, Lazy)\n"
          "  when S > -125, byte_size(T) >= -(S + 120) ->\n"
          "    Size = -(S + 120) * 8,\n"
          "    <<I:Size/signed, T1/binary>> = T,\n"
          "    {I, T1, Lazy};\n"
          "decode_int(<<S/signed, T/binary>>, Lazy) when S > -125 ->\n"
          "    Size = -(S + 120) * 8,\n"
          "    case Lazy(?LAZY_WAIT) of\n"
          "        {Bin, Lazy1} when byte_size(T) + byte_size(Bin) >= Size ->\n"
          "            decode_int(<<S, T/binary, Bin/binary>>, Lazy1);\n"
          "        _ ->\n"
          "            exit(truncated_int)\n"
          "    end;\n"
          "decode_int(<<>>, Lazy) ->\n"
          "    {Bin1, Lazy1} = Lazy(?LAZY_WAIT),\n"
          "    decode_int(Bin1, Lazy1);\n"
          "decode_int(_, _) ->\n"
          "    exit(truncated_int).\n\n"},
         {long,
          "decode_long(<<I/signed, T/binary>>, Lazy) when I >= -120, "
          "I < 128 ->\n"
          "    {I, T, Lazy};\n"
          "decode_long(<<S/signed, T/binary>>, Lazy)\n"
          "  when S > -129, byte_size(T) >= -(S + 120) ->\n"
          "    Size = -(S + 120) * 8,\n"
          "    <<I:Size/signed, T1/binary>> = T,\n"
          "    {I, T1, Lazy};\n"
          "decode_long(<<S/signed, T/binary>>, Lazy) ->\n"
          "    Size = -(S + 120) * 8,\n"
          "    case Lazy(?LAZY_WAIT) of\n"
          "        {Bin, Lazy1} when byte_size(T) + byte_size(Bin) >= Size ->\n"
          "            decode_long(<<S, T/binary, Bin/binary>>, Lazy1);\n"
          "        _ ->\n"
          "            exit(truncated_long)\n"
          "    end;\n"
          "decode_long(<<>>, Lazy) ->\n"
          "    {Bin1, Lazy1} = Lazy(?LAZY_WAIT),\n"
          "    decode_long(Bin1, Lazy1);\n"
          "decode_long(_, _) ->\n"
          "    exit(truncated_long).\n\n"},
         {float,
          "decode_float(<<F/32/float, T/binary>>, Lazy) -> {F, T, Lazy};\n"
          "decode_float(Bin, Lazy) ->\n"
          "    case Lazy(?LAZY_WAIT) of\n"
          "        {Bin1, Lazy1} when byte_size(Bin) + byte_size(Bin1) "
          ">= 8 ->\n"
          "            decode_float(<<Bin/binary, Bin1/binary>>, Lazy1);\n"
          "        _ ->\n"
          "            exit(truncated_float)\n"
          "    end.\n\n"},
         {double,
          "decode_float(<<F/64/float, T/binary>>, Lazy) -> {F, T, Lazy};\n"
          "decode_float(Bin, Lazy) ->\n"
          "    case Lazy(?LAZY_WAIT) of\n"
          "        {Bin1, Lazy1} when byte_size(Bin) + byte_size(Bin1) "
          ">= 8 ->\n"
          "            decode_float(<<Bin/binary, Bin1/binary>>, Lazy1);\n"
          "        _ ->\n"
          "            exit(truncated_duoble)\n"
          "    end.\n\n"},
         {ustring,
          "decode_ustring(Bin, Lazy) ->\n"
          "    {Size, Bin1, Lazy1}  = decode_int(Bin, Lazy),\n"
          "    decode_ustring(Size, Bin1, Lazy1, <<>>).\n\n"
          "decode_ustring(0, Bin, Lazy, Acc) -> {Acc, Bin, Lazy};\n"
          "decode_ustring(N, <<H, T/binary>>, Lazy, Acc) ->\n"
          "    decode_ustring(N - 1, T, Lazy, <<Acc/binary, H>>);\n"
          "decode_ustring(N, <<>>, Lazy, Acc) ->\n"
          "    case Lazy(?LAZY_WAIT) of\n"
          "        {<<>>, _} -> exit(truncated_ustring);\n"
          "        {Bin, Lazy1} -> decode_ustring(N, Bin, Lazy1, Acc)\n"
          "    end.\n\n"},
         {buffer,
          "decode_buffer(Bin, Lazy) ->\n"
          "    {Size, Bin1, Lazy1}  = decode_int(Bin, Lazy),\n"
          "    decode_buffer(Size, Bin1, Lazy1, <<>>).\n"
          "\n"
          "decode_buffer(0, Bin, Lazy, Acc) -> {Acc, Bin, Lazy};\n"
          "decode_buffer(N, <<H, T/binary>>, Lazy, Acc) ->\n"
          "    decode_buffer(N - 1, T, Lazy, <<Acc/binary, H>>);\n"
          "decode_buffer(N, <<>>, Lazy, Acc) ->\n"
          "    case Lazy(?LAZY_WAIT) of\n"
          "        {<<>>, _} -> exit(truncated_ustring);\n"
          "        {Bin, Lazy1} -> decode_buffer(N, Bin, Lazy1, Acc)\n"
          "    end.\n\n"}
        ]).

-define(DECODE_CHAIN,
        "chain([], Binary, Lazy, Acc) -> {Acc, Binary, Lazy};\n"
        "chain([{F, Type} | T], Binary, Lazy, Acc) ->\n"
        "    {H1, Binary1, Lazy1} = F(Type, Binary, Lazy),\n"
        "    chain(T, Binary1, Lazy1, [H1 | Acc]);\n"
        "chain([F | T], Binary, Lazy, Acc) ->\n"
        "    {H1, Binary1, Lazy1} = F(Binary, Lazy),\n"
        "    chain(T, Binary1, Lazy1, [H1 | Acc])."
       ).

-define(ERL_POSTAMBLE,
        "%% ===========================================================\n"
        "%% Common parts\n"
        "%% ===========================================================\n\n"
        "parse_opts(Opts, Rec) -> lists:foldl(fun parse_opt/2, Rec, Opts).\n"
        "\n"
        "parse_opt(binary, Opts) -> Opts#opts{return_type = binary};\n"
        "parse_opt(iolist, Opts) -> Opts#opts{return_type = iolist}."
        ).

-define(CASE_DIFF, 32).
-define(BUILT_IN, [boolean, byte, int, long, float, double, ustring, buffer]).

-define(DIGIT(C), C >= $0, C =< $9).

%% Records
-record(opts, {dest_name :: string(),
               include_paths = [] :: [string()],
               src_dir = "." :: string(),
               dest_dir = "." :: string(),
               include_dir = "" :: string(),
               license = ?LICENSE_PREAMBLE :: string(),
               copyright = ?COPYRIGHT_PREAMBLE :: string()
              }).

-record(attr, {type ::atom(),
               new_name :: string(),
               id :: reference()
              }).

%% Types
-type opt() :: {dest_name, string()} | {include_paths, [string()]} |
               {src_dir, string()} | {dest_dir, string()} |
               {include_dir, string()} |
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
                Dest = filename:basename(File, filename:extension(File)),
                OptsRec0#opts{dest_name = Dest};
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

%% ===================================================================
%% Read file
%% ===================================================================

read_file(File, #opts{src_dir = Dir}) ->
    FileName = case filename:extension(File) of
                   [] -> filename:join(Dir, File ++ ".jute");
                   ".jute" -> filename:join(Dir, File)
               end,
    file:read_file(FileName).

%% ===================================================================
%%  Scan
%% ===================================================================

scan(Bin, _) ->
    case zk_hadoop_record_scan:string(binary_to_list(Bin)) of
        {ok, Tokens, _} -> {ok, Tokens};
        Error -> Error
    end.

%% ===================================================================
%% Parse
%% ===================================================================

parse(Tokens, _) -> zk_hadoop_record_parse:parse(Tokens).

%% ===================================================================
%% Analyse
%% ===================================================================

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

line(#name{line = Line}) -> Line.

fullname(#name{type = simple, value  = Value1}, #name{value = Value2}) ->
    [Value1, Value2];
fullname(#name{value  = Value1}, #name{value = Value2}) ->
    Value1 ++ [Value2].

%% ===================================================================
%% Rename
%% ===================================================================

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
    {Rec#record{name = NewName,
                fields = Fields1,
                variable = name_to_variable(NewName)},
     Uses};
rename(Field = #field{name = Name, type = Type}, Names, IdList, Module) ->
    {NewType, Uses} = rename(Type, Names, IdList, Module),
    {Field#field{name = join([value(Name)], []),
                 type = NewType,
                 variable = name_to_variable(value(Name))},
     Uses};
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
    {Element, [Element]}.

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

but_last([]) -> [];
but_last([H, _]) -> [H];
but_last([_]) -> [];
but_last([H | T]) -> [H | but_last(T)].

shrink([], Names) -> Names;
shrink(Prefix, Names) ->
    dict:fold(fun(K, V, A) ->  shrink(Prefix, K, V, A) end, Names, Names).

shrink(Prefix, K, V = #attr{}, Names) ->
    dict:store(K, V#attr{new_name = remove_fuse(Prefix, K)}, Names);
shrink(_, _, _, Names) -> Names.

remove_fuse([], Key) -> list_to_atom(join(Key, []));
remove_fuse([H | T], [H | Key]) -> remove_fuse(T, Key).

name_to_variable(Atom) -> name_to_variable(i, atom_to_list(Atom), []).

name_to_variable(_, [], Acc) -> lists:reverse(Acc);
name_to_variable(_, [$_ | T], Acc) -> name_to_variable(i, T, Acc);
name_to_variable(X, [H | T], Acc) when ?DIGIT(H) -> name_to_variable(X, T, Acc);
name_to_variable(i, [H | T], Acc) -> name_to_variable(n, T, [up(H) | Acc]);
name_to_variable(n, [H | T], Acc) -> name_to_variable(n, T, [H | Acc]).

%% ===================================================================
%% Gen
%% ===================================================================

gen(File, Opts = #opts{dest_name = Name}) when is_atom(Name) ->
    gen(File, Opts#opts{dest_name = atom_to_list(Name)});
gen(#file{modules = Modules, uses = Uses}, Opts) ->
    #opts{dest_name = Name, dest_dir = Dir} = Opts,
    HrlFile = hrl_file(Opts),
    {ok, HrlStream} = file:open(HrlFile, [write]),
    gen(hrl, [preamble, Uses | Modules], HrlStream, Opts),
    file:close(HrlStream),
    ErlFile = filename:join(Dir, Name ++ ".erl"),
    {ok, ErlStream} = file:open(ErlFile, [write]),
    gen(erl, [preamble, Uses | Modules], ErlStream, Opts),
    file:close(ErlStream),
    ok.

gen(hrl, [preamble, Uses | Modules], Stream, Opts) ->
    #opts{copyright = Copyright, license = License} = Opts,
    io:format(Stream, "%%~60c~n%% Copyright ~s~n", [$=, Copyright]),
    io:format(Stream, "%%~n~s~n%%~n%%~60c~n~n", [License, $=]),
    io:format(Stream, "%%~60c~n~s ~p~n%% ~s~n%%~60c~n~n",
              [$-, "%% This module was generated by", ?MODULE,
               "Copyright " ++ ?COPYRIGHT_PREAMBLE, $-]),
    io:format(Stream, "%%~60c~n%% Records~n%%~60c~n~n", [$=, $=]),
    [gen_module(Module, Stream) || Module <- Modules],
    io:format(Stream, "%%~60c~n%% Types~n%%~60c~n~n", [$=, $=]),
    io:format(Stream, "~s~n~n", [?TYPE_PREAMBLE]),
    io:format(Stream, "%% Generated~n", []),
    [gen_type(Use, Stream) || Use <- Uses -- ?BUILT_IN],
    io:format(Stream, "~n", []);
gen(erl, [preamble, Uses | Modules], Stream, Opts) ->
    #opts{dest_name = Name, copyright = Copyright, license = License} = Opts,
    io:format(Stream, "%%~60c~n%% Copyright ~s~n", [$=, Copyright]),
    io:format(Stream, "%%~n~s~n%%~n%%~60c~n~n", [License, $=]),
    io:format(Stream, "%%~60c~n~s ~p~n%% ~s~s~n%%~60c~n",
              [$-, "%% This module was generated by", ?MODULE,
               "Copyright ", ?COPYRIGHT_PREAMBLE, $-]),
    io:format(Stream, "-module(~s).~n-copyright('~s').~n~n",
              [Name, ?COPYRIGHT_PREAMBLE]),
    io:format(Stream,
              "%% API~n-export([encode/1, encode/2, decode/3]).~n~n",
              []),
    io:format(Stream, "%% Includes~n-include(\"~s\").~n~n", [hrl_file(Opts)]),
    io:format(Stream, "~s~n~n", [?ERL_PREAMBLE]),
    io:format(Stream, "%%~60c~n%% Internal functions~n%%~60c~n~n", [$=, $=]),
    io:format(Stream, "%%~60c~n%% Encoding~n%%~60c~n~n", [$-, $-]),
    Records =
        [Record || #module{records=Records} <- Modules, Record <- Records],
    spaced(Records, fun gen_do_encode/2, ";\n", Stream),
    io:format(Stream, ";~n", []),
    [case lists:member(Type, Uses) of
         true ->
             io:format(Stream, "do_encode({~p, ~s}) ->~n    encode_~p(~s);~n",
                       [Type,
                        name_to_variable(Type),
                        Type,
                        name_to_variable(Type)]);
         false -> ok
     end || Type <- ?BASE_TYPES],
    io:format(Stream, "~s~n~n", [?ERL_ENCODE_POSTAMBLE]),
    [case lists:member(Type, Uses) of
         true -> io:format(Stream, "~s", [Format]);
         false -> ok
     end || {Type, Format} <- ?ERL_ENCODE_MAP],
    io:format(Stream, "~n~n%%~60c~n%% Decoding~n%%~60c~n~n", [$-, $-]),
    spaced(Records, fun gen_do_decode/2, ";\n", Stream),
    io:format(Stream, ";~n", []),
    [case lists:member(Type, Uses) of
         true ->
             io:format(Stream,
                       "do_decode(~p, Bin, Lazy) ->~n"
                       "    decode_~p(Bin, Lazy);~n",
                       [Type, Type]);
         false -> ok
     end || Type <- ?BASE_TYPES],
    io:format(Stream, "~s~n~n", [?ERL_DECODE_POSTAMBLE]),
    [case lists:member(Type, Uses) of
         true -> io:format(Stream, "~s", [Format]);
         false -> ok
     end || {Type, Format} <- ?ERL_DECODE_MAP],
    io:format(Stream, "~s~n~n", [?DECODE_CHAIN]),
    io:format(Stream, "~s~n", [?ERL_POSTAMBLE]).

gen_module(#module{name = Name, records = Records}, Stream) ->
    io:format(Stream, "%%~60c~n%% Module ~s~n%%~60c~n", [$-, Name, $-]),
    [gen_record(Record, Stream) || Record <- Records],
    io:format(Stream, "~n", []).

gen_record(#record{name = Name, fields = Fields}, Stream) ->
    io:format(Stream, "-record(~s,~n~8c{~n", [Name, $ ]),
    spaced(Fields, fun gen_field/2, ",\n", Stream),
    io:format(Stream, "~n~8c}).~n", [$ ]).

gen_field(#field{name = Name, type = Type}, Stream) ->
    io:format(Stream, "~10c~s :: ", [$ , Name]),
    gen_field_type(Type, Stream).

gen_field_type(#vector{type = Type}, Stream) ->
    io:format(Stream, "[", []),
    gen_field_type(Type, Stream),
    io:format(Stream, "]", []);
gen_field_type(#map{key = Key, value = Value}, Stream) ->
    io:format(Stream, "[{", []),
    gen_field_type(Key, Stream),
    io:format(Stream, ", ", []),
    gen_field_type(Value, Stream),
    io:format(Stream, "}]", []);
gen_field_type(Type, Stream) ->
    io:format(Stream, "~p()", [Type]).

gen_type(Type, Stream) ->
    io:format(Stream, "-type ~p() :: #~p{}.~n", [Type, Type]).

%%------------------------------------------------------------
%% Encoding
%%------------------------------------------------------------

gen_do_encode(#record{name = Name, fields = Fields, variable = Var}, Stream) ->
    io:format(Stream, "do_encode(~s = #~s{}) ->~n", [Var, Name]),
    io:format(Stream, "    #~s{", [Name]),
    spaced(Fields, fun gen_do_encode_fields_match/2, ",", Stream),
    io:format(Stream, "~n      } = ~s,~n", [Var]),
    io:format(Stream, "    [", []),
    spaced(Fields, fun gen_do_encode_fields/2, ",\n     ", Stream),
    io:format(Stream, "]", []).

gen_do_encode_fields_match(#field{name = Name, variable = Var}, Stream) ->
    io:format(Stream, "~n       ~s = ~s", [Name, Var]).

gen_do_encode_fields(#field{variable = Var, type = Type}, Stream) ->
    io:format(Stream, "~s", [gen_do_encode_type(Type, Var)]).

gen_do_encode_type(Type, Var) when is_atom(Type) ->
    case lists:member(Type, ?BUILT_IN) of
        true -> io_lib:format("encode_~p(~s)", [Type, Var]);
        false -> io_lib:format("do_encode(~s)", [Var])
    end;
gen_do_encode_type(#vector{type = Type}, Var) ->
    io_lib:format(
      "encode_int(length(~s)),~n     [~s || E <- ~s]",
      [Var, gen_do_encode_type(Type, "E"), Var]);
gen_do_encode_type(#map{key = Key, value = Value}, Var) ->
    io_lib:format(
      "encode_int(length(~s)),~n     [[~s, ~s] || {Key, Value} <- ~s]",
      [Var,
       gen_do_encode_type(Key, "K"),
       gen_do_encode_type(Value, "Value"),
       Var]).

%%------------------------------------------------------------
%% Decoding
%%------------------------------------------------------------

gen_do_decode(#record{name = Name, fields = [Field]}, Stream) ->
    #field{name = FieldName, variable = FieldVar} = Field,
    io:format(Stream, "do_decode(~s, Bin, Lazy) ->~n", [Name]),
    io:format(Stream, "    {[~s], Bin1, Lazy1} =~n        chain([", [FieldVar]),
    spaced([Field], fun gen_decode_chain/2, ",\n               ", Stream),
    io:format(Stream, "], Bin, Lazy, []),~n", []),
    io:format(Stream,
              "    {#~s{~s = ~s}, Bin1, Lazy1}",
              [Name, FieldName, FieldVar]);
gen_do_decode(#record{name = Name, fields = Fields, variable = Var}, Stream) ->
    io:format(Stream, "do_decode(~s, Bin, Lazy) ->~n", [Name]),
    io:format(Stream, "    {Result, Bin1, Lazy1} =~n", []),
    io:format(Stream, "        chain([", []),
    spaced(Fields, fun gen_decode_chain/2, ",\n               ", Stream),
    io:format(Stream, "],~n               Bin, Lazy, []),~n    [", []),
    spaced(lists:reverse(Fields), fun gen_do_decode_field/2, ",\n     ",Stream),
    io:format(Stream, "] = Result,~n", []),
    io:format(Stream, "    ~s =~n        #~s{", [Var, Name]),
    spaced(Fields, fun gen_do_decode_field_match/2, ",", Stream),
    io:format(Stream, "~n          },~n    {~s, Bin1, Lazy1}", [Var]).

gen_decode_chain(#field{type = Type}, Stream) when is_atom(Type) ->
    case lists:member(Type, ?BUILT_IN) of
        true -> io:format(Stream, "fun decode_~p/2", [Type]);
        false -> io:format(Stream, "{fun do_decode/3, ~s}", [Type])
    end;
gen_decode_chain(#field{type = #vector{type = Type}}, Stream) ->
    io:format(Stream, "{fun do_decode_vector/3, ~s}", [Type]);
gen_decode_chain(#field{type = #map{key = Key, value = Value}}, Stream) ->
    io:format(Stream, "{fun do_decode_map/3, ~s}", [{Key, Value}]).

gen_do_decode_field_match(#field{name = Name, variable = Var}, Stream) ->
    io:format(Stream, "~n           ~s = ~s", [Name, Var]).

gen_do_decode_field(#field{variable = Var}, Stream) ->
    io:format(Stream, "~s", [Var]).

hrl_file(#opts{dest_name = Name, dest_dir = Dir, include_dir = IDir}) ->
    case IDir of
        "" -> filename:join(Dir, Name ++ ".hrl");
        _ -> filename:join(IDir, Name ++ ".hrl")
    end.

up(D) -> D - ?CASE_DIFF.

%% ===================================================================
%% Common parts
%% ===================================================================

value(#name{value = Value}) -> Value.

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

down(U) -> U + ?CASE_DIFF.

spaced([], _, _, _) -> ok;
spaced([H], Fun, _, Stream) -> Fun(H, Stream);
spaced([H | T], Fun, Spacing, Stream) ->
    Fun(H, Stream),
    io:format(Stream, "~s", [Spacing]),
    spaced(T, Fun, Spacing, Stream).

%% format_error(Module, Message, Line) ->
%%     io:format("Error Line ~p:~s~n", [Line, Module:format_error(Message)]).

parse_opts([], Rec) -> Rec;
parse_opts(Opts, Rec) -> lists:foldl(fun parse_opt/2, Rec, Opts).

parse_opt({dest_name, Name}, Opts) -> Opts#opts{dest_name = Name};
parse_opt({src_dir, Dir}, Opts) -> Opts#opts{src_dir = Dir};
parse_opt({dest_dir, Dir}, Opts) -> Opts#opts{dest_dir = Dir};
parse_opt({include_dir, Dir}, Opts) -> Opts#opts{include_dir = Dir};
parse_opt({license, License}, Opts) -> Opts#opts{license = License};
parse_opt({copyright, Copyright}, Opts) -> Opts#opts{copyright = Copyright};
parse_opt({include_paths, Paths}, Opts = #opts{include_paths = Paths1}) ->
    Opts#opts{include_paths = Paths1 ++ Paths}.
