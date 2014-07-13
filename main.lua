function log (...)
    print(os.date("[%H:%M:%S]").."(CLIENT) : ", ...)
end

function love.load ()
    require "lib/LoveFrames"
    require "enet"

    state = "mainmenu"
    loveframes.SetState(state)


    -- Network --

    username, hostip, port = "", "", "2048"
    host   = enet.host_create()
    server = false

    serverThread  = love.thread.newThread("server.lua")
    serverChannel = false


    -- Main menu --

    function checkCredentials ()
        if USERNAME == "" then
            hostButton:SetEnabled(false)
            joinButton:SetEnabled(false)
        else
            local portn = tonumber(port) or 2048
            if portn <= 65535 then
                hostButton:SetEnabled(true)
                if HOST ~= "" then
                    local chunks = {hostip:match("^(%d+)%.(%d+)%.(%d+)%.(%d+)$")}
                    if #chunks == 4 then
                        for _,v in pairs(chunks) do
                            if tonumber(v) > 255 then
                                joinButton:SetEnabled(false)
                                return
                            end
                        end
                        joinButton:SetEnabled(true)
                    else
                        joinButton:SetEnabled(false)
                    end
                end
            else
                hostButton:SetEnabled(false)
                joinButton:SetEnabled(false)
            end
        end
    end

    frame = loveframes.Create("frame")
    frame:SetName("Play")
    frame:SetWidth(400)
    frame:SetHeight(120)
    frame:Center()
    frame:SetDraggable(false)
    frame:ShowCloseButton(false)
    frame:SetState(state)

    usernameInput = loveframes.Create("textinput", frame)
    usernameInput:SetWidth(390)
    usernameInput:SetPos(5, 30)
    usernameInput:SetLimit(16)
    usernameInput:SetUsable({
        "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n",
        "o", "p", "q", "r", "s", "t", "u", "v", "x", "y", "z",
        "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N",
        "O", "P", "Q", "R", "S", "T", "U", "V", "X", "Y", "Z",
        "0", "1", "2", "3", "4", "5", "6", "7", "8", "9"})
    usernameInput:SetPlaceholderText("User name (a-zA-Z0-9)")
    usernameInput.OnTextChanged = function (object)
        username = object:GetText()
        checkCredentials()
    end

    hostInput = loveframes.Create("textinput", frame)
    hostInput:SetWidth(300)
    hostInput:SetPos(5, 60)
    hostInput:SetLimit(15)
    hostInput:SetUsable({"0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "."})
    hostInput:SetPlaceholderText("Host IP (IPv4 only)")
    hostInput.OnTextChanged = function (object)
        hostip = object:GetText()
        checkCredentials()
    end

    portInput = loveframes.Create("textinput", frame)
    portInput:SetWidth(85)
    portInput:SetPos(310, 60)
    portInput:SetLimit(5)
    portInput:SetUsable({"0", "1", "2", "3", "4", "5", "6", "7", "8", "9"})
    portInput:SetPlaceholderText("Port (2048)")
    portInput.OnTextChanged = function (object)
        port = object:GetText()
        checkCredentials()
    end

    joinButton = loveframes.Create("button", frame)
    joinButton:SetText("Join")
    joinButton.OnClick = joinServer
    joinButton:SetWidth(192.5)
    joinButton:SetPos(5, 90)
    joinButton:SetEnabled(false)

    hostButton = loveframes.Create("button", frame)
    hostButton:SetText("Host")
    hostButton.OnClick = hostServer
    hostButton:SetWidth(192.5)
    hostButton:SetPos(202.5, 90)
    hostButton:SetEnabled(false)


    -- Game --

    love.graphics.setColor(255, 255, 255)
    canvas = love.graphics.newCanvas()
end

function love.update (dt)
    if state == "game" then
        x, y = 0, 0
    end

    local event = host:service()
    if event then
        if event.type == "receive" then
            log("Got message from", event.peer, event.data)
            if state == "game" then
                love.graphics.setCanvas(canvas)
                x, y = string.match(event.data, "(%d+):(%d+)")
                love.graphics.circle("fill", x, y, 10, 100)
                love.graphics.setCanvas()
            end
        elseif event.type == "connect" then
            log("Connection attempt to", event.peer)
        elseif event.type == "disconnect" then
            log("Disconnection from", event.peer)
        end
    end

    loveframes.update(dt)
end

function love.draw ()
    if state == "game" then
        love.graphics.draw(canvas)
    end

    loveframes.draw()
end

function joinServer ()
    state = "game"
    loveframes.SetState(state)

    server = host:connect(hostip..":"..port)
end

function hostServer ()
    hostip = "127.0.0.1"
    serverThread:start(port)
    serverChannel = love.thread.getChannel("server")

    local hasStarted = serverChannel:demand()
    if hasStarted then
        server = host:connect(hostip..":"..port)
        state = "game"
        loveframes.SetState(state)
    else
        server = false
        serverThread = false
        serverChannel = false
    end

    log(state)
end

function love.quit ()
    log("Quit.")
    if server then
        if serverChannel then
            serverChannel:supply("stop")
            serverChannel:demand()
        end
    end
end

function love.mousepressed (x, y, button)
    if state == "game" then
        server:send(tostring(x)..":"..tostring(y))
    end

    loveframes.mousepressed (x, y, button)
end

function love.mousereleased (x, y, button)

    loveframes.mousereleased(x, y, button)
end

function love.keypressed (key, unicode)
    if key == "escape" then
        love.event.quit()
    end

    if state == "game" then
        server:send(key)
    end

    loveframes.keypressed(key, unicode)
end

function love.keyreleased (key, unicode)

    loveframes.keyreleased(key, unicode)
end

function love.textinput (text)

    loveframes.textinput(text)
end

function love.threaderror (thread, err)
    log("Thread error.", err)
end

