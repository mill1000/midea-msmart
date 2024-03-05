local VALUE_VERSION = 24
local JSON = require "cjson"
local function makeSum(tmpbuf, start_pos, end_pos)
    local resVal = 0
    for si = start_pos, end_pos do resVal = resVal + tmpbuf[si] end
    resVal = bit.bnot(resVal) + 1
    resVal = bit.band(resVal, 0x00ff)
    return resVal
end
local function string2table(hexstr)
    local tb = {}
    local i = 1
    local j = 1
    for i = 1, #hexstr - 1, 2 do
        local doublebytestr = string.sub(hexstr, i, i + 1)
        tb[j] = tonumber(doublebytestr, 16)
        j = j + 1
    end
    return tb
end
local function string2hexstring(str)
    local ret = ""
    for i = 1, #str do ret = ret .. string.format("%02x", str:byte(i)) end
    return ret
end
local function table2string(cmd)
    local ret = ""
    local i
    for i = 1, #cmd do ret = ret .. string.char(cmd[i]) end
    return ret
end
local function checkBoundary(data, min, max)
    if (not data) then data = 0 end
    data = tonumber(data)
    if ((data >= min) and (data <= max)) then return data else if (data < min) then return min else return max end end
end
local function Split(szFullString, szSeparator)
    local nFindStartIndex = 1
    local nSplitIndex = 1
    local nSplitArray = {}
    while true do
        local nFindLastIndex = string.find(szFullString, szSeparator, nFindStartIndex)
        if not nFindLastIndex then
            nSplitArray[nSplitIndex] = string.sub(szFullString, nFindStartIndex, string.len(szFullString))
            break
        end
        nSplitArray[nSplitIndex] = string.sub(szFullString, nFindStartIndex, nFindLastIndex - 1)
        nFindStartIndex = nFindLastIndex + string.len(szSeparator)
        nSplitIndex = nSplitIndex + 1
    end
    return nSplitArray
end
local function parseDevFlag(value, tab)
    for k, v in ipairs(tab) do if v == value then return true; end end
    return false;
end
local function parseFlag(value)
    local t = type(value)
    if t == "string" then
        value = tonumber(value)
        if (value <= 82 or value == 85 or value == 36353 or value == -29183) then return true else return false end
    else return false end
