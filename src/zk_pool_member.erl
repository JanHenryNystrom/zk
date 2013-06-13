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
%%% A member of a zk connection pool.
%%% @end
%%%
%% @author Jan Henry Nystrom <JanHenryNystrom@gmail.com>
%% @copyright (C) 2013, Jan Henry Nystrom <JanHenryNystrom@gmail.com>
%%%-------------------------------------------------------------------
-module(zk_pool_member).
-copyright('Jan Henry Nystrom <JanHenryNystrom@gmail.com>').

-behaviour(jhn_fsm).

%% Management API
-export([start/2]).

%% Testing API
-export([stop/1]).

%% API
-export([request/2]).

%% jhn_fsm callbacks
-export([init/1,
         handle_event/3, handle_msg/3,
         terminate/3, code_change/4
        ]).

%% jhn_fsm state callbacks
-export([idle/2, connected/2]).


%% Includes
-include_lib("zk/src/zk.hrl").

%% Records
-record(state,{seq :: pos_integer(),
               name :: atom(),
               timeout :: timeout(),
               size :: pos_integer(),
               hosts :: [{string(), non_neg_integer()}],
               no :: pos_integer(),
               socket :: undefined | inets:socket(),
               session_id = 0 :: integer(),
               passwd  = <<0:128>> :: binary()
              }).

%% Defines
-define(SOCK_OPTS, [binary, {packet, 4}]).

%% ===================================================================
%% Management API
%% ===================================================================

%%--------------------------------------------------------------------
%% Function: start_link(Number, PoolSpec) -> {ok, Pid}
%% @doc
%%   Starts the pool member.
%% @end
%%--------------------------------------------------------------------
-spec start(pos_integer(), #pool_spec{}) -> {ok, pid()} | ignore | {error, _}.
%%--------------------------------------------------------------------
start(N, Spec) -> jhn_fsm:start(?MODULE, [{arg, {N, Spec}}]).

%% ===================================================================
%% Testing API
%% ===================================================================

%%--------------------------------------------------------------------
%% Function: stop(Pid) -> ok.
%% @doc
%%   Stops the pool member, intended for testing.
%% @end
%%--------------------------------------------------------------------
-spec stop(pid()) -> ok.
%%--------------------------------------------------------------------
stop(Pid) -> jhn_fsm:call(Pid, stop).

%% ===================================================================
%% API
%% ===================================================================

%%--------------------------------------------------------------------
%% Function: 
%% @doc
%%   
%% @end
%% ------------------------------------------------------------
-spec request(pid(), #req{}) -> ok.
%% ------------------------------------------------------------
request(Pid, Req) -> jhn_fsm:event(Pid, Req).

%% ===================================================================
%% jhn_fsm callbacks
%% ===================================================================

%%--------------------------------------------------------------------
%% @private
%%--------------------------------------------------------------------
-spec init({pos_integer(), #pool_spec{}}) -> {ok, #state{}}.
%%--------------------------------------------------------------------
init({N, #pool_spec{name = Name, timeout = Timeout, hosts = Hosts}}) ->
    State = #state{seq = N,
                   name = Name,
                   timeout = Timeout,
                   hosts = Hosts,
                   no = length(Hosts)},
    connect(immediate, State),
    {ok, idle, State}.

%%--------------------------------------------------------------------
%% @private
%%--------------------------------------------------------------------
-spec handle_msg(connect, atom(), #state{}) -> {ok, atom(), #state{}}.
%%--------------------------------------------------------------------
handle_msg(connect, idle, State) ->
    case do_connect(State) of
        {ok, State1} -> {ok, connected, State1};
        State1 ->
            connect(later, State1),
            {ok, idle, State1}
    end.

%%--------------------------------------------------------------------
%% @private
%%--------------------------------------------------------------------
-spec handle_event(stop, atom(), #state{}) -> {stop, normal}.
%%--------------------------------------------------------------------
handle_event(stop, _, #state{socket = undefined}) ->
    jhn_fsm:reply(ok),
    {stop, normal};
handle_event(stop, _, #state{socket = Socket}) ->
    gen_tcp:close(Socket),
    jhn_fsm:reply(ok),
    {stop, normal}.

%%--------------------------------------------------------------------
%% @private
%%--------------------------------------------------------------------
-spec terminate(_, atom(), #state{}) -> _.
%%--------------------------------------------------------------------
terminate(_, payment, _) -> ok.

%%--------------------------------------------------------------------
%% @private
%%--------------------------------------------------------------------
-spec code_change(_, atom(), #state{}, _) -> {ok, atom(), #state{}}.
%%--------------------------------------------------------------------
code_change(_, StateName, State, _) -> {ok, StateName, State}.

%% ===================================================================
%% jhn_fsm state callbacks
%% ===================================================================

%%--------------------------------------------------------------------
%% @private
%%--------------------------------------------------------------------
-spec idle(_, #state{}) -> {ok, #state{}}.
%%--------------------------------------------------------------------
idle(Req = #req{}, State = #state{name = Name}) ->
    zk_pool_member:return(Name, Req),
    {ok, idle, State}.

%%--------------------------------------------------------------------
%% @private
%%--------------------------------------------------------------------
-spec connected(_, #state{}) -> {ok, #state{}}.
%%--------------------------------------------------------------------
connected(Req = #req{}, State) ->
    send(Req, State),
    {ok, connected, State}.

%% ===================================================================
%% Internal functions.
%% ===================================================================

connect(immediate, _) -> self() ! connect;
connect(later, #state{timeout = Timeout}) ->
    erlang:send_after(Timeout, self(), connect).

do_connect(State = #state{seq = Seq, hosts = Hosts, timeout = Timeout}) ->
    {Host, Port} = lists:nth(Seq, Hosts),
    case gen_tcp:connect(Host, Port, ?SOCK_OPTS, Timeout) of
        {ok, Socket} ->
            setup_connection(State#state{socket = Socket});
        {error, _} ->
            connect(later, State),
            update_seq(State)
    end.

send(_, State) -> State.

% We have do differentiate on reconnect and connect.

setup_connection(State = #state{session_id = 0}) ->
    #state{socket = Socket,
           session_id = SessionId,
           passwd = Passwd,
           timeout = Timeout} = State,
    case gen_tcp:send(Socket, zk_protocol:connect(Timeout,SessionId,Passwd)) of
        {error, _} -> update_seq(State);
        ok ->
            case zk_protocol:connect_response(Socket) of
                error -> update_seq(State);
                {Timeout, SessionId, Passwd} ->
                    {ok, State#state{timeout = Timeout}}
            end
    end.

update_seq(State=#state{seq=Seq,no=No}) when Seq < No-> State#state{seq=Seq+1};
update_seq(State) -> State#state{seq = 1}.
