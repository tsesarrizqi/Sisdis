-module(server).
-export([start/1]).

start(Port) ->
    {ok, LSock} = gen_tcp:listen(Port, [{reuseaddr,true},binary,{backlog,1024}]),
    %% spawn proses baru untuk accept connection/request
    spawn(fun() -> accept(LSock) end),
    receive 
        stop -> 
            gen_tcp:close(LSock) 
    end.

accept(LSock) ->
    {ok, Sock} = gen_tcp:accept(LSock),
    ok = inet:setopts(Sock, [{packet,raw}]),
    %% spawn proses baru untuk accept connection/request
    spawn(fun() -> accept(LSock) end),
    serve(Sock).

serve(Sock) ->
    ok = inet:setopts(Sock, [{active, once}]),
    HttpMsg = 
        receive
            {tcp,_,Msg} -> 
                Msg
        end,
    try
        [Req|Hdrs0] = re:split(HttpMsg,"\r\n"),
        [M,Uri,Ver] = re:split(Req," "),
        case (M == <<"POST">>) or (M == <<"GET">>) of
            true ->
                HdrParse = 
                    fun(Hdr) -> 
                        [H,V] = re:split(Hdr,": "), 
                        {string:lowercase(H),V} 
                    end,
                {Hdrs1, Rest} = lists:split(length(Hdrs0) - 2, Hdrs0),
                {_, Body} = lists:split(length(Rest) - 1, Rest),
                Hdrs = [HdrParse(Hdr) || Hdr <- Hdrs1],
                Args = [{method,M},{uri,Uri},{version,Ver},{headers, Hdrs},{body,Body}],
                {Stat, RespHdrs, RespBody} = response(Sock, Args),
                ok = gen_tcp:send(Sock, [binary_to_list(Ver)," ", Stat, "\r\n",
                                      [[H, ": ", V, "\r\n"] || {H,V} <- RespHdrs],
                                      "\r\n", RespBody]);
            _ ->
                ok = gen_tcp:send(Sock, [binary_to_list(Ver),
                        " 501 Not Implemented\r\nContent-type: text/plain; charset=UTF-8\r\nContent-length: ",
                        integer_to_list(byte_size(<<"501​ Not​ Implemented:​ Reason:​ OPTION\r\n">>)),
                        "\r\nConnection: close\r\n\r\n501​ Not​ Implemented:​ Reason:​ OPTION\r\n"])
        end
    catch _:_ ->
        ok = gen_tcp:send(Sock, ["HTTP/1.0 400 Bad Request\r\nContent-type: text/plain; charset=UTF-8\r\nContent-length: ",
                        integer_to_list(byte_size(<<"400 Bad Request\r\n">>)),
                        "\r\nConnection: close\r\n\r\n400 Bad Request\r\n"])
    end,
    gen_tcp:close(Sock).