end
local function assembleByteFromJson(result, msgBytes)
    local query = result["query"]
    local control = result["control"]
    local status = nil
    local devInfoData = result["deviceinfo"]["deviceSubType"]
    local flag = parseFlag(devInfoData)
    if (result["status"]) then status = result["status"] end
    if (control) then
        msgBytes[10] = 0x02
        if (control["power"]) then if (control["power"] == "on" or control["power"] == 1) then
                msgBytes[11] = 0x01
                msgBytes[12] = 0x01
            elseif (control["power"] == "off" or control["power"] == 0) then
                msgBytes[11] = 0x02
                msgBytes[12] = 0x01
            end else if (control["control_type"] and control["control_type"] == "part" or flag == false) then
                for i = 11, 17 do msgBytes[i] = 0x00 end
                msgBytes[11] = 0x14
                if (control["eplus"] or control["fast_wash"] or control["summer"] or control["winter"] or control["efficient"] or control["night"] or control["bath_person"] or control["cloud"] or control["wash"] or control["shower"] or control["bath"] or control["memory"]) then
                    msgBytes[12] = 0x03
                    msgBytes[18] = 0x00
                    msgBytes[19] = 0x00
                    msgBytes[20] = 0x00
                    if (control["eplus"] == "on" or control["eplus"] == 1) then msgBytes[13] = 0x01 elseif (control["fast_wash"] == "on" or control["fast_wash"] == 1) then msgBytes[13] = 0x02 elseif (control["summer"] == "on" or control["summer"] == 1) then msgBytes[13] = 0x04 elseif (control["winter"] == "on" or control["winter"] == 1) then msgBytes[13] = 0x08 elseif (control["efficient"] == "on" or control["efficient"] == 1) then msgBytes[13] = 0x10 elseif (control["night"] == "on" or control["night"] == 1) then msgBytes[13] = 0x20 elseif (control["bath_person"] == "one_person") then msgBytes[14] = 0x01 elseif (control["bath_person"] == "two_person") then msgBytes[14] = 0x02 elseif (control["bath_person"] == "three_person") then msgBytes[14] = 0x04 elseif (control["bath_person"] == "old_man") then msgBytes[14] = 0x08 elseif (control["bath_person"] == "adult") then msgBytes[14] = 0x10 elseif (control["bath_person"] == "children") then msgBytes[14] = 0x20 elseif (control["cloud"] == "on" or control["cloud"] == 1) then msgBytes[14] = 0x40 elseif (control["wash"] == "on" or control["wash"] == 1) then msgBytes[15] = 0x10 elseif (control["shower"] == "on" or control["shower"] == 1) then msgBytes[15] = 0x20 elseif (control["bath"] == "on" or control["bath"] == 1) then msgBytes[15] = 0x40 elseif (control["memory"] == "on" or control["memory"] == 1) then msgBytes[15] = 0x80 end
                else
                    if (control["half_heat"]) then
                        msgBytes[12] = 0x04
                        if (control["half_heat"] == "on" or control["half_heat"] == 1) then msgBytes[13] = bit.bor(
                            msgBytes[13], 0x01) end
                    end
                    if (control["whole_heat"]) then
                        msgBytes[12] = 0x04
                        if (control["whole_heat"] == "on" or control["whole_heat"] == 1) then msgBytes[13] = bit.bor(
                            msgBytes[13], 0x02) end
                    end
                    if (control["temperature"]) then
                        msgBytes[12] = 0x07
                        msgBytes[13] = control["temperature"]
                    end
                    if (control["egg_reset"]) then
                        msgBytes[12] = 0x0A
                        if (control["egg_reset"] == "on" or control["egg_reset"] == 1) then msgBytes[13] = bit.bor(
                            msgBytes[13], 0x01) end
                    end
                    if (control["sterilization"]) then
                        msgBytes[12] = 0x0D
                        if (control["sterilization"] == "on" or control["sterilization"] == 1) then msgBytes[13] = bit
                            .bor(msgBytes[13], 0x01) end
                    end
                    if (control["frequency_hot"]) then
                        msgBytes[12] = 0x10
                        if (control["frequency_hot"] == "on" or control["frequency_hot"] == 1) then msgBytes[13] = bit
                            .bor(msgBytes[13], 0x01) end
                    end
                    if (control["grea"]) then
                        msgBytes[12] = 0x10
                        msgBytes[14] = control["grea"]
                    end
                    if (control["scene"]) then
                        msgBytes[12] = 0x13
                        if (control["scene"] == "on" or control["scene"] == 1) then msgBytes[13] = bit.bor(msgBytes[13],
                                0x01) end
                    end
                    if (control["scene_id"]) then
                        msgBytes[12] = 0x13
                        msgBytes[14] = control["scene_id"]
                    end
                    if (control["protect"]) then
                        msgBytes[12] = 0x05
                        if (control["protect"] == "on" or control["protect"] == 1) then msgBytes[13] = bit.bor(
                            msgBytes[13], 0x01) end
                    end
                    if (control["filter_reset"]) then
                        msgBytes[12] = 0x08
                        if (control["filter_reset"] == "on" or control["filter_reset"] == 1) then msgBytes[13] = bit.bor(
                            msgBytes[13], 0x01) end
                    end
                    if (control["clean"]) then
                        msgBytes[12] = 0x0B
                        if (control["clean"] == "on" or control["clean"] == 1) then msgBytes[13] = bit.bor(msgBytes[13],
                                0x01) end
                    end
                    if (control["sleep"]) then
                        msgBytes[12] = 0x0E
                        if (control["sleep"] == "on" or control["sleep"] == 1) then msgBytes[13] = bit.bor(msgBytes[13],
                                0x01) end
                    end
                    if (control["big_water"]) then
                        msgBytes[12] = 0x11
                        if (control["big_water"] == "on" or control["big_water"] == 1) then msgBytes[13] = bit.bor(
                            msgBytes[13], 0x01) end
                    end
                    if (control["auto_off"]) then
                        msgBytes[12] = 0x14
                        if (control["auto_off"] == "on" or control["auto_off"] == 1) then msgBytes[13] = bit.bor(
                            msgBytes[13], 0x01) end
                    end
                    if (control["safe"]) then
                        msgBytes[12] = 0x06
                        if (control["safe"] == "on" or control["safe"] == 1) then msgBytes[13] = bit.bor(msgBytes[13],
                                0x01) end
                    end
                    if (control["mg_reset_part"]) then
                        msgBytes[12] = 0x09
                        if (control["mg_reset_part"] == "on" or control["mg_reset_part"] == 1) then msgBytes[13] = bit
                            .bor(msgBytes[13], 0x01) end
                    end
                    if (control["negative_ions"]) then
                        msgBytes[12] = 0x0C
                        if (control["negative_ions"] == "on" or control["negative_ions"] == 1) then msgBytes[13] = bit
                            .bor(msgBytes[13], 0x01) end
                    end
                    if (control["screen_off"]) then
                        msgBytes[12] = 0x0F
                        if (control["screen_off"] == "on" or control["screen_off"] == 1) then msgBytes[13] = bit.bor(
                            msgBytes[13], 0x01) end
                    end
                    if (control["t_hot"]) then
                        msgBytes[12] = 0x12
                        if (control["t_hot"] == "on" or control["t_hot"] == 1) then msgBytes[13] = bit.bor(msgBytes[13],
                                0x01) end
                    end
                    if (control["mg_reset"]) then
                        msgBytes[12] = 0x15
                        if (control["mg_reset"] == "on" or control["mg_reset"] == 1) then msgBytes[13] = bit.bor(
                            msgBytes[13], 0x01) end
                    end
                    if (control["baby_wash"] or control["dad_wash"] or control["mom_wash"] or control["wash_with_temp"] or control["single_wash"] or control["people_wash"]) then
                        if (control["baby_wash"] or control["dad_wash"] or control["mom_wash"]) then
                            msgBytes[12] = 0x17
                            if (control["baby_wash"] == "on" or control["baby_wash"] == 1) then msgBytes[13] = bit.bor(
                                msgBytes[13], 0x01) end
                            if (control["dad_wash"] == "on" or control["dad_wash"] == 1) then msgBytes[13] = bit.bor(
                                msgBytes[13], 0x02) end
                            if (control["mom_wash"] == "on" or control["mom_wash"] == 1) then msgBytes[13] = bit.bor(
                                msgBytes[13], 0x04) end
                        else
                            msgBytes[12] = 0x18
                            if (control["wash_with_temp"] == "on" or control["wash_with_temp"] == 1) then msgBytes[13] =
                                bit.bor(msgBytes[13], 0x01) end
                            if (control["single_wash"] == "on" or control["single_wash"] == 1) then msgBytes[13] = bit
                                .bor(msgBytes[13], 0x02) end
                            if (control["people_wash"] == "on" or control["people_wash"] == 1) then msgBytes[13] = bit
                                .bor(msgBytes[13], 0x04) end
                        end
                        if (control["wash_temperature"]) then msgBytes[14] = control["wash_temperature"] end
                    elseif (control["wash_temperature"]) then
                        msgBytes[12] = 0x16
                        msgBytes[13] = control["wash_temperature"]
                    end
                    if (control["one_egg"]) then
                        msgBytes[12] = 0x19
                        if (control["one_egg"] == "on" or control["one_egg"] == 1) then msgBytes[13] = bit.bor(
                            msgBytes[13], 0x01) end
                    end
                    if (control["two_egg"]) then
                        msgBytes[12] = 0x19
                        if (control["two_egg"] == "on" or control["two_egg"] == 1) then msgBytes[13] = bit.bor(
                            msgBytes[13], 0x02) end
                    end
                    if (control["always_fell"]) then
                        msgBytes[12] = 0x1A
                        if (control["always_fell"] == "on" or control["always_fell"] == 1) then msgBytes[13] = bit.bor(
                            msgBytes[13], 0x01) end
                    end
                    if (control["smart_sterilize"]) then
                        msgBytes[12] = 0x1B
                        if (control["smart_sterilize"] == "on" or control["smart_sterilize"] == 1) then msgBytes[13] =
                            bit.bor(msgBytes[13], 0x01) end
                    end
                    if (control["sterilize_cycle_days"]) then
                        msgBytes[12] = 0x1B
                        msgBytes[14] = control["sterilize_cycle_days"]
                    end
                    if (control["sterilize_cycle_index"]) then
                        msgBytes[12] = 0x1B
                        msgBytes[15] = control["sterilize_cycle_index"]
                    end
                    if (control["new_night"]) then
                        msgBytes[12] = 0x1C
                        if (control["new_night"] == "on" or control["new_night"] == 1) then msgBytes[13] = bit.bor(
                            msgBytes[13], 0x01) end
                    end
                    if (control["uv_sterilize"]) then
                        msgBytes[12] = 0x1D
                        if (control["uv_sterilize"] == "on" or control["uv_sterilize"] == 1) then msgBytes[13] = bit.bor(
                            msgBytes[13], 0x01) end
                    end
                    if (control["sound_dad"]) then
                        msgBytes[12] = 0x1E
                        if (control["sound_dad"] == "on" or control["sound_dad"] == 1) then
                            msgBytes[13] = bit.bor(msgBytes[13], 0x03)
                            msgBytes[14] = bit.bor(msgBytes[14], 0x01)
                        end
                        msgBytes[14] = bit.bor(msgBytes[14], 0x01)
                    end
                    if (control["screen_light"]) then
                        msgBytes[12] = 0x1F
                        msgBytes[13] = control["screen_light"]
                    end
                    if (control["morning_night_bash"]) then
                        msgBytes[12] = 0x21
                        msgBytes[13] = control["morning_night_bash"]
                    end
                end
            else
                for i = 11, 30 do msgBytes[i] = 0x00 end
                msgBytes[11] = 0x04
                msgBytes[12] = 0x01
                if ((control["eplus"] and (control["eplus"] == "on" or control["eplus"] == 1)) or (status["eplus"] and status["eplus"] == "on" and control["eplus"] == nil)) then msgBytes[13] =
                    bit.bor(msgBytes[13], 0x01) end
                if ((control["fast_wash"] and (control["fast_wash"] == "on" or control["fast_wash"] == 1)) or (status["fast_wash"] and status["fast_wash"] == "on" and control["fast_wash"] == nil)) then msgBytes[13] =
                    bit.bor(msgBytes[13], 0x02) end
                if ((control["summer"] and (control["summer"] == "on" or control["summer"] == 1)) or (status["summer"] and status["summer"] == "on" and control["summer"] == nil)) then msgBytes[13] =
                    bit.bor(msgBytes[13], 0x04) end
                if ((control["winter"] and (control["winter"] == "on" or control["winter"] == 1)) or (status["winter"] and status["winter"] == "on" and control["winter"] == nil)) then msgBytes[13] =
                    bit.bor(msgBytes[13], 0x08) end
                if ((control["efficient"] and (control["efficient"] == "on" or control["efficient"] == 1)) or (status["efficient"] and status["efficient"] == "on" and control["efficient"] == nil)) then msgBytes[13] =
                    bit.bor(msgBytes[13], 0x10) end
                if ((control["night"] and (control["night"] == "on" or control["night"] == 1)) or (status["night"] and status["night"] == "on" and control["night"] == nil)) then msgBytes[13] =
                    bit.bor(msgBytes[13], 0x20) end
                if (control["bath_person"] == nil and status["bath_person"]) then if (status["bath_person"] == "one_person") then msgBytes[14] =
                        bit.bor(msgBytes[14], 0x01) elseif (status["bath_person"] == "two_person") then msgBytes[14] =
                        bit.bor(msgBytes[14], 0x02) elseif (status["bath_person"] == "three_person") then msgBytes[14] =
                        bit.bor(msgBytes[14], 0x04) elseif (status["bath_person"] == "old_man") then msgBytes[14] = bit
                        .bor(msgBytes[14], 0x08) elseif (status["bath_person"] == "adult") then msgBytes[14] = bit.bor(
                        msgBytes[14], 0x10) elseif (status["bath_person"] == "children") then msgBytes[14] = bit.bor(
                        msgBytes[14], 0x20) end elseif (control["bath_person"]) then if (control["bath_person"] == "one_person") then msgBytes[14] =
                        bit.bor(msgBytes[14], 0x01) elseif (control["bath_person"] == "two_person") then msgBytes[14] =
                        bit.bor(msgBytes[14], 0x02) elseif (control["bath_person"] == "three_person") then msgBytes[14] =
                        bit.bor(msgBytes[14], 0x04) elseif (control["bath_person"] == "old_man") then msgBytes[14] = bit
                        .bor(msgBytes[14], 0x08) elseif (control["bath_person"] == "adult") then msgBytes[14] = bit.bor(
                        msgBytes[14], 0x10) elseif (control["bath_person"] == "children") then msgBytes[14] = bit.bor(
                        msgBytes[14], 0x20) end end
                if ((control["cloud"] and (control["cloud"] == "on" or control["cloud"] == 1)) or (status["cloud"] and status["cloud"] == "on" and control["cloud"] == nil)) then msgBytes[14] =
                    bit.bor(msgBytes[14], 0x40) end
                if ((control["custom"] and (control["custom"] == "on" or control["custom"] == 1)) or (status["custom"] and status["custom"] == "on" and control["custom"] == nil)) then msgBytes[14] =
                    bit.bor(msgBytes[14], 0x80) end
                if ((control["wash"] and (control["wash"] == "on" or control["wash"] == 1)) or (status["wash"] and status["wash"] == "on" and control["wash"] == nil)) then msgBytes[15] =
                    bit.bor(msgBytes[15], 0x10) end
                if ((control["shower"] and (control["shower"] == "on" or control["shower"] == 1)) or (status["shower"] and status["shower"] == "on" and control["shower"] == nil)) then msgBytes[15] =
                    bit.bor(msgBytes[15], 0x20) end
                if ((control["bath"] and (control["bath"] == "on" or control["bath"] == 1)) or (status["bath"] and status["bath"] == "on" and control["bath"] == nil)) then msgBytes[15] =
                    bit.bor(msgBytes[15], 0x40) end
                if ((control["memory"] and (control["memory"] == "on" or control["memory"] == 1)) or (status["memory"] and status["memory"] == "on" and control["memory"] == nil)) then msgBytes[15] =
                    bit.bor(msgBytes[15], 0x80) end
                if ((control["sterilization"] and (control["sterilization"] == "on" or control["sterilization"] == 1)) or (status["sterilization"] and status["sterilization"] == "on" and control["sterilization"] == nil)) then msgBytes[20] =
                    bit.bor(msgBytes[20], 0x02) end
                if (control["mode"]) then
                    msgBytes[13] = 0x00
                    msgBytes[14] = 0x00
                    msgBytes[15] = bit.band(msgBytes[15], 0x0f)
                    msgBytes[20] = bit.band(msgBytes[20], 0xfd)
                    if (control["mode"] == "eplus") then msgBytes[13] = 0x01 elseif (control["mode"] == "fast_wash") then msgBytes[13] = 0x02 elseif (control["mode"] == "summer") then msgBytes[13] = 0x04 elseif (control["mode"] == "winter") then msgBytes[13] = 0x08 elseif (control["mode"] == "efficient") then msgBytes[13] = 0x10 elseif (control["mode"] == "night") then msgBytes[13] = 0x20 elseif (control["mode"] == "sterilization") then msgBytes[20] = 0x02 elseif (control["mode"] == "one_person") then msgBytes[14] = 0x01 elseif (control["mode"] == "two_person") then msgBytes[14] = 0x02 elseif (control["mode"] == "three_person") then msgBytes[14] = 0x04 elseif (control["mode"] == "old_man") then msgBytes[14] = 0x08 elseif (control["mode"] == "adult") then msgBytes[14] = 0x10 elseif (control["mode"] == "children") then msgBytes[14] = 0x20 elseif (control["mode"] == "cloud") then msgBytes[14] = 0x40 elseif (control["mode"] == "custom") then msgBytes[14] = 0x80 elseif (control["mode"] == "wash") then msgBytes[15] = 0x10 elseif (control["mode"] == "shower") then msgBytes[15] = 0x20 elseif (control["mode"] == "bath") then msgBytes[15] = 0x40 elseif (control["mode"] == "memory") then msgBytes[15] = 0x80 end
                end
                if ((control["half_heat"] and (control["half_heat"] == "on" or control["half_heat"] == 1)) or (status["half_heat"] and status["half_heat"] == "on" and control["half_heat"] == nil and control["heat"] == nil)) then msgBytes[15] =
                    bit.bor(msgBytes[15], 0x01) end
                if ((control["whole_heat"] and (control["whole_heat"] == "on" or control["whole_heat"] == 1)) or (status["whole_heat"] and status["whole_heat"] == "on" and control["whole_heat"] == nil and control["heat"] == nil)) then msgBytes[15] =
                    bit.bor(msgBytes[15], 0x02) end
                if (control["heat"]) then if (control["heat"] == "whole") then msgBytes[15] = bit.bor(msgBytes[15], 0x02) elseif (control["heat"] == "half") then msgBytes[15] =
                        bit.bor(msgBytes[15], 0x01) end end
                if ((control["protect"] and (control["protect"] == "on" or control["protect"] == 1)) or (status["protect"] and status["protect"] == "on" and control["protect"] == nil)) then msgBytes[15] =
                    bit.bor(msgBytes[15], 0x04) end
                if ((control["safe"] and (control["safe"] == "on" or control["safe"] == 1)) or (status["safe"] and status["safe"] == "on" and control["safe"] == nil)) then msgBytes[15] =
                    bit.bor(msgBytes[15], 0x08) end
                if (status["temperature"] and control["temperature"] == nil) then msgBytes[16] = status["temperature"] elseif (control["temperature"]) then
                    if (control["custom"] == nil) then
                        msgBytes[13] = 0x00
                        msgBytes[14] = 0x80
                        msgBytes[15] = bit.band(msgBytes[15], 0x0f)
                        msgBytes[20] = bit.band(msgBytes[20], 0xfd)
                    end
                    msgBytes[16] = control["temperature"]
                end
                if ((control["filter_reset"] and (control["filter_reset"] == "on" or control["filter_reset"] == 1)) or (status["filter_reset"] and status["filter_reset"] == "on" and control["filter_reset"] == nil)) then msgBytes[19] =
                    bit.bor(msgBytes[19], 0x01) end
                if ((control["mg_reset_part"] and (control["mg_reset_part"] == "on" or control["mg_reset_part"] == 1)) or (status["mg_reset_part"] and status["mg_reset_part"] == "on" and control["mg_reset_part"] == nil)) then msgBytes[19] =
                    bit.bor(msgBytes[19], 0x02) end
                if ((control["egg_reset"] and (control["egg_reset"] == "on" or control["egg_reset"] == 1)) or (status["egg_reset"] and status["egg_reset"] == "on" and control["egg_reset"] == nil)) then msgBytes[19] =
                    bit.bor(msgBytes[19], 0x04) end
                if ((control["clean"] and (control["clean"] == "on" or control["clean"] == 1)) or (status["clean"] and status["clean"] == "on" and control["clean"] == nil)) then msgBytes[19] =
                    bit.bor(msgBytes[19], 0x08) end
                if ((control["negative_ions"] and (control["negative_ions"] == "on" or control["negative_ions"] == 1)) or (status["negative_ions"] and status["negative_ions"] == "on" and control["negative_ions"] == nil)) then msgBytes[20] =
                    bit.bor(msgBytes[20], 0x01) end
                if ((control["sleep"] and (control["sleep"] == "on" or control["sleep"] == 1)) or (status["sleep"] and status["sleep"] == "on" and control["sleep"] == nil)) then msgBytes[20] =
                    bit.bor(msgBytes[20], 0x04) end
                if ((control["screen_off"] and (control["screen_off"] == "on" or control["screen_off"] == 1)) or (status["screen_off"] and status["screen_off"] == "on" and control["screen_off"] == nil)) then msgBytes[20] =
                    bit.bor(msgBytes[20], 0x08) end
                if ((control["frequency_hot"] and (control["frequency_hot"] == "on" or control["frequency_hot"] == 1)) or (status["frequency_hot"] and status["frequency_hot"] == "on" and control["frequency_hot"] == nil)) then msgBytes[20] =
                    bit.bor(msgBytes[20], 0x10) end
                if ((control["big_water"] and (control["big_water"] == "on" or control["big_water"] == 1)) or (status["big_water"] and status["big_water"] == "on" and control["big_water"] == nil)) then msgBytes[20] =
                    bit.bor(msgBytes[20], 0x20) end
                if ((control["t_hot"] and (control["t_hot"] == "on" or control["t_hot"] == 1)) or (status["t_hot"] and status["t_hot"] == "on" and control["t_hot"] == nil)) then msgBytes[20] =
                    bit.bor(msgBytes[20], 0x40) end
                if (control["scene"] and (control["scene"] == "on" or control["scene"] == 1)) then msgBytes[20] = bit
                    .bor(msgBytes[20], 0x80) end
                if (status["scene_id"] and control["scene_id"] == nil) then msgBytes[21] = status["scene_id"] elseif (control["scene_id"]) then msgBytes[21] =
                    control["scene_id"] end
                if ((control["auto_off"] and (control["auto_off"] == "on" or control["auto_off"] == 1)) or (status["auto_off"] and status["auto_off"] == "on" and control["auto_off"] == nil)) then msgBytes[22] =
                    bit.bor(msgBytes[22], 0x01) end
                if ((control["set_bath_temp"] and (control["set_bath_temp"] == "on" or control["set_bath_temp"] == 1)) or (status["set_bath_temp"] and status["set_bath_temp"] == "on" and control["set_bath_temp"] == nil)) then msgBytes[22] =
                    bit.bor(msgBytes[22], 0x02) end
                if ((control["mom_wash"] and (control["mom_wash"] == "on" or control["mom_wash"] == 1)) or (status["mom_wash"] and status["mom_wash"] == "on" and control["mom_wash"] == nil)) then msgBytes[22] =
                    bit.bor(msgBytes[22], 0x04) end
                if ((control["dad_wash"] and (control["dad_wash"] == "on" or control["dad_wash"] == 1)) or (status["dad_wash"] and status["dad_wash"] == "on" and control["dad_wash"] == nil)) then msgBytes[22] =
                    bit.bor(msgBytes[22], 0x08) end
                if ((control["baby_wash"] and (control["baby_wash"] == "on" or control["baby_wash"] == 1)) or (status["baby_wash"] and status["baby_wash"] == "on" and control["baby_wash"] == nil)) then msgBytes[22] =
                    bit.bor(msgBytes[22], 0x10) end
                if (status["wash_temperature"] and control["wash_temperature"] == nil) then msgBytes[23] = status
                    ["wash_temperature"] elseif (control["wash_temperature"]) then msgBytes[23] = control
                    ["wash_temperature"] end
                if (control["grea"]) then msgBytes[24] = bit.band(control["grea"], 0xff) end
            end end
        if (control["appoint0"] ~= nil or control["appoint1"] ~= nil or control["appoint2"] ~= nil) then
            for i = 11, 20 do msgBytes[i] = 0x00 end
            local ap
            if (control["appoint0"] ~= nil) then
                msgBytes[11] = 0x05
                ap = Split(control["appoint0"], ",")
            elseif (control["appoint1"] ~= nil) then
                msgBytes[11] = 0x06
                ap = Split(control["appoint1"], ",")
            elseif (control["appoint2"] ~= nil) then
                msgBytes[11] = 0x07
                ap = Split(control["appoint2"], ",")
            end
            msgBytes[12] = 0x01
            for k, v in pairs(ap) do if (k == 1) then if (tonumber(v) == 1) then msgBytes[13] = 0xff else msgBytes[13] = 0x00 end else msgBytes[k + 12] =
                    tonumber(v) end end
        end
    elseif (query) then
        msgBytes[10] = 0x03
        if (query["query_type"] == "appoint_query") then msgBytes[11] = 0x02 else msgBytes[11] = 0x01 end
        msgBytes[12] = 0x01
    end
    return msgBytes
