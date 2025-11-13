-- 协议解析文件描述，根据实际情况修正
-- author : nixj8
--        : xiewb
-- email  : wenbin.xie@midea.com
-- date   : 2024/05/31
-- 0xC3   : 86X Controller
-- 修改记录
-- 2023-11-16 创建修改记录
-- 2023-11-18 dataToJson 不再返回全部字段
-- 2023-11-18 jsonToData 强制更新关联值
-- 2024-01-04 修改名称接口
-- 2024-01-10 修改SN的字节数
-- 2024-02-21 修复周定时，星期的结果返回"Sun,Mon,",要为“Sun,Mon"
-- 2024-05-31 �·�������������10�ֽڱ���ͷ
-- 2024-06-03 �·�������ѯ��������10�ֽڱ���ͷ
-- 必须要引入的库

local test        = 0
local lua_version = { 0, 0, 130}
local idu_addr = 0
if test >= 2 then
    --package.cpath = '/usr/lib/x86_64-linux-gnu/lua/5.4/?.so;'
    bit           = require "bit"
end
local JSON = require "cjson"
local function io_debug(data)
    if test >= 3 then
        io.write(data)
    end
end

local function io_msg(data)
    if test >= 2 then
        local layout_num = 1
        local pad        = ''
        for i = 10, 1, -1 do
            if nil ~= debug.getinfo(i) and nil ~= debug.getinfo(i).name then
                layout_num = i
                break
            end
        end
        for i = 1, layout_num - 1 do
            pad = pad .. '  '
        end

        if string.sub(data, -string.len('\n')) ~= '\n' then
            io.write(pad .. '  ' .. data)
            return
        end
        if layout_num >= 2 then
            io.write(pad .. debug.getinfo(2).name .. ' ' .. data)
        else
            io.write(pad .. data)
        end
    end
end

local function io_err(data)
    if test >= 1 then
        io.write(data)
    end
end

-- 协议相关常量，请勿修改

-- 控制请求
local BYTE_CONTROL_REQUEST = 0x02
-- 查询请求
local BYTE_QUERY_REQUEST   = 0x03
-- 协议头
local BYTE_PROTOCOL_HEAD   = 0xAA
-- 协议头长度
local BYTE_PROTOCOL_LENGTH = 0x0A

-- 公共属性值，预定义的值，请勿修改
-- 属性值为未知值时，使用此值。
local VALUE_UNKNOWN        = "unknown"
-- 属性值为无效值时，使用此值。
local VALUE_INVALID        = "invalid"



-- 协议相关变量,此部分根据实际需要修改，但是local变量的个数不能超过60个，若超过，请使用table封装变量。

-- 数据返回类型，02:控制返回, 03:查询返回, 04:主动上报, 05:主动上报(需要响应), 06:设备异常事件上报。
-- 子命令（若有）


-- nixj8 add
local language             = { supported = "CH,EN", current = "CH" }

-- nixj8 add done


--公共的函数，请勿随意修改。

-- 从电控协议(byteData)中提取消息体(body)，返回的消息体数组索引从0开始。
local function extractBodyBytes(byteData)
    local msgLength = #byteData
    local msgBytes  = {}
    local bodyBytes = {}
    for i = 1, msgLength do
        msgBytes[i - 1] = byteData[i]
    end
    --去掉消息头和校验码就剩下消息体
    local bodyLength = msgLength - BYTE_PROTOCOL_LENGTH - 1
    --获取消息体 body 部分
    for i = 0, bodyLength - 1 do
        bodyBytes[i] = msgBytes[i + BYTE_PROTOCOL_LENGTH]
    end
    return bodyBytes
end

-- 计算校验和
local function makeSum(tmpbuf, start_pos, end_pos)
    local resVal = 0
    for si = start_pos, end_pos do
        resVal = resVal + tmpbuf[si]
    end
    resVal = bit.bnot(resVal) + 1
    resVal = bit.band(resVal, 0x00ff)
    return resVal
end

-- CRC码表
local crc8_854_table = {
    0, 94, 188, 226, 97, 63, 221, 131, 194, 156, 126, 32, 163, 253, 31, 65,
    157, 195, 33, 127, 252, 162, 64, 30, 95, 1, 227, 189, 62, 96, 130, 220,
    35, 125, 159, 193, 66, 28, 254, 160, 225, 191, 93, 3, 128, 222, 60, 98,
    190, 224, 2, 92, 223, 129, 99, 61, 124, 34, 192, 158, 29, 67, 161, 255,
    70, 24, 250, 164, 39, 121, 155, 197, 132, 218, 56, 102, 229, 187, 89, 7,
    219, 133, 103, 57, 186, 228, 6, 88, 25, 71, 165, 251, 120, 38, 196, 154,
    101, 59, 217, 135, 4, 90, 184, 230, 167, 249, 27, 69, 198, 152, 122, 36,
    248, 166, 68, 26, 153, 199, 37, 123, 58, 100, 134, 216, 91, 5, 231, 185,
    140, 210, 48, 110, 237, 179, 81, 15, 78, 16, 242, 172, 47, 113, 147, 205,
    17, 79, 173, 243, 112, 46, 204, 146, 211, 141, 111, 49, 178, 236, 14, 80,
    175, 241, 19, 77, 206, 144, 114, 44, 109, 51, 209, 143, 12, 82, 176, 238,
    50, 108, 142, 208, 83, 13, 239, 177, 240, 174, 76, 18, 145, 207, 45, 115,
    202, 148, 118, 40, 171, 245, 23, 73, 8, 86, 180, 234, 105, 55, 213, 139,
    87, 9, 235, 181, 54, 104, 138, 212, 149, 203, 41, 119, 244, 170, 72, 22,
    233, 183, 85, 11, 136, 214, 52, 106, 43, 117, 151, 201, 74, 20, 246, 168,
    116, 42, 200, 150, 21, 75, 169, 247, 182, 232, 10, 84, 215, 137, 107, 53
}

-- CRC校验码
local function crc8_854(dataBuf, start_pos, end_pos)
    local crc = 0

    for si = start_pos, end_pos do
        crc = crc8_854_table[bit.band(bit.bxor(crc, dataBuf[si]), 0xFF) + 1]
    end

    return crc
end

-- 将json字符串转换为LUA中的table
local function decodeJsonToTable(cmd)
    local tb

    if JSON == nil then
        JSON = require "cjson"
    end

    tb = JSON.decode(cmd)

    return tb
end

-- 将LUA中的table转换为json字符串
local function encodeTableToJson(luaTable)
    local jsonStr

    if JSON == nil then
        JSON = require "cjson"
    end

    jsonStr = JSON.encode(luaTable)

    return jsonStr
end

-- 将十六进制string字符串转成LUA中的table
local function string2table(hexstr)
    local tb = {}
    local i  = 1
    local j  = 1

    for i = 1, #hexstr - 1, 2 do
        local doublebytestr = string.sub(hexstr, i, i + 1)
        tb[j]               = tonumber(doublebytestr, 16)
        j                   = j + 1
    end

    return tb
end

-- ��ʮ������string�ַ���ת��LUA�е�table
local function string2tableFromZero(hexstr)
    local tb = {}
    local i  = 1
    local j  = 0

    for i = 1, #hexstr - 1, 2 do
        local doublebytestr = string.sub(hexstr, i, i + 1)
        tb[j]               = tonumber(doublebytestr, 16)
        j                   = j + 1
    end
    print("string2table",tb[0],tb[1],tb[2])
    return tb
end

-- 将table转成字符串
local function table2string(cmd)
    local ret = ""
    local i

    for i = 1, #cmd do
        ret = ret .. string.char(cmd[i])
    end

    return ret
end

-- 将字符串转成十六进制字符串输出
local function string2hexstring(str)
    local ret = ""

    for i = 1, #str do
        ret = ret .. string.format("%02x", str:byte(i))
    end

    return ret
end

-- 检查data的值是否超过边界
local function checkBoundary(data, min, max)
    if (not data) then
        data = 0
    end

    data = tonumber(data)

    if ((data >= min) and (data <= max)) then
        return data
    else
        if (data < min) then
            return min
        else
            return max
        end
    end
end

-- 将String转int
local function string2Int(data)
    if (not data) then
        data = tonumber("0")
    end
    data = tonumber(data)
    if (data == nil) then
        data = 0
    end
    return data
end

-- 将int转String
local function int2String(data)
    if (not data) then
        data = tostring(0)
    end
    data = tostring(data)
    if (data == nil) then
        data = "0"
    end
    return data
end

-- 打印table表
local function print_lua_table(lua_table, indent)
    indent = indent or 0

    for k, v in pairs(lua_table) do
        if type(k) == "string" then
            k = string.format("%q", k)
        end

        local szSuffix = ""

        if type(v) == "table" then
            szSuffix = "{"
        end

        local szPrefix = string.rep("    ", indent)
        formatting     = szPrefix .. "[" .. k .. "]" .. " = " .. szSuffix

        if type(v) == "table" then
            io_msg(formatting)

            print_lua_table(v, indent + 1)

            io_msg(szPrefix .. "},")
        else
            local szValue = ""

            if type(v) == "string" then
                szValue = string.format("%q", v)
            else
                szValue = tostring(v)
            end

            io_msg(formatting .. szValue .. ",")
        end
    end
end


-- 1.��bodyBytes��װ�ϵ��Э��ͷ(10�ֽ�)��β��У����(1�ֽ�)��
-- 2.����� bodyBytes Ϊ������0��ʼ��
-- 3.���ص� table ����Ҳ��0��ʼ��
local function assembleUart(bodyBytes, type)
    local bodyLength = #bodyBytes + 1
    if bodyLength == 0 then
        return nil
    end

    local msgLength = (bodyLength + BYTE_PROTOCOL_LENGTH + 1)
    local msgBytes  = {}

    for i = 0, msgLength - 1 do
        msgBytes[i] = 0
    end
    --������Ϣ����
    msgBytes[0] = BYTE_PROTOCOL_HEAD
    msgBytes[1] = msgLength - 1
    msgBytes[2] = 0xCC
    msgBytes[9] = type

    for i = 0, bodyLength - 1 do
        msgBytes[i + BYTE_PROTOCOL_LENGTH] = bodyBytes[i]
    end

    msgBytes[msgLength - 1] = makeSum(msgBytes, 1, msgLength - 2)
    return msgBytes
end


-- 根据电控协议不同，需要改变的函数
local key_map_value = {
    ['sche_mode'] = { [1] = "poweroff", [2] = "fan", [3] = "cool", [4] = "heat", [6] = "auto", [7] = "dry", [117] = "poweron" },
    ['mode'] = { [2] = "fan", [3] = "cool", [4] = "heat", [6] = "auto", [7] = "dry" },
    ['wind_speed'] = { [1] = '0', [2] = '1', [3] = '2', [4] = '3', [5] = '4', [6] = '5', [7] = '6', [8] = '7', [9] = 'auto' },
    ['area_name'] = {[1] = "metting room",[2] = "lobby",[3] = "hallway",[4] = "classroom",[5] = "room",
                    [6] = "living room",[7] = "restaurant",[8] = "office",[9] = "ward",[10] = "workshop",[11] = "lab",[12] = "warehouse",[256] = "none",},
    ['direction_name'] = {[1] = "east",[2] = "south",[3] = "west",[4] = "north",[5] = "southeast",[6] = "northeast",[7] = "southwest",
                        [8] = "northwest",[256] = "none",},
    ['serial_name'] = {[1] = "0",[2] = "1",[3] = "2",[4] = "3",[5] = "4",[6] = "5",[7] = "6",
                            [8] = "7",[9] = "8", [256] = "none"},
}


