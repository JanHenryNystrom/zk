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
%%%   Logging funcionality lib for zk.
%%% @end
%%%
%% @author Jan Henry Nystrom <JanHenryNystrom@gmail.com>
%% @copyright (C) 2013, Jan Henry Nystrom <JanHenryNystrom@gmail.com>
%%%-------------------------------------------------------------------
-module(zk_log).
-copyright('Jan Henry Nystrom <JanHenryNystrom@gmail.com>').

%% Library functions
-export([info/3]).

%% Types

%% Records

%% Defines

%% ===================================================================
%% Library functions.
%% ===================================================================

%%--------------------------------------------------------------------
%% Function: info(Module, Format, Arguments) -> ok.
%% @doc
%%   Logs info to the standard error logger.
%% @end
%%--------------------------------------------------------------------
-spec info(atom(), string(), [_]) -> ok.
%%--------------------------------------------------------------------
info(Module, Format, Args) ->
    error_logger:info_msg(
      io_lib:format("[~p]~p(~p) " ++ Format ++ "~n",
                    [node(), Module, self() | Args])).

%% ===================================================================
%% Internal functions.
%% ===================================================================

