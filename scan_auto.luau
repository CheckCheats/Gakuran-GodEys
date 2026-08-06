-- ═══════════════════════════════════════
--  加库兰 上帝之眼 · 自动扫描器(循环版)
--  进服后自动开始扫描, 每 SCAN_INTERVAL 秒重扫一次
--  每次把数据写到 Real workspace/GakuranTianYan/data.json
--  本地 auto_push.ps1 检测到变化会自动推送到 GitHub
--
--  用法: Real executor 运行本脚本, 挂着即可
-- ═══════════════════════════════════════

local SCAN_INTERVAL = 60    -- 每次扫描间隔(秒)
local FOLDER = "GakuranTianYan"
local LOCAL_FILE = FOLDER .. "/data.json"
makefolder(FOLDER)

local Players = game:GetService("Players")
local HS = game:GetService("HttpService")

local genv = getgenv()
genv.__god_eye = genv.__god_eye or { running = false, cycle = 0, errors = 0 }

-- 防重复启动: 若已有循环在跑, 直接退出
if genv.__god_eye.running then
  print("!! 自动扫描已在运行, 跳过 (cycle=" .. genv.__god_eye.cycle .. ")")
  return
end

local S = genv.__god_eye
S.running = true

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

-- 只解析缺头像的 uid
local function resolveMissingAvatars(byUid)
  local need = {}
  for uid, rec in pairs(byUid) do
    if not rec.avatar then need[#need+1] = tonumber(uid) end
  end
  local cache = {}
  if #need == 0 then return cache end
  local i = 1
  while i <= #need do
    local batch = {}
    for k = i, math.min(i + 99, #need) do batch[#batch+1] = tostring(need[k]) end
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

-- 单次扫描
local function doScan()
  local byUid = {}
  -- 读历史
  if isfile(LOCAL_FILE) then
    local ok, old = pcall(function() return HS:JSONDecode(readfile(LOCAL_FILE)) end)
    if ok and old and old.players then
      for _, rec in ipairs(old.players) do
        if rec and rec.uid then byUid[tostring(rec.uid)] = rec end
      end
    end
  end
  -- 扫当前服
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
  -- 头像增量
  local av = resolveMissingAvatars(byUid)
  local list = {}
  for uid, rec in pairs(byUid) do
    local a = av[uid] or rec.avatar
    rec.avatar = a or nil
    table.insert(list, rec)
  end
  local payload = { captured = os.time(), count = #list, players = list }
  writefile(LOCAL_FILE, HS:JSONEncode(payload))
  return scanned, #list
end

-- ============ 主循环 ============
print("======= 加库仑 上帝之眼 · 自动扫描已启动 =======")
print("间隔 " .. SCAN_INTERVAL .. "s, 每轮扫描一次当前服并合并历史")
print("停止: 重新运行本脚本并改 SCAN_INTERVAL, 或重启客户端")

while S.running do
  S.cycle = S.cycle + 1
  local ok, a, b = pcall(doScan)
  if ok then
    print(string.format("[cycle %d] 本轮 %d 人, 累计 %d 人, 已写盘", S.cycle, a, b))
  else
    S.errors = S.errors + 1
    warn("[cycle " .. S.cycle .. "] 扫描出错: " .. tostring(b) .. " (累计错误 " .. S.errors .. ")")
  end
  for _ = 1, SCAN_INTERVAL do
    if not S.running then break end
    task.wait(1)
  end
end
print("======= 自动扫描已停止 =======")