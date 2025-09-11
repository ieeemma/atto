
get(Bin, Line, Col) ->
    <<T, Rest/binary>> = Bin
    {NewLine, NewCol} =
        case Byte of
            10 -> {Line + 1, 1};
            _  -> {Line, Col + 1}
        end.
    {T, Rest, NewLine, NewCol}.

gets(Bin, N, Line, Col) ->
    <<Ts:N/binary, Rest/binary>> = Bin
    {NewLine, NewCol} = update(Ts, Line, Col),
    {Ts, Rest, NewLine, NewCol}.

update(<<>>, Line, Col) ->
    {Line, Col};
update(<<10, Rest/binary>>, Line, _Col) ->
    update(Rest, Line + 1, 1);
update(<<_Byte, Rest/binary>>, Line, Col) ->
    update(Rest, Line, Col + 1).

size(Bin) -> byte_size(Bin).

to_string(X) -> X.

from_string(X) -> X.