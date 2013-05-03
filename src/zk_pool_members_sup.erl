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
%%% The supervisor for the members of a pool.
%%% @end
%%%
%% @author Jan Henry Nystrom <JanHenryNystrom@gmail.com>
%% @copyright (C) 2013, Jan Henry Nystrom <JanHenryNystrom@gmail.com>
%%%-------------------------------------------------------------------
-module(zk_pool_members_sup).
-copyright('Jan Henry Nystrom <JanHenryNystrom@gmail.com>').

-behaviour(supervisor).

%% Management API
-export([start_link/1]).

%% supervisor callbacks
-export([init/1]).

%% Includes
-include_lib("zk/src/zk.hrl").

%% Types
-type init_return() :: {ok,
                        {{supervisor:strategy(), integer(), integer()},
                         [supervisor:child_spec()]}}.

%% Defines
-define(MEMBER_SHUTDOWN, 5000).

%% ===================================================================
%% Management API
%% ===================================================================

%%--------------------------------------------------------------------
%% Function: start_link(PoolSpec) -> {ok, Pid}
%% @doc
%%   Starts the pool supervisor.
%% @end
%%--------------------------------------------------------------------
-spec start_link(#pool_spec{}) -> {ok, pid()} | ignore | {error, _}.
%%--------------------------------------------------------------------
start_link(Spec) -> supervisor:start_link({local, ?MODULE}, ?MODULE, Spec).

%% ===================================================================
%% supervisor callbacks
%% ===================================================================

%%--------------------------------------------------------------------
-spec init(#pool_spec{}) -> init_return().
%%--------------------------------------------------------------------
init(Spec) -> {ok, {{one_for_one, 4, 3600}, children(Spec)}}.

%% ===================================================================
%% Internal functions.
%% ===================================================================

children(Spec = #pool_spec{size = Size}) ->
    lists:foldr(fun(N, Acc) -> [child(N, Spec) | Acc] end, lists:seq(1, Size)).

child(No, Spec) ->
    {master, {zk_pool_member, start, [No, Spec]},
     permanent, ?MEMBER_SHUTDOWN, worker, [zk_pool_master]}.

