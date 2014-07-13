require "love.timer"
require "enet"

function log (...)
    print(os.date("[%H:%M:%S]").."(SERVER) : ", ...)
end

port = ...

serverChannel = love.thread.getChannel("server")

host = enet.host_create("localhost:"..port)
if host then
    log("Has started on port", port)
    serverChannel:push(true)
else
    log("Could not be started. Perhaps a server is already running on this port ?", port)
    serverChannel:push(false)
    goto endThread
end

event = false

while true do
    love.timer.sleep(0.0001)

    if serverChannel:pop() == "stop" then
        for i = 1, host:peer_count() do
            host:get_peer(i):disconnect()
        end
        log("Disconnecting peers...")
        host:flush()
        log("Stopped.")
        serverChannel:push(true)
    end

    event = host:service()
    if event then
        if event.type == "receive" then
            --log("Got message from ", event.peer, event.data)
            host:broadcast(event.data)
        elseif event.type == "connect" then
            log("Connection attempt from ", event.peer)
        elseif event.type == "disconnect" then
            log("Disconnection", event.peer)
        end
    end
end

::endThread::

