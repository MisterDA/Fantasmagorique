function log (...)
    print(os.date("[%H:%M:%S]").."(CLIENT) : ", ...)
end

function love.load ()
    require "lib/LoveFrames"
    require "enet"

    state = "mainmenu"
    loveframes.SetState(state)


    -- Network --

    username, serverip, port = "", "", "2048"
    host   = enet.host_create()
    server = false
    timeBeginConnection = 0

    serverThread  = love.thread.newThread("server.lua")
    serverChannel = false


    -- Main menu --

    function checkCredentials ()
        if username == "" then
            hostButton:SetEnabled(false)
            joinButton:SetEnabled(false)
        else
            local portn = tonumber(port) or 2048
            if portn <= 65535 then
                hostButton:SetEnabled(true)
                if serverip ~= "" then
                    local chunks = { serverip:match("^(%d+)%.(%d+)%.(%d+)%.(%d+)$") }
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
    frame:SetHeight(190)
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
        serverip = object:GetText()
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

    textError = loveframes.Create("text", frame)
    textError:SetWidth(390)
    textError:SetPos(5, 120)

    textInfo = loveframes.Create("text", frame)
    textInfo:SetWidth(390)
    textInfo:SetPos(5, 150)
    textInfo:SetLinksEnabled(true)
    textInfo:SetDetectLinks(true)
    textInfo:SetText("Fantasmagorique is a collaborative drawing game, made by A.Decimo. http://github.com/MisterDA/Fantasmagorique")
    textInfo.OnClickLink = function (object, link)
        love.system.openURL(link)
    end


    -- Game --

    love.graphics.setColor(255, 255, 255)
    canvas = love.graphics.newCanvas()
    mouse = {
        x = -1,
        y = -1,
    }
end

function love.update (dt)
    if state == "game" then
        if love.mouse.isDown('l') then
            if mouse.x == -1 then
                mouse.x, mouse.y = love.mouse.getPosition()
            end
            server:send(
                tostring(mouse.x)..":"..tostring(mouse.y)..":"..
                tostring(love.mouse.getX()) ..":"..tostring(love.mouse.getY())..":")
            mouse.x, mouse.y = love.mouse.getPosition()
        else
            mouse.x = -1
        end
    elseif state == "mainmenu" then
        if server and server:state() == "connecting"
            and os.time() - timeBeginConnection > 5 then
            log("Could not reach server.")
            textError:SetText({{color = {255, 0, 0}}, "Could not reach server."})
            server:reset()
        end
    end

    local event = host:service()
    if event then
        if event.type == "receive" then
            --log("Got message from", event.peer, event.data)
            if state == "game" then
                love.graphics.setCanvas(canvas)
                for data in string.gmatch(event.data, "(%d+:%d+:%d+:%d+:)") do
                    ox, oy, x, y = string.match(data, "(%d+):(%d+):(%d+):(%d+):")
                    love.graphics.line(ox, oy, x, y)
                end
                love.graphics.setCanvas()
            end
        elseif event.type == "connect" then
            log("Connection attempt to", event.peer)
            state = "game"
            loveframes.SetState(state)
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
    server = host:connect(serverip..":"..port)
    timeBeginConnection = os.time()
end

function hostServer ()
    serverip = "127.0.0.1"
    serverThread:start(port)
    serverChannel = love.thread.getChannel("server")

    local hasStarted = serverChannel:demand()
    if hasStarted then
        textError:SetText("")
        server = host:connect(serverip..":"..port)
        timeBeginConnection = os.time()
    else
        textError:SetText({{color ={255, 0, 0}}, "Could not start server."})
        server = false
        serverThread  = love.thread.newThread("server.lua")
        serverChannel = false
    end
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

    loveframes.mousepressed (x, y, button)
end

function love.mousereleased (x, y, button)

    loveframes.mousereleased(x, y, button)
end

function love.keypressed (key, unicode)
    if key == "escape" then
        love.event.quit()
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

