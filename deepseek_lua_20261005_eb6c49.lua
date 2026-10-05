local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local Players = game:GetService("Players")
local LP = Players.LocalPlayer

local ROOT = "Spy"
local session = os.date("%Y-%m-%d_%H-%M-%S")
local SESSION_DIR = ROOT .. "/" .. session
local SOURCE_DIR = SESSION_DIR .. "/sources"
local LOG_DIR = SESSION_DIR .. "/logs"

if not isfolder(ROOT) then makefolder(ROOT) end
if not isfolder(SESSION_DIR) then makefolder(SESSION_DIR) end
if not isfolder(SOURCE_DIR) then makefolder(SOURCE_DIR) end
if not isfolder(LOG_DIR) then makefolder(LOG_DIR) end

local Config = {
    MinSourceSize = 50,
    MaxSourceSize = 5 * 1024 * 1024,
    SkipSelfFingerprint = "SPY_v3_MARKER_" .. tostring(math.random(1, 1e9)),
    BlacklistUrls = {
        "raw.githubusercontent.com/ActualMasterOogway/Fluent",
    },
    AutoSaveInterval = 5,
    AutoExportAtSize = 500,
    EnableInputHook = true,
    EnableDebugHook = true,
    EnableMetaHook = true,
}

local log = {
    Meta = {
        StartTime = os.time(),
        DateStr = session,
        PlaceId = game.PlaceId,
        JobId = game.JobId,
        PlayerName = LP.Name,
        UserId = LP.UserId,
        Executor = (function()
            local ok, n = pcall(function() return identifyexecutor and identifyexecutor() or "Unknown" end)
            return ok and n or "Unknown"
        end)(),
    },
    LoadedSources = {},
    HttpRequests = {},
    EnvSets = {},
    EnvGets = {},
    Hooks = {},
    Remotes = {},
    Requires = {},
    UIInstances = {},
    Inputs = {},
    MetaCalls = {},
    DebugCalls = {},
    Warnings = {},
}

local fileIndex = {}
local counter = { src = 0, http = 0, env = 0, hook = 0, remote = 0, ui = 0, input = 0, meta = 0, debug = 0, req = 0 }

local function notify(text)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = "Spy v3",
            Text = tostring(text):sub(1, 200),
            Duration = 2,
        })
    end)
    print("[SPY] " .. tostring(text))
end

local function safeSerialize(v, depth, seen)
    depth = depth or 0
    seen = seen or {}
    if depth > 4 then return "<depth>" end
    local t = type(v)
    if t == "string" then
        if #v > 3000 then return v:sub(1, 3000) .. "...<cut>" end
        return v
    elseif t == "number" or t == "boolean" or t == "nil" then
        return v
    elseif t == "table" then
        if seen[v] then return "<cycle>" end
        seen[v] = true
        local out, n = {}, 0
        for k, val in pairs(v) do
            n = n + 1
            if n > 100 then out["<more>"] = "..."; break end
            out[tostring(k)] = safeSerialize(val, depth + 1, seen)
        end
        return out
    elseif typeof(v) == "Instance" then
        return "<Instance:" .. v:GetFullName() .. ">"
    elseif typeof(v) == "Vector3" or typeof(v) == "CFrame" or typeof(v) == "Color3" then
        return "<" .. typeof(v) .. ":" .. tostring(v) .. ">"
    elseif typeof(v) == "function" then
        local ok, s = pcall(debug.info, v, "s")
        return ok and ("<Function:" .. s .. ">") or "<Function>"
    end
    return tostring(v)
end

local function passesUrlFilter(url)
    url = tostring(url or "")
    if not url or url == "" then return false end
    for _, bl in ipairs(Config.BlacklistUrls) do
        if url:find(bl, 1, true) then return false end
    end
    return true
end

local function appendLog(name, entry)
    table.insert(log[name], entry)
    if #log[name] % Config.AutoExportAtSize == 0 then
        task.spawn(function() pcall(SaveAll) end)
    end
end

function SaveAll()
    pcall(function()
        writefile(SESSION_DIR .. "/capture.json", HttpService:JSONEncode(log))
        writefile(SESSION_DIR .. "/meta.json", HttpService:JSONEncode(log.Meta))
    end)
end

