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
%%% The application callback module for zk.
%%% @end
%%%
%% @author Jan Henry Nystrom <JanHenryNystrom@gmail.com>
%% @copyright (C) 2013, Jan Henry Nystrom <JanHenryNystrom@gmail.com>
%%%-------------------------------------------------------------------
-module(zk_app).
-copyright('Jan Henry Nystrom <JanHenryNystrom@gmail.com>').

-behaviour(application).

%% application callbacks
-export([start/2, stop/1]).

%% ===================================================================
%% application callbacks
%% ===================================================================

%%--------------------------------------------------------------------
-spec start(normal, no_arg) -> {ok, pid()}.
%%--------------------------------------------------------------------
start(normal, no_arg) -> zk_sup:start_link().

%%--------------------------------------------------------------------
-spec stop(_) -> ok.
%%--------------------------------------------------------------------
stop(_) -> ok.
