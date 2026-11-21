--[[
  NoxExplorer.lua
  AI-powered game class scanner + cheat generator
  Scans all game classes via Lua reflection, sends to MiMo AI, executes returned cheat code
  Compatible with: Synapse X, KRNL, Fluxus, Script-Ware (Roblox executors)
]]

-- =========================================================
-- CONFIG
-- =========================================================
local REPO_RAW         = "https://raw.githubusercontent.com/joazinhojaoo96-blip/NoxExplorer-Server/main/endpoint.txt"
local RAILWAY_RAW      = "https://raw.githubusercontent.com/joazinhojaoo96-blip/NoxExplorer-Server/main/railway_url.txt"
local GATEWAY_PATH     = "/analyze"
local SCAN_DEPTH       = 4        -- how deep to follow __index chains
local MAX_CLASSES      = 120      -- cap sent to AI (avoid token overflow)
local GAME_NAME        = game and tostring(game.Name) or "unknown"
local HTTP             = syn and syn.request or (http and http.request) or request
local USE_RAILWAY      = true     -- prefer Railway over Cloudflare tunnel
-- =========================================================

local nox = {}
nox.version   = "1.0.0"
nox.classes   = {}
nox.endpoint  = nil
nox.generated = nil

-- safe pcall wrapper — returns nil on error
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
    Headers = { ["User-Agent"] = "NoxExplorer/1.0" }
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
      ["User-Agent"]   = "NoxExplorer/1.0"
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
-- Reads endpoint from GitHub raw URL (Railway or Cloudflare)
-- =========================================================
function nox.resolve_endpoint()
  print("[nox] Fetching endpoint from GitHub...")
  
  -- Try Railway first (preferred)
  if USE_RAILWAY then
    local railway_body = http_get(RAILWAY_RAW)
    if railway_body then
      local url = railway_body:match("(https?://[^\r\n]+)")
      if url and url ~= "https://your-railway-app.up.railway.app" then
        nox.endpoint = url
        print("[nox] Railway endpoint resolved: " .. url)
        return url
      end
    end
  end
  
  -- Fallback to Cloudflare tunnel
  local body = http_get(REPO_RAW)
  if body then
    local url = body:match("(https?://[^\r\n]+)")
    if url and url ~= "https://placeholder.trycloudflare.com" then
      nox.endpoint = url
      print("[nox] Cloudflare endpoint resolved: " .. url)
      return url
    end
  end
  
  warn("[nox] Could not resolve endpoint. Is Railway deployed?")
  warn("[nox] Run setup_railway.bat to deploy")
  return nil
end

-- =========================================================
-- CLASS SCANNER
-- Walks the full Roblox/game object tree via GetDescendants or
-- Children, then inspects metatables for methods and properties
-- =========================================================

-- Extract method names from a metatable's __index table
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
  -- recurse into nested __index
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

-- Get class info from a single object
local function inspect_object(obj)
  local info = { name = nil, class = nil, methods = {}, props = {} }
  -- Roblox objects
  if try(function() return obj.ClassName end) then
    info.class = tostring(obj.ClassName)
    info.name  = try(function() return tostring(obj.Name) end) or info.class
  elseif type(obj) == "table" then
    info.class = try(function() return tostring(obj.__type or obj.type or "table") end) or "table"
    info.name  = try(function() return tostring(obj.Name or obj.name or "unnamed") end) or "unnamed"
  end
  -- inspect metatable for methods
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

-- Main scan: collect all unique classes from the game
function nox.scan_classes()
  print("[nox] Scanning game classes...")
  local seen_classes = {}
  local results = {}

  local function register(obj)
    if not obj then return end
    local info = inspect_object(obj)
    if not info.class then return end
    if seen_classes[info.class] then
      -- merge new methods into existing entry
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

  -- Roblox path: GetDescendants from workspace + services
  if game then
    -- walk workspace descendants
    local ok_ws, descendants = pcall(function()
      return game:GetService("Workspace"):GetDescendants()
    end)
    if ok_ws then
      for _, obj in ipairs(descendants) do
        register(obj)
        if #results >= MAX_CLASSES then break end
      end
    end
    -- walk key services
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

  -- Generic path: scan _G and package.loaded for Lua tables with metatables
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
-- AI CALL — send classes to gateway, get Lua cheat code back
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

  -- build a serializable class list
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
    warn("[nox] No response from gateway. Is the tunnel active?")
    return nil
  end

  -- parse JSON response: { code = "...", classes_analyzed = N }
  local ok, decoded = pcall(function()
    if svc then
      return svc:JSONDecode(body)
    else
      -- fallback: extract code field with pattern
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
-- EXECUTE generated code
-- =========================================================
function nox.execute()
  if not nox.generated or #nox.generated == 0 then
    warn("[nox] Nothing to execute. Call nox.generate_cheat() first.")
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
    warn("[nox] Runtime error in generated code: " .. tostring(run_err))
    return false
  end
  print("[nox] Cheat code running.")
  return true
end

-- =========================================================
-- PRINT — dump found classes to console
-- =========================================================
function nox.print_classes()
  print(string.format("[nox] === %d Classes Found ===", #nox.classes))
  for i, c in ipairs(nox.classes) do
    local methods = #c.methods > 0 and (" | " .. table.concat(c.methods, ", ")) or ""
    print(string.format("  [%03d] %s (%s)%s", i, c.name, c.class, methods))
  end
end

-- =========================================================
-- MAIN — full pipeline
-- =========================================================
function nox.run()
  print("===========================================")
  print(" NoxExplorer v" .. nox.version .. " — AI Cheat Engine")
  print("===========================================")

  -- 1. resolve endpoint
  if not nox.resolve_endpoint() then
    warn("[nox] ABORT: could not reach AI server.")
    warn("[nox] Make sure start_all.bat is running on your PC.")
    return
  end

  -- 2. scan all game classes
  nox.scan_classes()

  -- 3. send to AI and get cheat code
  local code = nox.generate_cheat()
  if not code then
    warn("[nox] ABORT: AI did not return code.")
    return
  end

  -- 4. print what was found
  nox.print_classes()

  -- 5. execute
  nox.execute()
end

-- =========================================================
-- AUTO-RUN
-- =========================================================
nox.run()
return nox
