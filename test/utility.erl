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
%%%   A utility module to perform manual testing during development.
%%% @end
%%%
%% @author Jan Henry Nystrom <JanHenryNystrom@gmail.com>
%% @copyright (C) 2013, Jan Henry Nystrom <JanHenryNystrom@gmail.com>
%%%-------------------------------------------------------------------
-module(utility).
-copyright('Jan Henry Nystrom <JanHenryNystrom@gmail.com>').

%% API
-export([connect/0, connect/2, disconnect/1,
         send/2]).

%% Includes
%-include_lib("zk/include/zookeeper.hrl").

%% Types
-type client_id() :: string() | atom().


%% ===================================================================
%% Library functions.
%% ===================================================================

%%--------------------------------------------------------------------
%% Function: connect() -> Socket
%% @doc
%%   Connect to zookeeper started locally.
%% @end
%%--------------------------------------------------------------------
-spec connect() -> inets:socket().
%%--------------------------------------------------------------------
connect() -> connect("127.0.0.1", 2181).

%%--------------------------------------------------------------------
%% Function: connect(Host, Port) -> Socket
%% @doc
%%   Connect to zookeeper on Host using Port.
%% @end
%%--------------------------------------------------------------------
-spec connect(string(), integer()) -> inets:socket().
%%--------------------------------------------------------------------
connect(Host, Port) ->
    {ok, Socket} = gen_tcp:connect(Host, Port, [binary, {packet, 4}]),
    Socket.

%%--------------------------------------------------------------------
%% Function: disconnect(Socket) -> ok
%% @doc
%%   Disconnect from the zookeeper server.
%% @end
%%--------------------------------------------------------------------
-spec disconnect(inets:socket()) -> ok.
%%--------------------------------------------------------------------
disconnect(Socket) -> gen_tcp:close(Socket).


send(Socket, Data) -> gen_tcp:send(Socket, Data).
