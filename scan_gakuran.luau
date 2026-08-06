-- ═══════════════════════════════════════
--  加库兰 上帝之眼 · 扫描器(仅扫描+合并落盘)
--  在 Roblox 任意服务器跑一次 = 抓一次快照
--  数据写到 Real workspace 的 GakuranTianYan/data.json
--  然后运行 push_data.bat 即推送到 GitHub 更新天眼
-- ═══════════════════════════════════════

local Players = game:GetService("Players")
local HS = game:GetService("HttpService")
local FOLDER = "GakuranTianYan"
local LOCAL_FILE = FOLDER .. "/data.json"
makefolder(FOLDER)

-- ============ 工具 ============
local function colorToHex(c)
  if c == nil then return "" end
  local t = typeof(c)
  if t == "Color3" then
    return string.format("#%02X%02X%02X", math.floor(c.R*255+0.5), math.floor(c.G*255+0.5), math.floor(c.B*255+0.5))
  elseif t == "string" then
    local r,g,b = string.match(c, "([%d%.]+)[, ]+([%d%.]+)[, ]+([%d%.]+)")
    if r then return string.format("#%02X%02X%02X", math.floor(tonumber(r)*255+0.5), math.floor(tonumber(g)*255+0.5), math.floor(tonumber(b)*255+0.5)) end
    return c
  elseif t == "table" then
    return string.format("#%02X%02X%02X", math.floor(c.r*255+0.5), math.floor(c.g*255+0.5), math.floor(c.b*255+0.5))
  end
  return ""
end

local function countKeys(t)
  local n = 0
  for _ in pairs(t) do n = n + 1 end
  return n
end

local function allUids(byUid)
  local out = {}
  for uid in pairs(byUid) do out[#out+1] = tonumber(uid) end
  return out
end

-- 批量解析头像 uid -> tr.rbxcdn imageUrl
local function resolveAvatars(uids)
  local cache = {}
  if #uids == 0 then return cache end
  local i = 1
  while i <= #uids do
    local batch = {}
    for k = i, math.min(i + 99, #uids) do batch[#batch+1] = tostring(uids[k]) end
    local ok, resp = pcall(function() return request({
      Url = "https://thumbnails.roblox.com/v1/users/avatar-headshot?userIds=" .. table.concat(batch, ",") .. "&size=420x420&format=Png",
      Method = "GET", Headers = { ["User-Agent"] = "tianyan" }
    }) end)
    if ok and resp and resp.StatusCode == 200 then
      local d = HS:JSONDecode(resp.Body)
      if d and d.data then
        for _, e in ipairs(d.data) do
          if e.imageUrl then cache[tostring(e.targetId)] = e.imageUrl end
        end
      end
    end
    task.wait(0.2)
    i = i + #batch
  end
  return cache
end

-- ============ 主流程 ============
print("======= 加库仑 上帝之眼 · 扫描开始 =======")

-- 1) 读本地历史数据(合并用)
local byUid = {}
if isfile(LOCAL_FILE) then
  local ok, old = pcall(function() return HS:JSONDecode(readfile(LOCAL_FILE)) end)
  if ok and old and old.players then
    for _, rec in ipairs(old.players) do
      if rec and rec.uid then byUid[tostring(rec.uid)] = rec end
    end
    print("读入本地历史 " .. #old.players .. " 条")
  end
else
  print("无历史数据, 从空开始")
end

-- 2) 扫描当前服
local scanned = 0
for _, pl in ipairs(Players:GetPlayers()) do
  local pd = pl.Character and pl.Character:FindFirstChild("PlayerData")
  if pd then
    local A = pd:GetAttributes()
    byUid[tostring(pl.UserId)] = {
      username = pl.Name, uid = pl.UserId, display = pl.DisplayName,
      first = A.FirstName, last = A.LastName,
      gender = A.Gender, ethnicity = A.Ethnicity, age = A.Age,
      grade = A.Grade, role = A.Role, height = A.Height,
      skin = colorToHex(A.SkinTone), hairColor = colorToHex(A.HairColor),
      faceId = A.FaceID, hairId = A.HairID, headId = A.HeadAccessoryID,
      faceAcc = A.FaceAccessoryID, neckId = A.NeckAccessoryID,
      shoulderId = A.ShoulderAccessoryID, waistId = A.WaistAccessoryID,
      backId = A.BackAccessoryID, torsoAccId = A.TorsoAccessoryID,
      style1 = A.CombatStyleSlot1, style2 = A.CombatStyleSlot2, styleEq = A.CombatStyleEquippedSlot,
      unif1 = A.UniformSlot1, unif2 = A.UniformSlot2, unifEq = A.UniformEquippedSlot,
      hunger = tonumber(A.Hunger), thirst = tonumber(A.Thirst), seenAt = os.time(),
      avatar = nil
    }
    scanned = scanned + 1
  end
end
print("扫描当前服 " .. scanned .. " 人, 累计库内 " .. countKeys(byUid) .. " 人")

-- 3) 头像解析(所有 uid, 含历史)
print("解析头像...")
local avCache = resolveAvatars(allUids(byUid))

-- 4) 组装
local list = {}
for uid, rec in pairs(byUid) do
  local av = avCache[uid] or rec.avatar
  if av then rec.avatar = av else rec.avatar = nil end
  table.insert(list, rec)
end
local payload = { captured = os.time(), count = #list, players = list }
local json = HS:JSONEncode(payload)
writefile(LOCAL_FILE, json)
local withAv = 0
for _, r in ipairs(list) do if r.avatar then withAv = withAv + 1 end end
print("✅ 扫描完成, 已保存 " .. #list .. " 条 (含头像 " .. withAv .. ")")
print("   位置: Real workspace/" .. LOCAL_FILE)
print("   下一步: 运行 push_data.bat 同步到GitHub")
print("======= 扫描完成 =======")