-- nixj8 add
local key_maps     = {
    -- 消息体子命令类型0x01 ：基本控制/查询 回复 /基本上报 命令
    { idx = 0, changed = 0, value = { 1 }, size = 1, path = "power", value_map = { [1] = "off", [2] = "on" } },

	--/*温度设置*/
	{ idx = 1, changed = 0, value = { 114 }, size = 1, path = "temperature_min", value_type = "temp" },
	{ idx = 2, changed = 0, value = { 140 }, size = 1, path = "temperature_max", value_type = "temp"  },
	{ idx = 3, changed = 0, value = { 132 }, size = 1, path = "temperature_current", value_type = "temp" },
	{ idx = 4, changed = 0, value = {0xFFFF}, size = 2, path = "temperature_room", value_type = "temp_10s" },
	{ idx = 5, changed = 0, value = { 132 },  size = 1, path = "temperature_outside", value_type = "temp" },
	{ idx = 6, changed = 0, value = { 114 },  size = 1, path = "temperature_range_cool_min" ,value_type = "temp"},
    { idx = 7, changed = 0, value = { 140 },  size = 1, path = "temperature_range_cool_max" ,value_type = "temp"},
    { idx = 8, changed = 0, value = { 114 },  size = 1, path = "temperature_range_heat_min" ,value_type = "temp"},
    { idx = 9, changed = 0, value = { 140 },  size = 1, path = "temperature_range_heat_max" ,value_type = "temp"},
	{ idx = 10, changed = 0, value = { 114 },  size = 1, path = "temperature_auto_min", value_type = "temp"  },
    { idx = 11, changed = 0, value = { 140 },  size = 1, path = "temperature_auto_max", value_type = "temp"  },
	{ idx = 12, changed = 0, value = { 1 },    size = 1, path = "temp_unit", value_map = { [1] = "C", [2] = "F" }  },
	{ idx = 13, changed = 0, value = { 1 },    size = 1, path = "temp_accurate", value_map = { [1] = "1", [2] = "0.5" }  },

	--/*湿度设置*/
	{ idx = 14, changed = 0, value = { 1 },    size = 1, path = "humidification_enable", value_map = { [1] = "false", [2] = "true" } },
    { idx = 15, changed = 0, value = { 65 },   size = 1, path = "humidification_value",  },
	{ idx = 16, changed = 0, value = { 65 },   size = 1, path = "humidification_room", },

    --/*模式设置*/
	{ idx =  17, changed = 0, value = { 2, 6 }, size = 5, path = "mode_supported", value_map = key_map_value['mode'] },
	{ idx =  18, changed = 0, value = { 3 },    size = 1, path = "mode_current", value_map = key_map_value['mode']  },

	--/*风速控制*/
	{ idx =  19, changed = 0, value = { 1 },    size = 1, path = "wind_speed_enable", value_map = { [1] = "false", [2] = "true" } },
    { idx =  20, changed = 0, value = { 8 },    size = 1, path = "wind_speed_max", value_map = { [8] = "7", [4] = "3" } },
	{ idx =  21, changed = 0, value = { 2 },    size = 1, path = "wind_speed_level", value_map = { [2] = '1', [3] = '2', [4] = '3', [5] = '4', [6] = '5', [7] = '6', [8] = '7', [9] = 'auto' }   },

	--/*摇摆控制*/
	{ idx =  22, changed = 0, value = { 1 },    size = 1, path = "swing_multiple", value_map = { [1] = "false", [2] = "true" } },
    { idx =  23, changed = 0, value = { 1 },    size = 1, path = "swing_louver1", value_map = { [13] = "close", [1] = 'close', [2] = '1', [3] = '2', [4] = '3', [5] = '4', [6] = '5', [7] = 'auto' }  },
    { idx =  24, changed = 0, value = { 1 },    size = 1, path = "swing_louver2", value_map = { [13] = "close", [1] = 'close', [2] = '1', [3] = '2', [4] = '3', [5] = '4', [6] = '5', [7] = 'auto' }  },
    { idx =  25, changed = 0, value = { 1 },    size = 1, path = "swing_louver3", value_map = { [13] = "close", [1] = 'close', [2] = '1', [3] = '2', [4] = '3', [5] = '4', [6] = '5', [7] = 'auto' }  },
    { idx =  26, changed = 0, value = { 1 },    size = 1, path = "swing_louver4", value_map = { [13] = "close", [1] = 'close', [2] = '1', [3] = '2', [4] = '3', [5] = '4', [6] = '5', [7] = 'auto' }  },
    { idx =  27, changed = 0, value = { 1 },    size = 1, path = "swing_louver_vertical_enable", value_map = { [1] = "false", [2] = "true" } },
    { idx =  28, changed = 0, value = { 3 },    size = 1, path = "swing_louver_vertical_level", value_map = { [13] = "close", [1] = 'close', [2] = '1', [3] = '2', [4] = '3', [5] = '4', [6] = '5', [7] = 'auto' }  },
    { idx =  29, changed = 0, value = { 1 },    size = 1, path = "swing_louver_horizontal_enable", value_map = { [1] = "false", [2] = "true" } },
    { idx =  30, changed = 0, value = { 1 },    size = 1, path = "swing_louver_horizontal_level", value_map = { [13] = "close", [1] = 'close', [2] = '1', [3] = '2', [4] = '3', [5] = '4', [6] = '5', [7] = 'auto' }  },

	--/*AQI-空气质量*/
	-- { idx =  31, changed = 0, value = { 1 },    size = 1, path = "aqi_enable ", value_map = { [1] = "false", [2] = "true" } },
	--{ idx =  32, changed = 0, value = { 65 },   size = 2, path = "aqi_value",value_type = "uint16_t"  },
    --/*��п���*/
    { idx =  31, changed = 0, value = { 1 },    size = 1, path = "wind_feeling_enable", value_map = { [1] = "false", [2] = "true" } },
    { idx =  32, changed = 0, value = { 1 },    size = 1, path = "wind_feeling_current", value_map = {[1] = "close", [2] = "follow", [3] = "avoid", [4] = "soft", [5] = "strong"} },

    { idx =  33, changed = 0, value = { 1 },    size = 1, path = "cur_fault_enable", value_map = { [1] = "false", [2] = "true" } },
    { idx =  34, changed = 0, value = { 48 },   size = 3, path = "cur_fault_code", value_type = "chars" },

    { idx =  35, changed = 0, value = { 1 },    size = 1, path = "back_up_code", value_map = { [1] = "0", [2] = "T1", [3] = "T2", [5] = "T2B", [9] = "T2A" } },
    { idx =  36, changed = 0, value = { 48 },   size = 1, path = "back_up_status", value_map = { [1] = "off", [2] = "on", [3] = "unset" } },
	--/*pm2.5*/
	--{ idx =  33, changed = 0, value = { 1 },    size = 1, path = "pm25_enable", value_map = { [1] = "false", [2] = "true" } },
    --{ idx =  34, changed = 0, value = { 100 },  size = 2, path = "pm25_value", value_type = "uint16_t" },

	--/*Co2*/
	{ idx =  37, changed = 0, value = { 1 },    size = 1, path = "co2_enable", value_map = { [1] = "false", [2] = "true" } },
    { idx =  38, changed = 0, value = { 100 },  size = 2, path = "co2_value", value_type = "uint16_t" },

	--/*强劲模式*/
	--{ idx =  37, changed = 0, value = { 1 },    size = 1, path = "strong_enable", value_map = { [1] = "false", [2] = "true" } },
    --{ idx =  38, changed = 0, value = { 1 },    size = 1, path = "strong_status", value_map = { [1] = "off", [2] = "on" }  },
	--/*ECO功能*/
	{ idx =  39, changed = 0, value = { 1 },    size = 1, path = "eco_enable", value_map = { [1] = "false", [2] = "true" } },
    { idx =  40, changed = 0, value = { 1 },    size = 1, path = "eco_status", value_map = { [1] = "off", [2] = "on" }  },
	--/*静音功能*/
	{ idx =  41, changed = 0, value = { 1 },    size = 1, path = "idu_silent_enable", value_map = { [1] = "false", [2] = "true" } },
    { idx =  42, changed = 0, value = { 1 },    size = 1, path = "idu_silent_status", value_map = { [1] = "off", [2] = "on" }  },
	--/*睡眠功能*/
	{ idx =  43, changed = 0, value = { 1 },    size = 1, path = "idu_sleep_enable", value_map = { [1] = "false", [2] = "true" } },
    { idx =  44, changed = 0, value = { 1 },    size = 1, path = "idu_sleep_status", value_map = { [1] = "off", [2] = "on" }  },
    --/*自清洁*/
	{ idx =  45, changed = 0, value = { 1 },    size = 1, path = "selfclean_enable", value_map = { [1] = "false", [2] = "true" } },
    { idx =  46, changed = 0, value = { 1 },    size = 1, path = "selfclean_status", value_map = { [1] = "off", [2] = "on" }  },
	{ idx =  47, changed = 0, value = {0xFFFF}, size = 2, path = "selfclean_time_left", value_type = "uint16_t" },
	--/*人感节能*/
	{ idx =  48, changed = 0, value = { 1 },   size = 1, path = "energy_saving_human_type", value_map = { [1] = "nobody_off", [2] = "nobody_temp",[3] = "none" }  },
	{ idx =  49, changed = 0, value = { 15 },  size = 1, path = "energy_saving_nobody_off_delay",value_map = { [1] = "15", [2] = "30", [3] = "45", [4] = "60", [5] = "90", [6] = "120" }  },
	{ idx =  50, changed = 0, value = { 3 },   size = 1, path = "energy_nobody_temp_time_interval" ,value_map = { [1] = "15", [2] = "30", [3] = "45", [4] = "60", [5] = "90", [6] = "120" }  },
	{ idx =  51, changed = 0, value = { 3 },   size = 1, path = "energy_nobody_temp_max" , value_type = "uint8_t" },
	--/*离家模式setBack*/
	{ idx =  52, changed = 0, value = { 1 },    size = 1, path = "leave_home_enable", value_map = { [1] = "false", [2] = "true" } },
    { idx =  53, changed = 0, value = { 1 },    size = 1, path = "leave_home_status", value_map = { [1] = "off", [2] = "on" }  },
    { idx =  54, changed = 0, value = { 132 },  size = 1, path = "leave_home_temperature_max", value_type = "temp"  },
    { idx =  55, changed = 0, value = { 132 },  size = 1, path = "leave_home_temperature_min", value_type = "temp"  },
	-- /*杀菌功能*/
	{ idx =  56, changed = 0, value = { 1 },    size = 1, path = "sterilize_enable", value_map = { [1] = "false", [2] = "true" } },
    { idx =  57, changed = 0, value = { 1 },    size = 1, path = "sterilize_auto_enable", value_map = { [1] = "false", [2] = "true" }  },
	{ idx =  58, changed = 0, value = { 1 },    size = 1, path = "sterilize_status", value_map = { [1] = "auto", [2] = "on", [3] = "off" }  },
	--/*性能衰减等级*/
	{ idx =  59, changed = 0, value = { 1 },    size = 1, path = "system_decay_enable", value_map = { [1] = "false", [2] = "true" }  },
	{ idx =  60, changed = 0, value = { 3 },    size = 1, path = "system_decay_level" ,value_type = "uint8_t"},
	--/*内机脏堵等级*/
	{ idx =  61, changed = 0, value = { 1 },    size = 1, path = "idu_filter_enable", value_map = { [1] = "false", [2] = "true" }   },
	{ idx =  62, changed = 0, value = { 1 },    size = 1, path = "idu_filter_level" ,value_type = "uint8_t"},
	--/*室内机蜂鸣器*/
	{ idx =  63, changed = 0, value = { 1 },    size = 1, path = "idu_beep", value_map = { [1] = "off", [2] = "on" }  },
	--/*室内机显示板灯光*/
	{ idx =  64, changed = 0, value = { 1 },    size = 1, path = "idu_light", value_map = { [1] = "off", [2] = "on" }  },

	--/*室内机显示板接收遥控接收功能*/
-- 	{ idx =  65, changed = 0, value = { 1 },    size = 1, path = "idu_remote", value_map = { [1] = "off", [2] = "on" } },

	--/*电辅热功能*/
	{ idx =  65, changed = 0, value = { 1 },    size = 1, path = "ptc_enable", value_map = { [1] = "false", [2] = "true" } },
    { idx =  66, changed = 0, value = {1,2,3},  size = 4, path = "ptc_supported", value_map = { [1] = "auto", [2] = "on", [3] = "off", [4] = "separate" } },
	{ idx =  67, changed = 0, value = { 1 },    size = 1, path = "ptc_status", value_map = { [1] = "auto", [2] = "on", [3] = "off", [4] = "separate" }  },
	--/*气流群控*/
	{ idx =  68, changed = 0, value = { 1 },    size = 1, path = "airflow_group_control_type", value_map = { [1] = "custom1", [2] = "custom2",[3] = "soft",[4] = "whole_house",[5] = "close"}  },
	{ idx =  69, changed = 0, value = { 1 },    size = 1, path = "airflow_group_control_custom1_type", value_map = { [1] = "type1", [2] = "type2", [3] = "none"}  },
	{ idx =  70, changed = 0, value = { 1 },    size = 1, path = "airflow_group_custom1_type2_updown", value_map = { [13] = "close", [1] = 'close', [2] = '1', [3] = '2', [4] = '3', [5] = '4', [6] = '5', [7] = 'auto' }  },
	{ idx =  71, changed = 0, value = { 1 },    size = 1, path = "airflow_group_custom1_type2_leftright", value_map = { [13] = "close", [1] = 'close', [2] = '1', [3] = '2', [4] = '3', [5] = '4', [6] = '5', [7] = 'auto' }  },
    { idx =  72, changed = 0, value = { 1 },    size = 1, path = "airflow_group_control_custom2_type", value_map = { [1] = "type1", [2] = "type2", [3] = "none"}  },
	{ idx =  73, changed = 0, value = { 1 },    size = 1, path = "airflow_group_custom2_type2_updown", value_map = { [13] = "close", [1] = 'close', [2] = '1', [3] = '2', [4] = '3', [5] = '4', [6] = '5', [7] = 'auto' }  },
	{ idx =  74, changed = 0, value = { 1 },    size = 1, path = "airflow_group_custom2_type2_leftright", value_map = { [13] = "close", [1] = 'close', [2] = '1', [3] = '2', [4] = '3', [5] = '4', [6] = '5', [7] = 'auto' }  },
	--/*语言选择*/
	{ idx =  75, changed = 0, value = { 1 },    size = 4, path = "language_supported", value_map = { [1] = "CH", [2] = "EN" } },
    { idx =  76, changed = 0, value = { 2 },    size = 1, path = "language_current", value_map = { [1] = "CH", [2] = "EN" }  },
	--/*meta*/
	{ idx =  77, changed = 0, value = { 1 },    size = 1, path = "meta_enable", value_map = { [1] = "false", [2] = "true" } },
    { idx =  78, changed = 0, value = { 1 },    size = 1, path = "meta_status", value_map = { [1] = "off", [2] = "on" }  },
	--/*错误码*/
	{ idx =  79, changed = 0, value = { 1 },    size = 1, path = "cur_fault_enable", value_map = { [1] = "false", [2] = "true" } },
    { idx =  80, changed = 0, value = { 48 },   size = 6, path = "cur_fault_code", value_type = "chars" },
	--/*系统诊断*/
	{ idx =  81, changed = 0, value = { 1 },    size = 1, path = "diagnose_status", value_map = { [1] = "off", [2] = "on" } },
	--/*线控器信息*/
	{ idx =  82, changed = 0, value = {0,0,21}, size = 3, path = "about_version", value_type = "version" },
	{ idx =  83, changed = 2, value=lua_version,size = 3, path = "about_lua_version", value_type = "version" },
	--/*滤网提醒*/
	{ idx =  84, changed = 0, value = { 1 },    size = 1, path = "filter_notification_enable", value_map = { [1] = "false", [2] = "true" } },
    { idx =  85, changed = 0, value = { 1 },    size = 1, path = "filter_notification_status", value_map = { [1] = "off", [2] = "on" }  },
	--/*日期与时间设置*/
	{ idx =  86, changed = 0, value = { 60 },   size = 4, path = "date_seconds", value_type = 'uint32_t'  },
	--/*定时开关*/
	{ idx =  87, changed = 0, value = {   1 },  size = 1, path = "timer_on_enable", value_map = { [1] = "false", [2] = "true" }  ,},
	{ idx =  88, changed = 0, value = {   0 },  size = 2, path = "timer_on_timeout" ,value_type = 'uint16_t' },
	{ idx =  89, changed = 0, value = {   1 },  size = 1, path = "timer_off_enable", value_map = { [1] = "false", [2] = "true" }  ,},
	{ idx =  90, changed = 0, value = {   0 },  size = 2, path = "timer_off_timeout" ,value_type = 'uint16_t' },
	--/*周定时-延时关机*/
	{ idx =  91, changed = 0, value = {   1 },  size = 1, path = "schedule_week_override_enable", value_map = { [1] = "false", [2] = "true" }  },
	{ idx =  92, changed = 0, value = {   0 },  size = 1, path = "schedule_week_override_time" ,value_map = { [1] = 30, [2] = 60, [3] = 90, [4] = 120, [5] = 180, [6] = 240 }  ,},
	{ idx =  93, changed = 0, value = {   0 },  size = 1, path = "schedule_week_override_left" ,value_type = "uint8_t" },
	--/*周定时1*/
	{ idx =  94,  changed = 0, value = {   1 },  size = 1, path = "schedule_week_template0_enable", value_map = { [1] = "false", [2] = "true" } , },
    { idx =  95,  changed = 0, value = {   0 },  size = 2, path = "schedule_week_template0_weekday", value_type = 'weekday' , },
    { idx =  96,  changed = 0, value = {   1 },  size = 1, path = "schedule_week_template0_action0_enable", value_map = { [1] = "false", [2] = "true" } , },
	{ idx =  97,  changed = 0, value = {   0 },  size = 1, path = "schedule_week_template0_action0_min" ,value_type = "min" ,},
    { idx =  98,  changed = 0, value = {   0 },  size = 1, path = "schedule_week_template0_action0_hour" ,value_type = "hour" ,},
	{ idx =  99,  changed = 0, value = { 132 },  size = 1, path = "schedule_week_template0_action0_temp", value_type = "temp" , },
	{ idx =  100, changed = 0, value = { 132 },  size = 1, path = "schedule_week_template0_action0_temp_heat", value_type = "temp" , },
    { idx =  101, changed = 0, value = {   2 },  size = 1, path = "schedule_week_template0_action0_fan", value_map = key_map_value['wind_speed']  ,},
	{ idx =  102, changed = 0, value = {   2 },  size = 1, path = "schedule_week_template0_action0_mode", value_map = key_map_value["sche_mode"]  ,},

    { idx =  103, changed = 0, value = {   1 },  size = 1, path = "schedule_week_template0_action1_enable", value_map = { [1] = "false", [2] = "true" } , },
	{ idx =  104, changed = 0, value = {   0 },  size = 1, path = "schedule_week_template0_action1_min" ,value_type = "min" ,},
    { idx =  105, changed = 0, value = {   0 },  size = 1, path = "schedule_week_template0_action1_hour" ,value_type = "hour" ,},
	{ idx =  106, changed = 0, value = { 132 },  size = 1, path = "schedule_week_template0_action1_temp", value_type = "temp" , },
	{ idx =  107, changed = 0, value = { 132 },  size = 1, path = "schedule_week_template0_action1_temp_heat", value_type = "temp" , },
    { idx =  108, changed = 0, value = {   2 },  size = 1, path = "schedule_week_template0_action1_fan", value_map = key_map_value['wind_speed']  ,},
	{ idx =  109, changed = 0, value = {   2 },  size = 1, path = "schedule_week_template0_action1_mode", value_map = key_map_value["sche_mode"]  ,},

    { idx =  110, changed = 0, value = {   1 },  size = 1, path = "schedule_week_template0_action2_enable", value_map = { [1] = "false", [2] = "true" } , },
	{ idx =  111, changed = 0, value = {   0 },  size = 1, path = "schedule_week_template0_action2_min" ,value_type = "min" ,},
    { idx =  112, changed = 0, value = {   0 },  size = 1, path = "schedule_week_template0_action2_hour" ,value_type = "hour" ,},
	{ idx =  113, changed = 0, value = { 132 },  size = 1, path = "schedule_week_template0_action2_temp", value_type = "temp" , },
	{ idx =  114, changed = 0, value = { 132 },  size = 1, path = "schedule_week_template0_action2_temp_heat", value_type = "temp" , },
    { idx =  115, changed = 0, value = {   2 },  size = 1, path = "schedule_week_template0_action2_fan", value_map = key_map_value['wind_speed']  ,},
	{ idx =  116, changed = 0, value = {   2 },  size = 1, path = "schedule_week_template0_action2_mode", value_map = key_map_value["sche_mode"]  ,},

    { idx =  117, changed = 0, value = {   1 },  size = 1, path = "schedule_week_template0_action3_enable", value_map = { [1] = "false", [2] = "true" } , },
	{ idx =  118, changed = 0, value = {   0 },  size = 1, path = "schedule_week_template0_action3_min" ,value_type = "min" ,},
    { idx =  119, changed = 0, value = {   0 },  size = 1, path = "schedule_week_template0_action3_hour" ,value_type = "hour" ,},
	{ idx =  120, changed = 0, value = { 132 },  size = 1, path = "schedule_week_template0_action3_temp", value_type = "temp" , },
	{ idx =  121, changed = 0, value = { 132 },  size = 1, path = "schedule_week_template0_action3_temp_heat", value_type = "temp" , },
    { idx =  122, changed = 0, value = {   2 },  size = 1, path = "schedule_week_template0_action3_fan", value_map = key_map_value['wind_speed']  ,},
	{ idx =  123, changed = 0, value = {   2 },  size = 1, path = "schedule_week_template0_action3_mode", value_map = key_map_value["sche_mode"]  ,},

	{ idx =  124, changed = 0, value = {   1 },  size = 1, path = "schedule_week_template0_action4_enable", value_map = { [1] = "false", [2] = "true" } , },
	{ idx =  125, changed = 0, value = {   0 },  size = 1, path = "schedule_week_template0_action4_min" ,value_type = "min" ,},
    { idx =  126, changed = 0, value = {   0 },  size = 1, path = "schedule_week_template0_action4_hour" ,value_type = "hour" ,},
	{ idx =  127, changed = 0, value = { 132 },  size = 1, path = "schedule_week_template0_action4_temp", value_type = "temp" , },
	{ idx =  128, changed = 0, value = { 132 },  size = 1, path = "schedule_week_template0_action4_temp_heat", value_type = "temp" , },
    { idx =  129, changed = 0, value = {   2 },  size = 1, path = "schedule_week_template0_action4_fan", value_map = key_map_value['wind_speed']  ,},
	{ idx =  130, changed = 0, value = {   2 },  size = 1, path = "schedule_week_template0_action4_mode", value_map = key_map_value["sche_mode"]  ,},

	--/*周定时2*/
	{ idx =  131, changed = 0, value = {   1 },  size = 1, path = "schedule_week_template1_enable", value_map = { [1] = "false", [2] = "true" } , },
    { idx =  132, changed = 0, value = {   0 },  size = 2, path = "schedule_week_template1_weekday", value_type = 'weekday' , },
    { idx =  133, changed = 0, value = {   1 },  size = 1, path = "schedule_week_template1_action0_enable", value_map = { [1] = "false", [2] = "true" } , },
	{ idx =  134, changed = 0, value = {   0 },  size = 1, path = "schedule_week_template1_action0_min" ,value_type = "min" ,},
    { idx =  135, changed = 0, value = {   0 },  size = 1, path = "schedule_week_template1_action0_hour" ,value_type = "hour" ,},
	{ idx =  136, changed = 0, value = { 132 },  size = 1, path = "schedule_week_template1_action0_temp", value_type = "temp" , },
	{ idx =  137, changed = 0, value = { 132 },  size = 1, path = "schedule_week_template1_action0_temp_heat", value_type = "temp" , },
    { idx =  138, changed = 0, value = {   2 },  size = 1, path = "schedule_week_template1_action0_fan", value_map = key_map_value['wind_speed']  ,},
	{ idx =  139, changed = 0, value = {   2 },  size = 1, path = "schedule_week_template1_action0_mode", value_map = key_map_value["sche_mode"]  ,},

    { idx =  140, changed = 0, value = {   1 },  size = 1, path = "schedule_week_template1_action1_enable", value_map = { [1] = "false", [2] = "true" } , },
	{ idx =  141, changed = 0, value = {   0 },  size = 1, path = "schedule_week_template1_action1_min" ,value_type = "min" ,},
    { idx =  142, changed = 0, value = {   0 },  size = 1, path = "schedule_week_template1_action1_hour" ,value_type = "hour" ,},
	{ idx =  143, changed = 0, value = { 132 },  size = 1, path = "schedule_week_template1_action1_temp", value_type = "temp" , },
	{ idx =  144, changed = 0, value = { 132 },  size = 1, path = "schedule_week_template1_action1_temp_heat", value_type = "temp" , },
    { idx =  145, changed = 0, value = {   2 },  size = 1, path = "schedule_week_template1_action1_fan", value_map = key_map_value['wind_speed']  ,},
	{ idx =  146, changed = 0, value = {   2 },  size = 1, path = "schedule_week_template1_action1_mode", value_map = key_map_value["sche_mode"]  ,},

    { idx =  147, changed = 0, value = {   1 },  size = 1, path = "schedule_week_template1_action2_enable", value_map = { [1] = "false", [2] = "true" } , },
	{ idx =  148, changed = 0, value = {   0 },  size = 1, path = "schedule_week_template1_action2_min" ,value_type = "min" ,},
    { idx =  149, changed = 0, value = {   0 },  size = 1, path = "schedule_week_template1_action2_hour" ,value_type = "hour" ,},
	{ idx =  150, changed = 0, value = { 132 },  size = 1, path = "schedule_week_template1_action2_temp", value_type = "temp" , },
	{ idx =  151, changed = 0, value = { 132 },  size = 1, path = "schedule_week_template1_action2_temp_heat", value_type = "temp" , },
    { idx =  152, changed = 0, value = {   2 },  size = 1, path = "schedule_week_template1_action2_fan", value_map = key_map_value['wind_speed']  ,},
	{ idx =  153, changed = 0, value = {   2 },  size = 1, path = "schedule_week_template1_action2_mode", value_map = key_map_value["sche_mode"]  ,},

    { idx =  154, changed = 0, value = {   1 },  size = 1, path = "schedule_week_template1_action3_enable", value_map = { [1] = "false", [2] = "true" } , },
	{ idx =  155, changed = 0, value = {   0 },  size = 1, path = "schedule_week_template1_action3_min" ,value_type = "min" ,},
    { idx =  156, changed = 0, value = {   0 },  size = 1, path = "schedule_week_template1_action3_hour" ,value_type = "hour" ,},
	{ idx =  157, changed = 0, value = { 132 },  size = 1, path = "schedule_week_template1_action3_temp", value_type = "temp" , },
	{ idx =  158, changed = 0, value = { 132 },  size = 1, path = "schedule_week_template1_action3_temp_heat", value_type = "temp" , },
    { idx =  159, changed = 0, value = {   2 },  size = 1, path = "schedule_week_template1_action3_fan", value_map = key_map_value['wind_speed']  ,},
	{ idx =  160, changed = 0, value = {   2 },  size = 1, path = "schedule_week_template1_action3_mode", value_map = key_map_value["sche_mode"]  ,},

	{ idx =  161, changed = 0, value = {   1 },  size = 1, path = "schedule_week_template1_action4_enable", value_map = { [1] = "false", [2] = "true" } , },
	{ idx =  162, changed = 0, value = {   0 },  size = 1, path = "schedule_week_template1_action4_min" ,value_type = "min" ,},
    { idx =  163, changed = 0, value = {   0 },  size = 1, path = "schedule_week_template1_action4_hour" ,value_type = "hour" ,},
	{ idx =  164, changed = 0, value = { 132 },  size = 1, path = "schedule_week_template1_action4_temp", value_type = "temp" , },
	{ idx =  165, changed = 0, value = { 132 },  size = 1, path = "schedule_week_template1_action4_temp_heat", value_type = "temp" , },
    { idx =  166, changed = 0, value = {   2 },  size = 1, path = "schedule_week_template1_action4_fan", value_map = key_map_value['wind_speed']  ,},
	{ idx =  167, changed = 0, value = {   2 },  size = 1, path = "schedule_week_template1_action4_mode", value_map = key_map_value["sche_mode"]  ,},

	--/*周定时3*/
	{ idx =  168, changed = 0, value = {   1 },  size = 1, path = "schedule_week_template2_enable", value_map = { [1] = "false", [2] = "true" } , },
    { idx =  169, changed = 0, value = {   0 },  size = 2, path = "schedule_week_template2_weekday", value_type = 'weekday' , },
    { idx =  170, changed = 0, value = {   1 },  size = 1, path = "schedule_week_template2_action0_enable", value_map = { [1] = "false", [2] = "true" } , },
	{ idx =  171, changed = 0, value = {   0 },  size = 1, path = "schedule_week_template2_action0_min" ,value_type = "min" ,},
    { idx =  172, changed = 0, value = {   0 },  size = 1, path = "schedule_week_template2_action0_hour" ,value_type = "hour" ,},
	{ idx =  173, changed = 0, value = { 132 },  size = 1, path = "schedule_week_template2_action0_temp", value_type = "temp" , },
	{ idx =  174, changed = 0, value = { 132 },  size = 1, path = "schedule_week_template2_action0_temp_heat", value_type = "temp" , },
    { idx =  175, changed = 0, value = {   2 },  size = 1, path = "schedule_week_template2_action0_fan", value_map = key_map_value['wind_speed']  ,},
	{ idx =  176, changed = 0, value = {   2 },  size = 1, path = "schedule_week_template2_action0_mode", value_map = key_map_value["sche_mode"]  ,},

    { idx =  177, changed = 0, value = {   1 },  size = 1, path = "schedule_week_template2_action1_enable", value_map = { [1] = "false", [2] = "true" } , },
	{ idx =  178, changed = 0, value = {   0 },  size = 1, path = "schedule_week_template2_action1_min" ,value_type = "min" ,},
    { idx =  179, changed = 0, value = {   0 },  size = 1, path = "schedule_week_template2_action1_hour" ,value_type = "hour" ,},
	{ idx =  180, changed = 0, value = { 132 },  size = 1, path = "schedule_week_template2_action1_temp", value_type = "temp" , },
	{ idx =  181, changed = 0, value = { 132 },  size = 1, path = "schedule_week_template2_action1_temp_heat", value_type = "temp" , },
    { idx =  182, changed = 0, value = {   2 },  size = 1, path = "schedule_week_template2_action1_fan", value_map = key_map_value['wind_speed']  ,},
	{ idx =  183, changed = 0, value = {   2 },  size = 1, path = "schedule_week_template2_action1_mode", value_map = key_map_value["sche_mode"]  ,},

    { idx =  184, changed = 0, value = {   1 },  size = 1, path = "schedule_week_template2_action2_enable", value_map = { [1] = "false", [2] = "true" } , },
	{ idx =  185, changed = 0, value = {   0 },  size = 1, path = "schedule_week_template2_action2_min" ,value_type = "min" ,},
    { idx =  186, changed = 0, value = {   0 },  size = 1, path = "schedule_week_template2_action2_hour" ,value_type = "hour" ,},
	{ idx =  187, changed = 0, value = { 132 },  size = 1, path = "schedule_week_template2_action2_temp", value_type = "temp" , },
	{ idx =  188, changed = 0, value = { 132 },  size = 1, path = "schedule_week_template2_action2_temp_heat", value_type = "temp" , },
    { idx =  189, changed = 0, value = {   2 },  size = 1, path = "schedule_week_template2_action2_fan", value_map = key_map_value['wind_speed']  ,},
	{ idx =  190, changed = 0, value = {   2 },  size = 1, path = "schedule_week_template2_action2_mode", value_map = key_map_value["sche_mode"]  ,},

    { idx =  191, changed = 0, value = {   1 },  size = 1, path = "schedule_week_template2_action3_enable", value_map = { [1] = "false", [2] = "true" } , },
	{ idx =  192, changed = 0, value = {   0 },  size = 1, path = "schedule_week_template2_action3_min" ,value_type = "min" ,},
    { idx =  193, changed = 0, value = {   0 },  size = 1, path = "schedule_week_template2_action3_hour" ,value_type = "hour" ,},
	{ idx =  194, changed = 0, value = { 132 },  size = 1, path = "schedule_week_template2_action3_temp", value_type = "temp" , },
	{ idx =  195, changed = 0, value = { 132 },  size = 1, path = "schedule_week_template2_action3_temp_heat", value_type = "temp" , },
    { idx =  196, changed = 0, value = {   2 },  size = 1, path = "schedule_week_template2_action3_fan", value_map = key_map_value['wind_speed']  ,},
	{ idx =  197, changed = 0, value = {   2 },  size = 1, path = "schedule_week_template2_action3_mode", value_map = key_map_value["sche_mode"]  ,},

	{ idx =  198, changed = 0, value = {   1 },  size = 1, path = "schedule_week_template2_action4_enable", value_map = { [1] = "false", [2] = "true" } , },
	{ idx =  199, changed = 0, value = {   0 },  size = 1, path = "schedule_week_template2_action4_min" ,value_type = "min" ,},
    { idx =  200, changed = 0, value = {   0 },  size = 1, path = "schedule_week_template2_action4_hour" ,value_type = "hour" ,},
	{ idx =  201, changed = 0, value = { 132 },  size = 1, path = "schedule_week_template2_action4_temp", value_type = "temp" , },
	{ idx =  202, changed = 0, value = { 132 },  size = 1, path = "schedule_week_template2_action4_temp_heat", value_type = "temp" , },
    { idx =  203, changed = 0, value = {   2 },  size = 1, path = "schedule_week_template2_action4_fan", value_map = key_map_value['wind_speed']  ,},
	{ idx =  204, changed = 0, value = {   2 },  size = 1, path = "schedule_week_template2_action4_mode", value_map = key_map_value["sche_mode"]  ,},


	--/*简易周定时*/
	{ idx = 205, changed = 0, value = {   1 },  size = 1, path = "schedule_week_template_simple_enable", value_map = { [1] = "false", [2] = "true" }  },
    { idx = 206, changed = 0, value = {   0 },  size = 2, path = "schedule_week_template_simple_weekday", value_type = 'weekday'  },

	{ idx = 207, changed = 0, value = {   1 },  size = 1, path = "schedule_week_template_simple_action0_enable", value_map = { [1] = "false", [2] = "true" } , },
    { idx = 208, changed = 0, value = {   0 },  size = 1, path = "schedule_week_template_simple_action0_min" ,value_type = "min" , },
	{ idx = 209, changed = 0, value = {   0 },  size = 1, path = "schedule_week_template_simple_action0_hour" , value_type = "hour" , },
    { idx = 210, changed = 0, value = {   2 },  size = 1, path = "schedule_week_template_simple_action0_mode", value_map = key_map_value["sche_mode"] , },

	{ idx = 211, changed = 0, value = {   1 },  size = 1, path = "schedule_week_template_simple_action1_enable", value_map = { [1] = "false", [2] = "true" } , },
    { idx = 212, changed = 0, value = {   0 },  size = 1, path = "schedule_week_template_simple_action1_min" ,value_type = "min" , },
	{ idx = 213, changed = 0, value = {   0 },  size = 1, path = "schedule_week_template_simple_action1_hour" , value_type = "hour" , },
    { idx = 214, changed = 0, value = {   2 },  size = 1, path = "schedule_week_template_simple_action1_mode", value_map = key_map_value["sche_mode"] , },

	{ idx = 215, changed = 0, value = {   1 },  size = 1, path = "schedule_week_template_simple_action2_enable", value_map = { [1] = "false", [2] = "true" } , },
    { idx = 216, changed = 0, value = {   0 },  size = 1, path = "schedule_week_template_simple_action2_min" ,value_type = "min" , },
	{ idx = 217, changed = 0, value = {   0 },  size = 1, path = "schedule_week_template_simple_action2_hour" , value_type = "hour" , },
    { idx = 218, changed = 0, value = {   2 },  size = 1, path = "schedule_week_template_simple_action2_mode", value_map = key_map_value["sche_mode"] , },

	{ idx = 219, changed = 0, value = {   1 },  size = 1, path = "schedule_week_template_simple_action3_enable", value_map = { [1] = "false", [2] = "true" } , },
    { idx = 220, changed = 0, value = {   0 },  size = 1, path = "schedule_week_template_simple_action3_min" ,value_type = "min" , },
	{ idx = 221, changed = 0, value = {   0 },  size = 1, path = "schedule_week_template_simple_action3_hour" , value_type = "hour" , },
    { idx = 222, changed = 0, value = {   2 },  size = 1, path = "schedule_week_template_simple_action3_mode", value_map = key_map_value["sche_mode"] , },

	{ idx = 223, changed = 0, value = {   1 },  size = 1, path = "schedule_week_template_simple_action4_enable", value_map = { [1] = "false", [2] = "true" } , },
    { idx = 224, changed = 0, value = {   0 },  size = 1, path = "schedule_week_template_simple_action4_min" ,value_type = "min" , },
	{ idx = 225, changed = 0, value = {   0 },  size = 1, path = "schedule_week_template_simple_action4_hour" , value_type = "hour" , },
    { idx = 226, changed = 0, value = {   2 },  size = 1, path = "schedule_week_template_simple_action4_mode", value_map = key_map_value["sche_mode"] , },

	-- /*********************假期***************************/
	{ idx = 227, changed = 0, value = {   1 },  size = 1, path = "holiday_template0_enable", value_map = { [1] = "false", [2] = "true" } ,  },
	{ idx = 228, changed = 0, value = {   0 },  size = 2, path = "holiday_template0_start_year",value_type = "year" , },
	{ idx = 229, changed = 0, value = {   0 },  size = 1, path = "holiday_template0_start_month", value_type = "month" , },
	{ idx = 230, changed = 0, value = {   0 },  size = 1, path = "holiday_template0_start_day",value_type = "date" , },
	{ idx = 231, changed = 0, value = {   0 },  size = 2, path = "holiday_template0_end_year" ,value_type = "year" , },
	{ idx = 232, changed = 0, value = {   0 },  size = 1, path = "holiday_template0_end_month", value_type = "month" , },
	{ idx = 233, changed = 0, value = {   0 },  size = 1, path = "holiday_template0_end_day", value_type = "date" , },

    { idx = 234, changed = 0, value = {   1 },  size = 1, path = "holiday_template1_enable", value_map = { [1] = "false", [2] = "true" } ,  },
	{ idx = 235, changed = 0, value = {   0 },  size = 2, path = "holiday_template1_start_year",value_type = "year"  , },
	{ idx = 236, changed = 0, value = {   0 },  size = 1, path = "holiday_template1_start_month" ,value_type = "month"  , },
	{ idx = 237, changed = 0, value = {   0 },  size = 1, path = "holiday_template1_start_day", value_type = "date" , },
	{ idx = 238, changed = 0, value = {   0 },  size = 2, path = "holiday_template1_end_year" ,value_type = "year"  , },
	{ idx = 239, changed = 0, value = {   0 },  size = 1, path = "holiday_template1_end_month" ,value_type = "month"  , },
	{ idx = 240, changed = 0, value = {   0 },  size = 1, path = "holiday_template1_end_day" ,value_type = "date" , },

	{ idx = 241, changed = 0, value = {   1 },  size = 1, path = "holiday_template2_enable", value_map = { [1] = "false", [2] = "true" } ,  },
	{ idx = 242, changed = 0, value = {   0 },  size = 2, path = "holiday_template2_start_year",value_type = "year"  , },
	{ idx = 243, changed = 0, value = {   0 },  size = 1, path = "holiday_template2_start_month" , value_type = "month"  , },
	{ idx = 244, changed = 0, value = {   0 },  size = 1, path = "holiday_template2_start_day" ,value_type = "date"  , },
	{ idx = 245, changed = 0, value = {   0 },  size = 2, path = "holiday_template2_end_year", value_type = "year"  , },
	{ idx = 246, changed = 0, value = {   0 },  size = 1, path = "holiday_template2_end_month",value_type = "month"  , },
	{ idx = 247, changed = 0, value = {   0 },  size = 1, path = "holiday_template2_end_day" , value_type = "date" , },

	{ idx = 248, changed = 0, value = {   1 },  size = 1, path = "holiday_template3_enable", value_map = { [1] = "false", [2] = "true" } ,  },
	{ idx = 249, changed = 0, value = {   0 },  size = 2, path = "holiday_template3_start_year" ,value_type = "year" , },
	{ idx = 250, changed = 0, value = {   0 },  size = 1, path = "holiday_template3_start_month" , value_type = "month" , },
	{ idx = 251, changed = 0, value = {   0 },  size = 1, path = "holiday_template3_start_day" ,value_type = "date" , },
	{ idx = 252, changed = 0, value = {   0 },  size = 2, path = "holiday_template3_end_year", value_type = "year"  , },
	{ idx = 253, changed = 0, value = {   0 },  size = 1, path = "holiday_template3_end_month",value_type = "month"  , },
	{ idx = 254, changed = 0, value = {   0 },  size = 1, path = "holiday_template3_end_day", value_type = "date"  , },

	{ idx = 255, changed = 0, value = {   1 },  size = 1, path = "holiday_template4_enable", value_map = { [1] = "false", [2] = "true" } ,  },
	{ idx = 256, changed = 0, value = {   0 },  size = 2, path = "holiday_template4_start_year" ,value_type = "year"  , },
	{ idx = 257, changed = 0, value = {   0 },  size = 1, path = "holiday_template4_start_month",value_type = "month"  , },
	{ idx = 258, changed = 0, value = {   0 },  size = 1, path = "holiday_template4_start_day"  ,value_type = "date"  , },
	{ idx = 259, changed = 0, value = {   0 },  size = 2, path = "holiday_template4_end_year"   , value_type = "year"  , },
	{ idx = 260, changed = 0, value = {   0 },  size = 1, path = "holiday_template4_end_month"  ,value_type = "month"  , },
	{ idx = 261, changed = 0, value = {   0 },  size = 1, path = "holiday_template4_end_day"	,value_type = "date"  , },

	-- /****************区域命名/内机命名*******************/
	{ idx = 262, changed = 0, value = {   2 },  size = 1, path = "name_area", value_map = key_map_value["area_name"]   },
	{ idx = 263, changed = 0, value = {   2 },  size = 1, path = "name_idx0_addr", },
	{ idx = 264, changed = 0, value = {   2 },  size = 1, path = "name_idx0_part0", value_map = key_map_value["area_name"]   },
	{ idx = 265, changed = 0, value = {   2 },  size = 1, path = "name_idx0_part1", value_map = key_map_value["direction_name"]   },
	{ idx = 266, changed = 0, value = {   2 },  size = 1, path = "name_idx0_part2_number0", value_map = key_map_value["serial_name"]  },
	{ idx = 267, changed = 0, value = {   2 },  size = 1, path = "name_idx0_part2_number1", value_map = key_map_value["serial_name"] },
	{ idx = 268, changed = 0, value = {   2 },  size = 1, path = "name_idx0_part2_number2", value_map = key_map_value["serial_name"] },
	{ idx = 269, changed = 0, value = {   2 },  size = 1, path = "name_idx0_part2_number3", value_map = key_map_value["serial_name"] },

	{ idx = 270, changed = 0, value = {   2 },  size = 1, path = "name_idx1_addr", },
	{ idx = 271, changed = 0, value = {   2 },  size = 1, path = "name_idx1_part0", value_map = key_map_value["area_name"]  },
	{ idx = 272, changed = 0, value = {   2 },  size = 1, path = "name_idx1_part1", value_map = key_map_value["direction_name"]  },
	{ idx = 273, changed = 0, value = {   2 },  size = 1, path = "name_idx1_part2_number0", value_map = key_map_value["serial_name"]},
	{ idx = 274, changed = 0, value = {   2 },  size = 1, path = "name_idx1_part2_number1", value_map = key_map_value["serial_name"]},
	{ idx = 275, changed = 0, value = {   2 },  size = 1, path = "name_idx1_part2_number2", value_map = key_map_value["serial_name"]},
	{ idx = 276, changed = 0, value = {   2 },  size = 1, path = "name_idx1_part2_number3", value_map = key_map_value["serial_name"]},

	{ idx = 277, changed = 0, value = {   2 },  size = 1, path = "name_idx2_addr", },
	{ idx = 278, changed = 0, value = {   2 },  size = 1, path = "name_idx2_part0", value_map = key_map_value["area_name"]  },
	{ idx = 279, changed = 0, value = {   2 },  size = 1, path = "name_idx2_part1", value_map = key_map_value["direction_name"]  },
	{ idx = 280, changed = 0, value = {   2 },  size = 1, path = "name_idx2_part2_number0", value_map = key_map_value["serial_name"]},
	{ idx = 281, changed = 0, value = {   2 },  size = 1, path = "name_idx2_part2_number1", value_map = key_map_value["serial_name"]},
	{ idx = 282, changed = 0, value = {   2 },  size = 1, path = "name_idx2_part2_number2", value_map = key_map_value["serial_name"]},
	{ idx = 283, changed = 0, value = {   2 },  size = 1, path = "name_idx2_part2_number3", value_map = key_map_value["serial_name"]},

	{ idx = 284, changed = 0, value = {   2 },  size = 1, path = "name_idx3_addr", },
	{ idx = 285, changed = 0, value = {   2 },  size = 1, path = "name_idx3_part0", value_map = key_map_value["area_name"]  },
	{ idx = 286, changed = 0, value = {   2 },  size = 1, path = "name_idx3_part1", value_map = key_map_value["direction_name"]  },
	{ idx = 287, changed = 0, value = {   2 },  size = 1, path = "name_idx3_part2_number0", value_map = key_map_value["serial_name"]},
	{ idx = 288, changed = 0, value = {   2 },  size = 1, path = "name_idx3_part2_number1", value_map = key_map_value["serial_name"]},
	{ idx = 289, changed = 0, value = {   2 },  size = 1, path = "name_idx3_part2_number2", value_map = key_map_value["serial_name"]},
	{ idx = 290, changed = 0, value = {   2 },  size = 1, path = "name_idx3_part2_number3", value_map = key_map_value["serial_name"]},

	{ idx = 291, changed = 0, value = {   2 },  size = 1, path = "name_idx4_addr", },
	{ idx = 292, changed = 0, value = {   2 },  size = 1, path = "name_idx4_part0", value_map = key_map_value["area_name"]  },
	{ idx = 293, changed = 0, value = {   2 },  size = 1, path = "name_idx4_part1", value_map = key_map_value["direction_name"]  },
	{ idx = 294, changed = 0, value = {   2 },  size = 1, path = "name_idx4_part2_number0", value_map = key_map_value["serial_name"] },
	{ idx = 295, changed = 0, value = {   2 },  size = 1, path = "name_idx4_part2_number1", value_map = key_map_value["serial_name"] },
	{ idx = 296, changed = 0, value = {   2 },  size = 1, path = "name_idx4_part2_number2", value_map = key_map_value["serial_name"] },
	{ idx = 297, changed = 0, value = {   2 },  size = 1, path = "name_idx4_part2_number3", value_map = key_map_value["serial_name"] },

	{ idx = 298, changed = 0, value = {   2 },  size = 1, path = "name_idx5_addr", },
	{ idx = 299, changed = 0, value = {   2 },  size = 1, path = "name_idx5_part0", value_map = key_map_value["area_name"]  },
	{ idx = 300, changed = 0, value = {   2 },  size = 1, path = "name_idx5_part1", value_map = key_map_value["direction_name"]  },
	{ idx = 301, changed = 0, value = {   2 },  size = 1, path = "name_idx5_part2_number0", value_map = key_map_value["serial_name"]  },
	{ idx = 302, changed = 0, value = {   2 },  size = 1, path = "name_idx5_part2_number1", value_map = key_map_value["serial_name"] },
	{ idx = 303, changed = 0, value = {   2 },  size = 1, path = "name_idx5_part2_number2", value_map = key_map_value["serial_name"] },
	{ idx = 304, changed = 0, value = {   2 },  size = 1, path = "name_idx5_part2_number3", value_map = key_map_value["serial_name"] },

	{ idx = 305, changed = 0, value = {   2 },  size = 1, path = "name_idx6_addr", },
	{ idx = 306, changed = 0, value = {   2 },  size = 1, path = "name_idx6_part0", value_map = key_map_value["area_name"]  },
	{ idx = 307, changed = 0, value = {   2 },  size = 1, path = "name_idx6_part1", value_map = key_map_value["direction_name"]  },
	{ idx = 308, changed = 0, value = {   2 },  size = 1, path = "name_idx6_part2_number0", value_map = key_map_value["serial_name"]  },
	{ idx = 309, changed = 0, value = {   2 },  size = 1, path = "name_idx6_part2_number1", value_map = key_map_value["serial_name"]  },
	{ idx = 310, changed = 0, value = {   2 },  size = 1, path = "name_idx6_part2_number2", value_map = key_map_value["serial_name"]  },
	{ idx = 311, changed = 0, value = {   2 },  size = 1, path = "name_idx6_part2_number3", value_map = key_map_value["serial_name"]  },

	{ idx = 312, changed = 0, value = {   2 },  size = 1, path = "name_idx7_addr", },
	{ idx = 313, changed = 0, value = {   2 },  size = 1, path = "name_idx7_part0", value_map = key_map_value["area_name"]  },
	{ idx = 314, changed = 0, value = {   2 },  size = 1, path = "name_idx7_part1", value_map = key_map_value["direction_name"]  },
	{ idx = 315, changed = 0, value = {   2 },  size = 1, path = "name_idx7_part2_number0", value_map = key_map_value["serial_name"]  },
	{ idx = 316, changed = 0, value = {   2 },  size = 1, path = "name_idx7_part2_number1", value_map = key_map_value["serial_name"] },
	{ idx = 317, changed = 0, value = {   2 },  size = 1, path = "name_idx7_part2_number2", value_map = key_map_value["serial_name"] },
	{ idx = 318, changed = 0, value = {   2 },  size = 1, path = "name_idx7_part2_number3", value_map = key_map_value["serial_name"] },

	{ idx = 319, changed = 0, value = {   2 },  size = 1, path = "name_idx8_addr", },
	{ idx = 320, changed = 0, value = {   2 },  size = 1, path = "name_idx8_part0", value_map = key_map_value["area_name"]  },
	{ idx = 321, changed = 0, value = {   2 },  size = 1, path = "name_idx8_part1", value_map = key_map_value["direction_name"]  },
	{ idx = 322, changed = 0, value = {   2 },  size = 1, path = "name_idx8_part2_number0", value_map = key_map_value["serial_name"]  },
	{ idx = 323, changed = 0, value = {   2 },  size = 1, path = "name_idx8_part2_number1", value_map = key_map_value["serial_name"] },
	{ idx = 324, changed = 0, value = {   2 },  size = 1, path = "name_idx8_part2_number2", value_map = key_map_value["serial_name"] },
	{ idx = 325, changed = 0, value = {   2 },  size = 1, path = "name_idx8_part2_number3", value_map = key_map_value["serial_name"] },

	{ idx = 326, changed = 0, value = {   2 },  size = 1, path = "name_idx9_addr", },
	{ idx = 327, changed = 0, value = {   2 },  size = 1, path = "name_idx9_part0", value_map = key_map_value["area_name"]  },
	{ idx = 328, changed = 0, value = {   2 },  size = 1, path = "name_idx9_part1", value_map = key_map_value["direction_name"]  },
	{ idx = 329, changed = 0, value = {   2 },  size = 1, path = "name_idx9_part2_number0", value_map = key_map_value["serial_name"]  },
	{ idx = 330, changed = 0, value = {   2 },  size = 1, path = "name_idx9_part2_number1", value_map = key_map_value["serial_name"]  },
	{ idx = 331, changed = 0, value = {   2 },  size = 1, path = "name_idx9_part2_number2", value_map = key_map_value["serial_name"]  },
	{ idx = 332, changed = 0, value = {   2 },  size = 1, path = "name_idx9_part2_number3", value_map = key_map_value["serial_name"]  },

	{ idx = 333, changed = 0, value = {   2 },  size = 1, path = "name_idx10_addr", },
	{ idx = 334, changed = 0, value = {   2 },  size = 1, path = "name_idx10_part0", value_map = key_map_value["area_name"]  },
	{ idx = 335, changed = 0, value = {   2 },  size = 1, path = "name_idx10_part1", value_map = key_map_value["direction_name"]  },
	{ idx = 336, changed = 0, value = {   2 },  size = 1, path = "name_idx10_part2_number0", value_map = key_map_value["serial_name"] },
	{ idx = 337, changed = 0, value = {   2 },  size = 1, path = "name_idx10_part2_number1", value_map = key_map_value["serial_name"] },
	{ idx = 338, changed = 0, value = {   2 },  size = 1, path = "name_idx10_part2_number2", value_map = key_map_value["serial_name"] },
	{ idx = 339, changed = 0, value = {   2 },  size = 1, path = "name_idx10_part2_number3", value_map = key_map_value["serial_name"] },

	{ idx = 340, changed = 0, value = {   2 },  size = 1, path = "name_idx11_addr", },
	{ idx = 341, changed = 0, value = {   2 },  size = 1, path = "name_idx11_part0", value_map = key_map_value["area_name"]  },
	{ idx = 342, changed = 0, value = {   2 },  size = 1, path = "name_idx11_part1", value_map = key_map_value["direction_name"]  },
	{ idx = 343, changed = 0, value = {   2 },  size = 1, path = "name_idx11_part2_number0", value_map = key_map_value["serial_name"]  },
	{ idx = 344, changed = 0, value = {   2 },  size = 1, path = "name_idx11_part2_number1", value_map = key_map_value["serial_name"] },
	{ idx = 345, changed = 0, value = {   2 },  size = 1, path = "name_idx11_part2_number2", value_map = key_map_value["serial_name"] },
	{ idx = 346, changed = 0, value = {   2 },  size = 1, path = "name_idx11_part2_number3", value_map = key_map_value["serial_name"]  },

	{ idx = 347, changed = 0, value = {   2 },  size = 1, path = "name_idx12_addr", },
	{ idx = 348, changed = 0, value = {   2 },  size = 1, path = "name_idx12_part0", value_map = key_map_value["area_name"]  },
	{ idx = 349, changed = 0, value = {   2 },  size = 1, path = "name_idx12_part1", value_map = key_map_value["direction_name"]  },
	{ idx = 350, changed = 0, value = {   2 },  size = 1, path = "name_idx12_part2_number0", value_map = key_map_value["serial_name"]  },
	{ idx = 351, changed = 0, value = {   2 },  size = 1, path = "name_idx12_part2_number1", value_map = key_map_value["serial_name"] },
	{ idx = 352, changed = 0, value = {   2 },  size = 1, path = "name_idx12_part2_number2", value_map = key_map_value["serial_name"] },
	{ idx = 353, changed = 0, value = {   2 },  size = 1, path = "name_idx12_part2_number3", value_map = key_map_value["serial_name"] },

	{ idx = 354, changed = 0, value = {   2 },  size = 1, path = "name_idx13_addr", },
	{ idx = 355, changed = 0, value = {   2 },  size = 1, path = "name_idx13_part0", value_map = key_map_value["area_name"]  },
	{ idx = 356, changed = 0, value = {   2 },  size = 1, path = "name_idx13_part1", value_map = key_map_value["direction_name"]  },
	{ idx = 357, changed = 0, value = {   2 },  size = 1, path = "name_idx13_part2_number0", value_map = key_map_value["serial_name"] },
	{ idx = 358, changed = 0, value = {   2 },  size = 1, path = "name_idx13_part2_number1", value_map = key_map_value["serial_name"] },
	{ idx = 359, changed = 0, value = {   2 },  size = 1, path = "name_idx13_part2_number2", value_map = key_map_value["serial_name"] },
	{ idx = 360, changed = 0, value = {   2 },  size = 1, path = "name_idx13_part2_number3", value_map = key_map_value["serial_name"] },

	{ idx = 361, changed = 0, value = {   2 },  size = 1, path = "name_idx14_addr", },
	{ idx = 362, changed = 0, value = {   2 },  size = 1, path = "name_idx14_part0", value_map = key_map_value["area_name"]   },
	{ idx = 363, changed = 0, value = {   2 },  size = 1, path = "name_idx14_part1", value_map = key_map_value["direction_name"]   },
	{ idx = 364, changed = 0, value = {   2 },  size = 1, path = "name_idx14_part2_number0", value_map = key_map_value["serial_name"] },
	{ idx = 365, changed = 0, value = {   2 },  size = 1, path = "name_idx14_part2_number1", value_map = key_map_value["serial_name"] },
	{ idx = 366, changed = 0, value = {   2 },  size = 1, path = "name_idx14_part2_number2", value_map = key_map_value["serial_name"]  },
	{ idx = 367, changed = 0, value = {   2 },  size = 1, path = "name_idx14_part2_number3", value_map = key_map_value["serial_name"]},

	{ idx = 368, changed = 0, value = {   2 },  size = 1, path = "name_idx15_addr", },
	{ idx = 369, changed = 0, value = {   2 },  size = 1, path = "name_idx15_part0", value_map = key_map_value["area_name"] },
	{ idx = 370, changed = 0, value = {   2 },  size = 1, path = "name_idx15_part1", value_map = key_map_value["direction_name"] },
	{ idx = 371, changed = 0, value = {   2 },  size = 1, path = "name_idx15_part2_number0", value_map = key_map_value["serial_name"]  },
	{ idx = 372, changed = 0, value = {   2 },  size = 1, path = "name_idx15_part2_number1", value_map = key_map_value["serial_name"]  },
	{ idx = 373, changed = 0, value = {   2 },  size = 1, path = "name_idx15_part2_number2", value_map = key_map_value["serial_name"]  },
	{ idx = 374, changed = 0, value = {   2 },  size = 1, path = "name_idx15_part2_number3", value_map = key_map_value["serial_name"]  },



--/****************内机单控***************************/
	{ idx = 375, changed = 0, value = {0xFF },  size = 1, path = "mcs_num"},

	{ idx = 376, changed = 0, value = {   2 },  size = 1, path = "mcs_idx0_addr", },
    { idx = 377, changed = 0, value = { 48 },   size = 6, path = "mcs_idx0_fault_code", value_type = "chars" },
	{ idx = 378, changed = 0, value = {   2 },  size = 1, path = "mcs_idx0_type", },
	{ idx = 379, changed = 0, value = {   2 },  size = 2, path = "mcs_idx0_temp_room", value_type = "temp_10s" },
	{ idx = 380, changed = 0, value = {   2 },  size = 1, path = "mcs_idx0_power", value_map = { [1] = "off", [2] = "on" } },
	{ idx = 381, changed = 0, value = { 3 },    size = 1, path = "mcs_idx0_mode", value_map = key_map_value['mode'] },
	{ idx = 382, changed = 0, value = {   2 },  size = 1, path = "mcs_idx0_wind_speed", value_map = key_map_value['wind_speed'] },
	{ idx = 383, changed = 0, value = { 132 },  size = 1, path = "mcs_idx0_temp", value_type = "temp" },
	{ idx = 384, changed = 0, value = { 114 },   size = 1, path = "mcs_idx0_auto_min" ,value_type = "temp"},
    { idx = 385, changed = 0, value = { 140 },   size = 1, path = "mcs_idx0_auto_max" ,value_type = "temp"},
    { idx = 386, changed = 0, value = { 1 },    size = 1, path = "mcs_idx0_louver_horizontal_enable", value_map = { [1] = "false", [2] = "true" } },
    { idx = 387, changed = 0, value = { 1 },    size = 1, path = "mcs_idx0_louver_horizontal_level", value_map = { [13] = "close", [1] = 'close', [2] = '1', [3] = '2', [4] = '3', [5] = '4', [6] = '5', [7] = 'auto' } },
    { idx = 388, changed = 0, value = { 1 },    size = 1, path = "mcs_idx0_louver_vertical_enable", value_map = { [1] = "false", [2] = "true" } },
    { idx = 389, changed = 0, value = { 3 },    size = 1, path = "mcs_idx0_louver_vertical_level", value_map = { [13] = "close", [1] = 'close', [2] = '1', [3] = '2', [4] = '3', [5] = '4', [6] = '5', [7] = 'auto' } },
	{ idx = 390, changed = 0, value = { 1 },    size = 1, path = "mcs_idx0_swing_multiple_enable", value_map = { [1] = "false", [2] = "true" } },
    { idx = 391, changed = 0, value = { 1 },    size = 1, path = "mcs_idx0_swing_multiple_louver1", value_map = { [13] = "close", [1] = 'close', [2] = '1', [3] = '2', [4] = '3', [5] = '4', [6] = '5', [7] = 'auto' } },
    { idx = 392, changed = 0, value = { 1 },    size = 1, path = "mcs_idx0_swing_multiple_louver2", value_map = { [13] = "close", [1] = 'close', [2] = '1', [3] = '2', [4] = '3', [5] = '4', [6] = '5', [7] = 'auto' } },
    { idx = 393, changed = 0, value = { 1 },    size = 1, path = "mcs_idx0_swing_multiple_louver3", value_map = { [13] = "close", [1] = 'close', [2] = '1', [3] = '2', [4] = '3', [5] = '4', [6] = '5', [7] = 'auto' } },
    { idx = 394, changed = 0, value = { 1 },    size = 1, path = "mcs_idx0_swing_multiple_louver4", value_map = { [13] = "close", [1] = 'close', [2] = '1', [3] = '2', [4] = '3', [5] = '4', [6] = '5', [7] = 'auto' } },

	{ idx = 395, changed = 0, value = {   2 },  size = 1, path = "mcs_idx1_addr", },
    { idx = 396, changed = 0, value = { 48 },   size = 6, path = "mcs_idx1_fault_code", value_type = "chars" },
	{ idx = 397, changed = 0, value = {   2 },  size = 1, path = "mcs_idx1_type", },
	{ idx = 398, changed = 0, value = {   2 },  size = 2, path = "mcs_idx1_temp_room", value_type = "temp_10s" },
	{ idx = 399, changed = 0, value = {   2 },  size = 1, path = "mcs_idx1_power", value_map = { [1] = "off", [2] = "on" } },
	{ idx = 400, changed = 0, value = { 3 },    size = 1, path = "mcs_idx1_mode", value_map = key_map_value['mode'] },
	{ idx = 401, changed = 0, value = {   2 },  size = 1, path = "mcs_idx1_wind_speed", value_map = key_map_value['wind_speed'] },
	{ idx = 402, changed = 0, value = { 132 },  size = 1, path = "mcs_idx1_temp", value_type = "temp" },
	{ idx = 403, changed = 0, value = { 114 },   size = 1, path = "mcs_idx1_auto_min" ,value_type = "temp"},
    { idx = 404, changed = 0, value = { 140 },   size = 1, path = "mcs_idx1_auto_max" ,value_type = "temp"},
    { idx = 405, changed = 0, value = { 1 },    size = 1, path = "mcs_idx1_louver_horizontal_enable", value_map = { [1] = "false", [2] = "true" } },
    { idx = 406, changed = 0, value = { 1 },    size = 1, path = "mcs_idx1_louver_horizontal_level", value_map = { [13] = "close", [1] = 'close', [2] = '1', [3] = '2', [4] = '3', [5] = '4', [6] = '5', [7] = 'auto' } },
    { idx = 407, changed = 0, value = { 1 },    size = 1, path = "mcs_idx1_louver_vertical_enable", value_map = { [1] = "false", [2] = "true" } },
    { idx = 408, changed = 0, value = { 3 },    size = 1, path = "mcs_idx1_louver_vertical_level", value_map = { [13] = "close", [1] = 'close', [2] = '1', [3] = '2', [4] = '3', [5] = '4', [6] = '5', [7] = 'auto' } },
	{ idx = 409, changed = 0, value = { 1 },    size = 1, path = "mcs_idx1_swing_multiple_enable", value_map = { [1] = "false", [2] = "true" } },
    { idx = 410, changed = 0, value = { 1 },    size = 1, path = "mcs_idx1_swing_multiple_louver1", value_map = { [13] = "close", [1] = 'close', [2] = '1', [3] = '2', [4] = '3', [5] = '4', [6] = '5', [7] = 'auto' } },
    { idx = 411, changed = 0, value = { 1 },    size = 1, path = "mcs_idx1_swing_multiple_louver2", value_map = { [13] = "close", [1] = 'close', [2] = '1', [3] = '2', [4] = '3', [5] = '4', [6] = '5', [7] = 'auto' } },
    { idx = 412, changed = 0, value = { 1 },    size = 1, path = "mcs_idx1_swing_multiple_louver3", value_map = { [13] = "close", [1] = 'close', [2] = '1', [3] = '2', [4] = '3', [5] = '4', [6] = '5', [7] = 'auto' } },
    { idx = 413, changed = 0, value = { 1 },    size = 1, path = "mcs_idx1_swing_multiple_louver4", value_map = { [13] = "close", [1] = 'close', [2] = '1', [3] = '2', [4] = '3', [5] = '4', [6] = '5', [7] = 'auto' } },

	{ idx = 414, changed = 0, value = {   2 },  size = 1, path = "mcs_idx2_addr", },
    { idx = 415, changed = 0, value = { 48 },   size = 6, path = "mcs_idx2_fault_code", value_type = "chars" },
	{ idx = 416, changed = 0, value = {   2 },  size = 1, path = "mcs_idx2_type", },
	{ idx = 417, changed = 0, value = {   2 },  size = 2, path = "mcs_idx2_temp_room", value_type = "temp_10s" },
	{ idx = 418, changed = 0, value = {   2 },  size = 1, path = "mcs_idx2_power", value_map = { [1] = "off", [2] = "on" } },
	{ idx = 419, changed = 0, value = { 3 },    size = 1, path = "mcs_idx2_mode", value_map = key_map_value['mode'] },
	{ idx = 420, changed = 0, value = {   2 },  size = 1, path = "mcs_idx2_wind_speed", value_map = key_map_value['wind_speed'] },
	{ idx = 421, changed = 0, value = { 132 },  size = 1, path = "mcs_idx2_temp", value_type = "temp" },
	{ idx = 422, changed = 0, value = { 114 },   size = 1, path = "mcs_idx2_auto_min" ,value_type = "temp"},
    { idx = 423, changed = 0, value = { 140 },   size = 1, path = "mcs_idx2_auto_max" ,value_type = "temp"},
    { idx = 424, changed = 0, value = { 1 },    size = 1, path = "mcs_idx2_louver_horizontal_enable", value_map = { [1] = "false", [2] = "true" } },
    { idx = 425, changed = 0, value = { 1 },    size = 1, path = "mcs_idx2_louver_horizontal_level", value_map = { [13] = "close", [1] = 'close', [2] = '1', [3] = '2', [4] = '3', [5] = '4', [6] = '5', [7] = 'auto' } },
    { idx = 426, changed = 0, value = { 1 },    size = 1, path = "mcs_idx2_louver_vertical_enable", value_map = { [1] = "false", [2] = "true" } },
    { idx = 427, changed = 0, value = { 3 },    size = 1, path = "mcs_idx2_louver_vertical_level", value_map = { [13] = "close", [1] = 'close', [2] = '1', [3] = '2', [4] = '3', [5] = '4', [6] = '5', [7] = 'auto' } },
	{ idx = 428, changed = 0, value = { 1 },    size = 1, path = "mcs_idx2_swing_multiple_enable", value_map = { [1] = "false", [2] = "true" } },
    { idx = 429, changed = 0, value = { 1 },    size = 1, path = "mcs_idx2_swing_multiple_louver1", value_map = { [13] = "close", [1] = 'close', [2] = '1', [3] = '2', [4] = '3', [5] = '4', [6] = '5', [7] = 'auto' } },
    { idx = 430, changed = 0, value = { 1 },    size = 1, path = "mcs_idx2_swing_multiple_louver2", value_map = { [13] = "close", [1] = 'close', [2] = '1', [3] = '2', [4] = '3', [5] = '4', [6] = '5', [7] = 'auto' } },
    { idx = 431, changed = 0, value = { 1 },    size = 1, path = "mcs_idx2_swing_multiple_louver3", value_map = { [13] = "close", [1] = 'close', [2] = '1', [3] = '2', [4] = '3', [5] = '4', [6] = '5', [7] = 'auto' } },
    { idx = 432, changed = 0, value = { 1 },    size = 1, path = "mcs_idx2_swing_multiple_louver4", value_map = { [13] = "close", [1] = 'close', [2] = '1', [3] = '2', [4] = '3', [5] = '4', [6] = '5', [7] = 'auto' } },


	{ idx = 433, changed = 0, value = {   2 },  size = 1, path = "mcs_idx3_addr", },
    { idx = 434, changed = 0, value = { 48 },   size = 6, path = "mcs_idx3_fault_code", value_type = "chars" },
	{ idx = 435, changed = 0, value = {   2 },  size = 1, path = "mcs_idx3_type", },
	{ idx = 436, changed = 0, value = {   2 },  size = 2, path = "mcs_idx3_temp_room", value_type = "temp_10s" },
	{ idx = 437, changed = 0, value = {   2 },  size = 1, path = "mcs_idx3_power", value_map = { [1] = "off", [2] = "on" } },
	{ idx = 438, changed = 0, value = { 3 },    size = 1, path = "mcs_idx3_mode", value_map = key_map_value['mode'] },
	{ idx = 439, changed = 0, value = {   2 },  size = 1, path = "mcs_idx3_wind_speed", value_map = key_map_value['wind_speed'] },
	{ idx = 440, changed = 0, value = { 132 },  size = 1, path = "mcs_idx3_temp", value_type = "temp" },
	{ idx = 441, changed = 0, value = { 114 },   size = 1, path = "mcs_idx3_auto_min" ,value_type = "temp"},
    { idx = 442, changed = 0, value = { 140 },   size = 1, path = "mcs_idx3_auto_max" ,value_type = "temp"},
    { idx = 443, changed = 0, value = { 1 },    size = 1, path = "mcs_idx3_louver_horizontal_enable", value_map = { [1] = "false", [2] = "true" } },
    { idx = 444, changed = 0, value = { 1 },    size = 1, path = "mcs_idx3_louver_horizontal_level", value_map = { [13] = "close", [1] = 'close', [2] = '1', [3] = '2', [4] = '3', [5] = '4', [6] = '5', [7] = 'auto' } },
    { idx = 445, changed = 0, value = { 1 },    size = 1, path = "mcs_idx3_louver_vertical_enable", value_map = { [1] = "false", [2] = "true" } },
    { idx = 446, changed = 0, value = { 3 },    size = 1, path = "mcs_idx3_louver_vertical_level", value_map = { [13] = "close", [1] = 'close', [2] = '1', [3] = '2', [4] = '3', [5] = '4', [6] = '5', [7] = 'auto' } },
	{ idx = 447, changed = 0, value = { 1 },    size = 1, path = "mcs_idx3_swing_multiple_enable", value_map = { [1] = "false", [2] = "true" } },
    { idx = 448, changed = 0, value = { 1 },    size = 1, path = "mcs_idx3_swing_multiple_louver1", value_map = { [13] = "close", [1] = 'close', [2] = '1', [3] = '2', [4] = '3', [5] = '4', [6] = '5', [7] = 'auto' } },
    { idx = 449, changed = 0, value = { 1 },    size = 1, path = "mcs_idx3_swing_multiple_louver2", value_map = { [13] = "close", [1] = 'close', [2] = '1', [3] = '2', [4] = '3', [5] = '4', [6] = '5', [7] = 'auto' } },
    { idx = 450, changed = 0, value = { 1 },    size = 1, path = "mcs_idx3_swing_multiple_louver3", value_map = { [13] = "close", [1] = 'close', [2] = '1', [3] = '2', [4] = '3', [5] = '4', [6] = '5', [7] = 'auto' } },
    { idx = 451, changed = 0, value = { 1 },    size = 1, path = "mcs_idx3_swing_multiple_louver4", value_map = { [13] = "close", [1] = 'close', [2] = '1', [3] = '2', [4] = '3', [5] = '4', [6] = '5', [7] = 'auto' } },

	{ idx = 452, changed = 0, value = {   2 },  size = 1, path = "mcs_idx4_addr", },
    { idx = 453, changed = 0, value = { 48 },   size = 6, path = "mcs_idx4_fault_code", value_type = "chars" },
	{ idx = 454, changed = 0, value = {   2 },  size = 1, path = "mcs_idx4_type", },
	{ idx = 455, changed = 0, value = {   2 },  size = 2, path = "mcs_idx4_temp_room", value_type = "temp_10s" },
	{ idx = 456, changed = 0, value = {   2 },  size = 1, path = "mcs_idx4_power", value_map = { [1] = "off", [2] = "on" } },
	{ idx = 457, changed = 0, value = { 3 },    size = 1, path = "mcs_idx4_mode", value_map = key_map_value['mode'] },
	{ idx = 458, changed = 0, value = {   2 },  size = 1, path = "mcs_idx4_wind_speed", value_map = key_map_value['wind_speed'] },
	{ idx = 459, changed = 0, value = { 132 },  size = 1, path = "mcs_idx4_temp", value_type = "temp" },
	{ idx = 460, changed = 0, value = { 114 },   size = 1, path = "mcs_idx4_auto_min" ,value_type = "temp"},
    { idx = 461, changed = 0, value = { 140 },   size = 1, path = "mcs_idx4_auto_max" ,value_type = "temp"},
    { idx = 462, changed = 0, value = { 1 },    size = 1, path = "mcs_idx4_louver_horizontal_enable", value_map = { [1] = "false", [2] = "true" } },
    { idx = 463, changed = 0, value = { 1 },    size = 1, path = "mcs_idx4_louver_horizontal_level", value_map = { [13] = "close", [1] = 'close', [2] = '1', [3] = '2', [4] = '3', [5] = '4', [6] = '5', [7] = 'auto' } },
    { idx = 464, changed = 0, value = { 1 },    size = 1, path = "mcs_idx4_louver_vertical_enable", value_map = { [1] = "false", [2] = "true" } },
    { idx = 465, changed = 0, value = { 3 },    size = 1, path = "mcs_idx4_louver_vertical_level", value_map = { [13] = "close", [1] = 'close', [2] = '1', [3] = '2', [4] = '3', [5] = '4', [6] = '5', [7] = 'auto' } },
	{ idx = 466, changed = 0, value = { 1 },    size = 1, path = "mcs_idx4_swing_multiple_enable", value_map = { [1] = "false", [2] = "true" } },
    { idx = 467, changed = 0, value = { 1 },    size = 1, path = "mcs_idx4_swing_multiple_louver1", value_map = { [13] = "close", [1] = 'close', [2] = '1', [3] = '2', [4] = '3', [5] = '4', [6] = '5', [7] = 'auto' } },
    { idx = 468, changed = 0, value = { 1 },    size = 1, path = "mcs_idx4_swing_multiple_louver2", value_map = { [13] = "close", [1] = 'close', [2] = '1', [3] = '2', [4] = '3', [5] = '4', [6] = '5', [7] = 'auto' } },
    { idx = 469, changed = 0, value = { 1 },    size = 1, path = "mcs_idx4_swing_multiple_louver3", value_map = { [13] = "close", [1] = 'close', [2] = '1', [3] = '2', [4] = '3', [5] = '4', [6] = '5', [7] = 'auto' } },
    { idx = 470, changed = 0, value = { 1 },    size = 1, path = "mcs_idx4_swing_multiple_louver4", value_map = { [13] = "close", [1] = 'close', [2] = '1', [3] = '2', [4] = '3', [5] = '4', [6] = '5', [7] = 'auto' } },

	{ idx = 471, changed = 0, value = {   2 },  size = 1, path = "mcs_idx5_addr", },
    { idx = 472, changed = 0, value = { 48 },   size = 6, path = "mcs_idx5_fault_code", value_type = "chars" },
	{ idx = 473, changed = 0, value = {   2 },  size = 1, path = "mcs_idx5_type", },
	{ idx = 474, changed = 0, value = {   2 },  size = 2, path = "mcs_idx5_temp_room", value_type = "temp_10s" },
	{ idx = 475, changed = 0, value = {   2 },  size = 1, path = "mcs_idx5_power", value_map = { [1] = "off", [2] = "on" } },
	{ idx = 476, changed = 0, value = { 3 },    size = 1, path = "mcs_idx5_mode", value_map = key_map_value['mode'] },
	{ idx = 477, changed = 0, value = {   2 },  size = 1, path = "mcs_idx5_wind_speed", value_map = key_map_value['wind_speed'] },
	{ idx = 478, changed = 0, value = { 132 },  size = 1, path = "mcs_idx5_temp", value_type = "temp" },
	{ idx = 479, changed = 0, value = { 114 },   size = 1, path = "mcs_idx5_auto_min" ,value_type = "temp"},
    { idx = 480, changed = 0, value = { 140 },   size = 1, path = "mcs_idx5_auto_max" ,value_type = "temp"},
    { idx = 481, changed = 0, value = { 1 },    size = 1, path = "mcs_idx5_louver_horizontal_enable", value_map = { [1] = "false", [2] = "true" } },
    { idx = 482, changed = 0, value = { 1 },    size = 1, path = "mcs_idx5_louver_horizontal_level", value_map = { [13] = "close", [1] = 'close', [2] = '1', [3] = '2', [4] = '3', [5] = '4', [6] = '5', [7] = 'auto' } },
    { idx = 483, changed = 0, value = { 1 },    size = 1, path = "mcs_idx5_louver_vertical_enable", value_map = { [1] = "false", [2] = "true" } },
    { idx = 484, changed = 0, value = { 3 },    size = 1, path = "mcs_idx5_louver_vertical_level", value_map = { [13] = "close", [1] = 'close', [2] = '1', [3] = '2', [4] = '3', [5] = '4', [6] = '5', [7] = 'auto' } },
	{ idx = 485, changed = 0, value = { 1 },    size = 1, path = "mcs_idx5_swing_multiple_enable", value_map = { [1] = "false", [2] = "true" } },
    { idx = 486, changed = 0, value = { 1 },    size = 1, path = "mcs_idx5_swing_multiple_louver1", value_map = { [13] = "close", [1] = 'close', [2] = '1', [3] = '2', [4] = '3', [5] = '4', [6] = '5', [7] = 'auto' } },
    { idx = 487, changed = 0, value = { 1 },    size = 1, path = "mcs_idx5_swing_multiple_louver2", value_map = { [13] = "close", [1] = 'close', [2] = '1', [3] = '2', [4] = '3', [5] = '4', [6] = '5', [7] = 'auto' } },
    { idx = 488, changed = 0, value = { 1 },    size = 1, path = "mcs_idx5_swing_multiple_louver3", value_map = { [13] = "close", [1] = 'close', [2] = '1', [3] = '2', [4] = '3', [5] = '4', [6] = '5', [7] = 'auto' } },
    { idx = 489, changed = 0, value = { 1 },    size = 1, path = "mcs_idx5_swing_multiple_louver4", value_map = { [13] = "close", [1] = 'close', [2] = '1', [3] = '2', [4] = '3', [5] = '4', [6] = '5', [7] = 'auto' } },

	{ idx = 490, changed = 0, value = {   2 },  size = 1, path = "mcs_idx6_addr", },
    { idx = 491, changed = 0, value = { 48 },   size = 6, path = "mcs_idx6_fault_code", value_type = "chars" },
	{ idx = 492, changed = 0, value = {   2 },  size = 1, path = "mcs_idx6_type", },
	{ idx = 493, changed = 0, value = {   2 },  size = 2, path = "mcs_idx6_temp_room", value_type = "temp_10s" },
	{ idx = 494, changed = 0, value = {   2 },  size = 1, path = "mcs_idx6_power", value_map = { [1] = "off", [2] = "on" } },
	{ idx = 495, changed = 0, value = { 3 },    size = 1, path = "mcs_idx6_mode", value_map = key_map_value['mode'] },
	{ idx = 496, changed = 0, value = {   2 },  size = 1, path = "mcs_idx6_wind_speed", value_map = key_map_value['wind_speed'] },
	{ idx = 497, changed = 0, value = { 132 },  size = 1, path = "mcs_idx6_temp", value_type = "temp" },
	{ idx = 498, changed = 0, value = { 114 },   size = 1, path = "mcs_idx6_auto_min" ,value_type = "temp"},
    { idx = 499, changed = 0, value = { 140 },   size = 1, path = "mcs_idx6_auto_max" ,value_type = "temp"},
    { idx = 500, changed = 0, value = { 1 },    size = 1, path = "mcs_idx6_louver_horizontal_enable", value_map = { [1] = "false", [2] = "true" } },
    { idx = 501, changed = 0, value = { 1 },    size = 1, path = "mcs_idx6_louver_horizontal_level", value_map = { [13] = "close", [1] = 'close', [2] = '1', [3] = '2', [4] = '3', [5] = '4', [6] = '5', [7] = 'auto' } },
    { idx = 502, changed = 0, value = { 1 },    size = 1, path = "mcs_idx6_louver_vertical_enable", value_map = { [1] = "false", [2] = "true" } },
    { idx = 503, changed = 0, value = { 3 },    size = 1, path = "mcs_idx6_louver_vertical_level", value_map = { [13] = "close", [1] = 'close', [2] = '1', [3] = '2', [4] = '3', [5] = '4', [6] = '5', [7] = 'auto' } },
	{ idx = 504, changed = 0, value = { 1 },    size = 1, path = "mcs_idx6_swing_multiple_enable", value_map = { [1] = "false", [2] = "true" } },
    { idx = 505, changed = 0, value = { 1 },    size = 1, path = "mcs_idx6_swing_multiple_louver1", value_map = { [13] = "close", [1] = 'close', [2] = '1', [3] = '2', [4] = '3', [5] = '4', [6] = '5', [7] = 'auto' } },
    { idx = 506, changed = 0, value = { 1 },    size = 1, path = "mcs_idx6_swing_multiple_louver2", value_map = { [13] = "close", [1] = 'close', [2] = '1', [3] = '2', [4] = '3', [5] = '4', [6] = '5', [7] = 'auto' } },
    { idx = 507, changed = 0, value = { 1 },    size = 1, path = "mcs_idx6_swing_multiple_louver3", value_map = { [13] = "close", [1] = 'close', [2] = '1', [3] = '2', [4] = '3', [5] = '4', [6] = '5', [7] = 'auto' } },
    { idx = 508, changed = 0, value = { 1 },    size = 1, path = "mcs_idx6_swing_multiple_louver4", value_map = { [13] = "close", [1] = 'close', [2] = '1', [3] = '2', [4] = '3', [5] = '4', [6] = '5', [7] = 'auto' } },

	{ idx = 509, changed = 0, value = {   2 },  size = 1, path = "mcs_idx7_addr", },
    { idx = 510, changed = 0, value = { 48 },   size = 6, path = "mcs_idx7_fault_code", value_type = "chars" },
	{ idx = 511, changed = 0, value = {   2 },  size = 1, path = "mcs_idx7_type", },
	{ idx = 512, changed = 0, value = {   2 },  size = 2, path = "mcs_idx7_temp_room", value_type = "temp_10s" },
	{ idx = 513, changed = 0, value = {   2 },  size = 1, path = "mcs_idx7_power", value_map = { [1] = "off", [2] = "on" } },
	{ idx = 514, changed = 0, value = { 3 },    size = 1, path = "mcs_idx7_mode", value_map = key_map_value['mode'] },
	{ idx = 515, changed = 0, value = {   2 },  size = 1, path = "mcs_idx7_wind_speed", value_map = key_map_value['wind_speed'] },
	{ idx = 516, changed = 0, value = { 132 },  size = 1, path = "mcs_idx7_temp", value_type = "temp" },
	{ idx = 517, changed = 0, value = { 114 },   size = 1, path = "mcs_idx7_auto_min" ,value_type = "temp"},
    { idx = 518, changed = 0, value = { 140 },   size = 1, path = "mcs_idx7_auto_max" ,value_type = "temp"},
    { idx = 519, changed = 0, value = { 1 },    size = 1, path = "mcs_idx7_louver_horizontal_enable", value_map = { [1] = "false", [2] = "true" } },
    { idx = 520, changed = 0, value = { 1 },    size = 1, path = "mcs_idx7_louver_horizontal_level", value_map = { [13] = "close", [1] = 'close', [2] = '1', [3] = '2', [4] = '3', [5] = '4', [6] = '5', [7] = 'auto' } },
    { idx = 521, changed = 0, value = { 1 },    size = 1, path = "mcs_idx7_louver_vertical_enable", value_map = { [1] = "false", [2] = "true" } },
    { idx = 522, changed = 0, value = { 3 },    size = 1, path = "mcs_idx7_louver_vertical_level", value_map = { [13] = "close", [1] = 'close', [2] = '1', [3] = '2', [4] = '3', [5] = '4', [6] = '5', [7] = 'auto' } },
	{ idx = 523, changed = 0, value = { 1 },    size = 1, path = "mcs_idx7_swing_multiple_enable", value_map = { [1] = "false", [2] = "true" } },
    { idx = 524, changed = 0, value = { 1 },    size = 1, path = "mcs_idx7_swing_multiple_louver1", value_map = { [13] = "close", [1] = 'close', [2] = '1', [3] = '2', [4] = '3', [5] = '4', [6] = '5', [7] = 'auto' } },
    { idx = 525, changed = 0, value = { 1 },    size = 1, path = "mcs_idx7_swing_multiple_louver2", value_map = { [13] = "close", [1] = 'close', [2] = '1', [3] = '2', [4] = '3', [5] = '4', [6] = '5', [7] = 'auto' } },
    { idx = 526, changed = 0, value = { 1 },    size = 1, path = "mcs_idx7_swing_multiple_louver3", value_map = { [13] = "close", [1] = 'close', [2] = '1', [3] = '2', [4] = '3', [5] = '4', [6] = '5', [7] = 'auto' } },
    { idx = 527, changed = 0, value = { 1 },    size = 1, path = "mcs_idx7_swing_multiple_louver4", value_map = { [13] = "close", [1] = 'close', [2] = '1', [3] = '2', [4] = '3', [5] = '4', [6] = '5', [7] = 'auto' } },

	{ idx = 528, changed = 0, value = {   2 },  size = 1, path = "mcs_idx8_addr", },
    { idx = 529, changed = 0, value = { 48 },   size = 6, path = "mcs_idx8_fault_code", value_type = "chars" },
	{ idx = 530, changed = 0, value = {   2 },  size = 1, path = "mcs_idx8_type", },
	{ idx = 531, changed = 0, value = {   2 },  size = 2, path = "mcs_idx8_temp_room", value_type = "temp_10s" },
	{ idx = 532, changed = 0, value = {   2 },  size = 1, path = "mcs_idx8_power", value_map = { [1] = "off", [2] = "on" } },
	{ idx = 533, changed = 0, value = { 3 },    size = 1, path = "mcs_idx8_mode", value_map = key_map_value['mode'] },
	{ idx = 534, changed = 0, value = {   2 },  size = 1, path = "mcs_idx8_wind_speed", value_map = key_map_value['wind_speed'] },
	{ idx = 535, changed = 0, value = { 132 },  size = 1, path = "mcs_idx8_temp", value_type = "temp" },
	{ idx = 536, changed = 0, value = { 114 },   size = 1, path = "mcs_idx8_auto_min" ,value_type = "temp"},
    { idx = 537, changed = 0, value = { 140 },   size = 1, path = "mcs_idx8_auto_max" ,value_type = "temp"},
    { idx = 538, changed = 0, value = { 1 },    size = 1, path = "mcs_idx8_louver_horizontal_enable", value_map = { [1] = "false", [2] = "true" } },
    { idx = 539, changed = 0, value = { 1 },    size = 1, path = "mcs_idx8_louver_horizontal_level", value_map = { [13] = "close", [1] = 'close', [2] = '1', [3] = '2', [4] = '3', [5] = '4', [6] = '5', [7] = 'auto' } },
    { idx = 540, changed = 0, value = { 1 },    size = 1, path = "mcs_idx8_louver_vertical_enable", value_map = { [1] = "false", [2] = "true" } },
    { idx = 541, changed = 0, value = { 3 },    size = 1, path = "mcs_idx8_louver_vertical_level", value_map = { [13] = "close", [1] = 'close', [2] = '1', [3] = '2', [4] = '3', [5] = '4', [6] = '5', [7] = 'auto' } },
	{ idx = 542, changed = 0, value = { 1 },    size = 1, path = "mcs_idx8_swing_multiple_enable", value_map = { [1] = "false", [2] = "true" } },
    { idx = 543, changed = 0, value = { 1 },    size = 1, path = "mcs_idx8_swing_multiple_louver1", value_map = { [13] = "close", [1] = 'close', [2] = '1', [3] = '2', [4] = '3', [5] = '4', [6] = '5', [7] = 'auto' } },
    { idx = 544, changed = 0, value = { 1 },    size = 1, path = "mcs_idx8_swing_multiple_louver2", value_map = { [13] = "close", [1] = 'close', [2] = '1', [3] = '2', [4] = '3', [5] = '4', [6] = '5', [7] = 'auto' } },
    { idx = 545, changed = 0, value = { 1 },    size = 1, path = "mcs_idx8_swing_multiple_louver3", value_map = { [13] = "close", [1] = 'close', [2] = '1', [3] = '2', [4] = '3', [5] = '4', [6] = '5', [7] = 'auto' } },
    { idx = 546, changed = 0, value = { 1 },    size = 1, path = "mcs_idx8_swing_multiple_louver4", value_map = { [13] = "close", [1] = 'close', [2] = '1', [3] = '2', [4] = '3', [5] = '4', [6] = '5', [7] = 'auto' } },

	{ idx = 547, changed = 0, value = {   2 },  size = 1, path = "mcs_idx9_addr", },
    { idx = 548, changed = 0, value = { 48 },   size = 6, path = "mcs_idx9_fault_code", value_type = "chars" },
	{ idx = 549, changed = 0, value = {   2 },  size = 1, path = "mcs_idx9_type", },
	{ idx = 550, changed = 0, value = {   2 },  size = 2, path = "mcs_idx9_temp_room", value_type = "temp_10s" },
	{ idx = 551, changed = 0, value = {   2 },  size = 1, path = "mcs_idx9_power", value_map = { [1] = "off", [2] = "on" } },
	{ idx = 552, changed = 0, value = { 3 },    size = 1, path = "mcs_idx9_mode", value_map = key_map_value['mode'] },
	{ idx = 553, changed = 0, value = {   2 },  size = 1, path = "mcs_idx9_wind_speed", value_map = key_map_value['wind_speed'] },
	{ idx = 554, changed = 0, value = { 132 },  size = 1, path = "mcs_idx9_temp", value_type = "temp" },
	{ idx = 555, changed = 0, value = { 114 },   size = 1, path = "mcs_idx9_auto_min" ,value_type = "temp"},
    { idx = 556, changed = 0, value = { 140 },   size = 1, path = "mcs_idx9_auto_max" ,value_type = "temp"},
    { idx = 557, changed = 0, value = { 1 },    size = 1, path = "mcs_idx9_louver_horizontal_enable", value_map = { [1] = "false", [2] = "true" } },
    { idx = 558, changed = 0, value = { 1 },    size = 1, path = "mcs_idx9_louver_horizontal_level", value_map = { [13] = "close", [1] = 'close', [2] = '1', [3] = '2', [4] = '3', [5] = '4', [6] = '5', [7] = 'auto' } },
    { idx = 559, changed = 0, value = { 1 },    size = 1, path = "mcs_idx9_louver_vertical_enable", value_map = { [1] = "false", [2] = "true" } },
    { idx = 560, changed = 0, value = { 3 },    size = 1, path = "mcs_idx9_louver_vertical_level", value_map = { [13] = "close", [1] = 'close', [2] = '1', [3] = '2', [4] = '3', [5] = '4', [6] = '5', [7] = 'auto' } },
	{ idx = 561, changed = 0, value = { 1 },    size = 1, path = "mcs_idx9_swing_multiple_enable", value_map = { [1] = "false", [2] = "true" } },
    { idx = 562, changed = 0, value = { 1 },    size = 1, path = "mcs_idx9_swing_multiple_louver1", value_map = { [13] = "close", [1] = 'close', [2] = '1', [3] = '2', [4] = '3', [5] = '4', [6] = '5', [7] = 'auto' } },
    { idx = 563, changed = 0, value = { 1 },    size = 1, path = "mcs_idx9_swing_multiple_louver2", value_map = { [13] = "close", [1] = 'close', [2] = '1', [3] = '2', [4] = '3', [5] = '4', [6] = '5', [7] = 'auto' } },
    { idx = 564, changed = 0, value = { 1 },    size = 1, path = "mcs_idx9_swing_multiple_louver3", value_map = { [13] = "close", [1] = 'close', [2] = '1', [3] = '2', [4] = '3', [5] = '4', [6] = '5', [7] = 'auto' } },
    { idx = 565, changed = 0, value = { 1 },    size = 1, path = "mcs_idx9_swing_multiple_louver4", value_map = { [13] = "close", [1] = 'close', [2] = '1', [3] = '2', [4] = '3', [5] = '4', [6] = '5', [7] = 'auto' } },

	{ idx = 566, changed = 0, value = {   2 },  size = 1, path = "mcs_idx10_addr", },
    { idx = 567, changed = 0, value = { 48 },   size = 6, path = "mcs_idx10_fault_code", value_type = "chars" },
	{ idx = 568, changed = 0, value = {   2 },  size = 1, path = "mcs_idx10_type", },
	{ idx = 569, changed = 0, value = {   2 },  size = 2, path = "mcs_idx10_temp_room", value_type = "temp_10s" },
	{ idx = 570, changed = 0, value = {   2 },  size = 1, path = "mcs_idx10_power", value_map = { [1] = "off", [2] = "on" } },
	{ idx = 571, changed = 0, value = { 3 },    size = 1, path = "mcs_idx10_mode", value_map = key_map_value['mode'] },
	{ idx = 572, changed = 0, value = {   2 },  size = 1, path = "mcs_idx10_wind_speed", value_map = key_map_value['wind_speed'] },
	{ idx = 573, changed = 0, value = { 132 },  size = 1, path = "mcs_idx10_temp", value_type = "temp" },
	{ idx = 574, changed = 0, value = { 114 },   size = 1, path = "mcs_idx10_auto_min" ,value_type = "temp"},
    { idx = 575, changed = 0, value = { 140 },   size = 1, path = "mcs_idx10_auto_max" ,value_type = "temp"},
    { idx = 576, changed = 0, value = { 1 },    size = 1, path = "mcs_idx10_louver_horizontal_enable", value_map = { [1] = "false", [2] = "true" } },
    { idx = 577, changed = 0, value = { 1 },    size = 1, path = "mcs_idx10_louver_horizontal_level", value_map = { [13] = "close", [1] = 'close', [2] = '1', [3] = '2', [4] = '3', [5] = '4', [6] = '5', [7] = 'auto' } },
    { idx = 578, changed = 0, value = { 1 },    size = 1, path = "mcs_idx10_louver_vertical_enable", value_map = { [1] = "false", [2] = "true" } },
    { idx = 579, changed = 0, value = { 3 },    size = 1, path = "mcs_idx10_louver_vertical_level", value_map = { [13] = "close", [1] = 'close', [2] = '1', [3] = '2', [4] = '3', [5] = '4', [6] = '5', [7] = 'auto' } },
	{ idx = 580, changed = 0, value = { 1 },    size = 1, path = "mcs_idx10_swing_multiple_enable", value_map = { [1] = "false", [2] = "true" } },
    { idx = 581, changed = 0, value = { 1 },    size = 1, path = "mcs_idx10_swing_multiple_louver1", value_map = { [13] = "close", [1] = 'close', [2] = '1', [3] = '2', [4] = '3', [5] = '4', [6] = '5', [7] = 'auto' } },
    { idx = 582, changed = 0, value = { 1 },    size = 1, path = "mcs_idx10_swing_multiple_louver2", value_map = { [13] = "close", [1] = 'close', [2] = '1', [3] = '2', [4] = '3', [5] = '4', [6] = '5', [7] = 'auto' } },
    { idx = 583, changed = 0, value = { 1 },    size = 1, path = "mcs_idx10_swing_multiple_louver3", value_map = { [13] = "close", [1] = 'close', [2] = '1', [3] = '2', [4] = '3', [5] = '4', [6] = '5', [7] = 'auto' } },
    { idx = 584, changed = 0, value = { 1 },    size = 1, path = "mcs_idx10_swing_multiple_louver4", value_map = { [13] = "close", [1] = 'close', [2] = '1', [3] = '2', [4] = '3', [5] = '4', [6] = '5', [7] = 'auto' } },

	{ idx = 585, changed = 0, value = {   2 },  size = 1, path = "mcs_idx11_addr", },
    { idx = 586, changed = 0, value = { 48 },   size = 6, path = "mcs_idx11_fault_code", value_type = "chars" },
	{ idx = 587, changed = 0, value = {   2 },  size = 1, path = "mcs_idx11_type", },
	{ idx = 588, changed = 0, value = {   2 },  size = 2, path = "mcs_idx11_temp_room", value_type = "temp_10s" },
	{ idx = 589, changed = 0, value = {   2 },  size = 1, path = "mcs_idx11_power", value_map = { [1] = "off", [2] = "on" } },
	{ idx = 590, changed = 0, value = { 3 },    size = 1, path = "mcs_idx11_mode", value_map = key_map_value['mode'] },
	{ idx = 591, changed = 0, value = {   2 },  size = 1, path = "mcs_idx11_wind_speed", value_map = key_map_value['wind_speed'] },
	{ idx = 592, changed = 0, value = { 132 },  size = 1, path = "mcs_idx11_temp", value_type = "temp" },
	{ idx = 593, changed = 0, value = { 114 },   size = 1, path = "mcs_idx11_auto_min" ,value_type = "temp"},
    { idx = 594, changed = 0, value = { 140 },   size = 1, path = "mcs_idx11_auto_max" ,value_type = "temp"},
    { idx = 595, changed = 0, value = { 1 },    size = 1, path = "mcs_idx11_louver_horizontal_enable", value_map = { [1] = "false", [2] = "true" } },
    { idx = 596, changed = 0, value = { 1 },    size = 1, path = "mcs_idx11_louver_horizontal_level", value_map = { [13] = "close", [1] = 'close', [2] = '1', [3] = '2', [4] = '3', [5] = '4', [6] = '5', [7] = 'auto' } },
    { idx = 597, changed = 0, value = { 1 },    size = 1, path = "mcs_idx11_louver_vertical_enable", value_map = { [1] = "false", [2] = "true" } },
    { idx = 598, changed = 0, value = { 3 },    size = 1, path = "mcs_idx11_louver_vertical_level", value_map = { [13] = "close", [1] = 'close', [2] = '1', [3] = '2', [4] = '3', [5] = '4', [6] = '5', [7] = 'auto' } },
	{ idx = 599, changed = 0, value = { 1 },    size = 1, path = "mcs_idx11_swing_multiple_enable", value_map = { [1] = "false", [2] = "true" } },
    { idx = 600, changed = 0, value = { 1 },    size = 1, path = "mcs_idx11_swing_multiple_louver1", value_map = { [13] = "close", [1] = 'close', [2] = '1', [3] = '2', [4] = '3', [5] = '4', [6] = '5', [7] = 'auto' } },
    { idx = 601, changed = 0, value = { 1 },    size = 1, path = "mcs_idx11_swing_multiple_louver2", value_map = { [13] = "close", [1] = 'close', [2] = '1', [3] = '2', [4] = '3', [5] = '4', [6] = '5', [7] = 'auto' } },
    { idx = 602, changed = 0, value = { 1 },    size = 1, path = "mcs_idx11_swing_multiple_louver3", value_map = { [13] = "close", [1] = 'close', [2] = '1', [3] = '2', [4] = '3', [5] = '4', [6] = '5', [7] = 'auto' } },
    { idx = 603, changed = 0, value = { 1 },    size = 1, path = "mcs_idx11_swing_multiple_louver4", value_map = { [13] = "close", [1] = 'close', [2] = '1', [3] = '2', [4] = '3', [5] = '4', [6] = '5', [7] = 'auto' } },

	{ idx = 604, changed = 0, value = {   2 },  size = 1, path = "mcs_idx12_addr", },
    { idx = 605, changed = 0, value = { 48 },   size = 6, path = "mcs_idx12_fault_code", value_type = "chars" },
	{ idx = 606, changed = 0, value = {   2 },  size = 1, path = "mcs_idx12_type", },
	{ idx = 607, changed = 0, value = {   2 },  size = 2, path = "mcs_idx12_temp_room", value_type = "temp_10s" },
	{ idx = 608, changed = 0, value = {   2 },  size = 1, path = "mcs_idx12_power", value_map = { [1] = "off", [2] = "on" } },
	{ idx = 609, changed = 0, value = { 3 },    size = 1, path = "mcs_idx12_mode", value_map = key_map_value['mode'] },
	{ idx = 610, changed = 0, value = {   2 },  size = 1, path = "mcs_idx12_wind_speed", value_map = key_map_value['wind_speed'] },
	{ idx = 611, changed = 0, value = { 132 },  size = 1, path = "mcs_idx12_temp", value_type = "temp" },
	{ idx = 612, changed = 0, value = { 114 },   size = 1, path = "mcs_idx12_auto_min" ,value_type = "temp"},
    { idx = 613, changed = 0, value = { 140 },   size = 1, path = "mcs_idx12_auto_max" ,value_type = "temp"},
    { idx = 614, changed = 0, value = { 1 },    size = 1, path = "mcs_idx12_louver_horizontal_enable", value_map = { [1] = "false", [2] = "true" } },
    { idx = 615, changed = 0, value = { 1 },    size = 1, path = "mcs_idx12_louver_horizontal_level", value_map = { [13] = "close", [1] = 'close', [2] = '1', [3] = '2', [4] = '3', [5] = '4', [6] = '5', [7] = 'auto' } },
    { idx = 616, changed = 0, value = { 1 },    size = 1, path = "mcs_idx12_louver_vertical_enable", value_map = { [1] = "false", [2] = "true" } },
    { idx = 617, changed = 0, value = { 3 },    size = 1, path = "mcs_idx12_louver_vertical_level", value_map = { [13] = "close", [1] = 'close', [2] = '1', [3] = '2', [4] = '3', [5] = '4', [6] = '5', [7] = 'auto' } },
	{ idx = 618, changed = 0, value = { 1 },    size = 1, path = "mcs_idx12_swing_multiple_enable", value_map = { [1] = "false", [2] = "true" } },
    { idx = 619, changed = 0, value = { 1 },    size = 1, path = "mcs_idx12_swing_multiple_louver1", value_map = { [13] = "close", [1] = 'close', [2] = '1', [3] = '2', [4] = '3', [5] = '4', [6] = '5', [7] = 'auto' } },
    { idx = 620, changed = 0, value = { 1 },    size = 1, path = "mcs_idx12_swing_multiple_louver2", value_map = { [13] = "close", [1] = 'close', [2] = '1', [3] = '2', [4] = '3', [5] = '4', [6] = '5', [7] = 'auto' } },
    { idx = 621, changed = 0, value = { 1 },    size = 1, path = "mcs_idx12_swing_multiple_louver3", value_map = { [13] = "close", [1] = 'close', [2] = '1', [3] = '2', [4] = '3', [5] = '4', [6] = '5', [7] = 'auto' } },
    { idx = 622, changed = 0, value = { 1 },    size = 1, path = "mcs_idx12_swing_multiple_louver4", value_map = { [13] = "close", [1] = 'close', [2] = '1', [3] = '2', [4] = '3', [5] = '4', [6] = '5', [7] = 'auto' } },

	{ idx = 623, changed = 0, value = {   2 },  size = 1, path = "mcs_idx13_addr", },
    { idx = 624, changed = 0, value = { 48 },   size = 6, path = "mcs_idx13_fault_code", value_type = "chars" },
	{ idx = 625, changed = 0, value = {   2 },  size = 1, path = "mcs_idx13_type", },
	{ idx = 626, changed = 0, value = {   2 },  size = 2, path = "mcs_idx13_temp_room", value_type = "temp_10s" },
	{ idx = 627, changed = 0, value = {   2 },  size = 1, path = "mcs_idx13_power", value_map = { [1] = "off", [2] = "on" } },
	{ idx = 628, changed = 0, value = { 3 },    size = 1, path = "mcs_idx13_mode", value_map = key_map_value['mode'] },
	{ idx = 629, changed = 0, value = {   2 },  size = 1, path = "mcs_idx13_wind_speed", value_map = key_map_value['wind_speed'] },
	{ idx = 630, changed = 0, value = { 132 },  size = 1, path = "mcs_idx13_temp", value_type = "temp" },
	{ idx = 631, changed = 0, value = { 114 },   size = 1, path = "mcs_idx13_auto_min" ,value_type = "temp"},
    { idx = 632, changed = 0, value = { 140 },   size = 1, path = "mcs_idx13_auto_max" ,value_type = "temp"},
    { idx = 633, changed = 0, value = { 1 },    size = 1, path = "mcs_idx13_louver_horizontal_enable", value_map = { [1] = "false", [2] = "true" } },
    { idx = 634, changed = 0, value = { 1 },    size = 1, path = "mcs_idx13_louver_horizontal_level", value_map = { [13] = "close", [1] = 'close', [2] = '1', [3] = '2', [4] = '3', [5] = '4', [6] = '5', [7] = 'auto' } },
    { idx = 635, changed = 0, value = { 1 },    size = 1, path = "mcs_idx13_louver_vertical_enable", value_map = { [1] = "false", [2] = "true" } },
    { idx = 636, changed = 0, value = { 3 },    size = 1, path = "mcs_idx13_louver_vertical_level", value_map = { [13] = "close", [1] = 'close', [2] = '1', [3] = '2', [4] = '3', [5] = '4', [6] = '5', [7] = 'auto' } },
	{ idx = 637, changed = 0, value = { 1 },    size = 1, path = "mcs_idx13_swing_multiple_enable", value_map = { [1] = "false", [2] = "true" } },
    { idx = 638, changed = 0, value = { 1 },    size = 1, path = "mcs_idx13_swing_multiple_louver1", value_map = { [13] = "close", [1] = 'close', [2] = '1', [3] = '2', [4] = '3', [5] = '4', [6] = '5', [7] = 'auto' } },
    { idx = 639, changed = 0, value = { 1 },    size = 1, path = "mcs_idx13_swing_multiple_louver2", value_map = { [13] = "close", [1] = 'close', [2] = '1', [3] = '2', [4] = '3', [5] = '4', [6] = '5', [7] = 'auto' } },
    { idx = 640, changed = 0, value = { 1 },    size = 1, path = "mcs_idx13_swing_multiple_louver3", value_map = { [13] = "close", [1] = 'close', [2] = '1', [3] = '2', [4] = '3', [5] = '4', [6] = '5', [7] = 'auto' } },
    { idx = 641, changed = 0, value = { 1 },    size = 1, path = "mcs_idx13_swing_multiple_louver4", value_map = { [13] = "close", [1] = 'close', [2] = '1', [3] = '2', [4] = '3', [5] = '4', [6] = '5', [7] = 'auto' } },

	{ idx = 642, changed = 0, value = {   2 },  size = 1, path = "mcs_idx14_addr", },
    { idx = 643, changed = 0, value = { 48 },   size = 6, path = "mcs_idx14_fault_code", value_type = "chars" },
	{ idx = 644, changed = 0, value = {   2 },  size = 1, path = "mcs_idx14_type", },
	{ idx = 645, changed = 0, value = {   2 },  size = 2, path = "mcs_idx14_temp_room", value_type = "temp_10s" },
	{ idx = 646, changed = 0, value = {   2 },  size = 1, path = "mcs_idx14_power", value_map = { [1] = "off", [2] = "on" } },
	{ idx = 647, changed = 0, value = { 3 },    size = 1, path = "mcs_idx14_mode", value_map = key_map_value['mode'] },
	{ idx = 648, changed = 0, value = {   2 },  size = 1, path = "mcs_idx14_wind_speed", value_map = key_map_value['wind_speed'] },
	{ idx = 649, changed = 0, value = { 132 },  size = 1, path = "mcs_idx14_temp", value_type = "temp" },
	{ idx = 650, changed = 0, value = { 114 },   size = 1, path = "mcs_idx14_auto_min" ,value_type = "temp"},
    { idx = 651, changed = 0, value = { 140 },   size = 1, path = "mcs_idx14_auto_max" ,value_type = "temp"},
    { idx = 652, changed = 0, value = { 1 },    size = 1, path = "mcs_idx14_louver_horizontal_enable", value_map = { [1] = "false", [2] = "true" } },
    { idx = 653, changed = 0, value = { 1 },    size = 1, path = "mcs_idx14_louver_horizontal_level", value_map = { [13] = "close", [1] = 'close', [2] = '1', [3] = '2', [4] = '3', [5] = '4', [6] = '5', [7] = 'auto' } },
    { idx = 654, changed = 0, value = { 1 },    size = 1, path = "mcs_idx14_louver_vertical_enable", value_map = { [1] = "false", [2] = "true" } },
    { idx = 655, changed = 0, value = { 3 },    size = 1, path = "mcs_idx14_louver_vertical_level", value_map = { [13] = "close", [1] = 'close', [2] = '1', [3] = '2', [4] = '3', [5] = '4', [6] = '5', [7] = 'auto' } },
	{ idx = 656, changed = 0, value = { 1 },    size = 1, path = "mcs_idx14_swing_multiple_enable", value_map = { [1] = "false", [2] = "true" } },
    { idx = 657, changed = 0, value = { 1 },    size = 1, path = "mcs_idx14_swing_multiple_louver1", value_map = { [13] = "close", [1] = 'close', [2] = '1', [3] = '2', [4] = '3', [5] = '4', [6] = '5', [7] = 'auto' } },
    { idx = 658, changed = 0, value = { 1 },    size = 1, path = "mcs_idx14_swing_multiple_louver2", value_map = { [13] = "close", [1] = 'close', [2] = '1', [3] = '2', [4] = '3', [5] = '4', [6] = '5', [7] = 'auto' } },
    { idx = 659, changed = 0, value = { 1 },    size = 1, path = "mcs_idx14_swing_multiple_louver3", value_map = { [13] = "close", [1] = 'close', [2] = '1', [3] = '2', [4] = '3', [5] = '4', [6] = '5', [7] = 'auto' } },
    { idx = 660, changed = 0, value = { 1 },    size = 1, path = "mcs_idx14_swing_multiple_louver4", value_map = { [13] = "close", [1] = 'close', [2] = '1', [3] = '2', [4] = '3', [5] = '4', [6] = '5', [7] = 'auto' } },

	{ idx = 661, changed = 0, value = {   2 },  size = 1, path = "mcs_idx15_addr", },
    { idx = 662, changed = 0, value = { 48 },   size = 6, path = "mcs_idx15_fault_code", value_type = "chars" },
	{ idx = 663, changed = 0, value = {   2 },  size = 1, path = "mcs_idx15_type", },
	{ idx = 664, changed = 0, value = {   2 },  size = 2, path = "mcs_idx15_temp_room", value_type = "temp_10s" },
	{ idx = 665, changed = 0, value = {   2 },  size = 1, path = "mcs_idx15_power", value_map = { [1] = "off", [2] = "on" } },
	{ idx = 666, changed = 0, value = { 3 },    size = 1, path = "mcs_idx15_mode", value_map = key_map_value['mode'] },
	{ idx = 667, changed = 0, value = {   2 },  size = 1, path = "mcs_idx15_wind_speed", value_map = key_map_value['wind_speed'] },
	{ idx = 668, changed = 0, value = { 132 },  size = 1, path = "mcs_idx15_temp", value_type = "temp" },
	{ idx = 669, changed = 0, value = { 114 },   size = 1, path = "mcs_idx15_auto_min" ,value_type = "temp"},
    { idx = 670, changed = 0, value = { 140 },   size = 1, path = "mcs_idx15_auto_max" ,value_type = "temp"},
    { idx = 671, changed = 0, value = { 1 },    size = 1, path = "mcs_idx15_louver_horizontal_enable", value_map = { [1] = "false", [2] = "true" } },
    { idx = 672, changed = 0, value = { 1 },    size = 1, path = "mcs_idx15_louver_horizontal_level", value_map = { [13] = "close", [1] = 'close', [2] = '1', [3] = '2', [4] = '3', [5] = '4', [6] = '5', [7] = 'auto' } },
    { idx = 673, changed = 0, value = { 1 },    size = 1, path = "mcs_idx15_louver_vertical_enable", value_map = { [1] = "false", [2] = "true" } },
    { idx = 674, changed = 0, value = { 3 },    size = 1, path = "mcs_idx15_louver_vertical_level", value_map = { [13] = "close", [1] = 'close', [2] = '1', [3] = '2', [4] = '3', [5] = '4', [6] = '5', [7] = 'auto' } },
	{ idx = 675, changed = 0, value = { 1 },    size = 1, path = "mcs_idx15_swing_multiple_enable", value_map = { [1] = "false", [2] = "true" } },
    { idx = 676, changed = 0, value = { 1 },    size = 1, path = "mcs_idx15_swing_multiple_louver1", value_map = { [13] = "close", [1] = 'close', [2] = '1', [3] = '2', [4] = '3', [5] = '4', [6] = '5', [7] = 'auto' } },
    { idx = 677, changed = 0, value = { 1 },    size = 1, path = "mcs_idx15_swing_multiple_louver2", value_map = { [13] = "close", [1] = 'close', [2] = '1', [3] = '2', [4] = '3', [5] = '4', [6] = '5', [7] = 'auto' } },
    { idx = 678, changed = 0, value = { 1 },    size = 1, path = "mcs_idx15_swing_multiple_louver3", value_map = { [13] = "close", [1] = 'close', [2] = '1', [3] = '2', [4] = '3', [5] = '4', [6] = '5', [7] = 'auto' } },
    { idx = 679, changed = 0, value = { 1 },    size = 1, path = "mcs_idx15_swing_multiple_louver4", value_map = { [13] = "close", [1] = 'close', [2] = '1', [3] = '2', [4] = '3', [5] = '4', [6] = '5', [7] = 'auto' } },

	--/*内机单控以及内机命名 only write */
	{ idx = 680, changed = 0, value = {   2 },  size = 1, path = "ctrl_addr", value_type = "mcs_addr"},
	{ idx = 681, changed = 0, value = {   2 },  size = 2, path = "ctrl_power", value_map = { [1] = "off", [2] = "on" } ,extra_type = "need_addr"},
	{ idx = 682, changed = 0, value = { 3 },    size = 2, path = "ctrl_mode", value_map = key_map_value['mode'] ,extra_type = "need_addr"},
	{ idx = 683, changed = 0, value = {   2 },  size = 2, path = "ctrl_wind_speed", value_map = key_map_value['wind_speed'] ,extra_type = "need_addr"},
	{ idx = 684, changed = 0, value = { 132 },  size = 2, path = "ctrl_temp", value_type = "temp" ,extra_type = "need_addr"},
	{ idx = 685, changed = 0, value = { 114 },  size = 2, path = "ctrl_auto_min" ,value_type = "temp",extra_type = "need_addr"},
    { idx = 686, changed = 0, value = { 140 },  size = 2, path = "ctrl_auto_max" ,value_type = "temp",extra_type = "need_addr"},
    { idx = 687, changed = 0, value = { 1 },    size = 2, path = "ctrl_louver_hori_level", value_map = { [13] = "close", [1] = 'close', [2] = '1', [3] = '2', [4] = '3', [5] = '4', [6] = '5', [7] = 'auto' } ,extra_type = "need_addr"},
	{ idx = 688, changed = 0, value = { 3 },    size = 2, path = "ctrl_louver_vertical_level", value_map = { [13] = "close", [1] = 'close', [2] = '1', [3] = '2', [4] = '3', [5] = '4', [6] = '5', [7] = 'auto' } ,extra_type = "need_addr"},
	{ idx = 689, changed = 0, value = { 1 },    size = 2, path = "ctrl_swing_multiple_louver1", value_map = { [13] = "close", [1] = 'close', [2] = '1', [3] = '2', [4] = '3', [5] = '4', [6] = '5', [7] = 'auto' } ,extra_type = "need_addr"},
    { idx = 690, changed = 0, value = { 1 },    size = 2, path = "ctrl_swing_multiple_louver2", value_map = { [13] = "close", [1] = 'close', [2] = '1', [3] = '2', [4] = '3', [5] = '4', [6] = '5', [7] = 'auto' } ,extra_type = "need_addr"},
    { idx = 691, changed = 0, value = { 1 },    size = 2, path = "ctrl_swing_multiple_louver3", value_map = { [13] = "close", [1] = 'close', [2] = '1', [3] = '2', [4] = '3', [5] = '4', [6] = '5', [7] = 'auto' } ,extra_type = "need_addr"},
    { idx = 692, changed = 0, value = { 1 },    size = 2, path = "ctrl_swing_multiple_louver4", value_map = { [13] = "close", [1] = 'close', [2] = '1', [3] = '2', [4] = '3', [5] = '4', [6] = '5', [7] = 'auto' } ,extra_type = "need_addr"},
	{ idx = 693, changed = 0, value = {   2 },  size = 2, path = "idu_name_part0", value_map = key_map_value["area_name"] ,extra_type = "need_addr"},
	{ idx = 694, changed = 0, value = {   2 },  size = 2, path = "idu_name_part1", value_map = key_map_value["direction_name"],extra_type = "need_addr" },
	{ idx = 695, changed = 0, value = {   2 },  size = 2, path = "idu_name_part2_number0" ,extra_type = "need_addr" },
	{ idx = 696, changed = 0, value = {   2 },  size = 2, path = "idu_name_part2_number1" ,extra_type = "need_addr"},
	{ idx = 697, changed = 0, value = {   2 },  size = 2, path = "idu_name_part2_number2",extra_type = "need_addr" },
	{ idx = 698, changed = 0, value = {   2 },  size = 2, path = "idu_name_part2_number3", extra_type = "need_addr" },

	--/*内机SN*/
	{ idx = 699, changed = 0, value = {   2 },  size = 1, path = "name_idx0_addr", },
	{ idx = 700, changed = 0, value = { 48 },   size = 22, path = "name_idx0_sn", value_type = "chars" },
	{ idx = 701, changed = 0, value = {   2 },  size = 1, path = "name_idx1_addr", },
	{ idx = 702, changed = 0, value = { 48 },   size = 22, path = "name_idx1_sn", value_type = "chars" },
	{ idx = 703, changed = 0, value = {   2 },  size = 1, path = "name_idx2_addr", },
	{ idx = 704, changed = 0, value = { 48 },   size = 22, path = "name_idx2_sn", value_type = "chars" },
	{ idx = 705, changed = 0, value = {   2 },  size = 1, path = "name_idx3_addr", },
	{ idx = 706, changed = 0, value = { 48 },   size = 22, path = "name_idx3_sn", value_type = "chars" },
	{ idx = 707, changed = 0, value = {   2 },  size = 1, path = "name_idx4_addr", },
	{ idx = 708, changed = 0, value = { 48 },   size = 22, path = "name_idx4_sn", value_type = "chars" },
	{ idx = 709, changed = 0, value = {   2 },  size = 1, path = "name_idx5_addr", },
	{ idx = 710, changed = 0, value = { 48 },   size = 22, path = "name_idx5_sn", value_type = "chars" },
	{ idx = 711, changed = 0, value = {   2 },  size = 1, path = "name_idx6_addr", },
	{ idx = 712, changed = 0, value = { 48 },   size = 22, path = "name_idx6_sn", value_type = "chars" },
	{ idx = 713, changed = 0, value = {   2 },  size = 1, path = "name_idx7_addr", },
	{ idx = 714, changed = 0, value = { 48 },   size = 22, path = "name_idx7_sn", value_type = "chars" },
	{ idx = 715, changed = 0, value = {   2 },  size = 1, path = "name_idx8_addr", },
	{ idx = 716, changed = 0, value = { 48 },   size = 22, path = "name_idx8_sn", value_type = "chars" },
	{ idx = 717, changed = 0, value = {   2 },  size = 1, path = "name_idx9_addr", },
	{ idx = 718, changed = 0, value = { 48 },   size = 22, path = "name_idx9_sn", value_type = "chars" },
	{ idx = 719, changed = 0, value = {   2 },  size = 1, path = "name_idx10_addr", },
	{ idx = 720, changed = 0, value = { 48 },   size = 22, path = "name_idx10_sn", value_type = "chars" },
	{ idx = 721, changed = 0, value = {   2 },  size = 1, path = "name_idx11_addr", },
	{ idx = 722, changed = 0, value = { 48 },   size = 22, path = "name_idx11_sn", value_type = "chars" },
	{ idx = 723, changed = 0, value = {   2 },  size = 1, path = "name_idx12_addr", },
	{ idx = 724, changed = 0, value = { 48 },   size = 22, path = "name_idx12_sn", value_type = "chars" },
	{ idx = 725, changed = 0, value = {   2 },  size = 1, path = "name_idx13_addr", },
	{ idx = 726, changed = 0, value = { 48 },   size = 22, path = "name_idx13_sn", value_type = "chars" },
	{ idx = 727, changed = 0, value = {   2 },  size = 1, path = "name_idx14_addr", },
	{ idx = 728, changed = 0, value = { 48 },   size = 22, path = "name_idx14_sn", value_type = "chars" },
	{ idx = 729, changed = 0, value = {   2 },  size = 1, path = "name_idx15_addr", },
	{ idx = 730, changed = 0, value = { 48 },   size = 22, path = "name_idx15_sn", value_type = "chars" },
	-- 工程参数设定
}