end
local function parseByteToJson(status, bodyBytes)
    if ((bodyBytes[10] == 0x02 and bodyBytes[11] == 0x01) or (bodyBytes[10] == 0x02 and bodyBytes[11] == 0x02) or (bodyBytes[10] == 0x02 and bodyBytes[11] == 0x04) or (bodyBytes[10] == 0x02 and bodyBytes[11] == 0x14) or (bodyBytes[10] == 0x03 and bodyBytes[11] == 0x01) or (bodyBytes[10] == 0x04 and bodyBytes[11] == 0x01)) then
        status["mode"] = "none"
        if (bodyBytes[13] and bit.band(bodyBytes[13], 0x01) == 0x01) then status["power"] = "on" else status["power"] =
            "off" end
        if (bodyBytes[13] and bit.band(bodyBytes[13], 0x02) == 0x02) then status["fast_hot_power"] = "on" else status["fast_hot_power"] =
            "off" end
        if (bodyBytes[13] and bit.band(bodyBytes[13], 0x04) == 0x04) then status["hot_power"] = "on" else status["hot_power"] =
            "off" end
        if (bodyBytes[13] and bit.band(bodyBytes[13], 0x08) == 0x08) then status["warm_power"] = "on" else status["warm_power"] =
            "off" end
        if (bodyBytes[13] and bit.band(bodyBytes[13], 0x10) == 0x10) then status["water_flow"] = "on" else status["water_flow"] =
            "off" end
        if (bodyBytes[13] and bit.band(bodyBytes[13], 0x20) == 0x20) then status["negative_ions"] = "on" else status["negative_ions"] =
            "off" end
        if (bodyBytes[13] and bit.band(bodyBytes[13], 0x40) == 0x40) then
            status["sterilization"] = "on"
            status["mode"] = "sterilization"
        else status["sterilization"] = "off" end
        if (bodyBytes[13] and bit.band(bodyBytes[13], 0x80) == 0x80) then status["frequency_hot"] = "on" else status["frequency_hot"] =
            "off" end
        status["error_code"] = tonumber(bodyBytes[14])
        status["cur_temperature"] = tonumber(bodyBytes[15])
        status["heat_water_level"] = tonumber(bodyBytes[16])
        status["flow"] = tonumber(bodyBytes[17])
        if (bodyBytes[18] and bit.band(bodyBytes[18], 0x01) == 0x01) then
            status["eplus"] = "on"
            status["mode"] = "eplus"
        else status["eplus"] = "off" end
        if (bodyBytes[18] and bit.band(bodyBytes[18], 0x02) == 0x02) then
            status["fast_wash"] = "on"
            status["mode"] = "fast_wash"
        else status["fast_wash"] = "off" end
        if (bodyBytes[18] and bit.band(bodyBytes[18], 0x04) == 0x04) then status["half_heat"] = "on" else status["half_heat"] =
            "off" end
        if (bodyBytes[18] and bit.band(bodyBytes[18], 0x08) == 0x08) then status["whole_heat"] = "on" else status["whole_heat"] =
            "off" end
        if (bodyBytes[18]) then if (bit.band(bodyBytes[18], 0x08) == 0x08) then status["heat"] = "whole" elseif (bit.band(bodyBytes[18], 0x04) == 0x04) then status["heat"] =
                "half" else status["heat"] = "none" end end
        if (bodyBytes[18] and bit.band(bodyBytes[18], 0x10) == 0x10) then
            status["summer"] = "on"
            status["mode"] = "summer"
        else status["summer"] = "off" end
        if (bodyBytes[18] and bit.band(bodyBytes[18], 0x20) == 0x20) then
            status["winter"] = "on"
            status["mode"] = "winter"
        else status["winter"] = "off" end
        if (bodyBytes[18] and bit.band(bodyBytes[18], 0x40) == 0x40) then
            status["efficient"] = "on"
            status["mode"] = "efficient"
        else status["efficient"] = "off" end
        if (bodyBytes[18] and bit.band(bodyBytes[18], 0x80) == 0x80) then
            status["night"] = "on"
            status["mode"] = "night"
        else status["night"] = "off" end
        if (bodyBytes[19]) then if (bit.band(bodyBytes[19], 0x07) == 0x06) then
                status["bath_person"] = "children"
                status["mode"] = "children"
            elseif (bit.band(bodyBytes[19], 0x07) == 0x05) then
                status["bath_person"] = "adult"
                status["mode"] = "adult"
            elseif (bit.band(bodyBytes[19], 0x07) == 0x04) then
                status["bath_person"] = "old_man"
                status["mode"] = "old_man"
            elseif (bit.band(bodyBytes[19], 0x07) == 0x03) then
                status["bath_person"] = "three_person"
                status["mode"] = "three_person"
            elseif (bit.band(bodyBytes[19], 0x07) == 0x02) then
                status["bath_person"] = "two_person"
                status["mode"] = "two_person"
            elseif (bit.band(bodyBytes[19], 0x07) == 0x01) then
                status["bath_person"] = "one_person"
                status["mode"] = "one_person"
            else status["bath_person"] = "off" end end
        if (bodyBytes[19] and bit.band(bodyBytes[19], 0x08) == 0x08) then status["screen_off"] = "on" else status["screen_off"] =
            "off" end
        if (bodyBytes[19] and bit.band(bodyBytes[19], 0x10) == 0x10) then status["sleep"] = "on" else status["sleep"] =
            "off" end
        if (bodyBytes[19] and bit.band(bodyBytes[19], 0x20) == 0x20) then
            status["cloud"] = "on"
            status["mode"] = "cloud"
        else status["cloud"] = "off" end
        if (bodyBytes[19] and bit.band(bodyBytes[19], 0x40) == 0x40) then status["appoint_wash"] = "on" else status["appoint_wash"] =
            "off" end
        if (bodyBytes[19] and bit.band(bodyBytes[19], 0x80) == 0x80) then status["now_wash"] = "on" else status["now_wash"] =
            "off" end
        status["end_time_hour"] = tonumber(bodyBytes[20])
        status["end_time_minute"] = tonumber(bodyBytes[21])
        status["temperature"] = tonumber(bodyBytes[22])
        if (bodyBytes[23] and bit.band(bodyBytes[23], 0x01) == 0x01) then status["get_time"] = "on" else status["get_time"] =
            "off" end
        if (bodyBytes[23] and bit.band(bodyBytes[23], 0x02) == 0x02) then status["get_temp"] = "on" else status["get_temp"] =
            "off" end
        if (bodyBytes[23] and bit.band(bodyBytes[23], 0x04) == 0x04) then status["func_select"] = "middle" else status["func_select"] =
            "low" end
        if (bodyBytes[23] and bit.band(bodyBytes[23], 0x10) == 0x10) then status["type_select"] = "valve" else status["type_select"] =
            "normal" end
        if (bodyBytes[23] and bit.band(bodyBytes[23], 0x20) == 0x20) then status["smart_sterilize"] = "on" else status["smart_sterilize"] =
            "off" end
        if (bodyBytes[23] and bit.band(bodyBytes[23], 0x40) == 0x40) then status["sterilize_high_temp"] = "on" else status["sterilize_high_temp"] =
            "off" end
        if (bodyBytes[23] and bit.band(bodyBytes[23], 0x80) == 0x80) then status["uv_sterilize"] = "on" else status["uv_sterilize"] =
            "off" end
        status["discharge_status"] = tonumber(bodyBytes[24])
        status["top_temp"] = tonumber(bodyBytes[25])
        if (bodyBytes[26] and bit.band(bodyBytes[26], 0x01) == 0x01) then status["bottom_heat"] = "on" else status["bottom_heat"] =
            "off" end
        if (bodyBytes[26] and bit.band(bodyBytes[26], 0x02) == 0x02) then status["top_heat"] = "on" else status["top_heat"] =
            "off" end
        if (bodyBytes[26] and bit.band(bodyBytes[26], 0x04) == 0x04) then status["show_h"] = "on" else status["show_h"] =
            "off" end
        if (bodyBytes[26] and bit.band(bodyBytes[26], 0x08) == 0x08) then status["need_discharge"] = "on" else status["need_discharge"] =
            "off" end
        if (bodyBytes[26] and bit.band(bodyBytes[26], 0x10) == 0x10) then status["machine"] = "empty_machine" else status["machine"] =
            "real_machine" end
        if (bodyBytes[26] and bit.band(bodyBytes[26], 0x20) == 0x20) then status["elec_warning"] = "on" else status["elec_warning"] =
            "off" end
        if (bodyBytes[26] and bit.band(bodyBytes[26], 0x40) == 0x40) then status["bottom_temp"] = "on" else status["bottom_temp"] =
            "off" end
        if (bodyBytes[26] and bit.band(bodyBytes[26], 0x80) == 0x80) then status["water_cyclic"] = "on" else status["water_cyclic"] =
            "off" end
        status["water_system"] = tonumber(bodyBytes[27])
        status["discharge_left_time"] = tonumber(bodyBytes[28])
        status["in_temperature"] = tonumber(bodyBytes[29])
        status["mg_remain"] = tonumber(bodyBytes[30])
        status["waterday_lowbyte"] = tonumber(bodyBytes[31])
        status["waterday_highbyte"] = tonumber(bodyBytes[32])
        if (bodyBytes[33] and bit.band(bodyBytes[33], 0x01) == 0x01) then status["tech_water"] = "on" else status["tech_water"] =
            "off" end
        if (bodyBytes[33] and bit.band(bodyBytes[33], 0x02) == 0x02) then status["protect"] = "on" else status["protect"] =
            "off" end
        if (bodyBytes[33] and bit.band(bodyBytes[33], 0x04) == 0x04) then status["safe"] = "on" else status["safe"] =
            "off" end
        if (bodyBytes[33] and bit.band(bodyBytes[33], 0x08) == 0x08) then status["protect_show"] = "on" else status["protect_show"] =
            "off" end
        if (bodyBytes[33] and bit.band(bodyBytes[33], 0x10) == 0x10) then status["appoint_power"] = "on" else status["appoint_power"] =
            "off" end
        if (bodyBytes[33] and bit.band(bodyBytes[33], 0x20) == 0x20) then status["music"] = "on" else status["music"] =
            "off" end
        if (bodyBytes[33] and bit.band(bodyBytes[33], 0x40) == 0x40) then status["ti_protect"] = "on" else status["ti_protect"] =
            "off" end
        if (bodyBytes[33] and bit.band(bodyBytes[33], 0x80) == 0x80) then status["scroll_hot"] = "on" else status["scroll_hot"] =
            "off" end
        if (bodyBytes[34] and bit.band(bodyBytes[34], 0x01) == 0x01) then
            status["wash"] = "on"
            status["mode"] = "wash"
        else status["wash"] = "off" end
        if (bodyBytes[34] and bit.band(bodyBytes[34], 0x01) == 0x01) then status["wash_with_temp"] = "on" else status["wash_with_temp"] =
            "off" end
        if (bodyBytes[34] and bit.band(bodyBytes[34], 0x02) == 0x02) then
            status["shower"] = "on"
            status["mode"] = "shower"
        else status["shower"] = "off" end
        if (bodyBytes[34] and bit.band(bodyBytes[34], 0x04) == 0x04) then
            status["bath"] = "on"
            status["mode"] = "bath"
        else status["bath"] = "off" end
        if (bodyBytes[34] and bit.band(bodyBytes[34], 0x08) == 0x08) then
            status["memory"] = "on"
            status["mode"] = "memory"
        else status["memory"] = "off" end
        if (bodyBytes[34] and bit.band(bodyBytes[34], 0x10) == 0x10) then status["midea_manager"] = "on" else status["midea_manager"] =
            "off" end
        if (bodyBytes[34] and bit.band(bodyBytes[34], 0x20) == 0x20) then status["big_water"] = "on" else status["big_water"] =
            "off" end
        if (bodyBytes[34] and bit.band(bodyBytes[34], 0x40) == 0x40) then status["ali_manager"] = "on" else status["ali_manager"] =
            "off" end
        if (bodyBytes[34] and bit.band(bodyBytes[34], 0x80) == 0x80) then status["cloud_appoint"] = "on" else status["cloud_appoint"] =
            "off" end
        status["passwater_lowbyte"] = tonumber(bodyBytes[35])
        status["passwater_highbyte"] = tonumber(bodyBytes[36])
        status["water_quality"] = tonumber(bodyBytes[37])
        status["volume"] = tonumber(bodyBytes[38])
        status["rate"] = tonumber(bodyBytes[39])
        if (bodyBytes[40] and bit.band(bodyBytes[40], 0x01) == 0x01) then status["t_hot"] = "on" else status["t_hot"] =
            "off" end
        if (bodyBytes[40] and bit.band(bodyBytes[40], 0x02) == 0x02) then status["clean"] = "on" else status["clean"] =
            "off" end
        if (bodyBytes[40] and bit.band(bodyBytes[40], 0x04) == 0x04) then status["scene"] = "on" else status["scene"] =
            "off" end
        if (bodyBytes[40] and bit.band(bodyBytes[40], 0x08) == 0x08) then status["auto_off"] = "on" else status["auto_off"] =
            "off" end
        if (bodyBytes[40] and bit.band(bodyBytes[40], 0x10) == 0x10) then status["ele_exception"] = "on" else status["ele_exception"] =
            "off" end
        if (bodyBytes[40] and bit.band(bodyBytes[40], 0x20) == 0x20) then status["mom_wash"] = "on" else status["mom_wash"] =
            "off" end
        if (bodyBytes[40] and bit.band(bodyBytes[40], 0x40) == 0x40) then status["dad_wash"] = "on" else status["dad_wash"] =
            "off" end
        if (bodyBytes[40] and bit.band(bodyBytes[40], 0x80) == 0x80) then status["baby_wash"] = "on" else status["baby_wash"] =
            "off" end
        status["scene_id"] = tonumber(bodyBytes[41])
        status["wash_temperature"] = tonumber(bodyBytes[42])
        status["grea"] = tonumber(bodyBytes[43])
        if (bodyBytes[44] and bit.band(bodyBytes[44], 0x01) == 0x01) then status["sensor_error"] = "on" else status["sensor_error"] =
            "off" end
        if (bodyBytes[44] and bit.band(bodyBytes[44], 0x02) == 0x02) then status["limit_error"] = "on" else status["limit_error"] =
            "off" end
        if (bodyBytes[44] and bit.band(bodyBytes[44], 0x04) == 0x04) then status["single_wash"] = "on" else status["single_wash"] =
            "off" end
        if (bodyBytes[44] and bit.band(bodyBytes[44], 0x08) == 0x08) then status["people_wash"] = "on" else status["people_wash"] =
            "off" end
        if (bodyBytes[44] and bit.band(bodyBytes[44], 0x10) == 0x10) then status["one_egg"] = "on" else status["one_egg"] =
            "off" end
        if (bodyBytes[44] and bit.band(bodyBytes[44], 0x20) == 0x20) then status["two_egg"] = "on" else status["two_egg"] =
            "off" end
        if (bodyBytes[44] and bit.band(bodyBytes[44], 0x40) == 0x40) then status["always_fell"] = "on" else status["always_fell"] =
            "off" end
        if (bodyBytes[44] and bit.band(bodyBytes[44], 0x80) == 0x80) then status["communication_error"] = "on" else status["communication_error"] =
            "off" end
        if (bodyBytes[45]) then status["cur_rate"] = tonumber(bodyBytes[45]) end
        if (bodyBytes[46]) then status["sterilize_left_days"] = tonumber(bodyBytes[46]) end
        if (bodyBytes[47]) then status["sterilize_cycle_index"] = tonumber(bodyBytes[47]) end
        if (bodyBytes[48]) then status["uv_sterilize_minute"] = tonumber(bodyBytes[48]) end
        if (bodyBytes[49]) then status["uv_sterilize_second"] = tonumber(bodyBytes[49]) end
        if (bodyBytes[50] and bit.band(bodyBytes[50], 0x01) == 0x01) then status["sound_dad"] = "on" else status["sound_dad"] =
            "off" end
        if (bodyBytes[50]) then status["screen_light"] = tonumber(bit.band(bodyBytes[50], 0x1E)) end
        if (bodyBytes[51] and bit.band(bodyBytes[51], 0x01) == 0x01) then status["door_status"] = "on" else status["door_status"] =
            "off" end
        if (bodyBytes[51]) then status["morning_night_bash"] = tonumber(bit.band(bodyBytes[51], 0x06) / 2) end
        if (bodyBytes[52]) then status["tds_value"] = tonumber(bodyBytes[52]) end
    elseif ((bodyBytes[10] == 0x02 and bodyBytes[11] == 0x05) or (bodyBytes[10] == 0x02 and bodyBytes[11] == 0x06) or (bodyBytes[10] == 0x02 and bodyBytes[11] == 0x07) or (bodyBytes[10] == 0x03 and bodyBytes[11] == 0x02)) then
        if (bit.band(bodyBytes[13], 0x01) == 0x01) then status["appoint0"] = "1," else status["appoint0"] = "0," end
        if (bit.band(bodyBytes[13], 0x02) == 0x02) then status["appoint1"] = "1," else status["appoint1"] = "0," end
        if (bit.band(bodyBytes[13], 0x04) == 0x04) then status["appoint2"] = "1," else status["appoint2"] = "0," end
        status["appoint0"] = status["appoint0"] ..
        tostring(bodyBytes[14]) ..
        "," .. tostring(bodyBytes[15]) .. "," .. tostring(bodyBytes[16]) .. "," .. tostring(bodyBytes[17])
        status["appoint1"] = status["appoint1"] ..
        tostring(bodyBytes[18]) ..
        "," .. tostring(bodyBytes[19]) .. "," .. tostring(bodyBytes[20]) .. "," .. tostring(bodyBytes[21])
        status["appoint2"] = status["appoint2"] ..
        tostring(bodyBytes[22]) ..
        "," .. tostring(bodyBytes[23]) .. "," .. tostring(bodyBytes[24]) .. "," .. tostring(bodyBytes[25])
    end
    status["version"] = VALUE_VERSION
    return status
end
function jsonToData(jsonCmdStr)
    if (#jsonCmdStr == 0) then return nil end
    local result
    if JSON == nil then JSON = require "cjson" end
    result = JSON.decode(jsonCmdStr)
    if result == nil then return end
    local msgBytes = { 0xAA, 0x00, 0xE2, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 }
    msgBytes = assembleByteFromJson(result, msgBytes)
    local len = #msgBytes
    msgBytes[2] = len
    msgBytes[len + 1] = makeSum(msgBytes, 2, len)
    local ret = table2string(msgBytes)
    ret = string2hexstring(ret)
    return ret
end

function dataToJson(cmdStr)
    if (not cmdStr) then return nil end
    local result
    if JSON == nil then JSON = require "cjson" end
    result = JSON.decode(cmdStr)
    if result == nil then return end
    local binData = result["msg"]["data"]
    local ret = {}
    ret["status"] = {}
    local bodyBytes = string2table(binData)
    ret["status"] = parseByteToJson(ret["status"], bodyBytes)
    local ret = JSON.encode(ret)
    return ret
end
