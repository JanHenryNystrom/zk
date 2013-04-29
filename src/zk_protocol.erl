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
%%% The protocol encoding/decoding for Zookeeper.
%%% @end
%%%
%% @author Jan Henry Nystrom <JanHenryNystrom@gmail.com>
%% @copyright (C) 2013, Jan Henry Nystrom <JanHenryNystrom@gmail.com>
%%%-------------------------------------------------------------------
-module(zk_protocol).
-copyright('Jan Henry Nystrom <JanHenryNystrom@gmail.com>').

%% Library functions
-export([]).

%% Includes
-include_lib("zk/src/zookeeper.hrl").

%% Types

%% Exported Types

%% Records

%% Defines

%% predefined xid's values recognized as special by the server
-define(WATCHER_EVENT_XID, -1).
-define(PING_XID, -2).
-define(AUTH_XID, -4).
-define(SET_WATCHES_XID, -8).

%% zookeeper event type constants
-define(CREATED_EVENT, 1).
-define(DELETED_EVENT, 2)
-define(CHANGED_EVENT, 3).
-define(CHILD_EVENT, 4).
-define(SESSION_EVENT, -1).
-define(NOTWATCHING_EVENT, -2).

%% the size of connect request
-define(HANDSHAKE_REQ_SIZE, 44).

%% Error code tables.
-define(ZOO_ERRORS,
        [{0, 'ZOK'},
         %% System and server-side errors.
         {-1, 'ZSYSTEMERROR'},
         {-2, 'ZRUNTIMEINCONSISTENCY'},
         {-3, 'ZDATAINCONSISTENCY'},
         {-4, 'ZCONNECTIONLOSS'},
         {-5, 'ZMARSHALLINGERROR'}
         {-6, 'ZUNIMPLEMENTED'},
         {-7, 'ZOPERATIONTIMEOUT'},
         {-8, 'ZBADARGUMENTS'},
         {-9, 'ZINVALIDSTATE'},
         %% API errors
         {-100, 'ZAPIERROR'},
         {-101, 'ZNONODE'},
         {-102, 'ZNOAUTH'},
         {-103, 'ZBADVERSION'}
         {-108, 'ZNOCHILDRENFOREPHEMERALS'},
         {-110, 'ZNODEEXISTS'},
         {-111, 'ZNOTEMPTY'},
         {-112, 'ZSESSIONEXPIRED'},
         {-113, 'ZINVALIDCALLBACK'}
         {-114, 'ZINVALIDACL'},
         {-115, 'ZAUTHFAILED'}
         {-116, 'ZCLOSING'},
         {-117, 'ZNOTHING'},
         {-118, 'ZSESSIONMOVED'},
         {-120, 'ZNEWCONFIGNOQUORUM'},
         {-121, 'ZRECONFIGINPROGRESS'}
        ]).

%% ===================================================================
%% Library functions.
%% ===================================================================

%%--------------------------------------------------------------------
%% Function: 
%% @doc
%%   
%% @end
%%--------------------------------------------------------------------

%%--------------------------------------------------------------------
prime_connection() ->
    Req = #proto_connect_request{protocol_version = 0}.

%% ===================================================================
%% Internal functions.
%% ===================================================================

%% ===================================================================
%% Common parts
%% ===================================================================

