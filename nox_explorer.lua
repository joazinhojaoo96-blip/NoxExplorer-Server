--[[
  NoxExplorer.lua
  AI-powered game class scanner + cheat generator
  Scans all game classes via Lua reflection, sends to MiMo AI, executes returned cheat code
  Compatible with: Synapse X, KRNL, Fluxus, Script-Ware (Roblox executors)
]]

-- =========================================================
-- CONFIG
-- =========================================================
local RAILWAY_URL    = "https://noxexplorer-server-production.up.railway.app"
local REPO_RAW       = "https://raw.githubusercontent.com/joazinhojaoo96-blip/NoxExplorer-Server/main/railway_url.txt"
local GATEWAY_PATH   = "/analyze"
local SCAN_DEPTH     = 4
local MAX_CLASSES    = 120
local GAME_NAME      = game and tostring(game.Name) or "unknown"
local HTTP           = syn and syn.request or (http and http.request) or request
-- =========================================================

local nox = {}
nox.version   = "1.1.0"
nox.classes   = {}
nox.endpoint  = nil
nox.generated = nil

local function try(fn, ...)
  local ok, v = pcall(fn, ...)
  return ok and v or nil
end

-- =========================================================
-- HTTP UTILS
-- =========================================================
local function http_get(url)
  if not HTTP then return nil end
  local ok, res = pcall(HTTP, {
    Url    = url,
    Method = "GET",
    Headers = { ["User-Agent"] = "NoxExplorer/1.1" }
  })
  if ok and res and res.StatusCode == 200 then
    return res.Body
  end
  return nil
end

local function http_post(url, body_table)
  if not HTTP then return nil end
  local body = game and game:GetService("HttpService"):JSONEncode(body_table)
           or (require and require("json") and require("json").encode(body_table))
           or tostring(body_table)
  local ok, res = pcall(HTTP, {
    Url     = url,
    Method  = "POST",
    Headers = {
      ["Content-Type"] = "application/json",
      ["User-Agent"]   = "NoxExplorer/1.1"
    },
    Body = body
  })
  if ok and res and res.StatusCode == 200 then
    return res.Body
  end
  return nil
end

-- =========================================================
-- ENDPOINT RESOLVER
-- Hardcoded Railway URL first, then GitHub raw fallback
-- =========================================================
function nox.resolve_endpoint()
  print("[nox] Using Railway endpoint: " .. RAILWAY_URL)
  nox.endpoint = RAILWAY_URL
  return RAILWAY_URL
end

-- =========================================================
-- CLASS SCANNER
-- =========================================================
local function extract_methods(mt_index, depth)
  if depth <= 0 or type(mt_index) ~= "table" then return {} end
  local methods = {}
  local seen = {}
  for k, v in pairs(mt_index) do
    if type(k) == "string" and not seen[k] then
      seen[k] = true
      table.insert(methods, k .. (type(v) == "function" and "()" or ""))
    end
    if #methods >= 20 then break end
  end
  local sub_mt = try(getrawmetatable, mt_index)
  if sub_mt and sub_mt.__index then
    local sub = extract_methods(sub_mt.__index, depth - 1)
    for _, m in ipairs(sub) do
      if not seen[m] then table.insert(methods, m) end
      if #methods >= 20 then break end
    end
  end
  return methods
end

local function inspect_object(obj)
  local info = { name = nil, class = nil, methods = {}, props = {} }
  if try(function() return obj.ClassName end) then
    info.class = tostring(obj.ClassName)
    info.name  = try(function() return tostring(obj.Name) end) or info.class
  elseif type(obj) == "table" then
    info.class = try(function() return tostring(obj.__type or obj.type or "table") end) or "table"
    info.name  = try(function() return tostring(obj.Name or obj.name or "unnamed") end) or "unnamed"
  end
  local mt = try(getrawmetatable, obj)
  if mt then
    if mt.__index then
      info.methods = extract_methods(mt.__index, SCAN_DEPTH)
    end
    if mt.__namecall then
      table.insert(info.methods, "__namecall")
    end
  end
  return info
end

