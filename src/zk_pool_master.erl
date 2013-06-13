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
%%% The pool master responsible for the pool coordination.
%%% @end
%%%
%% @author Jan Henry Nystrom <JanHenryNystrom@gmail.com>
%% @copyright (C) 2013, Jan Henry Nystrom <JanHenryNystrom@gmail.com>
%%%-------------------------------------------------------------------
-module(zk_pool_master).
-copyright('Jan Henry Nystrom <JanHenryNystrom@gmail.com>').

-behaviour(jhn_server).

%% Management API
-export([start/1]).

%% Pool member API
-export([enter/1, leave/1]).

%% API
-export([request/2, sync_request/2]).

%% jhn_server callbacks
-export([init/1,
         handle_req/2, handle_msg/2,
         terminate/2, code_change/3]).

%% Includes
-include_lib("zk/src/zk.hrl").

%% Records
-record(pool, {current = [] :: [pid()],
               template = [] :: [pid()]}).

-record(state,{pool = #pool{},
               queue = [] :: [#req{}],
               queue_len = 0 :: non_neg_integer(),
               max_queue_len = 0 :: non_neg_integer()
              }).

%% ===================================================================
%% Management API
%% ===================================================================

%%--------------------------------------------------------------------
%% Function: start_link(PoolSpec) -> {ok, Pid}
%% @doc
%%   Starts the pool Master.
%% @end
%%--------------------------------------------------------------------
-spec start(#pool_spec{}) -> {ok, pid()} | ignore | {error, _}.
%%--------------------------------------------------------------------
start(Spec = #pool_spec{name = Name}) ->
    jhn_server:start(?MODULE, [{name, Name}, {arg, Spec}]).

%% ===================================================================
%% Pool member API
%% ===================================================================

%%--------------------------------------------------------------------
%% Function: 
%% @doc
%%   
%% @end
%% ------------------------------------------------------------
-spec enter(atom()) -> ok.
%% ------------------------------------------------------------
enter(Name) -> jhn_server:cast(Name, {enter, self()}).

%%--------------------------------------------------------------------
%% Function: 
%% @doc
%%   
%% @end
%% ------------------------------------------------------------
-spec leave(atom()) -> ok.
%% ------------------------------------------------------------
leave(Name) -> catch exit(whereis(Name), leaving), ok.

%% ===================================================================
%% API
%% ===================================================================

%%--------------------------------------------------------------------
%% Function: 
%% @doc
%%   
%% @end
%% ------------------------------------------------------------
-spec request(atom(), _) -> ok.
%% ------------------------------------------------------------
request(Name, Payload) -> jhn_server:cast(Name, #req{payload = Payload}).

%%--------------------------------------------------------------------
%% Function: 
%% @doc
%%   
%% @end
%% ------------------------------------------------------------
-spec sync_request(atom(), _) -> _.
%% ------------------------------------------------------------
sync_request(Name, Payload) ->
    jhn_server:call(Name, #req{sync = true, payload = Payload}).

%% ===================================================================
%% jhn_server callbacks
%% ===================================================================

%%--------------------------------------------------------------------
%% @private
%%--------------------------------------------------------------------
-spec init(#pool_spec{}) -> {ok, #state{}}.
%%--------------------------------------------------------------------
init(#pool_spec{}) ->
    process_flag(trap_exit, true),
    {ok, Max} = application:get_env(zk, max_queue_len),
    {ok, #state{max_queue_len = Max}}.

%%--------------------------------------------------------------------
%% @private
%%--------------------------------------------------------------------
-spec handle_req(_, #state{}) -> {ok, #state{}}.
%%--------------------------------------------------------------------
handle_req({enter, Pid}, State) ->
    NewState = case catch link(Pid) of
                   true -> flush(add(Pid, State));
                   _ -> State
               end,
    {ok, NewState};
handle_req(Req = #req{}, State) ->
    Req1 = Req#req{from = jhn_server:from()},
    NewState =
        case select(Req1, State) of
            State1 = #state{} -> State1;
            {Member, State1} ->
                zk_pool_member:request(Member, Req1),
                State1
        end,
    {ok, NewState}.

%%--------------------------------------------------------------------
%% @private
%%--------------------------------------------------------------------
-spec handle_msg(_, #state{}) -> {ok, #state{}}.
%%--------------------------------------------------------------------
handle_msg({'EXIT', Pid, _}, State) -> {ok, remove(Pid, State)}.

%%--------------------------------------------------------------------
%% @private
%%--------------------------------------------------------------------
-spec terminate(_, #state{}) -> ok.
%%--------------------------------------------------------------------
terminate(_Reason, _State) -> ok.

%%--------------------------------------------------------------------
%% @private
%%--------------------------------------------------------------------
-spec code_change(_, #state{}, _) -> {ok, #state{}}.
%%--------------------------------------------------------------------
code_change(_OldVsn, State, _Extra) -> {ok, State}.

%% ===================================================================
%% Internal functions.
%% ===================================================================

select(Req, State = #state{pool = #pool{template = []}}) ->
    #state{queue = Queue, queue_len = Len, max_queue_len = Max} = State,
    case Len < Max of
        true -> State#state{queue = [Req |  Queue], queue_len = Len + 1};
        false ->
            info("Dropping queue, max queue ~p length reached", [Len]),
            drop([Req | Queue]),
            State#state{queue = [], queue_len = 0}
    end;
select(Req, State = #state{pool=Pool=#pool{current=[], template=Template}}) ->
    select(Req, State#state{pool = Pool#pool{current = Template}});
select(_, State = #state{pool = Pool=#pool{current = [Member | Current]}}) ->
    {Member,  State#state{pool = Pool#pool{current = Current}}}.

add(Pid, State = #state{pool = Pool = #pool{template = Template}}) ->
    case lists:member(Pid, Template) of
        true -> State;
        false -> State#state{pool = Pool#pool{template = [Pid | Template]}}
    end.

remove(Pid, State = #state{pool = Pool = #pool{current = C, template = T}}) ->
    State#state{pool = Pool#pool{current = lists:delete(Pid, C),
                                 template = lists:delete(Pid, T)}}.

drop([]) -> ok;
drop([#req{sync = false} | T]) -> drop(T);
drop([#req{sync = true, from = From} | T]) ->
    jhn_server:reply(From, error),
    drop(T).

flush(State = #state{queue = []}) -> State;
flush(State = #state{queue = Queue = [H | _]}) ->
    {Member, State1} = select(H, State),
    [zk_pool_member:request(Member, Req) || Req <- Queue],
    State1#state{queue = [], queue_len = 0}.

info(Format, Args) -> zk_log:info(?MODULE, Format, Args).