function ExportSources()
    for i, src in ipairs(log.LoadedSources) do
        local fname = SOURCE_DIR .. "/src_" .. string.format("%04d", i) .. "_" .. tostring(src.ChunkName or "unknown"):gsub("[^%w_%-]", "_"):sub(1, 60) .. ".lua"
        pcall(function()
            writefile(fname, src.Source)
            fileIndex["source_" .. i] = fname
        end)
    end
    pcall(function()
        writefile(SESSION_DIR .. "/sources_index.json", HttpService:JSONEncode(fileIndex))
    end)
    notify("Da xuat " .. #log.LoadedSources .. " source")
end

function ExportRemotes()
    pcall(function()
        writefile(LOG_DIR .. "/remotes.json", HttpService:JSONEncode(log.Remotes))
    end)
    notify("Da xuat " .. #log.Remotes .. " remote")
end

function ExportEnvs()
    pcall(function()
        writefile(LOG_DIR .. "/env_sets.json", HttpService:JSONEncode(log.EnvSets))
        writefile(LOG_DIR .. "/env_gets.json", HttpService:JSONEncode(log.EnvGets))
    end)
end

function ExportHooks()
    pcall(function()
        writefile(LOG_DIR .. "/hooks.json", HttpService:JSONEncode(log.Hooks))
        writefile(LOG_DIR .. "/meta_calls.json", HttpService:JSONEncode(log.MetaCalls))
        writefile(LOG_DIR .. "/debug_calls.json", HttpService:JSONEncode(log.DebugCalls))
    end)
end

function ExportHttp()
    pcall(function()
        writefile(LOG_DIR .. "/http_requests.json", HttpService:JSONEncode(log.HttpRequests))
    end)
end

function ExportRequires()
    pcall(function()
        writefile(LOG_DIR .. "/requires.json", HttpService:JSONEncode(log.Requires))
    end)
end

function ExportUI()
    pcall(function()
        writefile(LOG_DIR .. "/ui_instances.json", HttpService:JSONEncode(log.UIInstances))
    end)
end

function ExportInputs()
    pcall(function()
        writefile(LOG_DIR .. "/inputs.json", HttpService:JSONEncode(log.Inputs))
    end)
end

function ExportWarnings()
    pcall(function()
        writefile(LOG_DIR .. "/warnings.json", HttpService:JSONEncode(log.Warnings))
    end)
end

function ExportAll()
    ExportSources()
    ExportRemotes()
    ExportEnvs()
    ExportHooks()
    ExportHttp()
    ExportRequires()
    ExportUI()
    ExportInputs()
    ExportWarnings()
    SaveAll()
    notify("Da xuat tat ca vao " .. SESSION_DIR)
end

local function detectTampers()
    local findings = {}
    if type(loadstring) == "function" then
        local ok, s = pcall(debug.info, loadstring, "s")
        if ok and s and not s:find("loadstring") and not s:find("C") then
            table.insert(findings, "loadstring bi thay the: " .. tostring(s))
        end
    end
    if type(hookfunction) == "function" then
        local ok, s = pcall(debug.info, hookfunction, "s")
        if ok and s and not s:find("hook") and not s:find("C") then
            table.insert(findings, "hookfunction bi thay the: " .. tostring(s))
        end
    end
    if type(getgenv) == "function" then
        local ok, s = pcall(debug.info, getgenv, "s")
        if ok and s and not s:find("getgenv") and not s:find("C") then
            table.insert(findings, "getgenv bi thay the: " .. tostring(s))
        end
    end
    return findings
end

task.spawn(function()
    while task.wait(10) do
        local f = detectTampers()
        for _, msg in ipairs(f) do
            table.insert(log.Warnings, { Time = os.time(), Warning = msg })
            notify("CANH BAO: " .. msg)
        end
        if #f > 0 then SaveAll() end
    end
end)

local function safeHook(orig, hook)
    if type(hookfunction) == "function" then
        local ok = pcall(hookfunction, orig, hook)
        if ok then return true end
    end
    if type(replaceclosure) == "function" then
        local ok = pcall(replaceclosure, orig, hook)
        if ok then return true end
    end
    return false
end

if type(loadstring) == "function" then
    local realLoadstring = loadstring
    safeHook(realLoadstring, function(code, chunkname)
        local n = counter.src + 1
        counter.src = n
        local source = type(code) == "string" and code or tostring(code)

        if source:find(Config.SkipSelfFingerprint, 1, true) then
            return realLoadstring(code, chunkname)
        end

        if #source >= Config.MinSourceSize and #source <= Config.MaxSourceSize then
            appendLog("LoadedSources", {
                Id = n,
                Time = os.time(),
                ChunkName = tostring(chunkname or ""),
                Length = #source,
                Source = source,
            })
            notify("Loadstring #" .. n .. " (" .. #source .. " bytes)")
        end

        return realLoadstring(code, chunkname)
    end)
end

if type(game.HttpGet) == "function" then
    local realGet = game.HttpGet
    safeHook(realGet, function(self, url, ...)
        if passesUrlFilter(url) then
            appendLog("HttpRequests", { Time = os.time(), Type = "game.HttpGet", Url = tostring(url) })
            notify("HTTP: " .. tostring(url):sub(1, 80))
        end
        return realGet(self, url, ...)
    end)
end

if type(game.HttpGetAsync) == "function" then
    local realGet = game.HttpGetAsync
    safeHook(realGet, function(self, url, ...)
        if passesUrlFilter(url) then
            appendLog("HttpRequests", { Time = os.time(), Type = "game.HttpGetAsync", Url = tostring(url) })
        end
        return realGet(self, url, ...)
    end)
end

for _, name in ipairs({ "request", "http_request", "httprequest" }) do
    if type(_G[name]) == "function" then
        local real = _G[name]
        _G[name] = function(options)
            if type(options) == "table" and passesUrlFilter(options.Url) then
                appendLog("HttpRequests", {
                    Time = os.time(),
                    Type = name,
                    Url = tostring(options.Url or ""),
                    Method = tostring(options.Method or "GET"),
                    Body = options.Body and tostring(options.Body):sub(1, 1000) or nil,
                })
                notify("request: " .. tostring(options.Url or ""):sub(1, 80))
            end
            return real(options)
        end
    end
end

if type(getgenv) == "function" and type(setgenv) == "function" then
    local env = getgenv()
    if type(getrawmetatable) == "function" then
        local mt = getrawmetatable(env)
        if mt then
            if type(setreadonly) == "function" then setreadonly(mt, false) end
            local oldIdx = mt.__index
            local oldNewIdx = mt.__newindex

            mt.__index = function(t, k)
                local ks = tostring(k)
                if ks ~= "Spy" then
                    appendLog("EnvGets", { Time = os.time(), Key = ks })
                end
                if oldIdx then return oldIdx(t, k) end
            end

            mt.__newindex = function(t, k, v)
                local ks = tostring(k)
                if ks ~= "Spy" then
                    appendLog("EnvSets", { Time = os.time(), Key = ks, Value = safeSerialize(v) })
                    notify("setgenv: " .. ks)
                end
                if oldNewIdx then oldNewIdx(t, k, v)
                else rawset(t, k, v) end
            end

            if type(setreadonly) == "function" then setreadonly(mt, true) end
        end
    end
end

if type(hookfunction) == "function" then
    local realHook = hookfunction
    safeHook(realHook, function(target, hook)
        local tS, hS = "?", "?"
        pcall(function() tS = debug.info(target, "s") or tostring(target) end)
        pcall(function() hS = debug.info(hook, "s") or tostring(hook) end)
        appendLog("Hooks", { Time = os.time(), Type = "hookfunction", Target = tS, Hook = hS })
        notify("hookfunction: " .. tostring(tS):sub(1, 80))
        return realHook(target, hook)
    end)
end

if type(hookmetamethod) == "function" then
    local realHook = hookmetamethod
    safeHook(realHook, function(obj, method, hook)
        local hS = "?"
        pcall(function() hS = debug.info(hook, "s") or tostring(hook) end)
        appendLog("Hooks", { Time = os.time(), Type = "hookmetamethod", Object = tostring(obj), Method = tostring(method), Hook = hS })
        notify("hookmetamethod: " .. tostring(method))
        return realHook(obj, method, hook)
    end)
end

task.spawn(function()
    if type(getrawmetatable) ~= "function" then return end
    local mt = getrawmetatable(game)
    if not mt then return end
    if type(setreadonly) == "function" then setreadonly(mt, false) end
    local oldNameCall = mt.__namecall

    local function newNameCall(self, ...)
        local method = getnamecallmethod and getnamecallmethod()
        if method == "FireServer" or method == "InvokeServer" then
            local args = { ... }
            local n = counter.remote + 1
            counter.remote = n
            if n % 5 == 1 then
                appendLog("Remotes", {
                    Time = os.time(),
                    Method = method,
                    Remote = typeof(self) == "Instance" and self:GetFullName() or tostring(self),
                    Args = safeSerialize(args),
                })
            end
        end
        return oldNameCall(self, ...)
    end

    if type(newcclosure) == "function" then
        pcall(function() mt.__namecall = newcclosure(newNameCall) end)
    else
        mt.__namecall = newNameCall
    end

    if type(setreadonly) == "function" then setreadonly(mt, true) end
end)

if type(require) == "function" then
    local realRequire = require
    safeHook(realRequire, function(target)
        local n = counter.req + 1
        counter.req = n
        if n % 3 == 1 then
            appendLog("Requires", {
                Time = os.time(),
                Target = typeof(target) == "Instance" and target:GetFullName() or tostring(target),
            })
        end
        return realRequire(target)
    end)
end

if type(hookfunction) == "function" then
    local realNew = Instance.new
    safeHook(realNew, function(className, parent, ...)
        if className == "ScreenGui" or className == "Folder" or className == "BillboardGui" then
            appendLog("UIInstances", {
                Time = os.time(),
                ClassName = className,
                Parent = parent and typeof(parent) == "Instance" and parent:GetFullName() or tostring(parent or "nil"),
            })
        end
        return realNew(className, parent, ...)
    end)
end

if Config.EnableInputHook then
    UserInputService.InputBegan:Connect(function(input, gp)
        if gp then return end
        local n = counter.input + 1
        counter.input = n
        if n % 10 == 1 then
            appendLog("Inputs", {
                Time = os.time(),
                Type = tostring(input.UserInputType),
                Key = tostring(input.KeyCode),
            })
        end
    end)
end

if Config.EnableDebugHook and type(debug) == "table" then
    for _, fname in ipairs({ "getinfo", "getupvalue", "getupvalues", "setupvalue", "getregistry", "getconstants" }) do
        if type(debug[fname]) == "function" then
            local orig = debug[fname]
            safeHook(orig, function(...)
                local args = table.pack(...)
                local n = counter.debug + 1
                counter.debug = n
                if n % 20 == 1 then
                    appendLog("DebugCalls", {
                        Time = os.time(),
                        Func = fname,
                        Arg1 = safeSerialize(args[1]),
                        Count = n,
                    })
                end
                return orig(...)
            end)
        end
    end
end

if Config.EnableMetaHook then
    for _, fname in ipairs({ "getrawmetatable", "setrawmetatable", "getnamecallmethod" }) do
        if type(_G[fname]) == "function" then
            local orig = _G[fname]
            safeHook(orig, function(...)
                local n = counter.meta + 1
                counter.meta = n
                if n % 10 == 1 then
                    local args = table.pack(...)
                    appendLog("MetaCalls", {
                        Time = os.time(),
                        Func = fname,
                        Arg1 = safeSerialize(args[1]),
                        Count = n,
                    })
                end
                return orig(...)
            end)
        end
    end
end

task.spawn(function()
    while task.wait(Config.AutoSaveInterval) do
        pcall(SaveAll)
    end
end)

task.spawn(function()
    local sg = Instance.new("ScreenGui", LP:WaitForChild("PlayerGui"))
    sg.Name = "SpyControl"
    sg.ResetOnSpawn = false

    local frame = Instance.new("Frame", sg)
    frame.Size = UDim2.new(0, 240, 0, 260)
    frame.Position = UDim2.new(0, 10, 0, 10)
    frame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
    frame.BorderSizePixel = 0
    frame.Active = true
    frame.Draggable = true

    local corner = Instance.new("UICorner", frame)
    corner.CornerRadius = UDim.new(0, 8)

    local title = Instance.new("TextLabel", frame)
    title.Size = UDim2.new(1, 0, 0, 24)
    title.BackgroundColor3 = Color3.fromRGB(65, 145, 230)
    title.BorderSizePixel = 0
    title.Text = "Spy v3 - File Export"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 12

    local function makeBtn(text, y, color, cb)
        local b = Instance.new("TextButton", frame)
        b.Size = UDim2.new(1, -16, 0, 22)
        b.Position = UDim2.new(0, 8, 0, y)
        b.BackgroundColor3 = color
        b.BorderSizePixel = 0
        b.Text = text
        b.TextColor3 = Color3.fromRGB(255, 255, 255)
        b.Font = Enum.Font.GothamBold
        b.TextSize = 11
        local c = Instance.new("UICorner", b)
        c.CornerRadius = UDim.new(0, 5)
        b.MouseButton1Click:Connect(cb)
        return b
    end

    makeBtn("Save All", 30, Color3.fromRGB(60, 130, 60), function() SaveAll(); notify("Da luu") end)
    makeBtn("Export Sources", 56, Color3.fromRGB(80, 100, 180), ExportSources)
    makeBtn("Export Remotes", 82, Color3.fromRGB(120, 80, 180), ExportRemotes)
    makeBtn("Export Envs/Hooks", 108, Color3.fromRGB(80, 140, 200), function()
        ExportEnvs(); ExportHooks()
    end)
    makeBtn("Export HTTP", 134, Color3.fromRGB(80, 180, 140), ExportHttp)
    makeBtn("EXPORT ALL", 160, Color3.fromRGB(200, 120, 60), ExportAll)
    makeBtn("Mo Folder", 186, Color3.fromRGB(80, 80, 120), function()
        notify("Folder: /sdcard/" .. SESSION_DIR)
    end)
    makeBtn("Clear Log", 212, Color3.fromRGB(180, 60, 60), function()
        log.LoadedSources = {}
        log.HttpRequests = {}
        log.Remotes = {}
        log.EnvSets = {}
        log.Hooks = {}
        log.Requires = {}
        log.UIInstances = {}
        log.Inputs = {}
        log.MetaCalls = {}
        log.DebugCalls = {}
        notify("Da clear")
    end)
end)

getgenv().Spy = {
    Log = log,
    Config = Config,
    SessionDir = SESSION_DIR,

    SaveAll = SaveAll,
    ExportSources = ExportSources,
    ExportRemotes = ExportRemotes,
    ExportEnvs = ExportEnvs,
    ExportHooks = ExportHooks,
    ExportHttp = ExportHttp,
    ExportRequires = ExportRequires,
    ExportUI = ExportUI,
    ExportInputs = ExportInputs,
    ExportWarnings = ExportWarnings,
    ExportAll = ExportAll,

    DetectTampers = detectTampers,

    Clear = function()
        log.LoadedSources = {}
        log.HttpRequests = {}
        log.Remotes = {}
        log.EnvSets = {}
        log.EnvGets = {}
        log.Hooks = {}
        log.Requires = {}
        log.UIInstances = {}
        log.Inputs = {}
        log.MetaCalls = {}
        log.DebugCalls = {}
        SaveAll()
        notify("Da clear")
    end,
}

pcall(function()
    writefile(SESSION_DIR .. "/README.txt",
        "Spy v3 Capture\n" ..
        "Session: " .. session .. "\n" ..
        "PlaceId: " .. tostring(game.PlaceId) .. "\n" ..
        "Executor: " .. tostring(log.Meta.Executor) .. "\n\n" ..
        "FILES:\n" ..
        "  capture.json\n" ..
        "  meta.json\n" ..
        "  sources_index.json\n" ..
        "  sources/src_XXXX.lua\n" ..
        "  logs/remotes.json\n" ..
        "  logs/env_sets.json\n" ..
        "  logs/env_gets.json\n" ..
        "  logs/hooks.json\n" ..
        "  logs/meta_calls.json\n" ..
        "  logs/debug_calls.json\n" ..
        "  logs/http_requests.json\n" ..
        "  logs/requires.json\n" ..
        "  logs/ui_instances.json\n" ..
        "  logs/inputs.json\n" ..
        "  logs/warnings.json\n\n" ..
        "API:\n" ..
        "  getgenv().Spy.SaveAll()\n" ..
        "  getgenv().Spy.ExportSources()\n" ..
        "  getgenv().Spy.ExportAll()\n"
    )
end)

notify("Spy v3 san sang. Session: " .. session)
notify("Folder: /sdcard/" .. SESSION_DIR)