local array_f_to_c = {
    [-13] = 0,
    -- -25
    [-12] = 1,
    -- -24.5
    [-11] = 2,
    -- -24
    [-10] = 3,
    -- -23.5
    [-9]  = 4,
    -- -23
    [-9]  = 5,
    -- -22.5
    [-8]  = 6,
    -- -22
    [-7]  = 7,
    -- -21.5
    [-6]  = 8,
    -- -21
    [-5]  = 9,
    -- -20.5
    [-4]  = 10,
    -- -20
    [-3]  = 11,
    -- -19.5
    [-2]  = 12,
    -- -19
    [-2]  = 13,
    -- -18.5
    [-1]  = 14,
    -- -18
    [0]   = 15,
    -- -17.5
    [1]   = 16,
    -- -17
    [2]   = 17,
    -- -16.5
    [3]   = 18,
    -- -16
    [4]   = 19,
    -- -15.5
    [5]   = 20,
    -- -15
    [6]   = 21,
    -- -14.5
    [7]   = 22,
    -- -14
    [8]   = 23,
    -- -13.5
    [9]   = 24,
    -- -13
    [10]  = 25,
    -- -12.5
    [10]  = 26,
    -- -12
    [11]  = 27,
    -- -11.5
    [12]  = 28,
    -- -11
    [13]  = 29,
    -- -10.5
    [14]  = 30,
    -- -10
    [15]  = 31,
    -- -9.5
    [16]  = 32,
    -- -9
    [17]  = 33,
    -- -8.5
    [18]  = 34,
    -- -8
    [19]  = 35,
    -- -7.5
    [19]  = 36,
    -- -7
    [20]  = 37,
    -- -6.5
    [21]  = 38,
    -- -6
    [22]  = 39,
    -- -5.5
    [23]  = 40,
    -- -5
    [24]  = 41,
    -- -4.5
    [25]  = 42,
    -- -4
    [26]  = 43,
    -- -3.5
    [27]  = 44,
    -- -3
    [28]  = 45,
    -- -2.5
    [28]  = 46,
    -- -2
    [29]  = 47,
    -- -1.5
    [30]  = 48,
    -- -1
    [31]  = 49,
    -- -0.5
    [32]  = 50,
    -- 0
    [33]  = 51,
    -- 0.5
    [34]  = 52,
    -- 1
    [35]  = 53,
    -- 1.5
    [36]  = 54,
    -- 2
    [37]  = 55,
    -- 2.5
    [37]  = 56,
    -- 3
    [38]  = 57,
    -- 3.5
    [39]  = 58,
    -- 4
    [40]  = 59,
    -- 4.5
    [41]  = 60,
    -- 5
    [42]  = 61,
    -- 5.5
    [43]  = 62,
    -- 6
    [44]  = 63,
    -- 6.5
    [45]  = 64,
    -- 7
    [46]  = 65,
    -- 7.5
    [46]  = 66,
    -- 8
    [47]  = 67,
    -- 8.5
    [48]  = 68,
    -- 9
    [49]  = 69,
    -- 9.5
    [50]  = 70,
    -- 10
    [51]  = 71,
    -- 10.5
    [52]  = 72,
    -- 11
    [53]  = 73,
    -- 11.5
    [54]  = 74,
    -- 12
    [55]  = 75,
    -- 12.5
    [55]  = 76,
    -- 13
    [56]  = 77,
    -- 13.5
    [57]  = 78,
    -- 14
    [58]  = 79,
    -- 14.5
    [59]  = 80,
    -- 15
    [60]  = 81,
    -- 15.5
    [61]  = 82,
    -- 16
    [62]  = 83,
    -- 16.5
    [62]  = 84,
    -- 17
    [63]  = 85,
    -- 17.5
    [64]  = 86,
    -- 18
    [65]  = 87,
    -- 18.5
    [66]  = 88,
    -- 19
    [67]  = 89,
    -- 19.5
    [68]  = 90,
    -- 20
    [69]  = 91,
    -- 20.5
    [70]  = 92,
    -- 21
    [71]  = 93,
    -- 21.5
    [72]  = 94,
    -- 22
    [73]  = 95,
    -- 22.5
    [73]  = 96,
    -- 23
    [74]  = 97,
    -- 23.5
    [75]  = 98,
    -- 24
    [76]  = 99,
    -- 24.5
    [77]  = 100,
    -- 25
    [78]  = 101,
    -- 25.5
    [79]  = 102,
    -- 26
    [80]  = 103,
    -- 26.5
    [81]  = 104,
    -- 27
    [82]  = 105,
    -- 27.5
    [82]  = 106,
    -- 28
    [83]  = 107,
    -- 28.5
    [84]  = 108,
    -- 29
    [85]  = 109,
    -- 29.5
    [86]  = 110,
    -- 30
    [87]  = 111,
    -- 30.5
    [88]  = 112,
    -- 31
    [89]  = 113,
    -- 31.5
    [90]  = 114,
    -- 32
    [91]  = 115,
    -- 32.5
    [91]  = 116,
    -- 33
    [92]  = 117,
    -- 33.5
    [93]  = 118,
    -- 34
    [94]  = 119,
    -- 34.5
    [95]  = 120,
    -- 35
    [96]  = 121,
    -- 35.5
    [97]  = 122,
    -- 36
    [98]  = 123,
    -- 36.5
    [99]  = 124,
    -- 37
    [100] = 125,
    -- 37.5
    [100] = 126,
    -- 38
    [101] = 127,
    -- 38.5
    [102] = 128,
    -- 39
    [103] = 129,
    -- 39.5
    [104] = 130,
    -- 40
    [105] = 131,
    -- 40.5
    [106] = 132,
    -- 41
    [107] = 133,
    -- 41.5
    [108] = 134,
    -- 42
    [109] = 135,
    -- 42.5
    [109] = 136,
    -- 43
    [110] = 137,
    -- 43.5
    [111] = 138,
    -- 44
    [112] = 139,
    -- 44.5
    [113] = 140,
    -- 45
    [114] = 141,
    -- 45.5
    [115] = 142,
    -- 46
    [116] = 143,
    -- 46.5
    [117] = 144,
    -- 47
    [118] = 145,
    -- 47.5
    [118] = 146,
    -- 48
    [119] = 147,
    -- 48.5
    [120] = 148,
    -- 49
    [121] = 149,
    -- 49.5
    [122] = 150,
    -- 50
    [123] = 151,
    -- 50.5
    [124] = 152,
    -- 51
    [125] = 153,
    -- 51.5
    [126] = 154,
    -- 52
    [127] = 155,
    -- 52.5
    [127] = 156,
    -- 53
    [128] = 157,
    -- 53.5
    [129] = 158,
    -- 54
    [130] = 159,
    -- 54.5
    [131] = 160,
    -- 55
    [132] = 161,
    -- 55.5
    [133] = 162,
    -- 56
    [134] = 163,
    -- 56.5
    [135] = 164,
    -- 57
    [136] = 165,
    -- 57.5
    [136] = 166,
    -- 58
    [137] = 167,
    -- 58.5
    [138] = 168,
    -- 59
    [139] = 169,
    -- 59.5
    [140] = 170,
    -- 60
    [141] = 171,
    -- 60.5
    [142] = 172,
    -- 61
    [143] = 173,
    -- 61.5
    [144] = 174,
    -- 62
    [145] = 175,
    -- 62.5
    [145] = 176,
    -- 63
    [146] = 177,
    -- 63.5
    [147] = 178,
    -- 64
    [148] = 179,
    -- 64.5
    [149] = 180,
    -- 65
    [150] = 181,
    -- 65.5
    [151] = 182,
    -- 66
    [152] = 183,
    -- 66.5
    [153] = 184,
    -- 67
    [154] = 185,
    -- 67.5
    [154] = 186,
    -- 68
    [155] = 187,
    -- 68.5
    [156] = 188,
    -- 69
    [157] = 189,
    -- 69.5
    [158] = 190,
    -- 70
    [159] = 191,
    -- 70.5
    [160] = 192,
    -- 71
    [161] = 193,
    -- 71.5
    [162] = 194,
    -- 72
    [163] = 195,
    -- 72.5
    [163] = 196,
    -- 73
    [164] = 197,
    -- 73.5
    [165] = 198,
    -- 74
    [166] = 199,
    -- 74.5
    [167] = 200,
    -- 75
    [168] = 201,
    -- 75.5
    [169] = 202,
    -- 76
    [170] = 203,
    -- 76.5
    [171] = 204,
    -- 77
    [172] = 205,
    -- 77.5
    [172] = 206,
    -- 78
    [173] = 207,
    -- 78.5
    [174] = 208,
    -- 79
    [175] = 209,
    -- 79.5
    [176] = 210,
    -- 80
}
local array_c_to_f = { -13, -12, -11, -10, -9, -9, -8, -7, -6, -5, -4, -3, -2, -2, -1, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 55, 56, 57, 58, 59, 60, 61, 62, 62, 63, 64, 65, 66, 67, 68, 69, 70, 71, 72, 73, 73, 74, 75, 76, 77, 78, 79, 80, 81, 82, 82, 83, 84, 85, 86, 87, 88, 89, 90, 91, 91, 92, 93, 94, 95, 96, 97, 98, 99, 100, 100, 101, 102, 103, 104, 105, 106, 107, 108, 109, 109, 110, 111, 112, 113, 114, 115, 116, 117, 118, 118, 119, 120, 121, 122, 123, 124, 125, 126, 127, 127, 128, 129, 130, 131, 132, 133, 134, 135, 136, 136, 137, 138, 139, 140, 141, 142, 143, 144, 145, 145, 146, 147, 148, 149, 150, 151, 152, 153, 154, 154, 155, 156, 157, 158, 159, 160, 161, 162, 163, 163, 164, 165, 166, 167, 168, 169, 170, 171, 172, 172, 173, 174, 175, 176, }

