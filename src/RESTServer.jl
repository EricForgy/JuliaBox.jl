
function make_vargs(vargs::Dict{String,String})
    arr = Tuple[]
    for (n,v) in vargs
        push!(arr, (symbol(n),v))
    end
    arr
end

function rest_handler(api::APIInvoker, req::Request, res::Response)
    debug("processing request $req")

    try
        comps = @compat split(req.resource, '?', limit=2, keep=false)
        if isempty(comps)
            res = Response(404)
        else
            path = shift!(comps)
            query = isempty(comps) ? Dict{String,String}() : parsequerystring(comps[1])
            args = @compat split(path, '/', keep=false)
            data_dict = isempty(req.data) ? query : merge(query, parsequerystring(req.data))

            if isempty(args) || !isalnum(args[1]) || !isalpha(args[1][1])
                res = Response(404)
            else
                cmd = shift!(args)
                if isempty(data_dict)
                    debug("calling cmd $cmd with args $args")
                    res = httpresponse(apicall(api, cmd, args...))
                else
                    vargs = make_vargs(data_dict)
                    debug("calling cmd $cmd with args $args, vargs $vargs")
                    res = httpresponse(apicall(api, cmd, args...; vargs...))
                end
            end
        end
    catch e
        res = Response(500)
        Base.error_show(STDERR, e, catch_backtrace())
        err("Exception in handler: $e")
    end
    debug("\tresponse $res")
    return res
end

on_error(client, err) = err("HTTP error: $err")
on_listen(port) = info("listening on port $(port)...")

type RESTServer
    api::APIInvoker
    handler::HttpHandler
    server::Server

    function RESTServer(api::APIInvoker)
        r = new()

        function handler(req::Request, res::Response)
            return rest_handler(api, req, res)
        end

        r.api = api
        r.handler = HttpHandler(handler)
        r.handler.events["error"] = on_error
        r.handler.events["listen"] = on_listen
        r.server = Server(r.handler)
        r
    end
end

function run_rest(api::APIInvoker, port::Int) 
    debug("running rest server...")
    rest = RESTServer(api)
    run(rest.server, port)
end