function nox.scan_classes()
  print("[nox] Scanning game classes...")
  local seen_classes = {}
  local results = {}

  local function register(obj)
    if not obj then return end
    local info = inspect_object(obj)
    if not info.class then return end
    if seen_classes[info.class] then
      local existing = seen_classes[info.class]
      for _, m in ipairs(info.methods) do
        local found = false
        for _, em in ipairs(existing.methods) do
          if em == m then found = true; break end
        end
        if not found then table.insert(existing.methods, m) end
      end
      return
    end
    seen_classes[info.class] = info
    table.insert(results, info)
  end

  if game then
    local ok_ws, descendants = pcall(function()
      return game:GetService("Workspace"):GetDescendants()
    end)
    if ok_ws then
      for _, obj in ipairs(descendants) do
        register(obj)
        if #results >= MAX_CLASSES then break end
      end
    end
    local services = {
      "Players","RunService","UserInputService","Lighting",
      "ReplicatedStorage","ServerStorage","StarterGui",
      "Teams","SoundService","PathfindingService","TweenService",
      "PhysicsService","CollectionService","MarketplaceService"
    }
    for _, svc_name in ipairs(services) do
      local svc = try(function() return game:GetService(svc_name) end)
      if svc then register(svc) end
      if #results >= MAX_CLASSES then break end
    end
  end

  for k, v in pairs(_G) do
    if type(v) == "table" or type(v) == "userdata" then
      local info = inspect_object(v)
      if info.class and info.class ~= "table" then
        info.name = tostring(k)
        if not seen_classes[info.class] then
          seen_classes[info.class] = info
          table.insert(results, info)
        end
      end
    end
    if #results >= MAX_CLASSES then break end
  end

  nox.classes = results
  print(string.format("[nox] Found %d unique classes.", #results))
  return results
end

-- =========================================================
-- AI CALL
-- =========================================================
function nox.generate_cheat()
  if not nox.endpoint then
    warn("[nox] No endpoint. Call nox.resolve_endpoint() first.")
    return nil
  end
  if #nox.classes == 0 then
    warn("[nox] No classes found. Call nox.scan_classes() first.")
    return nil
  end

  print(string.format("[nox] Sending %d classes to AI...", #nox.classes))

  local class_list = {}
  for _, c in ipairs(nox.classes) do
    table.insert(class_list, {
      name    = c.name    or "?",
      class   = c.class   or "?",
      methods = c.methods or {}
    })
  end

  local svc = game and try(function() return game:GetService("HttpService") end)
  local payload = {
    classes = class_list,
    game    = GAME_NAME
  }

  local url  = nox.endpoint .. GATEWAY_PATH
  local body = http_post(url, payload)

  if not body then
    warn("[nox] No response from gateway.")
    return nil
  end

  local ok, decoded = pcall(function()
    if svc then
      return svc:JSONDecode(body)
    else
      local code = body:match('"code"%s*:%s*"(.-[^\\])"')
      return code and { code = code } or nil
    end
  end)

  if not ok or not decoded then
    warn("[nox] Failed to decode AI response: " .. tostring(body):sub(1, 200))
    return nil
  end

  nox.generated = decoded.code
  print(string.format("[nox] AI returned %d chars of Lua code.", #(nox.generated or "")))
  return nox.generated
end

-- =========================================================
-- EXECUTE
-- =========================================================
function nox.execute()
  if not nox.generated or #nox.generated == 0 then
    warn("[nox] Nothing to execute.")
    return false
  end
  print("[nox] Executing generated cheat code...")
  local fn, err = loadstring(nox.generated)
  if not fn then
    warn("[nox] loadstring failed: " .. tostring(err))
    warn("[nox] Code snippet: " .. nox.generated:sub(1, 300))
    return false
  end
  local ok, run_err = pcall(fn)
  if not ok then
    warn("[nox] Runtime error: " .. tostring(run_err))
    return false
  end
  print("[nox] Cheat code running.")
  return true
end

-- =========================================================
-- PRINT
-- =========================================================
function nox.print_classes()
  print(string.format("[nox] === %d Classes Found ===", #nox.classes))
  for i, c in ipairs(nox.classes) do
    local methods = #c.methods > 0 and (" | " .. table.concat(c.methods, ", ")) or ""
    print(string.format("  [%03d] %s (%s)%s", i, c.name, c.class, methods))
  end
end

-- =========================================================
-- MAIN
-- =========================================================
function nox.run()
  print("===========================================")
  print(" NoxExplorer v" .. nox.version .. " — AI Cheat Engine")
  print("===========================================")

  if not nox.resolve_endpoint() then
    warn("[nox] ABORT: could not reach AI server.")
    return
  end

  nox.scan_classes()
  local code = nox.generate_cheat()
  if not code then
    warn("[nox] ABORT: AI did not return code.")
    return
  end
  nox.print_classes()
  nox.execute()
end

-- =========================================================
-- AUTO-RUN
-- =========================================================
nox.run()
return nox
