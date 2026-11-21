local BASE_URL = "https://raw.githubusercontent.com/pietrocanaltu-rgb/nee/refs/heads/main/Zuni_hub_base.lua"
local ETW_URL  = "https://raw.githubusercontent.com/pietrocanaltu-rgb/nee/refs/heads/main/ETW.Lua"

-- Limpa o antigo
if _G.ZuniHub or _G.N3onHub then
    if _G.ZuniHub then _G.ZuniHub.Alive = false end
    if _G.N3onHub then _G.N3onHub.Alive = false end
    local pg = game.Players.LocalPlayer:FindFirstChild("PlayerGui")
    if pg then
        if pg:FindFirstChild("ZuniHub") then pg.ZuniHub:Destroy() end
        if pg:FindFirstChild("N3onHub") then pg.N3onHub:Destroy() end
    end
end
task.wait(0.2)

local function Load(url, label)
    local ok, src = pcall(game.HttpGet, game, url)
    if ok and src then
        local fn, err = loadstring(src)
        if fn then
            pcall(fn)
            print("[Loader] " .. label .. " carregado!")
        else
            warn("[Loader] Erro loadstring: " .. err)
        end
    end
end

Load(BASE_URL, "Base")

local wait_ready = 0
while (not _G.ZuniHub or not _G.ZuniHub.Ready) and wait_ready < 50 do
    task.wait(0.1)
    wait_ready = wait_ready + 1
end

if _G.ZuniHub and _G.ZuniHub.Ready then
    if game.GameId == 5677613211 then
        Load(ETW_URL, "ETW Module")
    end
end
