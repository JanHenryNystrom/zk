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
-export([connect/1]).

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


%% zookeeper op type constants
-define(ZOO_NOTIFY_OP, 0).
-define(ZOO_CREATE_OP, 1).
-define(ZOO_DELETE_OP, 2).
-define(ZOO_EXISTS_OP, 3).
-define(ZOO_GETDATA_OP, 4).
-define(ZOO_SETDATA_OP, 5).
-define(ZOO_GETACL_OP, 6).
-define(ZOO_SETACL_OP, 7).
-define(ZOO_GETCHILDREN_OP, 8).
-define(ZOO_SYNC_OP, 9).
-define(ZOO_PING_OP, 11).
-define(ZOO_GETCHILDREN2_OP, 12).
-define(ZOO_CHECK_OP, 13).
-define(ZOO_MULTI_OP, 14).
-define(ZOO_CREATE2_OP, 15).
-define(ZOO_RECONFIG_OP, 16).
-define(ZOO_CLOSE_OP, -11).
-define(ZOO_SETAUTH_OP, 100).
-define(ZOO_SETWATCHES_OP, 101).


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
%% Function: connect(Timeout) -> ConnectionRequest
%% @doc
%%   
%% @end
%%--------------------------------------------------------------------
-spec connect(pos_integer()) -> #proto_connect_request{}.
%%--------------------------------------------------------------------
connect(Timeout) ->
    #proto_connect_request{protocol_version = 0,
                           last_zxid_seen = 0,
                           time_out = Timeout,
                           session_id = 0,
                           passwd = <<0:128>>
                          }.

%% ===================================================================
%% Internal functions.
%% ===================================================================