local function convert_f_to_c_encode(f)
    return array_f_to_c[tonumber(f)] + 30
end

local function convert_c_to_f(c)
    return array_c_to_f[c - 30 + 1]
end

local function check_temp_is_c()
    return key_maps[13].value[1] == 1
end

local function decode_temp(t)
    io_debug('\ndecode_temp:' .. tostring(t) .. '\n')
    if check_temp_is_c() then
        return (t - 80) / 2
    else
        return convert_c_to_f(t)
    end
end

local function encode_temp(t)
    io_debug('\nencode_temp:' .. tostring(t) .. '\n')
    if check_temp_is_c() then
        local t_encode = (t * 2) + 80
        io_debug('\nis c\n')
        return t_encode
    else
        io_debug('\nis f\n')
        return convert_f_to_c_encode(t)
    end
end

local function c_10s_to_f_float(c_10s)
    io_debug('aaa' .. c_10s)
    return convert_c_to_f(tonumber(string.format("%d", c_10s / 5) + 80))
end

local function FGUtilStringSplit(str, split_char)
    -------------------------------------------------------
    -- 参数:待分割的字符串,分割字符
    -- 返回:子串表.(含有空串)
    local sub_str_tab = {};
    while (true) do
        local pos = string.find(str, split_char);
        if (not pos) then
            sub_str_tab[#sub_str_tab + 1] = str;
            break ;
        end
        local sub_str                 = string.sub(str, 1, pos - 1);
        sub_str_tab[#sub_str_tab + 1] = sub_str;
        str                           = string.sub(str, pos + 1, #str);
    end

    return sub_str_tab;
end

local function string_split(path, pattern)
    return pairs(FGUtilStringSplit(path, pattern))
end

-- nixj8 add done

-- 接口方法，json转二进制，可传入原状态，此方法不能使用local修饰

local function match_path(path, json_table)
    local value = json_table
    for i, k in string_split(path, "/") do
        io_debug(k .. " ")
        value = value[k]
        if value == nil then
            return 0, value
        end
    end
    return 1, value
end

local function general_bin_section_with_key_map(key_map)
    local value_section = ""
    local get_all_value = 0
    for i, name in pairs(key_map.value_map) do
        if get_all_value == 1 then
            break
        end
        io_debug("    key:[" .. i .. '] ' .. name .. ' : ')
        for k, j in ipairs(key_map.value, ",") do
            io_debug(i .. "<->" .. j)
            if i == j then
                io_debug('* ')
                value_section = value_section .. string.char(i - 1)
                if key_map.size == 1 then
                    get_all_value = 1
                end
            else
                io_debug('  ')
            end
        end
        io_debug('\n')
    end

    if key_map.extra_type == "need_addr"  then       --add by xiewb
        io_debug('idu_addr'.. string.char(idu_addr))
        value_section = value_section .. string.char(idu_addr)
    end

    io_debug('[' .. tostring(#value_section) .. ']' .. string2hexstring(value_section) .. '\n')
    return #value_section, value_section
end

local weekday = { 'Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat',}
local param_type_week = { 'once', 'workday', 'weekend', 'everyday', }  --add xwb 2024-01-15
local function general_bin_section_without_key_map(key_map)
    local value_section     = ""
    local value_section_len = 0
    local value             = key_map.value
    if key_map.value_type == "version" then
        -- do nothing
    elseif key_map.value_type == "uint16_t"
    or key_map.value_type == "uint16_t_100"
    or key_map.value_type == "year"
    or key_map.value_type == "temp_10s"then
        value_section_len = 2
        value_section     = table2string(string2table(string.format("%04x", value[1])))
        io_debug('uint16_t :' .. value_section .. '\n')
    elseif key_map.value_type == "chars" then
        value_section_len = key_map.size
        for i = 1, value_section_len do
            value_section = value_section .. string.char(value[i])
        end
    elseif key_map.value_type == "uint32_t"
    or key_map.value_type == "uint32_t_100" then
        value_section_len = 4
        value_section     = table2string(string2table(string.format("%08x", value[1])))
        io_debug('uint32_t : ' .. value_section .. '\n')
    elseif key_map.value_type == "temp" then
        io_debug('temp ' .. table2string(value))
        value_section     = string.char(value[1])
        value_section_len = 1
    elseif key_map.value_type == "weekday" then
--         io_debug('weekday' .. table2string(value))
--         value_section     = string.char(value[1])
        value_section     = table2string(string2table(string.format("%04x", value[1])))
        value_section_len = 2
    else
        value_section = string.char(tonumber(value[1]))
        io_debug((value_section))
        value_section_len = 1
    end

     if key_map.extra_type == "need_addr"  then       --add by xiewb
        io_debug('idu_addr'.. string.char(idu_addr))
        value_section = value_section .. string.char(idu_addr)
        value_section_len = key_map.size
     end

    io_debug('[' .. tostring(#value_section) .. ']' .. string2hexstring(value_section) .. '\n')
    return value_section_len, value_section
end

local function update_data_with_key_map_by_json(key_map, value)
    local new_value     = {}
    local get_all_value = 0
    for i, name in pairs(key_map.value_map) do
        if get_all_value == 1 then
            break
        end
        io_debug("    key:[" .. i .. '] ' .. name .. ' : ')
        for k, j in string_split(value, ",") do
            io_debug(name .. "<->" .. j)
            if name == j then
                io_debug('* ')
                table.insert(new_value, i)
                if key_map.size == 1 then
                    get_all_value = 1
                end
            else
                io_debug('  ')
            end
        end
        io_debug('\n')
    end
    return new_value
end

local function update_data_without_key_map_by_json(key_map, value)
    local new_value = {}
    if key_map.value_type == "version" then
        io_debug('update version:' .. value)
        --table.insert(new_value, )
    elseif key_map.value_type == "temp_10s" then

    elseif key_map.value_type == "uint8_t" then
        temp = tonumber(value)
        if key_map.max ~= nil  and temp > key_map.max then
            temp = key_map.max
        elseif key_map.min ~= nil and temp < key_map.min then
            temp = key_map.min
        end
        table.insert(new_value, temp)
    elseif key_map.value_type == "uint16_t" then
        table.insert(new_value, tonumber(value))
    elseif key_map.value_type == "uint16_t_100" then
        io_debug('get uint16_t_100\n')
        table.insert(new_value, tonumber(value) * 100)
    elseif key_map.value_type == "chars" then
        io_debug('chars :' .. value .. '\n')
        for i = 1, #value do
            table.insert(new_value, string2Int(value, i))
        end
        for i = #value+1, key_map.size do
            table.insert(new_value, 0)
        end
    elseif key_map.value_type == "uint32_t" then
        table.insert(new_value, tonumber(value))
    elseif key_map.value_type == "uint32_t_100" then
        table.insert(new_value, tonumber(value) * 100)
    elseif key_map.value_type == "temp" then
         if value == "invalid" then
            return new_value
        end
        io_debug('temp ' .. tonumber(encode_temp(value)))
        table.insert(new_value, tonumber(encode_temp(value)))
    elseif key_map.value_type == "weekday" then
        local weekbit = 0
        local week_type = 0
        for i, day in string_split(value, ',') do
            for j, wday in pairs(weekday) do
                if day == wday then
                    io_msg('pair:' .. tostring(j - 1) .. ' -> ' .. day .. '\n')
                    weekbit = bit.bxor(weekbit, bit.lshift(1, j - 1))
                    week_type = 1
                    break
                end
            end
        end
        --add xwb
        if 0 == week_type then
            weekbit = 0
            for j, wday in pairs(param_type_week) do
                if tostring(value) == wday then
                    weekbit = bit.bxor(weekbit, bit.lshift(1, 7 + j - 1))
                    break
                end
            end
        end
        io_debug('param_type_week ' .. tostring(value))
        io_debug('weekbit ' .. tonumber(weekbit))
        table.insert(new_value, tonumber(weekbit))
    elseif key_map.value_type == "int16_t" then
        io_debug('get int16_t\n')
        value = (tonumber(value))
        --if string.sub(value, 1, 1) == '-' then
        if value < 0 then
            io_debug('\n get -\n')
            io_msg(value)
            value = bit.bnot(value)
            table.insert(new_value, bit.bxor(value, 0xFFFF))
        else
            io_debug('\n not get -\n')
            table.insert(new_value, value)
        end
    elseif key_map.value_type == "int8_t" then
        io_debug('get int8_t\n')
        value = (tonumber(value))
        --if string.sub(value, 1, 1) == '-' then
        if value < 0 then
            io_debug('\n get -\n')
            io_msg(value)
            value = bit.bnot(value)
            table.insert(new_value, bit.bxor(value, 0xFF))
        else
            io_debug('\n not get -\n')
            table.insert(new_value, value)
        end
    elseif key_map.value_type == "uint8_t_double" then
        io_debug('get uint8_t_double\n')
        table.insert(new_value, (tonumber(value)) * 2)
    elseif key_map.value_type == "year" then
        year = tonumber(value)
        if(year > 2099) then
            year = 2099
        end
        table.insert(new_value, year)
    elseif key_map.value_type == "month" then
        io_debug('get month\n')
        month = tonumber(value)
        if(month == 0) then
            month = 1
        end
        if(month > 12) then
            month = 12
        end
        table.insert(new_value, month)
    elseif key_map.value_type == "date" then
        io_debug('get date\n')
        date = tonumber(value)
        if(date == 0) then
            date = 1
        end
        if(date > 31) then
            date = 31
        end
        table.insert(new_value, date)
    elseif key_map.value_type == "hour" then
        hour = tonumber(value)
        if(hour > 23) then
            hour = 23
        end
        table.insert(new_value, hour)
    elseif key_map.value_type == "min" then
        min = tonumber(value)
        if(min > 59) then
            min = 59
        end
        table.insert(new_value, min)
    elseif key_map.value_type == "min_10s" then
        min_10s = tonumber(value)
        if(min_10s > 59) then
            min_10s = 59
        end
        min_10s = min_10s - (min_10s % 10)
        table.insert(new_value, min_10s)
    elseif key_map.value_type == "curve_type" then
        curve_type = tonumber(value)
        if(curve_type == 0) then
            curve_type = 1
        end
        if(curve_type > 9) then
            curve_type = 9
        end
        table.insert(new_value, curve_type)
    elseif key_map.value_type == "eco_curve_type" then
        eco_curve_type = tonumber(value)
        if(eco_curve_type == 0) then
            eco_curve_type = 1
        end
        if(eco_curve_type > 8) then
            eco_curve_type = 8
        end
        table.insert(new_value, eco_curve_type)
    elseif key_map.value_type == 'power_10' then
        io_debug('get power_10\n')
        temp = (tonumber(value)) * 10
        temp = temp - (temp % 5)
        if(temp > 200) then
            temp = 200
        end
        table.insert(new_value, temp)
    else
        table.insert(new_value, tonumber(value))
        if key_map.value_type == 'mcs_addr' then
            idu_addr = tonumber(value)
            io_debug('get mcs_addr\n')
        end
    end
    return new_value
end

local function print_table(title, new_value)
    io_debug(title)
    for i, v in pairs(new_value) do
        io_debug(v .. ' ')
    end
    io_debug('\n')
end

function table.equal(a, b)
    if #a ~= #b then
        return false
    end
    for i = 1, #a do
        if a[i] ~= b[i] then
            return false
        end
    end
    return true
end

local function update_data_by_json_single(key_map, json)
    local value         = json
    local get_key_path  = 1

    if(key_map.upload ~= nil) then
        return ''
    end

    get_key_path, value = match_path(key_map.path, value)
    io_debug("\n")
    if 0 == get_key_path then
        return ''
    end

    local new_value = {}
    if key_map.value_map then
        new_value = update_data_with_key_map_by_json(key_map, value)
    else
        new_value = update_data_without_key_map_by_json(key_map, value)
    end

    if #new_value > 0 then
        print_table('    -> new_value:', new_value)
        key_map.value   = new_value
        if key_map.changed ~= nil then
           key_map.changed = 1
        end

        if key_map.idu_addr ~= nil then        --add xwb
             idu_addr = new_value
        end
    end
end

local function update_data_in_normal_type(data, key_map)
    --for i, v in pairs(key_map.value_map) do
    --    io_msg(v)
    --end
    --local ret       = ""
    local new_value = {}
    local first     = 0
    if type(data) == "string" then
        -- from binData
        for d in string.gmatch(data, "%w+") do
            --io_debug('d ' .. d .. ' ')
            --if first == 1 then
            --    ret = ret .. ','
            --end
            local data_index = string2Int(d) + 1
            for k, v in pairs(key_map.value_map) do
                if k == data_index then
                    --ret = ret .. key_map.value_map[data_index]
                    table.insert(new_value, data_index)
                    first = 1
                    break
                end
            end
        end
        --io_debug('\n')
    end
    return new_value
end

local function get_json_in_normal(data, key_map)
    local ret_json = ""
    --local new_value = {}
    local first    = 0
    if type(data) == "table" then
        -- from key_maps
        for i, d in pairs(data) do
            --print(d)
            if first == 1 then
                ret_json = ret_json .. ','
            end
            --io_msg(d)
            ret_json = ret_json .. key_map.value_map[d]
            --table.insert(new_value, d)
            first    = 1
        end
    end
    return ret_json
end

local function update_data_in_spec_type(data, key_map)
    --local ret       = ""
    --io_debug('update data in spec_type')
    local new_value = {}
    if type(data) == "string" then
        -- from binData
        if key_map.value_type == nil
        or key_map.value_type == "uint8_t"
        or key_map.value_type == "uint8_t_10"
        or key_map.value_type == "uint8_t_1/10"  then
            table.insert(new_value, string2Int(data))
        elseif key_map.value_type == "temp" then
            table.insert(new_value, string2Int(data))
        elseif key_map.value_type == "version" then
            --io_debug(' update_version:' .. data)
            for i, v in string_split(data, ',') do
                if string2Int(v) ~= 0xFF then
                    table.insert(new_value, string2Int(v))
                end
            end
            if #new_value < 3 then
                new_value = {}
            end
        elseif key_map.value_type == 'hex' then
            table.insert(new_value, string2Int(data))
        elseif key_map.value_type == 'chars' then
            io_debug('**chars:' .. data)
            for i, v in string_split(data, ',') do
                if string2Int(v) ~= 0xFF then
                    table.insert(new_value, string2Int(v))
                end
            end
        elseif key_map.value_type == 'uint16_t'
            or key_map.value_type == "temp_10s"
            or key_map.value_type == "uint16_t_100"
            or key_map.value_type == "year"
            or key_map.value_type == "uint16_t_1/8" then
            --io_debug('uint16_t or temp_10s[' .. #data .. ']' .. data .. '\n')
            if key_map.size == 2 then
                local new_data   = 0
                local data_table = FGUtilStringSplit(data, ',')
                --io_debug(string.format('uint16_t value: %x %x', data_table[1], data_table[2]))
                new_data         = bit.lshift(data_table[1], 8) + data_table[2]
                table.insert(new_value, new_data)
            end
        elseif key_map.value_type == 'uint32_t'
            or key_map.value_type == 'uint32_t_100' then
            local new_data   = 0
            local data_table = FGUtilStringSplit(data, ',')
            if #data_table == 4 then
                io_debug(string.format('uint32_t value: %x %x %x %x', data_table[1], data_table[2], data_table[3], data_table[4]))
                new_data = bit.lshift(data_table[1], 24) + bit.lshift(data_table[2], 16) + bit.lshift(data_table[3], 8) + data_table[4]
                table.insert(new_value, new_data)
            end
        elseif key_map.value_type == 'weekday' then
            io_debug(data)
            local new_data   = 0
            local data_table = FGUtilStringSplit(data, ',')
            print_lua_table(data_table)
            if #data_table == 2 then
                new_data = bit.lshift(data_table[1], 8) + data_table[2]
                table.insert(new_value, new_data)
            else
                table.insert(new_value, string2Int(data))
            end
        elseif key_map.value_type == "int16_t" then
            table.insert(new_value, string2Int(data))
        elseif key_map.value_type == "int8_t" then
            table.insert(new_value, string2Int(data))
--         elseif key_map.value_type == "year" then
--             io_debug('year' .. string2Int(data))
--             table.insert(new_value, string2Int(data))
        elseif key_map.value_type == "month" then
            table.insert(new_value, string2Int(data))
        elseif key_map.value_type == "date" then
            table.insert(new_value, string2Int(data))
        elseif key_map.value_type == "hour" then
            table.insert(new_value, string2Int(data))
        elseif key_map.value_type == "min" then
            table.insert(new_value, string2Int(data))
        elseif key_map.value_type == "week" then
            table.insert(new_value, string2Int(data))
        elseif key_map.value_type == "min_10s" then
            table.insert(new_value, string2Int(data))
        elseif key_map.value_type == "uint8_t_double" then
            table.insert(new_value, string2Int(data))
        elseif key_map.value_type == "tas" then
            table.insert(new_value, (string2Int(data)) / 2)
        elseif key_map.value_type == "curve_type" then
            table.insert(new_value, string2Int(data))
        elseif key_map.value_type == "eco_curve_type" then
            table.insert(new_value, string2Int(data))
        elseif key_map.value_type == "power_10" then
            table.insert(new_value, string2Int(data))
        end
    end

    return new_value
end

local function get_weekday_by_bits(data)
    local ret = ""
	local cnt = 0
	local cnt_num = 0

	for i = 1, 7 do   --add xwb 2024-02-21
		if 0 ~= bit.band(bit.lshift(1, i - 1), data) then
			cnt = cnt + 1
		end
	end

    for i = 1, 12 do
        if i < 8 then
            if 0 ~= bit.band(bit.lshift(1, i - 1), data) then
                --io_debug("get bit " .. tostring(i))
				cnt_num = cnt_num + 1
				if cnt_num < cnt then
                   ret = ret .. weekday[i] .. ","
				else
				   ret = ret .. weekday[i]
				end
            end
        else      --add xwb 2024-01-15
            if 0 ~= bit.band(bit.lshift(1, i - 1), data) then
                --io_debug("get bit " .. tostring(i))
                ret = ret .. param_type_week[i - 7]
                break
            end
        end
    end
    return ret
end

local function get_json_in_spec_type(data, key_map)
    local ret = ""
    if type(data) == "table" then
        -- from key_maps
        if key_map.value_type == nil or key_map.value_type == 'uint16_t' or key_map.value_type == 'uint32_t' then
            if key_map.value_type == nil and data[1] == 0xFF then
                ret = "invalid"
            elseif key_map.value_type == 'uint16_t' and data[1] == 0xFFFF then
                ret = "invalid"
            elseif key_map.value_type == 'uint32_t' and data[1] == 0xFFFFFFFF then
            else
                ret = tostring((data[1]))
            end
        elseif key_map.value_type == 'temp_10s' then
            if data[1] == 0xFFFF then
                ret = "invalid"
            else
                --if check_temp_is_c() then
                if bit.rshift(data[1], 15) == 1 then
                    ret = string.format('-%.1f', (bit.band(data[1], 0x7FFF) / 10))
                else
                    ret = string.format('%.1f', (data[1] / 10))
                end
                --else
                --    ret = string.format('%.1f', (c_10s_to_f_float(data[1])))
                --end
            end
        elseif key_map.value_type == 'chars' then
            --io_debug('****chars:' .. #data)
            --ret = string.format("%c.%d.%02d", data[1], data[2], data[3])
            for d, v in ipairs(data) do
                ret = ret .. string.format('%c', v)
            end
        elseif key_map.value_type == "hex" then
            ret = string.format("0x%X", data[1])
        elseif key_map.value_type == "version" then
            --io_debug('    version:' .. data)
            ret = string.format("%d.%d.%02d", data[1], data[2], data[3])
        elseif key_map.value_type == "temp" then
                  if data[1] == 0xFF then
                      ret = "invalid"
                  else
                      ret = tostring(decode_temp(data[1]))
                  end
        elseif key_map.value_type == "weekday" then
            ret = get_weekday_by_bits(data[1])
        elseif key_map.value_type == 'uint8_t' then
            ret = tostring(data[1])
        elseif key_map.value_type == 'int8_t' then
            if bit.rshift(data[1], 7) == 1 then
                ret = string.format('-%d', bit.band(bit.bnot(bit.band(data[1], 0x7F)), 0x7F) + 1)
            else
                ret = string.format('%d', data[1])
            end
        elseif key_map.value_type == 'int16_t' then
            if bit.rshift(data[1], 15) == 1 then
                ret = string.format('-%d', bit.band(bit.bnot(bit.band(data[1], 0x7FFF)), 0x7FFF) + 1)
            else
                ret = string.format('%d', data[1])
            end
        elseif key_map.value_type == 'year' then
            ret = tostring(data[1])
            io_debug('year' .. ':' .. ret .. ', ')
        elseif key_map.value_type == 'month' then
            ret = tostring(data[1])
        elseif key_map.value_type == 'date' then
            ret = tostring(data[1])
        elseif key_map.value_type == 'hour' then
            ret = tostring(data[1])
        elseif key_map.value_type == 'min' then
            ret = tostring(data[1])
        elseif key_map.value_type == 'week' then
            ret = tostring(data[1])
        elseif key_map.value_type == 'uint8_t_double' then
            ret = tostring(data[1]/2)
        elseif key_map.value_type == 'uint16_t_100' then
            ret = tostring(data[1]/100)
        elseif key_map.value_type == 'uint32_t_100' then
            ret = tostring(data[1]/100)
        elseif key_map.value_type == 'uint16_t_1/8' then
            ret = tostring(data[1]*8)
        elseif key_map.value_type == 'uint8_t_1/10' then
            ret = tostring(data[1]*10)
        elseif key_map.value_type == 'uint8_t_10' then
            ret = tostring(data[1]/10)
        elseif key_map.value_type == 'power_10' then
            ret = tostring(data[1]/10)
        else
            ret = tostring((data[1]))
        end
    end

    return ret
end

local function update_data_by_bin(key_map, data)
    local new_value = {}
    if key_map.upload ~= nil then
        key_map = key_maps[key_map.upload+1]
    end
    if key_map.value_map ~= nil then
        new_value = update_data_in_normal_type(data, key_map)
    else
        new_value = update_data_in_spec_type(data, key_map)
    end
    if #new_value > 0 then
        key_map.value = new_value
        key_map.changed = 1
    end
end

local function get_json_by_keymap(key_map, data)
    --io_msg('key_map path:' .. key_map.path)
    local ret_json  = ""
    --local key_map = key_maps[idx + 1]
    local new_value = {}
    if key_map.value_map ~= nil then
        ret_json = get_json_in_normal(data, key_map)
    else
        ret_json = get_json_in_spec_type(data, key_map)
    end
    --io_debug('    ret_json:' .. ret_json .. '\n')
    return ret_json
end

local function parse_section(section)
    io_msg('    ' .. string2hexstring(table2string(section)) .. ": ")
    io_debug('\n')
    --for j, val2 in pairs(section) do
    --    io_debug(j .. ':' .. val2 .. ', ')
    --end

    local idx  = bit.lshift(section[1], 8) + section[2]
    local size = section[3]
    local data = table.concat(section, ',', 4)
    io_debug('idx:' .. idx .. ',')
    io_debug('size:' .. size .. ',')
    io_debug('data:' .. data .. '  ')
    if size == "0" or size == 0 then
        return nil
    end

    local key_map = nil

    for i, km in pairs(key_maps) do
        if tonumber(idx) == km.idx then
            io_debug('match : ' .. km.path .. '  ')
            --io_msg('match :' .. km.path .. '\n')
            key_map = km
            break
        end
    end

    if key_map == nil then
        io_msg('can\'t match key_map idx, return')
        return nil
    end

    update_data_by_bin(key_map, data)
end

local function parse_data_bin_branch(idx_start, idx_end, len, binTable, idx)
    io_debug(string.format('  branch: %d -> %d [%d]\n', idx_start, idx_end, len))
    local pos = idx
    --io_msg(pos)
    for i = idx_start, idx_end do
        local key_map = key_maps[i + 1]
        io_debug(string.format('    %d [%d] ', i, key_map.size))
        update_data_by_bin(key_map, table.concat(binTable, ',', pos, pos + key_map.size - 1))
        for j = 1, key_map.size do
            io_debug(string.format(' %02x', tonumber(binTable[pos])))
            pos = pos + 1
        end
        key_map.changed = 1
        io_debug(string.format('\n'))
    end
end

local function parse_data_bin(binData)
    io_msg('\n')
    local conf_list = {}
    local section   = {}
    io_debug(string.format('get bin:%d\n', #binData))
    io_msg(binData .. '\n')
    local binTable = string2table(binData)

    for i, value in pairs(binTable) do
        if binTable[i + 1] == 0xFE and #section == 0 then
            --io_msg(i)
            local idx_start = bit.lshift(binTable[i + 2], 8) + binTable[i + 3]
            local idx_end   = bit.lshift(binTable[i + 4], 8) + binTable[i + 5]
            local len       = bit.lshift(binTable[i + 6], 8) + binTable[i + 7]
            parse_data_bin_branch(idx_start, idx_end, len, binTable, i + 8)
            break
        elseif binTable[i] == 0xFF and binTable[i+1] == 0xFF and binTable[i+5] == 0xFF then
            break
        elseif value == 0xFF and #section > 0 and section[3] + 3 == #section then
            --print_lua_table(section)
            table.insert(conf_list, section)
            section = {}
        else
            table.insert(section, value)
        end
    end
    io_debug('\n')

    io_msg('all sections[' .. #conf_list .. "]\n")

    --local json_data = {}
    for i, value in pairs(conf_list) do
        --parse_section(value, json_data)
        parse_section(value)
    end

    --return json_data
end

local function parse_data_bin_respond(binData)

    local binTable = string2table(binData)
    local table_size = #binTable
    if table_size < 5 then
        return
    end

    local begin  = 1
    for i = 1, table_size, 1 do
        if table_size - i < 5 then
            break
        end
        if i == begin then
            local idx_start = bit.lshift(binTable[begin], 8) + binTable[begin + 1]
            local idx_end   = idx_start
            parse_data_bin_branch(idx_start, idx_end, 1, binTable, begin+3)
            begin = begin + binTable[begin+2] + 4
        end
    end
end

local function key_map_convert_to_json(json_data, key_map)
    local idx         = key_map.idx
    local size        = key_map.size
    local data        = key_map.value

--     io_debug('  ' .. 'idx(' .. type(idx) .. '):' .. idx .. ',')
--     io_debug('size(' .. type(size) .. '):' .. size .. ',')
--     if type(data) == "string" then
--        io_debug('data(' .. type(data) .. '):' .. data .. ',')
--     else
--        if type(data) == "table" then
--            io_debug('data(' .. type(data) .. '):' .. int2String(#data) .. ',')
--        else
--            io_debug('data(' .. type(data) .. '):' .. ',')
--        end
--     end

    --local key_map = key_maps[idx + 1]
    local json_data_p = json_data
    local last_value  = ""
    for i, value in string_split(key_map.path, "/") do
        --io_debug(' ' .. value .. " ")
        if last_value == "" then
            last_value = value
        else
            if json_data_p[last_value] ~= nil then
                json_data_p = json_data_p[last_value]
            else
                json_data_p[last_value] = {}
                json_data_p             = json_data_p[last_value]
            end
            last_value = value
        end
    end
    --io_debug("\n")
    json_data_p[last_value] = get_json_by_keymap(key_map, data)

    return json_data
end

local function get_all_json_table(key_maps)
    --io_msg('\n')
    local json_data  = {}
    local json_data2 = {}
    for idx, key_map in pairs(key_maps) do
        --io_debug('    ' .. idx)
        if key_map.changed == 1 then
            io_debug('    ' .. idx)
            key_map_convert_to_json(json_data, key_map)
            json_data2[key_map.path] = key_map.from
            key_map.changed = 0
        end
    end

    return json_data, json_data2
end

local function general_bin_section_single(key_map)
    local binData           = ""
    local value_section     = ""
    local value_section_len = 0
    binData                 = binData .. string.char(bit.rshift(key_map.idx, 8)) .. string.char(bit.band(key_map.idx, 0x00FF))
    io_debug("\n")
    local new_value = {}
    if key_map.value_map then
        value_section_len, value_section = general_bin_section_with_key_map(key_map)
    else
        value_section_len, value_section = general_bin_section_without_key_map(key_map)
    end

    binData = binData .. string.char(value_section_len) .. value_section .. string.char(0xFF)

    return binData
end

local function general_all_bin()
    --print_lua_table(json)
    local binData = ""
    for idx in pairs(key_maps) do
        io_debug(idx .. ": [")
        binData = binData .. general_bin_section_single(key_maps[idx])
    end

    return binData
end

local function general_all_changed_bin()
    --print_lua_table(json)
    local binData = ""
    for idx in pairs(key_maps) do
        io_debug(idx .. ": [")
        if key_maps[idx].changed == 1 then
            key_maps[idx].changed = 0
            binData               = binData .. general_bin_section_single(key_maps[idx])
        end
    end

    return binData
end

local function update_data_by_json(json)
    --print_lua_table(json)
    io_msg('\n')

    local binData = ""
    for idx in pairs(key_maps) do
        --if key_maps[idx].writable == true then
        --io_debug(idx .. ": [")
        --local value = json[key_maps[idx].path][key_maps[idx].key]
        local json_temp = json
        update_data_by_json_single(key_maps[idx], json_temp)
        --binData         = binData .. update_data_by_json_single(key_maps[idx], json_temp)
        --end
    end

    return binData
end

local function get_query_cmd(json)
    io_debug('get query\n')
    local query_cmd   = 0xFF
    local query_index1 = 0xFF
    local query_index2 = 0xFF
    local query_index3 = 0xFF
    local query_type  = json["query_type"]

    if query_type ~= nil then
        local query = string2table(string.format("%02x", tonumber(query_type)))
        local len = #query
        if (len >= 1) then
            query_index1 = query[1]
            query_index2 = query[1]
            query_index3 = query[1]
        end
        if (len >= 2) then
            query_index2 = query[2]
        end
        if (len >= 3) then
            query_index3 = query[3]
        end
    end
    local binData = string.char(query_cmd) .. string.char(query_cmd) .. string.char(query_index1) .. string.char(query_index2) .. string.char(query_index3) .. string.char(query_cmd)

--     add xwb
    local data_table = string2tableFromZero(string2hexstring(binData))
    local msgBytes = assembleUart(data_table, BYTE_QUERY_REQUEST)
    --lua table ������ 1 ��ʼ����˴˴�Ҫ����ת��һ��
    local infoM = {}
    local length = #msgBytes + 1
    for i = 1, length do
       infoM[i] = msgBytes[i - 1]
    end
    binData = table2string(infoM)

    return string2hexstring(binData)
end

function jsonToData(jsonCmdStr)
    io_msg('\n')
    if (#jsonCmdStr == 0) then
        io_err("no json")
        return nil
    end

    -- for wlc
    --     get     ------      return
    --     query                status
    --     params               status

    local json  = decodeJsonToTable(jsonCmdStr)

    --print_lua_table(json)

    local filed = 'result'
    if json["query"] ~= nil then
        return get_query_cmd(json["query"])
    elseif json['control'] ~= nil then
        filed = 'control'
    elseif json['params'] ~= nil then
        filed = 'params'
    elseif json['result'] ~= nil then
        filed = 'result'
    elseif json['status'] ~= nil then
        filed = 'status'
    end

    io_msg(filed .. '\n')

    -- 若当前为控制，且带有温度单位控制，先处理温度单位的切换;然后再处理后续字段的处理
    if(filed == 'control') then
        if(json[filed]['temp_unit'] )  ~= nil then
            update_data_by_json({ temp_unit = json[filed]['temp_unit']})
            json[filed]['temp_unit'] = nil  -- 删除指定属性
        end
    end
    
    update_data_by_json(json[filed])
    
    local binData = general_all_changed_bin()

--     add xwb 20240531print_lua_table
    local data_table = string2tableFromZero(string2hexstring(binData))
    local msgBytes = assembleUart(data_table, BYTE_CONTROL_REQUEST)

    --lua table ������ 1 ��ʼ����˴˴�Ҫ����ת��һ��
    local infoM = {}
    local length = #msgBytes + 1
    for i = 1, length do
       infoM[i] = msgBytes[i - 1]
    end
    binData = table2string(infoM)

    --io_msg(':get bin ' .. string2hexstring(binData) .. '\n')
    return string2hexstring(binData)
end

local function show_key_maps_value(key_maps)
    io_msg('\n  show_key_maps_value \n')
    --io_msg('\n')
    for idx, key_map in pairs(key_maps) do
        --io_debug('    ' .. tostring(idx) .. ' [' .. key_map.size .. ']: ')
        io_msg(string.format("  %2d [%d]:", tostring(key_map.idx), key_map.size))
        io_debug(key_map.path .. '   { ')
        for i, v in pairs(key_map.value) do
            io_debug(v .. ' ')
        end
        io_debug('} : ')
        io_debug(get_json_by_keymap(key_map, key_map.value))
        --for idx, v in pairs(key_map.value) do
        --    io_debug(tostring(v))
        --    io_debug(get_json_by_keymap(key_map, v))
        --    if key_map.value_map ~= nil then
        --        io_debug(' [' .. (key_map.value_map[v] .. ']' .. ', '))
        --    elseif key_map.value_type == 'temp' then
        --        io_debug(' -> ' .. tostring(decode_temp(v)) .. ', ')
        --    end
        --end
        io_debug('\n')
    end
end

local function get_table_len(data)
    -- body
    local cnt = 0
    for i in pairs(data) do
        cnt = i
    end
    return cnt
end

local function check_lua_header(binData)
    local data = string2table(binData)
    local len  = get_table_len(data)
    if len < 10 then
        io_err('format error\n')
        return 0
    end
    io_msg(string.format('check_lua_header: %X %X %X %X\n', data[1], data[2], data[3], data[10]))
    io_msg(string.format('sum: %X\n', data[len]))
    io_msg(string.format('sum: %X\n', makeSum(data, 2, len - 1)))
    if data[1] ~= BYTE_PROTOCOL_HEAD
            or data[3] ~= 0xCC
            --or data[10] ~= BYTE_CONTROL_REQUEST
            or data[len] ~= makeSum(data, 2, len - 1) then
        io_err('format error\n')
        return 0
    end
    return 1
end

local function check_hmiversion(hmiversion, dest)
    local hmiversion_major, hmiversion_minor, hmiversion_patch = string.match(hmiversion, "(%d+).(%d+).(%d+)")
    local dest_major,       dest_minor,       dest_patch       = string.match(dest, "(%d+).(%d+).(%d+)")
    if hmiversion_major >= dest_major and
       hmiversion_minor >= dest_minor and
       hmiversion_patch >= dest_patch then
        return true
    end
    return false
end

local function patch_hmiversion(json_data, cmd_type)

    local hmiVersionNum = json_data['status']['hmiVersionNum']
    local _hmiVersionNum_patch = json_data['status']['_hmiVersionNum_patch']

    print(json_data['status']['hmiVersionNum'])
    print(json_data['status']['_hmiVersionNum_patch'])

    if  _hmiVersionNum_patch ~= nil then
        if hmiVersionNum ~= nil then
            local v1, v2, v3 = string.match(hmiVersionNum, "(%d+).(%d+).(%d+)")
            json_data['status']['hmiVersionNum'] = string.format("%d.%d.%d.%02d", v1, _hmiVersionNum_patch, v2, v3)
        end
    end
end


-- 接口方法，二进制转json，此方法不能使用local修饰
function dataToJson(jsonStr)
    io_msg('\n')
    if (not jsonStr) then
        io_err('no json str')
        return ''
    end

    local json    = decodeJsonToTable(jsonStr)

    --根据设备子类型来处理协议差异
    --local deviceinfo = json["deviceinfo"]
    --local deviceSubType = deviceinfo["deviceSubType"]
    --if (deviceSubType == 1) then
    --end

    --解析十六进制数据
    local binData = json["msg"]["data"]

    local cmd_type = { 0xFF, 0xFF }

    if check_lua_header(binData) == 1 then
        local data = string2table(binData)
        cmd_type[1] = data[10]
        cmd_type[2] = data[11]
        binData = string.sub(binData, 21)
    end

    -- 处理控制应答
    if cmd_type[1] == 0x02 then
        parse_data_bin_respond(binData)
    else
        parse_data_bin(binData)
    end

    --show_key_maps_value(key_maps)

    local json_data     = {}
    json_data['status'], json_data['from'] = get_all_json_table(key_maps)
    json_data['status']['version'] = string.format("%d.%d.%d", lua_version[1], lua_version[2], lua_version[3])

    if  json_data['status']['error_code_str'] ~= nil
    and json_data['status']['error_code_str'] ~= '/'   then
        json_data['status']['error_code'] = json_data['status']['error_code_str']
    end

    patch_hmiversion(json_data, cmd_type)

    if cmd_type[1] ~= 0xFF then
        json_data['cmd_type'] = string.format("%d", cmd_type[1])
        json_data['sub_type'] = string.format("0x%X", cmd_type[2])
    end

    -- 处理控制应答
    if cmd_type[1] == 0x04 then
        json_data['msg_up_type'] = string.format("%X", cmd_type[2])
    end

    return encodeTableToJson(json_data)
end


--[[
last is all test code
--]]
if test >= 1 then

    local function socket_get_ctrl(server)
        local control
        io_msg("waiting client connections...")
        io.flush()
        control = assert(server:accept())
        return control
    end

    local function format_bin_to_json(bin_data)
        local binData_json         = {}
        binData_json["deviceinfo"] = { ["deviceSubType"] = "22" }
        binData_json["msg"]        = { ["data"] = bin_data }
        return binData_json
    end

    local function key_map_to_bin()
        local json_data = get_all_json_table(key_maps)
        local bin       = update_data_by_json(json_data)
        bin             = bin
        io_msg(string2hexstring(bin))
        return bin
    end

    local function web_data_handle(data)
        local binData_json = {}
        io_debug('data:' .. data .. '\n')
        binData_json["deviceinfo"] = { ["deviceSubType"] = "22" }
        --binData_json["msg"] = { ["data"] = string2hexstring(data) }
        binData_json["msg"]        = { ["data"] = (data) }
        local json_bin             = dataToJson(encodeTableToJson(binData_json))
        local file_write           = io.open("profile_w.json", 'w')
        file_write:write(json_bin)
        file_write:close()
        show_key_maps_value(key_maps)
    end

    local function recv_and_handle_socket(data_handle)
        local control = nil
        local server  = nil
        local socket  = require("socket")
        server        = assert(socket.bind("127.0.0.1", "6667"))
        io_msg("server ready...")

        while (1) do
            if control == nil then
                control = socket_get_ctrl(server)
            end

            io_msg("waiting data receive..." .. os.date())
            io.flush()
            local data, status = control:receive("*l");
            if status == "closed" then
                control = nil
            else
                if data ~= nil then
                    data_handle(data)
                end
            end
        end
    end

    local function recv_and_handle_lzmq(data_handle)
        local zmq            = require "lzmq"
        local zassert        = zmq.assert
        local context        = zmq.context()   -- ����һ��ZMQ ������
        local publisher, err = context:socket { zmq.REP, bind = "tcp://127.0.0.1:6666" }  -- �����׽���  ����˽��׽��ְ��ڶ˿�5025
        zassert(publisher, err)   -- ��ʼ�ȴ���Ӧ ����Ӧ�� ���ѭ��
        --  �ͻ����Ƿ������� ���ȴ�����˵�Ӧ��
        local y = 0
        io_msg('zmq init done...')
        io.flush()
        while y >= 0 do
            local x   = "This is a zmq test!"
            y         = y + 1
            local ret = zassert(publisher:recv())
            io_msg(y .. "rep recv" .. ret)
            io.flush()
            --zassert(publisher:send(x))
            io_msg(y .. ":" .. x)
        end
    end

    local function test_func()
        recv_and_handle_socket(web_data_handle)
        --recv_and_handle_lzmq(web_data_handle)
    end

    local function check_bin_to_json(binData)
        io_msg('\n')
        local binData_json         = {}
        binData_json["deviceinfo"] = { ["deviceSubType"] = "22" }
        binData_json["msg"]        = { ["data"] = binData }

        local new_json             = dataToJson(JSON.encode(binData_json))
        local file_write           = io.open("profile_w.json", 'w')
        file_write:write(new_json)
        file_write:close()
    end

    local function add_iot_header(binData)
        binData = 'AAF50D00000000000000' .. binData
        --if data[1] ~= BYTE_PROTOCOL_HEAD
        --        or (data[2] ~= len - 1 and data[2] ~= 245)
        --        or data[3] ~= 13
        return binData
    end
    local function check_json_to_bin(json_read)
        io_msg('\n')
        --local binData = "000101FF01050502060103FF020102FF030170FF04018CFF050176FF080100FF090141FF0A0100FF0B0102FF0C0106FF0D0106FF0E0106FF0F0100FF100102FF110100FF120101FF130108FF140101FF150100FF160100FF17050001020304FF180100FF190101FF1A0100FF1B0101FF1C0100FF1D0100FF1E020000FF1F0100FF20020000FF210101FF220100FF230100FF240100FF2A03000045FF2B0101FF2C0100FF2D0101FF2E0100FF2F0100FF300101FF310101FF320101FF330107FF340101FF350101FF360100FF370400010203FF3C0103FF"
        local binData = jsonToData(json_read)
        io_msg('\n[' .. #binData .. '] ' .. binData)
--         binData = add_iot_header(binData)
        check_bin_to_json(binData)
    end

    io_msg("test begin\n")
    --test_func()

--      local binData ='aa28cc0000000000000404fe0057005a000600020c010000ff04fe0057005a000600020c010000ff7a'
--     --local binData = 'aa85cc0000000000000301fe00000056007201728c8c00f882728c728c8c8c00010041ff050206010301010707000101010100010003000000000000000000000000000000000001000000010200000101886100010000ff00ff01010100010203000500ffff00ffff00000000000000014a3433ffffff00ffffffffffff010000000000ffc1'
--
--     --io_msg('[' .. #binData .. '] ' .. binData)
--     --show_key_maps_value(key_maps)
--     check_bin_to_json(binData)
--     show_key_maps_value(key_maps)

    --key_map_to_bin()

--     --show_key_maps_value(key_maps)
    file_json       = io.open("lua_test.json")
--     --file_json = io.open("lua_test.json")
    local json_read = file_json:read("*a")
--     --file_json:close()
--     --local json_read = "{\"deviceinfo\":{\"deviceType\":\"CC\",\"deviceSubType\":\"8\",\"deviceSN\":\"0000CC311150062WT26010000021VV24\"},\"msg\":{\"data\":\"000100FF01050502060103FF020102FF030172FF04018CFF05018AFF080100FF090141FF0A0101FF0B0101FF0C0101FF0D0101FF0E0104FF0F0101FF100101FF110100FF120106FF130108FF140100FF150100FF160101FF17020003FF180100FF190101FF1A0101FF1B0101FF1C0100FF1D0100FF1E020000FF1F0100FF20020000FF210101FF220100FF230100FF240100FF250100FF260130FF2A0300006CFF2B0101FF2C0100FF2D0101FF2E0100FF2F0100FF300101FF310101FF320100FF330107FF340101FF350100FF360100FF370400010203FF380102FF390100FF3A04000006DEFF3B020000FF3C0100FF3D020000FF3E0100FF420200F9FF43020000FF\"}}"
    check_json_to_bin(json_read)

end