response(_Sock, Req) ->
    Body = proplists:get_value(body, Req),
    Headers = proplists:get_value(headers, Req),
    Method = proplists:get_value(method, Req),
    Uri = proplists:get_value(uri, Req),
    case {Method,Uri} of 
        {<<"GET">>,<<"/">>} ->
            RespHdrs = [{"Location","/hello-world"},
                        {"Content-Type","text/html; charset=UTF-8"},
                        {"Content-Length","0"},
                        {"Connection","close"}],
            {"302 Found", RespHdrs, []};
        {<<"POST">>,<<"/">>} ->
            RespHdrs = [{"Location","/hello-world"},
                        {"Content-Type","text/html; charset=UTF-8"},
                        {"Content-Length","0"},
                        {"Connection","close"}],
            {"302 Found", RespHdrs, []};
        {<<"GET">>,<<"/style">>} ->
            {ok, File} = file:read_file("style.css"),
            RespHdrs = [{"Content-Type","text/css; charset=UTF-8"},
                        {"Content-Length",integer_to_list(byte_size(File))},
                        {"Connection","close"}],
            {"200 OK", RespHdrs, binary_to_list(File)};
        {<<"GET">>,<<"/background">>} ->
            {ok, File} = file:read_file("background.jpg"),
            RespHdrs = [{"Content-Type","image/jpg; charset=UTF-8"},
                        {"Content-Length",integer_to_list(byte_size(File))},
                        {"Connection","close"}],
            {"200 OK", RespHdrs, binary_to_list(File)};
        {<<"GET">>,<<"/hello-world">>} ->
            {ok, File0} = file:read_file("hello-world.html"),
            File = re:replace(File0, <<"__HELLO__">>, <<"World">>, [{return,binary}]),
            RespHdrs = [{"Content-Type","text/html; charset=UTF-8"},
                        {"Content-Length",integer_to_list(byte_size(File))},
                        {"Connection","close"}],
            {"200 OK", RespHdrs, binary_to_list(File)};
        {<<"POST">>,<<"/hello-world">>} ->
            CType = proplists:get_value(<<"content-type">>,Headers), 
            case CType of 
                <<"application/x-www-form-urlencoded">> ->
                    Name = re:replace(Body, <<"name=">>, <<"">>, [{return,binary}]),
                    {ok, File0} = file:read_file("hello-world.html"),
                    File = re:replace(File0, <<"__HELLO__">>, Name, [{return,binary}]),
                    RespHdrs = [{"Content-Type","text/html; charset=UTF-8"},
                                {"Content-Length",integer_to_list(byte_size(File))},
                                {"Connection","close"}],
                    {"200 OK", RespHdrs, binary_to_list(File)};
                _ ->
                    RespHdrs = [{"Content-Type","text/plain; charset=UTF-8"},
                                {"Content-Length",integer_to_list(byte_size(<<"400 Bad Request\r\n">>))},
                                {"Connection","close"}],
                    {"400 Bad Request", RespHdrs, "400 Bad Request\r\n"}
            end;    
        {<<"GET">>,<<"/info?type=", Rest/binary>>} ->
            case Rest of 
                <<"time">> ->
                    {{Year, Month, Day}, {Hour, Minute, Second}} = calendar:now_to_local_time(erlang:now()),
                    Content = lists:flatten(io_lib:format(
                        "~s ~s ~2..0w ~2..0w:~2..0w:~2..0w WIB ~4..0w\r\n",
                        [day_of_the_week(Year, Month, Day), month(Month), Day, Hour, Minute, Second, Year])),
                    RespHdrs = [{"Content-Type","text/plain; charset=UTF-8"},
                                {"Content-Length",integer_to_list(byte_size(list_to_binary(Content)))},
                                {"Connection","close"}],
                    {"200 OK", RespHdrs, [Content,"\r\n"]};
                <<"random">> ->
                    Content = rand:uniform(4294967296)-2147483649,
                    RespHdrs = [{"Content-Type","text/plain; charset=UTF-8"},
                                {"Content-Length",integer_to_list(byte_size(integer_to_binary(Content))+2)},
                                {"Connection","close"}],
                    {"200 OK", RespHdrs, [integer_to_list(Content),"\r\n"]};
                _ ->
                    RespHdrs = [{"Content-Type","text/plain; charset=UTF-8"},
                                {"Content-Length",integer_to_list(byte_size(<<"No Data\r\n">>))},
                                {"Connection","close"}],
                    {"200 OK", RespHdrs, "No Data\r\n"}
            end;
        _ ->
            RespHdrs = [{"Content-Type","text/plain; charset=UTF-8"},
                        {"Content-Length",integer_to_list(byte_size(<<"404 Not Found\r\n">>))},
                        {"Connection","close"}],
            {"404 Not Found", RespHdrs, "404 Not Found\r\n"}
    end.

day_of_the_week(Year, Month, Day) ->   
    Num = calendar:day_of_the_week(Year, Month, Day), 
    case Num of 
        1 ->
            "Mon";
        2 ->
            "Tue";
        3 ->
            "Wed";
        4 ->
            "Thu";
        5 ->
            "Fri";
        6 ->
            "Sat";
        7 ->
            "Sun"
    end.

month(MonthNum) ->
    case MonthNum of
        1 ->
            "Jan";
        2 ->
            "Feb";
        3 ->
            "Mar";
        4 ->
            "Apr";
        5 ->
            "May";
        6 ->
            "Jun";
        7 ->
            "Jul";
        8 ->
            "Aug";
        9 ->
            "Sep";
        10 ->
            "Oct";
        11 ->
            "Nov";
        12 ->
            "Dec"
    end.