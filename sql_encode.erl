-module(sql_encode).
-export([encode/1,encode/2]).
-export([quote/1,quote/2]).

encode(Val) ->
    encode(Val, list).

encode(Val, ReturnType) when is_atom(Val)->
	encode(atom_to_list(Val), ReturnType, latin1);
encode(Val,ReturnType)->
	encode(Val, ReturnType, utf8).

encode(null, list, _)-> 
	"NULL";
encode(undefined, list, _)-> 
	"NULL";
encode(null, binary, _)->
	<<"NULL">>;
encode(undefined, binary, _)->
	<<"NULL">>;

encode(Val, list, latin1) when is_binary(Val) ->
	quote(binary_to_list(Val));
encode(Val, list, Encoding) when is_binary(Val) ->
	quote(unicode:characters_to_list(Val, Encoding));
encode(Val, list, _) when is_list(Val) ->
	quote(Val);
encode(Val, list, _) when is_integer(Val) ->
	integer_to_list(Val);
encode(Val, list, _) when is_float(Val) ->
	[Res] = io_lib:format("~w", [Val]),
	Res;

encode(Val, binary, latin1) when is_list(Val) -> 
	list_to_binary(quote(Val));
encode(Val, binary, Encoding) when is_list(Val) ->
	unicode:characters_to_binary(quote(Val), Encoding, Encoding);
encode(Val, binary, latin1) when is_binary(Val) ->
	quote(Val, latin1);
encode(Val, binary, Encoding) when is_binary(Val) ->
	quote(Val, Encoding);
encode(Val, binary, _) when is_integer(Val) ->
	list_to_binary(integer_to_list(Val));
encode(Val, binary, _) when is_float(Val) ->
	[Res] = io_lib:format("~w", [Val]),
	erlang:list_to_binary(Res);

encode({datetime, Val}, AsBinary) ->
    encode(Val, AsBinary);
encode({{Year,Month,Day}, {Hour,Minute,Second}}, false) ->
    [Year1,Month1,Day1,Hour1,Minute1,Second1] =
        lists:map(fun two_digits/1,[Year, Month, Day, Hour, Minute,Second]),
    lists:flatten(io_lib:format("'~s-~s-~s ~s:~s:~s'",
        [Year1,Month1,Day1,Hour1,Minute1,Second1]));
encode({date, {Year, Month, Day}}, false) ->
    [Year1,Month1,Day1] =
        lists:map(fun two_digits/1,[Year, Month, Day]),
    lists:flatten(io_lib:format("'~s-~s-~s'",[Year1,Month1,Day1]));
encode({time, {Hour, Minute, Second}}, false) ->
    [Hour1,Minute1,Second1] =
        lists:map(fun two_digits/1,[Hour, Minute, Second]),
    lists:flatten(io_lib:format("'~s:~s:~s'",[Hour1,Minute1,Second1]));
encode(Val, _AsBinary) ->
    {error, {unrecognized_value, {Val}}}.

quote(String) when is_list(String) ->
    [$' | lists:reverse([$' | quote_loop(String)])];
quote(Bin) when is_binary(Bin) ->
    quote(Bin,utf8).
quote(Bin, latin1) when is_binary(Bin) ->
    list_to_binary(quote(binary_to_list(Bin)));
quote(Bin, Encoding) when is_binary(Bin) ->
    case unicode:characters_to_list(Bin,Encoding) of
	{error,E1,E2} -> 
	    exit({invalid_encoding_binary, E1, E2});
	{incomplete,E1,E2} ->
	    exit({invalid_encoding_binary, E1, E2});
	List ->
	    unicode:characters_to_binary(quote(List),Encoding,Encoding)    	
    end.

quote_loop(List) ->
	quote_loop(List, []).
quote_loop([], Acc) ->
	Acc;
quote_loop([$\0 | Rest], Acc) ->
	quote_loop(Rest, [$0, $\\ | Acc]);
quote_loop([$\n | Rest], Acc) ->
	quote_loop(Rest, [$n, $\\ | Acc]);
quote_loop([$\r | Rest], Acc) ->
	quote_loop(Rest, [$r, $\\ | Acc]);
quote_loop([$\\ | Rest], Acc) ->
	quote_loop(Rest, [$\\ , $\\ | Acc]);
quote_loop([$' | Rest], Acc) -> %% 39 is $'
	quote_loop(Rest, [$', $\\ | Acc]); %% 39 is $'
quote_loop([$" | Rest], Acc) -> %% 34 is $"
	quote_loop(Rest, [34, $\\ | Acc]); %% 34 is $"
quote_loop([$\^Z | Rest], Acc) ->
	quote_loop(Rest, [$Z, $\\ | Acc]);
quote_loop([C | Rest], Acc) ->
	quote_loop(Rest, [C | Acc]).