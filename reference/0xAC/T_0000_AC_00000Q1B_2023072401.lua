----海外空调协议解析,从国内61版本拷贝
----author: Li Tong
----date  : 2023/01/08

--CA机型，04,05上报的温度 要按小数位在BIT1解释
--正常机型, 04,05上报的温度 要按小数位在BIT6解释

local JSON = require "cjson"

-----------------JSON相关key值变量-----------------
local keyT = {}

--版本号
keyT["KEY_VERSION"] = "version"
--电源
keyT["KEY_POWER"] = "power"
--净化
keyT["KEY_PURIFIER"] = "purifier"
--模式
keyT["KEY_MODE"] = "mode"
--智能抽湿值
keyT["KEY_SMART_DRY"] = "smart_dry_value"
--温度
keyT["KEY_TEMPERATURE"] = "temperature"
--风速
keyT["KEY_FANSPEED"] = "wind_speed"
--左右扫风
keyT["KEY_SWING_LR"] = "wind_swing_lr"
--上下扫风
keyT["KEY_SWING_UD"] = "wind_swing_ud"
--下左右扫风
keyT["KEY_SWING_LR_UNDER"] = "wind_swing_lr_under"
--定时开
keyT["KEY_TIME_ON"] = "power_on_timer"
--定时关
keyT["KEY_TIME_OFF"] = "power_off_timer"
--定时关时间
keyT["KEY_CLOSE_TIME"] = "power_off_time_value"
--定时开时间
keyT["KEY_OPEN_TIME"] = "power_on_time_value"
--ECO
keyT["KEY_ECO"] = "eco"
--干燥
keyT["KEY_DRY"] = "dry"
--电辅热
keyT["KEY_PTC"] = "ptc"
--本次开机运行时间
keyT["KEY_CURRENT_WORK_TIME"] = "current_work_time"
--错误码
keyT["KEY_ERROR_CODE"] = "error_code"
--按键（蜂鸣）
keyT["KEY_BUZZER"] = "buzzer"
--防过冷(快速降温，缓慢回温)
keyT["KEY_PREVENT_SUPER_COOL"] = "prevent_super_cool"
--防着凉
keyT["KEY_PREVENT_COLD"] = "prevent_cold"
--防直吹
keyT["KEY_PREVENT_STRAIGHT_WIND"] = "prevent_straight_wind"
--自动防直吹
keyT["KEY_AUTO_PREVENT_STRAIGHT_WIND"] = "auto_prevent_straight_wind"
--自清洁
keyT["KEY_SELF_CLEAN"] = "self_clean"
--风吹人
keyT["KEY_WIND_STRAIGHT"] = "wind_straight"
--风避人
keyT["KEY_WIND_AVOID"] = "wind_avoid"
--智慧风
keyT["KEY_INTELLIGENT_WIND"] = "intelligent_wind"
--无风感
keyT["KEY_NO_WIND_SENSE"] = "no_wind_sense"
--远近无风感
keyT["KEY_FA_NO_WIND_SENSE"] = "fa_no_wind_sense"
--儿童放冷风
keyT["KEY_CHILD_PREVENT_COLD_WIND"] = "child_prevent_cold_wind"
--强劲
keyT["KEY_STRONG_WIND"] = "strong_wind"
--Tubro
keyT["KEY_TUBRO"] = "tubro"
--舒省
keyT["KEY_COMFORT_POWER_SAVE"] = "comfort_power_save"
--屏显
keyT["KEY_SCREEN_DISPLAY"] = "screen_display"
--当前屏显状态
keyT["KEY_SCREEN_DISPLAY_NOW"] = "screen_display_now"
--小天使
keyT["KEY_LITTLE_ANGLE"] = "little_angel"
--冷热感
keyT["KEY_COOL_HOT_SENSE"] = "cool_hot_sense"
--柔风感
keyT["KEY_GENTLE_WIND_SENSE"] = "gentle_wind_sense"
--安防
keyT["KEY_SECURITY"] = "security"
--均匀风
keyT["KEY_EVEN_WIND"] = "even_wind"
--单风口
keyT["KEY_SINGLE_TUYERE"] = "single_tuyere"
--超远风
keyT["KEY_EXTREME_WIND"] = "extreme_wind"
--语音控制
keyT["KEY_VOICE_CONTROL"] = "voice_control"
--舒睡
keyT["KEY_COMFORT_SLEEP"] = "comfort_sleep"
--舒睡曲线
keyT["KEY_COMFORT_SLEEP_CURVE"] = "comfort_sleep_curve"
--预冷预热
keyT["KEY_PRE_COOL_HOT"] = "pre_cool_hot"
--自然风
keyT["KEY_NATURAL_WIND"] = "natural_wind"
--pmv
keyT["KEY_PMV"] = "pmv"
--水洗
keyT["KEY_WATER_WASHING"] = "water_washing"
--新风
keyT["KEY_FRESH_AIR"] = "fresh_air"
--yb系列风避人
keyT["KEY_YB_WIND_AVOID"] = "yb_wind_avoid"
--fa系列防直吹
keyT["KEY_FA_PREVENT_STRAIGHT_WIND"] = "fa_prevent_straight_wind"
--家长控制
keyT["KEY_PARENT_CONTROL"] = "parent_control"
--无人节能
keyT["KEY_NOBODY_ENERGY_SAVE"] = "nobody_energy_save"
--上下摆风角度
keyT["KEY_WIND_SWING_UD_ANGLE"] = "wind_swing_ud_angle"
--左右摆风角度
keyT["KEY_WIND_SWING_LR_ANGLE"] = "wind_swing_lr_angle"
--滤网脏堵检测值
keyT["KEY_FILTER_VALUE"] = "filter_value"
--滤网脏堵等级
keyT["KEY_FILTER_LEVEL"] = "filter_level"
--左右防直吹
keyT["KEY_PREVENT_STRAIGHT_WIND_LR"] = "prevent_straight_wind_lr"
--pm25值
keyT["KEY_PM25_VALUE"] = "pm25_value"
--水泵开关
keyT["KEY_WATER_PUMP"] = "water_pump"
--智能控制总开关
keyT["KEY_INTENLLIGENT_CONTROL"] = "intelligent_control"
--音量控制
keyT["KEY_VOLUME_CONTROL"] = "volume_control"
--语音控制开关（新）
keyT["KEY_VOICE_CONTROL_NEW"] = "voice_control_new"
--人脸注册人数
keyT["KEY_FACE_REGISTER"] = "face_register"
--温度上下限
keyT["KEY_COOL_TEMP_UP"] = "cool_temp_up"
keyT["KEY_COOL_TEMP_DOWN"] = "cool_temp_down"
keyT["KEY_AUTO_TEMP_UP"] = "auto_temp_up"
keyT["KEY_AUTO_TEMP_DOWN"] = "auto_temp_down"
keyT["KEY_HEAT_TEMP_UP"] = "heat_temp_up"
keyT["KEY_HEAT_TEMP_DOWN"] = "heat_temp_down"
--省电
keyT["KEY_POWER_SAVING"] = "power_saving"
--遥控器锁定
keyT["KEY_REMOTE_CONTROL_LOCK"] = "remote_control_lock"
--空调允许运行时间
keyT["KEY_OPERATING_TIME"] = "operating_time"
--新风滤网总时长
keyT["KEY_FRESH_FILTER_TIME_TOTAL"] = "fresh_filter_time_total"
--新风滤网已使用时长
keyT["KEY_FRESH_FILTER_TIME_USE"] = "fresh_filter_time_use"
--新风滤网使用超时标志
keyT["KEY_FRESH_FILTER_TIMEOUT"] = "fresh_filter_timeout"
--新风滤网使用超时标志(AE2)
keyT["KEY_FRESH_FILTER_TIMEOUT_AE2"] = "fresh_filter_timeout_ae2"
--新风滤网运行时间清零
keyT["KEY_FRESH_FILTER_RESET"] = "fresh_filter_reset"
--普通滤网运行时间清零
keyT["KEY_COMMON_FILTER_RESET"] = "common_filter_reset"
--室内湿度
keyT["KEY_INDOOR_HUMIDITY"] = "indoor_humidity"
--8度制热
keyT["KEY_DEGREE8_HEAT"] = "degree8_heat"

----------------JSON相关value值变量----------------
local keyV = {}
--版本号
keyV["VALUE_VERSION"] = 41
--功能开
keyV["VALUE_FUNCTION_ON"] = "on"
--功能关
keyV["VALUE_FUNCTION_OFF"] = "off"
--制热
keyV["VALUE_MODE_HEAT"] = "heat"
--制冷
keyV["VALUE_MODE_COOL"] = "cool"
--自动
keyV["VALUE_MODE_AUTO"] = "auto"
--干燥
keyV["VALUE_MODE_DRY"] = "dry"
--送风
keyV["VALUE_MODE_FAN"] = "fan"
--智能除湿
keyV["VALUE_MODE_SMART_DRY"] = "smart_dry"
--室内温度
keyV["VALUE_INDOOR_TEMPERATURE"] = "indoor_temperature"
--室外温度
keyV["VALUE_OUTDOOR_TEMPERATURE"] = "outdoor_temperature"
--运行状态
keyV["VALUE_RUN_STATE"] = "runstate"
--运行
keyV["VALUE_RUNNING"] = "running"
--停止
keyV["VALUE_STOP"] = "stopped"

local deviceSubType=0
local deviceSN8="00000000"
-----------------二进制相关属性变量----------------
local keyB = {}
--设备
keyB["BYTE_DEVICE_TYPE"] = 0xAC
--控制请求
keyB["BYTE_CONTROL_REQUEST"] = 0x02
--查询请求
keyB["BYTE_QUERYL_REQUEST"] = 0x03
--协议头
keyB["BYTE_PROTOCOL_HEAD"] = 0xAA
--协议头长度
keyB["BYTE_PROTOCOL_LENGTH"] = 0x0A
--电源开
keyB["BYTE_POWER_ON"] = 0x01
--电源关
keyB["BYTE_POWER_OFF"] = 0x00

--自动模式
keyB["BYTE_MODE_AUTO"] = 0x20
--制冷模式
keyB["BYTE_MODE_COOL"] = 0x40
--抽湿模式
keyB["BYTE_MODE_DRY"] = 0x60
--制热模式
keyB["BYTE_MODE_HEAT"] = 0x80
--送风模式
keyB["BYTE_MODE_FAN"] = 0xA0
--智能抽湿模式
keyB["BYTE_MODE_SMART_DRY"] = 0xC0

--自动风
keyB["BYTE_FANSPEED_AUTO"] = 0x66
--高风
keyB["BYTE_FANSPEED_HIGH"] = 0x50
--中风
keyB["BYTE_FANSPEED_MID"] = 0x3C
--低风
keyB["BYTE_FANSPEED_LOW"] = 0x28
--微风
keyB["BYTE_FANSPEED_MUTE"] = 0x14
--净化开
keyB["BYTE_PURIFIER_ON"] = 0x20
--净化关
keyB["BYTE_PURIFIER_OFF"] = 0x00
--经济（ECO）开
keyB["BYTE_ECO_ON"] = 0x80
--经济（ECO）关
keyB["BYTE_ECO_OFF"] = 0x00
--左右扫风开
keyB["BYTE_SWING_LR_ON"] = 0x03
--左右扫风关
keyB["BYTE_SWING_LR_OFF"] = 0x00
--下左右扫风开
keyB["BYTE_SWING_LR_UNDER_ON"] = 0x80
--下左右扫风关
keyB["BYTE_SWING_LR_UNDER_OFF"] = 0x00
--下左右扫风功能开
keyB["BYTE_SWING_LR_UNDER_ENABLE"] = 0x80
--下左右扫风功能关
keyB["BYTE_SWING_LR_UNDER_DISABLE"] = 0x00
--上下扫风开
keyB["BYTE_SWING_UD_ON"] = 0x0C
--上下扫风关
keyB["BYTE_SWING_UD_OFF"] = 0x00
--干燥开
keyB["BYTE_DRY_ON"] = 0x04
--干燥关
keyB["BYTE_DRY_OFF"] = 0x00
--buzzer（蜂鸣）开
keyB["BYTE_BUZZER_ON"] = 0x40
--buzzer（蜂鸣）关
keyB["BYTE_BUZZER_OFF"] = 0x00
--设备控制命令
keyB["BYTE_CONTROL_CMD"] = 0x40
--定时方式(相对)
keyB["BYTE_TIMER_METHOD_REL"] = 0x00
--定时方式(相对)
keyB["BYTE_TIMER_METHOD_ABS"] = 0x01
--定时方式(禁用)
keyB["BYTE_TIMER_METHOD_DISABLE"] = 0x7F
--移动终端控制
keyB["BYTE_CLIENT_MODE_MOBILE"] = 0x02
--移动端定时开
keyB["BYTE_TIMER_SWITCH_ON"] = 0x80
--移动端定时关
keyB["BYTE_TIMER_SWITCH_OFF"] = 0x00
--定时关(开)
keyB["BYTE_CLOSE_TIMER_SWITCH_ON"] = 0x80
--定时关(关)
keyB["BYTE_CLOSE_TIMER_SWITCH_OFF"] = 0x7F
--定时开(开)
keyB["BYTE_START_TIMER_SWITCH_ON"] = 0x80
--定时开(关)
keyB["BYTE_START_TIMER_SWITCH_OFF"] = 0x7F
--PTC（电辅热）开
keyB["BYTE_PTC_ON"] = 0x08
--PTC（电辅热）关
keyB["BYTE_PTC_OFF"] = 0x00
--强劲风开
keyB["BYTE_STRONG_WIND_ON"] = 0x20
--强劲风关
keyB["BYTE_STRONG_WIND_OFF"] = 0x00
--舒睡开
keyB["BYTE_SLEEP_ON"] = 0x03
--舒睡关
keyB["BYTE_SLEEP_OFF"] = 0x00
--舒省开
keyB["BYTE_COMFORT_POWER_SAVE_ON"] = 0x01
--舒省关
keyB["BYTE_COMFORT_POWER_SAVE_OFF"] = 0x00
--均匀风开
keyB["BYTE_EVEN_WIND_ON"] = 0x01
--均匀风关
keyB["BYTE_EVEN_WIND_OFF"] = 0x00 
--单风口开
keyB["BYTE_SINGLE_TUYERE_ON"] = 0x01
--单风口关
keyB["BYTE_SINGLE_TUYERE_OFF"] = 0x00
--超远风开
keyB["BYTE_EXTREME_WIND_ON"] = 0x01
--超远风关
keyB["BYTE_EXTREME_WIND_OFF"] = 0x00
--语音控制开
keyB["BYTE_VOICE_CONTROL_ON"] = 0x03
--语音控制关
keyB["BYTE_VOICE_CONTROL_OFF"] = 0x00
--自然风开
keyB["BYTE_NATURAL_WIND_ON"] = 0x40
--自然风关
keyB["BYTE_NATURAL_WIND_OFF"] = 0x00

--设备控制命令
keyB["BYTE_CONTROL_PROPERTY_CMD"] = 0xB0

-------------------定义属性变量--------------------
local keyP = {}
local dataType = 0
local comfortByte = nil

local function init_keyP()
	keyP["powerValue"] = nil 
	keyP["modeValue"] = nil 
	keyP["smartDryValue"] = nil 
	keyP["temperature"] = nil 
	keyP["smallTemperature"] = nil 
	keyP["indoorTemperatureValue"] = nil 
	keyP["smallIndoorTemperatureValue"] = nil
	keyP["outdoorTemperatureValue"] = nil 
	keyP["smallOutdoorTemperatureValue"] = nil
	keyP["fanspeedValue"] = nil 
	keyP["closeTimerSwitch"] = nil 
	keyP["openTimerSwitch"] = nil 
	keyP["closeHour"] = nil
	keyP["closeStepMintues"] = nil
	keyP["closeMin"] = nil
	keyP["closeTime"] = nil
	keyP["openHour"] = nil
	keyP["openStepMintues"] = nil
	keyP["openMin"] = nil
	keyP["openTime"] = nil
	keyP["strongWindValue"] = nil
	keyP["tubroValue"] = nil
	keyP["comfortableSleepValue"] = nil
	keyP["comfortableSleepSwitch"] = nil
	keyP["comfortableSleepTime"] = nil
	keyP["comfort_sleep_curve"] = nil
	keyP["PTCValue"] = nil
	keyP["purifierValue"] = nil 
	keyP["ecoValue"] = nil 
	keyP["dryValue"] = nil 
	keyP["swingLRValue"] = nil 
	keyP["swingUDValue"] = nil 
	keyP["swingLRValueUnder"] = 0
    keyP["swingLRUnderSwitch"] = 0
	keyP["currentWorkTime"] = nil
	keyP["PTCForceValue"] = 0
	keyP["screenDisplayNowValue"] = nil
	keyP["temperature_unit"] = nil
	--美居之前就是默认开的
	keyP["buzzerValue"] = 0x40 
	keyP["errorCode"] = 0
	--是否踢被子
	keyP["kickQuilt"]= nil
	--防着凉
	keyP["preventCold"] = nil
	--舒省
	keyP["comfortPowerSave"] = nil
	--自然风
	keyP["naturalWind"] = nil
	--pmv
	keyP["pmv"] = nil
	--新风滤网
	keyP["fresh_filter_time_total"] = nil
	keyP["fresh_filter_time_use"] = nil
	keyP["fresh_filter_timeout"] = nil
	keyP["fresh_filter_timeout_ae2"] = nil
	keyP["fresh_filter_reset"] = nil
	keyP["common_filter_reset"] = nil
	keyP["degree8_heat"] = nil

	--新协议，变长属性解析协议
	keyP["propertyNumber"] = 0
	keyP["prevent_super_cool"] = nil 
	keyP["prevent_straight_wind"] = nil 
	keyP["auto_prevent_straight_wind"] = nil 
	keyP["self_clean"] = nil 
	keyP["wind_straight"] = nil 
	keyP["wind_avoid"] = nil
    keyP["yb_wind_avoid"] = nil	
	keyP["intelligent_wind"] = nil 
	keyP["no_wind_sense"] = nil 
	keyP["child_prevent_cold_wind"] = nil 
	keyP["little_angel"] = nil 
	keyP["cool_hot_sense"] = nil 
	keyP["gentle_wind_sense"] = nil 
	keyP["security"] = nil
	keyP["even_wind"] = nil
	keyP["single_tuyere"] = nil
	keyP["extreme_wind"] = nil
	keyP["extreme_wind_level"] = nil
	keyP["voice_control"] = nil
	keyP["pre_cool_hot"] = nil
	keyP["water_washing"] = nil
	keyP["fresh_air"] = nil
	keyP["no_wind_sense_level"] = nil
	keyP["fa_no_wind_sense"] = nil
	keyP["fa_prevent_straight_wind"] = nil
	keyP["parent_control"] = nil
	keyP["parent_control_temp_up"] = nil
	keyP["parent_control_temp_down"] = nil
	keyP["nobody_energy_save"] = nil
	keyP["filter_value"] = nil
	keyP["filter_level"] = nil
	keyP["prevent_straight_wind_lr"] = nil
	keyP["pm25_value"] = nil
	keyP["water_pump"] = nil
	keyP["intelligent_control"] = nil
	keyP["wind_swing_ud_angle"] = nil
	keyP["wind_swing_lr_angle"] = nil
	keyP["volume_control"] = nil
	keyP["voice_control_new"] = nil
	keyP["face_register"] = nil
	keyP["cool_temp_up"] = nil
	keyP["cool_temp_down"] = nil
	keyP["auto_temp_up"] = nil
	keyP["auto_temp_down"] = nil
	keyP["heat_temp_up"] = nil
	keyP["heat_temp_down"] = nil
	keyP["power_saving"] = nil
	keyP["remote_control_lock"] = nil
	keyP["remote_control_lock_control"] = nil
	keyP["indoor_humidity"] = nil
	keyP["b5_mode"] = nil
	keyP["b5_strong_wind"] = nil
	keyP["b5_wind_speed"] = nil
	keyP["b5_humidity"] = nil
	keyP["b5_temperature_0"] = nil
	keyP["b5_temperature_1"] = nil
	keyP["b5_temperature_2"] = nil
	keyP["b5_temperature_3"] = nil
	keyP["b5_temperature_4"] = nil
	keyP["b5_temperature_5"] = nil
	keyP["b5_temperature_6"] = nil
	keyP["b5_eco"] = nil
	keyP["b5_filter_remind"] = nil
	keyP["b5_filter_check"] = nil
	keyP["b5_fahrenheit"] = nil
	keyP["b5_8_heat"] = nil
	keyP["b5_electricity"] = nil
	keyP["b5_ptc"] = nil
	keyP["b5_wind_straight"] = nil
	keyP["b5_wind_avoid"] = nil
	keyP["b5_wind_swing"] = nil
	keyP["b5_no_wind_sense"] = nil
	keyP["b5_screen_display"] = nil
	keyP["b5_anion"] = nil
	keyP["b5_self_clean"] = nil
	keyP["b5_fa_no_wind_sense"] = nil
	keyP["b5_nobody_energy_save"] = nil
	keyP["b5_prevent_straight_wind"] = nil
	keyP["real_time_power"] = nil
	keyP["real_time_power_10"] = nil
	keyP["current_humidity"] = nil
	keyP["prevent_straight_wind_flag"] = nil
	keyP["fa_gentle_wind_sense"] = nil
	keyP["jet_cool"] = nil
	keyP["b5_jet_cool"] = nil
	keyP["body_check"] = nil
	keyP["b5_body_check"] = nil
	keyP["rate_select"] = nil
	keyP["b5_rate_select"] = nil
	keyP["b5_fresh_air"] = nil
	keyP["b5_wind_swing_lr_angle"] = nil
	keyP["b5_wind_swing_ud_angle"] = nil
	keyP["main_horizontal_guide_strip_1"] = nil
	keyP["main_horizontal_guide_strip_2"] = nil
	keyP["main_horizontal_guide_strip_3"] = nil
	keyP["main_horizontal_guide_strip_4"] = nil
	keyP["sup_horizontal_guide_strip_1"] = nil
	keyP["sup_horizontal_guide_strip_2"] = nil
	keyP["sup_horizontal_guide_strip_3"] = nil
	keyP["sup_horizontal_guide_strip_4"] = nil
	keyP["twins_machine"] = nil
	keyP["guide_strip_type"] = nil
	keyP["b5_main_horizontal_guide_strip_1"] = nil
	keyP["b5_main_horizontal_guide_strip_2"] = nil
	keyP["b5_main_horizontal_guide_strip_3"] = nil
	keyP["b5_main_horizontal_guide_strip_4"] = nil
	keyP["b5_sup_horizontal_guide_strip_1"] = nil
	keyP["b5_sup_horizontal_guide_strip_2"] = nil
	keyP["b5_sup_horizontal_guide_strip_3"] = nil
	keyP["b5_sup_horizontal_guide_strip_4"] = nil
	keyP["b5_twins_machine"] = nil
	keyP["b5_guide_strip_type"] = nil
	keyP["main_strip_control"] = nil
	keyP["sup_strip_control"] = nil
	keyP["sleep_status"] = nil
	keyP["sound"] = nil
	keyP["b5_sound"] = nil
	keyP["anion"] = nil
	keyP["b5_anion"] = nil
	keyP["machine_type"] = nil
	keyP["independent_ptc"] = nil
	keyP["gen_mode"] = nil
	keyP["b5_parent_control"] = nil
	
	--ieco
	keyP["ieco_switch"]= nil
	keyP["ieco_frame"]= nil
	keyP["ieco_target_rate"]= nil
	keyP["ieco_indoor_wind_speed"]= nil
	keyP["ieco_outdoor_wind_speed"]= nil
	keyP["ieco_expansion_valve"]= nil
	keyP["b5_ieco_switch"]= nil
	keyP["ieco_indoor_wind_speed_level"]= nil
	keyP["ieco_outdoor_wind_speed_level"]= nil
	keyP["ieco_number"]= nil
	--2023-01-09
	keyP["wind_around"] = nil
	keyP["wind_around_ud"] = nil
	keyP["b5_wind_around"] = nil
	keyP["prevent_straight_wind_select"] = nil
	keyP["b5_prevent_straight_wind_select"] = nil
	
	--2023-03-24
	keyP["mito_cool"] = nil
	keyP["mito_heat"] = nil
	keyP["dr_time_hour"] = nil
	keyP["dr_time_min"] = nil
	keyP["t2_heat"] = nil
	keyP["tp_heat"] = nil
	keyP["k1_value"] = nil
	keyP["k2_value"] = nil
	keyP["k3_value"] = nil
	keyP["k4_value"] = nil
	keyP["cool_strong_wind_speed"] = nil
	keyP["cool_strong_wind_amount"] = nil
	keyP["has_cool_heat_amount"] = nil
	
	--2023-06-15
	keyP["has_icheck"] = nil
	keyP["b5_has_icheck"] = nil
	keyP["b5_emergent_heat_wind"] = nil
	keyP["b5_heat_ptc_wind"] = nil
	keyP["cvp"] = nil
	keyP["b5_cvp"] = nil
	
end

init_keyP()
local propertyPre = nil

---------------公共的函数 begin---------------
--打印 table 表
local function  print_lua_table(lua_table, indent)
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
        formatting = szPrefix.."["..k.."]".." = "..szSuffix
        
        if type(v) == "table" then
            print(formatting)
            
            print_lua_table(v, indent + 1)
            
            print(szPrefix.."},")
        else
            local szValue = ""
            
            if type(v) == "string" then
                szValue = string.format("%q", v)
            else
                szValue = tostring(v)
            end
            
            print(formatting..szValue..",")
        end
    end
end

--检查取值是否超过边界
local function  checkBoundary(data, min, max)
    if (not data) then
        data = 0
    end
    
    data = tonumber(data)

    if(data == nil) then
        data = 0
    end
    
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

--table 转 string
local function  table2string(cmd)
    local ret = ""
    local i
    
    for i = 1, #cmd do
        ret = ret..string.char(cmd[i])
    end
    
    return ret
end

--十六进制 string 转 table
local function  string2table(hexstr)
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

--string 转 table
local function  numstring2table(hexstr)
    local tb = {}
    local i = 1
    local j = 1
    
    for i = 1, #hexstr - 1, 2 do
        local doublebytestr = string.sub(hexstr, i, i + 1)
        tb[j] = doublebytestr
        j = j + 1
    end
    
    return tb
end

--十六进制 string 输出
local function  string2hexstring(str)
    local ret = ""
    
    for i = 1, #str do
        ret = ret .. string.format("%02x", str:byte(i))
    end
    
    return ret
end

--table 转 json
local function  encode(cmd)
    local tb
    
    if JSON == nil then
        JSON = require "cjson"
    end
    
    tb = JSON.encode(cmd)
    
    return tb
end

--json 转 table
local function  decode(cmd)
    local tb
    
    if JSON == nil then
        JSON = require "cjson"
    end
    
    tb = JSON.decode(cmd)
    
    return tb
end

--BCD转码
local function bcd2Int(bcd)
	return (bit.band(0x0F,bit.rshift(bcd,4))) * 10 + bit.band(0x0F,bcd)
end

--sum校验
local function  makeSum(tmpbuf, start_pos, end_pos)
    local resVal = 0
    
    for si = start_pos, end_pos do
        resVal = resVal + tmpbuf[si]
        
        if resVal > 0xff then
            resVal = bit.band(resVal, 0xff)
        end
    end
    
    resVal = bit.band(255 - resVal + 1, 0xff)
    
    return resVal
end

local function splitStrByChar(str,sepChar)
	local splitList = {}
	local pattern = '[^'..sepChar..']+'
		string.gsub(str, pattern, function(w) table.insert(splitList, w) end )
	return splitList
end

local function values (t)
	local i = 0
	return function() i = i + 1; return t[i] end
end

local function convert_to_F(temp)
	local tempTable = {}
	tempTable[10] = 50
	tempTable[10.5] = 51
	tempTable[11] = 52
	tempTable[11.5] = 53
	tempTable[12] = 54
	tempTable[12.5] = 54
	tempTable[13] = 55
	tempTable[13.5] = 56
	tempTable[14] = 57
	tempTable[14.5] = 58
	tempTable[15] = 59
	tempTable[15.5] = 59
	tempTable[16] = 60
	tempTable[16.5] = 61
	tempTable[17] = 62
	tempTable[17.5] = 63
	tempTable[18] = 64
	tempTable[18.5] = 65
	tempTable[19] = 66
	tempTable[19.5] = 67
	tempTable[20] = 68
	tempTable[20.5] = 69
	tempTable[21] = 70
	tempTable[21.5] = 71
	tempTable[22] = 72
	tempTable[22.5] = 73
	tempTable[23] = 73
	tempTable[23.5] = 74
	tempTable[24] = 75
	tempTable[24.5] = 76
	tempTable[25] = 77
	tempTable[25.5] = 78
	tempTable[26] = 79
	tempTable[26.5] = 80 
	tempTable[27] = 81
	tempTable[27.5] = 82
	tempTable[28] = 82
	tempTable[28.5] = 83
	tempTable[29] = 84
	tempTable[29.5] = 85
	tempTable[30] = 86
	tempTable[30.5] = 87
	tempTable[31] = 88
	tempTable[31.5] = 89

	local temperature = temp
	if(type(temp) == "string")then
		temperature = tonumber(temp)
	end
	return tempTable[temperature]
end

local function convert_to_C(temp)
	local tempTable = {}
	tempTable[50] = 10
	tempTable[51] = 10.5
	tempTable[52] = 11
	tempTable[53] = 11.5
	tempTable[54] = 12
	tempTable[55] = 13
	tempTable[56] = 13.5
	tempTable[57] = 14
	tempTable[58] = 14.5
	tempTable[59] = 15
	tempTable[60] = 16
	tempTable[61] = 16.5
	tempTable[62] = 17
	tempTable[63] = 17.5
	tempTable[64] = 18
	tempTable[65] = 18.5
	tempTable[66] = 19
	tempTable[67] = 19.5
	tempTable[68] = 20
	tempTable[69] = 20.5
	tempTable[70] = 21
	tempTable[71] = 21.5
	tempTable[72] = 22
	tempTable[73] = 23
	tempTable[74] = 23.5
	tempTable[75] = 24
	tempTable[76] = 24.5
	tempTable[77] = 25
	tempTable[78] = 25.5
	tempTable[79] = 26
	tempTable[80] = 26.5
	tempTable[81] = 27
	tempTable[82] = 28
	tempTable[83] = 28.5
	tempTable[84] = 29
	tempTable[85] = 29.5
	tempTable[86] = 30 
	tempTable[87] = 30.5
	tempTable[88] = 31
	tempTable[89] = 31.5
	local temperature = temp
	if(type(temp) == "string")then
		temperature = tonumber(temp)
	end
	return tempTable[temperature]
end
--CRC表
local crc8_854_table =
{
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

--CRC校验
local function  crc8_854(dataBuf, start_pos, end_pos)
    local crc = 0
    
    for si = start_pos, end_pos do
        crc = crc8_854_table[bit.band(bit.bxor(crc, dataBuf[si]), 0xFF) + 1]
    end
    
    return crc
end

---------------公共的函数 end---------------


-----------根据电控协议不同，需要改变的函数-------------
--根据 json 修改属性变量
local function  jsonToModel(jsonCmd,jsonType)
    local streams = jsonCmd
    
    --蜂鸣，定时方式，遥控器端来源，电源
    if (streams[keyT["KEY_POWER"]] == keyV["VALUE_FUNCTION_ON"]) then
        keyP["powerValue"] = keyB["BYTE_POWER_ON"]
		keyP["openTimerSwitch"] = keyB["BYTE_START_TIMER_SWITCH_OFF"]
		keyP["closeTimerSwitch"] = keyB["BYTE_CLOSE_TIMER_SWITCH_OFF"]
		keyP["PTCValue"] = keyB["BYTE_PTC_ON"]
    elseif (streams[keyT["KEY_POWER"]] == keyV["VALUE_FUNCTION_OFF"]) then
        keyP["powerValue"] = keyB["BYTE_POWER_OFF"]
		keyP["openTimerSwitch"] = keyB["BYTE_START_TIMER_SWITCH_OFF"]
		keyP["closeTimerSwitch"] = keyB["BYTE_CLOSE_TIMER_SWITCH_OFF"]
		keyP["PTCValue"] = keyB["BYTE_PTC_ON"]
    end
	
	--按键（按键有无用于决定空调器蜂鸣器是否发出声音）
	if (streams[keyT["KEY_BUZZER"]] == "VALUE_FUNCTION_ON") then
        keyP["buzzerValue"] = keyB["BYTE_BUZZER_ON"]
    elseif (streams[keyT["KEY_BUZZER"]] == keyV["VALUE_FUNCTION_OFF"]) then
        keyP["buzzerValue"] = keyB["BYTE_BUZZER_OFF"]
    end

    --净化
    if (streams[keyT["KEY_PURIFIER"]] == keyV["VALUE_FUNCTION_ON"]) then
        keyP["purifierValue"] = keyB["BYTE_PURIFIER_ON"]
    elseif (streams[keyT["KEY_PURIFIER"]] == keyV["VALUE_FUNCTION_OFF"]) then
        keyP["purifierValue"] = keyB["BYTE_PURIFIER_OFF"]
    end

    --ECO
    if (streams[keyT["KEY_ECO"]] == keyV["VALUE_FUNCTION_ON"]) then
        keyP["ecoValue"] = keyB["BYTE_ECO_ON"]
    elseif (streams[keyT["KEY_ECO"]] == keyV["VALUE_FUNCTION_OFF"]) then
        keyP["ecoValue"] = keyB["BYTE_ECO_OFF"]
    end

    --干燥
    if (streams[keyT["KEY_DRY"]] == keyV["VALUE_FUNCTION_ON"]) then
        keyP["dryValue"] = keyB["BYTE_DRY_ON"]
    elseif (streams[keyT["KEY_DRY"]] == keyV["VALUE_FUNCTION_OFF"]) then
        keyP["dryValue"] = keyB["BYTE_DRY_OFF"]
    end

    --模式和温度
    if (streams[keyT["KEY_MODE"]] == keyV["VALUE_MODE_HEAT"]) then
        keyP["modeValue"] = keyB["BYTE_MODE_HEAT"]
		keyP["PTCValue"] = keyB["BYTE_PTC_ON"]
    elseif (streams[keyT["KEY_MODE"]] == keyV["VALUE_MODE_COOL"]) then
        keyP["modeValue"] = keyB["BYTE_MODE_COOL"]
    elseif (streams[keyT["KEY_MODE"]] == keyV["VALUE_MODE_AUTO"]) then
        keyP["modeValue"] = keyB["BYTE_MODE_AUTO"]
		keyP["PTCValue"] = keyB["BYTE_PTC_ON"]
    elseif (streams[keyT["KEY_MODE"]] == keyV["VALUE_MODE_DRY"]) then
        keyP["modeValue"] = keyB["BYTE_MODE_DRY"]
    elseif (streams[keyT["KEY_MODE"]] == keyV["VALUE_MODE_FAN"]) then
        keyP["modeValue"] = keyB["BYTE_MODE_FAN"]
    elseif (streams[keyT["KEY_MODE"]] == keyV["VALUE_MODE_SMART_DRY"]) then
        keyP["modeValue"] = keyB["BYTE_MODE_SMART_DRY"]
	elseif (streams["mode"] == "single_elecheat")then
		keyP["modeValue"] = keyB["BYTE_MODE_HEAT"]
		keyP["independent_ptc"] = 0x08
	elseif (streams["mode"] == "heat_elecheat")then
		keyP["modeValue"] = keyB["BYTE_MODE_HEAT"]
		keyP["PTCValue"] = keyB["BYTE_PTC_ON"]
    end
    --智能除湿值
    if (streams[keyT["KEY_SMART_DRY"]] ~= nil) then
		keyP["smartDryValue"] = checkBoundary(streams[keyT["KEY_SMART_DRY"]], 30, 101)
	end
    --自然风
    if (streams[keyT["KEY_NATURAL_WIND"]] == keyV["VALUE_FUNCTION_ON"]) then
        keyP["naturalWind"] = keyB["BYTE_NATURAL_WIND_ON"]
    elseif (streams[keyT["KEY_NATURAL_WIND"]] == keyV["VALUE_FUNCTION_OFF"]) then
        keyP["naturalWind"] = keyB["BYTE_NATURAL_WIND_OFF"]
    end
    --pmv
    if (streams[keyT["KEY_PMV"]] ~= nil ) then
		keyP["pmv"] = checkBoundary(streams[keyT["KEY_PMV"]], -3.5, 3)
    end

    --风速
    if (streams[keyT["KEY_FANSPEED"]] ~= nil) then
		keyP["fanspeedValue"] = checkBoundary(streams[keyT["KEY_FANSPEED"]], 1, 102)
    end

    --上下扫风
    if (streams[keyT["KEY_SWING_UD"]] == keyV["VALUE_FUNCTION_ON"]) then
        keyP["swingUDValue"] = keyB["BYTE_SWING_UD_ON"]
    elseif (streams[keyT["KEY_SWING_UD"]] == keyV["VALUE_FUNCTION_OFF"]) then
        keyP["swingUDValue"] = keyB["BYTE_SWING_UD_OFF"]
    end
    
    --左右扫风
    if (streams[keyT["KEY_SWING_LR"]] == keyV["VALUE_FUNCTION_ON"]) then
        keyP["swingLRValue"] = keyB["BYTE_SWING_LR_ON"]
    elseif (streams[keyT["KEY_SWING_LR"]] == keyV["VALUE_FUNCTION_OFF"]) then
        keyP["swingLRValue"] = keyB["BYTE_SWING_LR_OFF"]
    end
	
	--下左右扫风
    if (streams[keyT["KEY_SWING_LR_UNDER"]] == keyV["VALUE_FUNCTION_ON"]) then
		keyP["swingLRUnderSwitch"] = keyB["BYTE_SWING_LR_UNDER_ENABLE"]
        keyP["swingLRValueUnder"] = keyB["BYTE_SWING_LR_UNDER_ON"]
    elseif (streams[keyT["KEY_SWING_LR_UNDER"]] == keyV["VALUE_FUNCTION_OFF"]) then
		keyP["swingLRUnderSwitch"] = keyB["BYTE_SWING_LR_UNDER_ENABLE"]
        keyP["swingLRValueUnder"] = keyB["BYTE_SWING_LR_UNDER_OFF"]
    end
    
    --定时开
    if (streams[keyT["KEY_TIME_ON"]] == keyV["VALUE_FUNCTION_ON"]) then
		keyP["openTimerSwitch"] = keyB["BYTE_START_TIMER_SWITCH_ON"]
    elseif (streams[keyT["KEY_TIME_ON"]] == keyV["VALUE_FUNCTION_OFF"]) then
		keyP["openTimerSwitch"] = keyB["BYTE_START_TIMER_SWITCH_OFF"]
    end
    
    --定时关
    if (streams[keyT["KEY_TIME_OFF"]] == keyV["VALUE_FUNCTION_ON"]) then
        keyP["closeTimerSwitch"] = keyB["BYTE_CLOSE_TIMER_SWITCH_ON"]
    elseif (streams[keyT["KEY_TIME_OFF"]] == keyV["VALUE_FUNCTION_OFF"]) then
        keyP["closeTimerSwitch"] = keyB["BYTE_CLOSE_TIMER_SWITCH_OFF"]
    end
    
    --定时关机时间
    if (streams[keyT["KEY_CLOSE_TIME"]] ~= nil) then 
        keyP["closeTime"] = streams[keyT["KEY_CLOSE_TIME"]]
    end

    --定时开机时间
    if (streams[keyT["KEY_OPEN_TIME"]] ~= nil) then
		keyP["openTime"] = streams[keyT["KEY_OPEN_TIME"]]
    end
	
	--舒睡
	if (streams[keyT["KEY_COMFORT_SLEEP"]] == keyV["VALUE_FUNCTION_ON"]) then
        keyP["comfortableSleepValue"] = keyB["BYTE_SLEEP_ON"]
		keyP["comfortableSleepSwitch"] = 0x40
		keyP["comfortableSleepTime"] = 0x0A
    elseif (streams[keyT["KEY_COMFORT_SLEEP"]] == keyV["VALUE_FUNCTION_OFF"]) then
        keyP["comfortableSleepValue"] = keyB["BYTE_SLEEP_OFF"]
		keyP["comfortableSleepSwitch"] = 0x00
		keyP["comfortableSleepTime"] = 0x00
    end
	
	--舒睡曲线
	if(streams[keyT["KEY_COMFORT_SLEEP_CURVE"]] ~= nil) then
	   streams[keyT["KEY_COMFORT_SLEEP_CURVE"]] = string.gsub(streams[keyT["KEY_COMFORT_SLEEP_CURVE"]],",","")
	   comfortByte = numstring2table(streams[keyT["KEY_COMFORT_SLEEP_CURVE"]])
	end
	   

    --电辅热
    if (streams[keyT["KEY_PTC"]] == keyV["VALUE_FUNCTION_ON"]) then
        keyP["PTCValue"] = keyB["BYTE_PTC_ON"]
    elseif (streams[keyT["KEY_PTC"]] == keyV["VALUE_FUNCTION_OFF"]) then
        keyP["PTCValue"] = keyB["BYTE_PTC_OFF"]
    end
	
	--单独电辅热
	if (streams["independent_ptc"] == keyV["VALUE_FUNCTION_ON"]) then
        keyP["independent_ptc"] = 0x08
    elseif (streams["independent_ptc"] == keyV["VALUE_FUNCTION_OFF"]) then
        keyP["independent_ptc"] = 0x00
    end
	

    --强劲
    if (streams[keyT["KEY_STRONG_WIND"]] == keyV["VALUE_FUNCTION_ON"]) then
        keyP["strongWindValue"] = keyB["BYTE_STRONG_WIND_ON"]
    elseif (streams[keyT["KEY_STRONG_WIND"]] == keyV["VALUE_FUNCTION_OFF"]) then
        keyP["strongWindValue"] = keyB["BYTE_STRONG_WIND_OFF"]
    end

    --Turbo(AE、AB强劲)
    if (streams[keyT["KEY_TUBRO"]] == keyV["VALUE_FUNCTION_ON"]) then
        keyP["tubroValue"] = 0x02
    elseif (streams[keyT["KEY_TUBRO"]] == keyV["VALUE_FUNCTION_OFF"]) then
        keyP["tubroValue"] = 0x00
    end

	--温度小数位(0/0.5)
	if(streams["small_temperature"] ~= nil) then
		keyP["smallTemperature"] = checkBoundary(streams["small_temperature"], 0, 0.5)
		if(keyP["smallTemperature"] == 0.5) then
			keyP["smallTemperature"] = 0x01
		else
			keyP["smallTemperature"] = 0x00
		end
	end

    --温度
    if (streams[keyT["KEY_TEMPERATURE"]] ~= nil) then
		if( type(streams[keyT["KEY_TEMPERATURE"]]) == "string") then
			streams[keyT["KEY_TEMPERATURE"]] = tonumber(streams[keyT["KEY_TEMPERATURE"]])
		end
		if(streams[keyT["KEY_TEMPERATURE"]] < 40) then
			keyP["temperature"] = checkBoundary(streams[keyT["KEY_TEMPERATURE"]], 10, 30)
		else
			keyP["temperature"] = checkBoundary(streams[keyT["KEY_TEMPERATURE"]], 50, 86)
			local temp = convert_to_C(keyP["temperature"]) 
			keyP["temperature"],keyP["smallTemperature"] = math.modf(temp)
			if(keyP["smallTemperature"] == 0.5) then
				keyP["smallTemperature"] = 0x01
			else
				keyP["smallTemperature"] = 0x00
			end
			keyP["temperature_unit"] = 1
		end
    end 
    
	--温度单位
    if (streams["temperature_unit"] ~= nil) then
        keyP["temperature_unit"] = checkBoundary(streams["temperature_unit"], 0, 1)
    end 
	
	--舒省
    if (streams[keyT["KEY_COMFORT_POWER_SAVE"]] == keyV["VALUE_FUNCTION_ON"]) then 
        keyP["comfortPowerSave"] = keyB["BYTE_COMFORT_POWER_SAVE_ON"]
    elseif (streams[keyT["KEY_COMFORT_POWER_SAVE"]] == keyV["VALUE_FUNCTION_OFF"]) then
        keyP["comfortPowerSave"] = keyB["BYTE_COMFORT_POWER_SAVE_OFF"]
    end
    
	--防过冷(快速降温，缓慢回温)
    if (jsonType == "control" and streams[keyT["KEY_PREVENT_SUPER_COOL"]] ~= nil) then 
		keyP["propertyNumber"] = keyP["propertyNumber"] + 1
		if (streams[keyT["KEY_PREVENT_SUPER_COOL"]] == keyV["VALUE_FUNCTION_ON"]) then
		keyP["prevent_super_cool"] = 0x01
		elseif (streams[keyT["KEY_PREVENT_SUPER_COOL"]] == keyV["VALUE_FUNCTION_OFF"]) then
		keyP["prevent_super_cool"] = 0x00
		end
	end 
	
	--8度制热
    if (streams[keyT["KEY_DEGREE8_HEAT"]] ~= nil) then 
		keyP["degree8_heat"] = checkBoundary(streams[keyT["KEY_DEGREE8_HEAT"]], 0, 1)
    end

	--防着凉
    if (streams[keyT["KEY_PREVENT_COLD"]] == keyV["VALUE_FUNCTION_ON"]) then 
        keyP["preventCold"] = 0x01
    elseif (streams[keyT["KEY_PREVENT_COLD"]] == keyV["VALUE_FUNCTION_OFF"]) then
        keyP["preventCold"] = 0x00
    end
	
	--防直吹
    if (jsonType == "control" and streams[keyT["KEY_PREVENT_STRAIGHT_WIND"]] ~= nil) then 
		keyP["propertyNumber"] = keyP["propertyNumber"] + 1
		keyP["prevent_straight_wind"] = checkBoundary(streams[keyT["KEY_PREVENT_STRAIGHT_WIND"]], 0, 2)
	end
	
	--fa系列防直吹
    if (jsonType == "control" and streams[keyT["KEY_FA_PREVENT_STRAIGHT_WIND"]] ~= nil) then 
		keyP["propertyNumber"] = keyP["propertyNumber"] + 1
		keyP["fa_prevent_straight_wind"] = checkBoundary(streams[keyT["KEY_FA_PREVENT_STRAIGHT_WIND"]], 0, 2)
	end

	--自动防直吹
    if (jsonType == "control" and streams[keyT["KEY_AUTO_PREVENT_STRAIGHT_WIND"]] ~= nil) then 
		keyP["propertyNumber"] = keyP["propertyNumber"] + 1
		if (streams[keyT["KEY_AUTO_PREVENT_STRAIGHT_WIND"]] == keyV["VALUE_FUNCTION_ON"]) then
		keyP["auto_prevent_straight_wind"] = 0x01
		elseif (streams[keyT["KEY_AUTO_PREVENT_STRAIGHT_WIND"]] == keyV["VALUE_FUNCTION_OFF"]) then
		keyP["auto_prevent_straight_wind"] = 0x00
		end 
	end

	--自清洁
    if (jsonType == "control" and streams[keyT["KEY_SELF_CLEAN"]] ~= nil) then 
		keyP["propertyNumber"] = keyP["propertyNumber"] + 1
		if (streams[keyT["KEY_SELF_CLEAN"]] == keyV["VALUE_FUNCTION_ON"]) then
		keyP["self_clean"] = 0x01
		elseif (streams[keyT["KEY_SELF_CLEAN"]] == keyV["VALUE_FUNCTION_OFF"]) then
		keyP["self_clean"] = 0x00
		end
	end 
	
	--风吹人
    if (jsonType == "control" and streams[keyT["KEY_WIND_STRAIGHT"]] ~= nil) then 
		keyP["propertyNumber"] = keyP["propertyNumber"] + 1
		if (streams[keyT["KEY_WIND_STRAIGHT"]] == keyV["VALUE_FUNCTION_ON"]) then
		keyP["wind_straight"] = 0x01
		elseif (streams[keyT["KEY_WIND_STRAIGHT"]] == keyV["VALUE_FUNCTION_OFF"]) then
		keyP["wind_straight"] = 0x00
		end
	end 
	
	--风避人
    if (jsonType == "control" and streams[keyT["KEY_WIND_AVOID"]] ~= nil) then 
		keyP["propertyNumber"] = keyP["propertyNumber"] + 1
		if (streams[keyT["KEY_WIND_AVOID"]] == keyV["VALUE_FUNCTION_ON"]) then
		keyP["wind_avoid"] = 0x01
		elseif (streams[keyT["KEY_WIND_AVOID"]] == keyV["VALUE_FUNCTION_OFF"]) then
		keyP["wind_avoid"] = 0x00
		end
	end 
	
	--yb系列风避人
    if (jsonType == "control" and streams[keyT["KEY_YB_WIND_AVOID"]] ~= nil) then 
		keyP["propertyNumber"] = keyP["propertyNumber"] + 1
		if (streams[keyT["KEY_YB_WIND_AVOID"]] == keyV["VALUE_FUNCTION_ON"]) then
		keyP["yb_wind_avoid"] = 0x02
		elseif (streams[keyT["KEY_YB_WIND_AVOID"]] == keyV["VALUE_FUNCTION_OFF"]) then
		keyP["yb_wind_avoid"] = 0x00
		end
	end 
	
	--智慧风
    if (jsonType == "control" and streams[keyT["KEY_INTELLIGENT_WIND"]] ~= nil) then 
		keyP["propertyNumber"] = keyP["propertyNumber"] + 1
		if (streams[keyT["KEY_INTELLIGENT_WIND"]] == keyV["VALUE_FUNCTION_ON"]) then
		keyP["intelligent_wind"] = 0x01
		elseif (streams[keyT["KEY_INTELLIGENT_WIND"]] == keyV["VALUE_FUNCTION_OFF"]) then
		keyP["intelligent_wind"] = 0x00
		end
	end 
	
	--无风感
    if (jsonType == "control" and  streams[keyT["KEY_NO_WIND_SENSE"]] ~= nil) then 
		keyP["propertyNumber"] = keyP["propertyNumber"] + 1
		keyP["no_wind_sense"] = checkBoundary(streams[keyT["KEY_NO_WIND_SENSE"]], 0, 5)
	end
	
	--远近无风感
	if (jsonType == "control" and  streams[keyT["KEY_FA_NO_WIND_SENSE"]] ~= nil) then 
		keyP["propertyNumber"] = keyP["propertyNumber"] + 1
		keyP["fa_no_wind_sense"] = checkBoundary(streams[keyT["KEY_FA_NO_WIND_SENSE"]], 1, 4)
	end
	
	--无风感等级
	if (streams["no_wind_sense_level"] ~= nil) then
	    keyP["no_wind_sense_level"] = streams["no_wind_sense_level"]
	end
	
	--儿童防冷风
    if (jsonType == "control" and streams[keyT["KEY_CHILD_PREVENT_COLD_WIND"]] ~= nil) then 
		keyP["propertyNumber"] = keyP["propertyNumber"] + 1
		if (streams[keyT["KEY_CHILD_PREVENT_COLD_WIND"]] == keyV["VALUE_FUNCTION_ON"]) then
		keyP["child_prevent_cold_wind"] = 0x01
		elseif (streams[keyT["KEY_CHILD_PREVENT_COLD_WIND"]] == keyV["VALUE_FUNCTION_OFF"]) then
		keyP["child_prevent_cold_wind"] = 0x00
		end
	end 
	
	--小天使
    if (jsonType == "control" and streams[keyT["KEY_LITTLE_ANGLE"]] ~= nil) then 
		keyP["propertyNumber"] = keyP["propertyNumber"] + 1
		if (streams[keyT["KEY_LITTLE_ANGLE"]] == keyV["VALUE_FUNCTION_ON"]) then
		keyP["little_angel"] = 0x01
		elseif (streams[keyT["KEY_LITTLE_ANGLE"]] == keyV["VALUE_FUNCTION_OFF"]) then
		keyP["little_angel"] = 0x00
		end
	end 
	
	--冷热感
    if (jsonType == "control" and streams[keyT["KEY_COOL_HOT_SENSE"]] ~= nil) then 
		keyP["propertyNumber"] = keyP["propertyNumber"] + 1
		if (streams[keyT["KEY_COOL_HOT_SENSE"]] == keyV["VALUE_FUNCTION_ON"]) then
		keyP["cool_hot_sense"] = 0x01
		elseif (streams[keyT["KEY_COOL_HOT_SENSE"]] == keyV["VALUE_FUNCTION_OFF"]) then
		keyP["cool_hot_sense"] = 0x00
		end
	end 
	
	--柔风感
    if (jsonType == "control" and streams[keyT["KEY_GENTLE_WIND_SENSE"]] ~= nil) then 
		keyP["propertyNumber"] = keyP["propertyNumber"] + 1
		if (streams[keyT["KEY_GENTLE_WIND_SENSE"]] == keyV["VALUE_FUNCTION_ON"]) then
		keyP["gentle_wind_sense"] = 0x03
		elseif (streams[keyT["KEY_GENTLE_WIND_SENSE"]] == keyV["VALUE_FUNCTION_OFF"]) then
		keyP["gentle_wind_sense"] = 0x01
		end
	end 
	
	--安防
	if (jsonType == "control" and streams[keyT["KEY_SECURITY"]] ~= nil) then 
		keyP["propertyNumber"] = keyP["propertyNumber"] + 1
		if (streams[keyT["KEY_SECURITY"]] == keyV["VALUE_FUNCTION_ON"]) then 
			keyP["security"] = 0x01 
		elseif (streams[keyT["KEY_SECURITY"]] == keyV["VALUE_FUNCTION_OFF"]) then 
			keyP["security"] = 0x00 
		end  
	end 
	--均匀风
	if (jsonType == "control" and streams[keyT["KEY_EVEN_WIND"]] ~= nil) then
        keyP["propertyNumber"] = keyP["propertyNumber"] + 1
		if (streams[keyT["KEY_EVEN_WIND"]] == keyV["VALUE_FUNCTION_ON"]) then 
			keyP["even_wind"] = 0x01 
		elseif (streams[keyT["KEY_EVEN_WIND"]] == keyV["VALUE_FUNCTION_OFF"]) then 
			keyP["even_wind"] = 0x00 
		end  
	end
	--单风口
	if (jsonType == "control" and streams[keyT["KEY_SINGLE_TUYERE"]] ~= nil) then
        keyP["propertyNumber"] = keyP["propertyNumber"] + 1
		if (streams[keyT["KEY_SINGLE_TUYERE"]] == keyV["VALUE_FUNCTION_ON"]) then 
			keyP["single_tuyere"] = 0x01 
		elseif (streams[keyT["KEY_SINGLE_TUYERE"]] == keyV["VALUE_FUNCTION_OFF"]) then 
			keyP["single_tuyere"] = 0x00 
		end  
	end
	--超远风
    if (jsonType == "control" and streams[keyT["KEY_EXTREME_WIND"]] ~= nil) then
        keyP["propertyNumber"] = keyP["propertyNumber"] + 1
		if (streams[keyT["KEY_EXTREME_WIND"]] == keyV["VALUE_FUNCTION_ON"]) then 
			keyP["extreme_wind"] = 0x01 
		elseif (streams[keyT["KEY_EXTREME_WIND"]] == keyV["VALUE_FUNCTION_OFF"]) then 
			keyP["extreme_wind"] = 0x00 
		end  
	end
    --超远风等级
    if(streams["extreme_wind_level"] ~= nil) then
        keyP["extreme_wind_level"] = streams["extreme_wind_level"]
	end
	--语音控制
	if (jsonType == "control" and streams[keyT["KEY_VOICE_CONTROL"]] ~= nil) then
        keyP["propertyNumber"] = keyP["propertyNumber"] + 1
		if (streams[keyT["KEY_VOICE_CONTROL"]] == keyV["VALUE_FUNCTION_ON"]) then 
			keyP["voice_control"] = 0x03 
		elseif (streams[keyT["KEY_VOICE_CONTROL"]] == keyV["VALUE_FUNCTION_OFF"]) then 
			keyP["voice_control"] = 0x00 
		end  
	end
	--预冷预热
	if (jsonType == "control" and streams[keyT["KEY_PRE_COOL_HOT"]] ~= nil) then 
		keyP["propertyNumber"] = keyP["propertyNumber"] + 1
		if (streams[keyT["KEY_PRE_COOL_HOT"]] == keyV["VALUE_FUNCTION_ON"]) then 
			keyP["pre_cool_hot"] = 0x01 
		elseif (streams[keyT["KEY_PRE_COOL_HOT"]] == keyV["VALUE_FUNCTION_OFF"]) then 
			keyP["pre_cool_hot"] = 0x00 
		end  
	end
	--水洗
	if (jsonType == "control" and streams[keyT["KEY_WATER_WASHING"]] ~= nil) then 
		keyP["propertyNumber"] = keyP["propertyNumber"] + 1
		if (streams[keyT["KEY_WATER_WASHING"]] == keyV["VALUE_FUNCTION_ON"]) then 
			keyP["water_washing"] = 0x01 
		elseif (streams[keyT["KEY_WATER_WASHING"]] == keyV["VALUE_FUNCTION_OFF"]) then 
			keyP["water_washing"] = 0x00 
		end         		
	end
	if(streams["water_washing_manual"] ~= nil) then
        keyP["water_washing_manual"] = streams["water_washing_manual"]
        keyP["water_washing_time"] = streams["water_washing_time"]
        keyP["water_washing_stage"] = streams["water_washing_stage"]	
	end
	--新风
	if (jsonType == "control" and streams[keyT["KEY_FRESH_AIR"]] ~= nil) then 
		keyP["propertyNumber"] = keyP["propertyNumber"] + 1
		if (streams[keyT["KEY_FRESH_AIR"]] == keyV["VALUE_FUNCTION_ON"]) then 
			keyP["fresh_air"] = 0x01 
		elseif (streams[keyT["KEY_FRESH_AIR"]] == keyV["VALUE_FUNCTION_OFF"]) then 
			keyP["fresh_air"] = 0x00 
		end 
        
        --keyP["fresh_air_fan_speed"] = streams["fresh_air_fan_speed"]
		--keyP["fresh_air_temp"] = streams["fresh_air_temp"]		
	end
	if(streams["fresh_air_fan_speed"] ~= nil) then
	   keyP["fresh_air_fan_speed"] = streams["fresh_air_fan_speed"]
	   keyP["fresh_air_temp"] = streams["fresh_air_temp"]
	end
    --家长控制
	if (jsonType == "control" and streams[keyT["KEY_PARENT_CONTROL"]] ~= nil) then 
		keyP["propertyNumber"] = keyP["propertyNumber"] + 1
		if (streams[keyT["KEY_PARENT_CONTROL"]] == keyV["VALUE_FUNCTION_ON"]) then 
			keyP["parent_control"] = 0x01 
		elseif (streams[keyT["KEY_PARENT_CONTROL"]] == keyV["VALUE_FUNCTION_OFF"]) then 
			keyP["parent_control"] = 0x00 
		end         		
	end
	if(streams["parent_control_temp_up"] ~= nil or keyP["parent_control_temp_down"] ~= nil) then
        keyP["parent_control_temp_up"] = streams["parent_control_temp_up"]
        keyP["parent_control_temp_down"] = streams["parent_control_temp_down"]		
	end
	
    --无人节能
	if (jsonType == "control" and streams[keyT["KEY_NOBODY_ENERGY_SAVE"]] ~= nil) then 
		keyP["propertyNumber"] = keyP["propertyNumber"] + 1
		if (streams[keyT["KEY_NOBODY_ENERGY_SAVE"]] == keyV["VALUE_FUNCTION_ON"]) then 
			keyP["nobody_energy_save"] = 0x01 
		elseif (streams[keyT["KEY_NOBODY_ENERGY_SAVE"]] == keyV["VALUE_FUNCTION_OFF"]) then 
			keyP["nobody_energy_save"] = 0x00 
		end         		
	end
	
	--左右无风感
    if (jsonType == "control" and streams[keyT["KEY_PREVENT_STRAIGHT_WIND_LR"]] ~= nil) then 
		keyP["propertyNumber"] = keyP["propertyNumber"] + 1
		keyP["prevent_straight_wind_lr"] = checkBoundary(streams[keyT["KEY_PREVENT_STRAIGHT_WIND_LR"]], 0, 2)
	end
	
	--pm25值
    if (jsonType == "control" and streams[keyT["KEY_PM25_VALUE"]] ~= nil) then 
		keyP["propertyNumber"] = keyP["propertyNumber"] + 1
		keyP["pm25_value"] = streams[keyT["KEY_PM25_VALUE"]]
	end
	
    --水泵开关
	if (jsonType == "control" and streams[keyT["KEY_WATER_PUMP"]] ~= nil) then 
		keyP["propertyNumber"] = keyP["propertyNumber"] + 1
		if (streams[keyT["KEY_WATER_PUMP"]] == keyV["VALUE_FUNCTION_ON"]) then 
			keyP["water_pump"] = 0x01 
		elseif (streams[keyT["KEY_WATER_PUMP"]] == keyV["VALUE_FUNCTION_OFF"]) then 
			keyP["water_pump"] = 0x00 
		end         		
	end
	
	--上下摆风角度
	if (jsonType == "control" and streams[keyT["KEY_WIND_SWING_UD_ANGLE"]] ~= nil) then 
		keyP["propertyNumber"] = keyP["propertyNumber"] + 1
		keyP["wind_swing_ud_angle"] = streams["wind_swing_ud_angle"]        		
	end
	--左右摆风角度
	if (jsonType == "control" and streams[keyT["KEY_WIND_SWING_LR_ANGLE"]] ~= nil) then 
		keyP["propertyNumber"] = keyP["propertyNumber"] + 1
		keyP["wind_swing_lr_angle"] = streams["wind_swing_lr_angle"]        		
	end
    --智能功能总开关
	if (jsonType == "control" and streams[keyT["KEY_INTENLLIGENT_CONTROL"]] ~= nil) then 
		keyP["propertyNumber"] = keyP["propertyNumber"] + 1
		if (streams[keyT["KEY_INTENLLIGENT_CONTROL"]] == keyV["VALUE_FUNCTION_ON"]) then 
			keyP["intelligent_control"] = 0x01 
		elseif (streams[keyT["KEY_INTENLLIGENT_CONTROL"]] == keyV["VALUE_FUNCTION_OFF"]) then 
			keyP["intelligent_control"] = 0x00 
		end         		
	end
	
	--音量控制
    if (jsonType == "control" and streams[keyT["KEY_VOLUME_CONTROL"]] ~= nil) then 
		keyP["propertyNumber"] = keyP["propertyNumber"] + 1
		keyP["volume_control"] = checkBoundary(streams[keyT["KEY_VOLUME_CONTROL"]], 0, 100)
	end
	
	--语音开关
    if (jsonType == "control" and streams[keyT["KEY_VOICE_CONTROL_NEW"]] ~= nil) then 
		keyP["propertyNumber"] = keyP["propertyNumber"] + 1
		keyP["voice_control_new"] = checkBoundary(streams[keyT["KEY_VOICE_CONTROL_NEW"]], 0, 3)
	end
	--温度上下限
	if (jsonType == "control" and (streams[keyT["KEY_AUTO_TEMP_UP"]] ~= nil or streams[keyT["KEY_AUTO_TEMP_DOWN"]] ~= nil or streams[keyT["KEY_COOL_TEMP_UP"]] ~= nil or streams[keyT["KEY_COOL_TEMP_DOWN"]] ~= nil or streams[keyT["KEY_HEAT_TEMP_UP"]] ~= nil or streams[keyT["KEY_HEAT_TEMP_DOWN"]] ~= nil)) then 
		keyP["propertyNumber"] = keyP["propertyNumber"] + 1
	end
	if(streams["cool_temp_up"] ~= nil) then 
	    keyP["cool_temp_up"] = streams["cool_temp_up"]
	end
	if(streams["cool_temp_down"] ~= nil) then 
	    keyP["cool_temp_down"] = streams["cool_temp_down"]
	end
	if(streams["auto_temp_up"] ~= nil) then 
	    keyP["auto_temp_up"] = streams["auto_temp_up"]
	end
	if(streams["auto_temp_down"] ~= nil) then 
	    keyP["auto_temp_down"] = streams["auto_temp_down"]
	end
	if(streams["heat_temp_up"] ~= nil) then 
	    keyP["heat_temp_up"] = streams["heat_temp_up"]
	end
	if(streams["heat_temp_down"] ~= nil) then 
	    keyP["heat_temp_down"] = streams["heat_temp_down"]
	end
	--省电
    if (streams[keyT["KEY_POWER_SAVING"]] == keyV["VALUE_FUNCTION_ON"]) then
        keyP["power_saving"] = 0x08
    elseif (streams[keyT["KEY_POWER_SAVING"]] == keyV["VALUE_FUNCTION_OFF"]) then
        keyP["power_saving"] = 0x00
    end
	--遥控器锁定
	if (jsonType == "control" and streams[keyT["KEY_REMOTE_CONTROL_LOCK"]] ~= nil) then 
		keyP["propertyNumber"] = keyP["propertyNumber"] + 1
		keyP["remote_control_lock"] = streams["remote_control_lock"]
		keyP["remote_control_lock_control"] = streams["remote_control_lock_control"]   		
	end
	--空调允许运行时间
	if (jsonType == "control" and streams[keyT["KEY_OPERATING_TIME"]] ~= nil) then 
		keyP["propertyNumber"] = keyP["propertyNumber"] + 1
		keyP["operating_time"] = streams["operating_time"] 		
	end
	
	--Gear
	if (jsonType == "control" and streams["rate_select"] ~= nil) then 
		keyP["propertyNumber"] = keyP["propertyNumber"] + 1
		keyP["rate_select"] = streams["rate_select"] 		
	end
	
	--Jet Cool
	if (jsonType == "control" and streams["jet_cool"] ~= nil) then 
		keyP["propertyNumber"] = keyP["propertyNumber"] + 1
		--keyP["jet_cool"] = streams["jet_cool"]
		if (streams["jet_cool"] == keyV["VALUE_FUNCTION_ON"]) then 
			keyP["jet_cool"] = 0x01 
		elseif (streams["jet_cool"] == keyV["VALUE_FUNCTION_OFF"]) then 
			keyP["jet_cool"] = 0x00 
		end 		
	end
	
	--四向风
	if (streams["main_horizontal_guide_strip_1"] ~= nil) then 
		keyP["main_horizontal_guide_strip_1"] = streams["main_horizontal_guide_strip_1"] 		
	end
	if (streams["main_horizontal_guide_strip_2"] ~= nil) then 
		keyP["main_horizontal_guide_strip_2"] = streams["main_horizontal_guide_strip_2"] 		
	end
	if (streams["main_horizontal_guide_strip_3"] ~= nil) then 
		keyP["main_horizontal_guide_strip_3"] = streams["main_horizontal_guide_strip_3"] 		
	end
	if (streams["main_horizontal_guide_strip_4"] ~= nil) then 
		keyP["main_horizontal_guide_strip_4"] = streams["main_horizontal_guide_strip_4"] 		
	end
	if (jsonType == "control" and (streams["main_horizontal_guide_strip_1"] ~= nil or streams["main_horizontal_guide_strip_2"] ~= nil or streams["main_horizontal_guide_strip_3"] ~= nil or streams["main_horizontal_guide_strip_4"] ~= nil)) then 
		keyP["propertyNumber"] = keyP["propertyNumber"] + 1
		keyP["main_strip_control"] = 1
	end
	
	
	if (streams["sup_horizontal_guide_strip_1"] ~= nil) then 
		keyP["sup_horizontal_guide_strip_1"] = streams["sup_horizontal_guide_strip_1"] 		
	end
	if (streams["sup_horizontal_guide_strip_2"] ~= nil) then 
		keyP["sup_horizontal_guide_strip_2"] = streams["sup_horizontal_guide_strip_2"] 		
	end
	if (streams["sup_horizontal_guide_strip_3"] ~= nil) then 
		keyP["sup_horizontal_guide_strip_3"] = streams["sup_horizontal_guide_strip_3"] 		
	end
	if (streams["sup_horizontal_guide_strip_4"] ~= nil) then 
		keyP["sup_horizontal_guide_strip_4"] = streams["sup_horizontal_guide_strip_4"] 		
	end
	if (jsonType == "control" and (streams["sup_horizontal_guide_strip_1"] ~= nil or streams["sup_horizontal_guide_strip_2"] ~= nil or streams["sup_horizontal_guide_strip_3"] ~= nil or streams["sup_horizontal_guide_strip_4"] ~= nil)) then 
		keyP["propertyNumber"] = keyP["propertyNumber"] + 1		
		keyP["sup_strip_control"] = 1
	end
	
	--声音(外销蜂鸣器)
	if (jsonType == "control" and streams["sound"] ~= nil) then 
		keyP["propertyNumber"] = keyP["propertyNumber"] + 1
		keyP["sound"] = streams["sound"] 		
	end
	
	
	--新风滤网运行时间清零
    if (streams[keyT["KEY_FRESH_FILTER_RESET"]] ~= nil) then
		if(tonumber(streams[keyT["KEY_FRESH_FILTER_RESET"]]) == 0x01)then
			keyP["fresh_filter_reset"] = 0x08
		end
    end
	
	--普通滤网运行时间清零
    if (streams[keyT["KEY_COMMON_FILTER_RESET"]] ~= nil) then
		if(tonumber(streams[keyT["KEY_COMMON_FILTER_RESET"]]) == 0x01)then
			keyP["common_filter_reset"] = 0x80
		end
    end
	
	--FA防直吹判断
	if (streams["prevent_straight_wind_flag"] ~= nil) then
		keyP["prevent_straight_wind_flag"] = streams["prevent_straight_wind_flag"]
    end
	
	if (streams["sleep_status"] ~= nil) then
		keyP["sleep_status"] = streams["sleep_status"]
    end
	
	--负离子
	if (jsonType == "control" and streams["anion"] ~= nil) then 
		--keyP["propertyNumber"] = keyP["propertyNumber"] + 1
		keyP["anion"] = streams["anion"] 		
	end
	
	--ieco
	
	if (jsonType == "control" and (streams["ieco_target_rate"] ~= nil or streams["ieco_indoor_wind_speed"] ~= nil or streams["ieco_outdoor_wind_speed"] ~= nil or streams["ieco_frame"] ~= nil or streams["ieco_expansion_valve"] ~= nil or streams["ieco_switch"] ~= nil)) then 
		keyP["propertyNumber"] = keyP["propertyNumber"] + 1
		keyP["ieco_status"] = 1
	end				  
	if (streams["ieco_switch"] ~= nil) then 
		keyP["ieco_switch"] = streams["ieco_switch"]
	end
	if (streams["ieco_target_rate"] ~= nil) then 
		keyP["ieco_target_rate"] = streams["ieco_target_rate"]
	end
	if (streams["ieco_indoor_wind_speed"] ~= nil) then 
		keyP["ieco_indoor_wind_speed"] = streams["ieco_indoor_wind_speed"]
	end
	if (streams["ieco_outdoor_wind_speed"] ~= nil) then 
		keyP["ieco_outdoor_wind_speed"] = streams["ieco_outdoor_wind_speed"]
	end
	if (streams["ieco_frame"] ~= nil) then 
		keyP["ieco_frame"] = streams["ieco_frame"]
	end
	if (streams["ieco_expansion_valve"] ~= nil) then 
		keyP["ieco_expansion_valve"] = streams["ieco_expansion_valve"]
	end
	if (streams["ieco_indoor_wind_speed_level"] ~= nil) then 
		keyP["ieco_indoor_wind_speed_level"] = streams["ieco_indoor_wind_speed_level"]
	end
	if (streams["ieco_outdoor_wind_speed_level"] ~= nil) then 
		keyP["ieco_outdoor_wind_speed_level"] = streams["ieco_outdoor_wind_speed_level"]
	end
	if (streams["ieco_number"] ~= nil) then 
		keyP["ieco_number"] = streams["ieco_number"]
	end
	--环绕风 
	if (jsonType == "control" and streams["wind_around"] ~= nil) then 
		keyP["propertyNumber"] = keyP["propertyNumber"] + 1
		if (streams["wind_around"] == keyV["VALUE_FUNCTION_ON"]) then
			keyP["wind_around"] = 0x01
		elseif (streams["wind_around"] == keyV["VALUE_FUNCTION_OFF"]) then
			keyP["wind_around"] = 0x00
		end
	end
    if (streams["wind_around_ud"] ~= nil) then
		keyP["wind_around_ud"] = streams["wind_around_ud"]
    end
	--mito
	if (streams["mito_cool"] ~= nil) then
		keyP["propertyNumber"] = keyP["propertyNumber"] + 1
		keyP["mito_cool"] = streams["mito_cool"]
    end
	if (streams["mito_heat"] ~= nil) then
		keyP["propertyNumber"] = keyP["propertyNumber"] + 1
		keyP["mito_heat"] = streams["mito_heat"]
    end
	if (streams["dr_time_hour"] ~= nil) then
		keyP["propertyNumber"] = keyP["propertyNumber"] + 1
		keyP["dr_time_hour"] = streams["dr_time_hour"]
    end
	if (streams["dr_time_min"] ~= nil) then
		keyP["dr_time_min"] = streams["dr_time_min"]
    end
	--防直吹类型选择
	if (jsonType == "control" and streams["prevent_straight_wind_select"] ~= nil) then 
		keyP["propertyNumber"] = keyP["propertyNumber"] + 1
		keyP["prevent_straight_wind_select"] = streams["prevent_straight_wind_select"]
    end
	--CVP
	if (jsonType == "control" and streams["cvp"] ~= nil) then 
		keyP["propertyNumber"] = keyP["propertyNumber"] + 1
		keyP["cvp"] = streams["cvp"]
    end
	
	
	
	--status中的属性协议不组，只组control中的属性协议
	if(jsonType == "status") then
		keyP["propertyNumber"] = 0
	end
end

--根据 bin 修改属性变量
local function  binToModel(binData,deviceSN8)

    local messageBytes = binData
    if ((dataType==0x02 and messageBytes[0] == 0xC0)or (dataType==0x03 and messageBytes[0] == 0xC0) or (dataType==0x05 and messageBytes[0] == 0xA0)) then
		if(#binData < 19) then
			return nil
		end
		keyP["powerValue"] = bit.band(messageBytes[1], 0x01)
        keyP["modeValue"] = bit.band(messageBytes[2], 0xE0)
		
		if(keyP["modeValue"] == keyB["BYTE_MODE_SMART_DRY"] or keyP["modeValue"] == keyB["BYTE_MODE_DRY"]) then
			if(dataType == 0x05) then
				keyP["smartDryValue"] = bit.band(messageBytes[13], 0x7F)
			else
				keyP["smartDryValue"] = bit.band(messageBytes[19], 0x7F)
			end
		end
		
        if(dataType == 0x05) then
            --CA机型 11447、11451、11453、11455、11457、11459、11525、11527、11533、11535
            if deviceSN8=="11447" or deviceSN8=="11451" or deviceSN8=="11453" or deviceSN8=="11455" or deviceSN8=="11457" or deviceSN8=="11459" or deviceSN8=="11525" or deviceSN8=="11527" or deviceSN8=="11533" or deviceSN8=="11535" then
                keyP["temperature"] = bit.rshift(bit.band(messageBytes[1], 0x7C), 2) + 0x0C
                keyP["smallTemperature"] = bit.rshift(bit.band(messageBytes[1], 0x02), 1)
            else
                keyP["temperature"] = bit.rshift(bit.band(messageBytes[1], 0x3E), 1) + 0x0C
                keyP["smallTemperature"] = bit.rshift(bit.band(messageBytes[1], 0x40), 6)
            end
        else
            keyP["temperature"] = bit.band(messageBytes[2], 0x0F) + 0x10
			keyP["smallTemperature"] = bit.rshift(bit.band(messageBytes[2], 0x10),4)
        end
        
        keyP["fanspeedValue"] = bit.band(messageBytes[3], 0x7F)

        if (bit.band(messageBytes[4], keyB["BYTE_START_TIMER_SWITCH_ON"]) == keyB["BYTE_START_TIMER_SWITCH_ON"]) then
            keyP["openTimerSwitch"] = keyB["BYTE_START_TIMER_SWITCH_ON"]
        else
           keyP["openTimerSwitch"] = keyB["BYTE_START_TIMER_SWITCH_OFF"]
        end

        if (bit.band(messageBytes[5], keyB["BYTE_CLOSE_TIMER_SWITCH_ON"]) == keyB["BYTE_CLOSE_TIMER_SWITCH_ON"]) then
            keyP["closeTimerSwitch"] = keyB["BYTE_CLOSE_TIMER_SWITCH_ON"]
        else
            keyP["closeTimerSwitch"] = keyB["BYTE_CLOSE_TIMER_SWITCH_OFF"]
        end

        keyP["closeHour"] = bit.rshift(bit.band(messageBytes[5], 0x7F), 2)
		
        keyP["closeStepMintues"] = bit.band(messageBytes[5], 0x03)
		
        keyP["closeMin"] = 15 - bit.band(messageBytes[6], 0x0f)
		
        keyP["closeTime"] = keyP["closeHour"] * 60 + keyP["closeStepMintues"] * 15 + keyP["closeMin"]

        keyP["openHour"] = bit.rshift(bit.band(messageBytes[4], 0x7F), 2)
		
        keyP["openStepMintues"] = bit.band(messageBytes[4], 0x03)
		
        keyP["openMin"] = 15 - bit.rshift(bit.band(messageBytes[6], 0xf0),4)
		
        keyP["openTime"] = keyP["openHour"] * 60 + keyP["openStepMintues"] * 15 + keyP["openMin"]

        keyP["strongWindValue"] = bit.band(messageBytes[8], 0x20)
        keyP["tubroValue"] = bit.band(messageBytes[10], 0x02)
		keyP["sleep_status"] = bit.band(messageBytes[10], 0x01)
		
		keyP["power_saving"] = bit.band(messageBytes[8], 0x08)
		
        keyP["comfortableSleepValue"] = bit.band(messageBytes[8], 0x03)
		
		keyP["comfortableSleepSwitch"] = bit.band(messageBytes[9], 0x40)
		
        keyP["pmv"] = bit.band(messageBytes[14], 0x0f) * 0.5 - 3.5
		keyP["comfortableSleepTime"] = bit.band(messageBytes[17], 0x15)
        keyP["naturalWind"] = bit.band(messageBytes[9], 0x02)
		
        keyP["PTCValue"] = bit.band(messageBytes[9], 0x18)
		
        keyP["purifierValue"] = bit.band(messageBytes[9], 0x20)
		
        keyP["ecoValue"] = bit.lshift(bit.band(messageBytes[9], 0x10), 3)
		
        keyP["dryValue"] = bit.band(messageBytes[9], 0x04)
				
        keyP["swingLRValue"] = bit.band(messageBytes[7], 0x03)
		
        keyP["swingUDValue"] = bit.band(messageBytes[7], 0x0C)
		
		keyP["fresh_filter_timeout_ae2"] = bit.rshift(bit.band(messageBytes[13], 0x20),5)
		
		if(#binData >= 21) then
			keyP["swingLRUnderSwitch"] = bit.band(messageBytes[19], 0x80)
			keyP["swingLRValueUnder"] = bit.band(messageBytes[20], 0x80)
		end

        if(dataType == 0x02 or dataType == 0x03) then
            --if ((messageBytes[11] ~= 0) and (messageBytes[11] ~= 0xFF)) then
                keyP["indoorTemperatureValue"] = (messageBytes[11] - 50) / 2
                keyP["smallIndoorTemperatureValue"]=bit.band(messageBytes[15],0xF);
            --end

            --if ((messageBytes[12] ~= 0) and (messageBytes[12] ~= 0xFF)) then
                keyP["outdoorTemperatureValue"]  = (messageBytes[12] - 50) / 2
                keyP["smallOutdoorTemperatureValue"]=bit.rshift(messageBytes[15],4);
				keyP["fresh_filter_timeout"] = bit.rshift(bit.band(messageBytes[13], 0x40),6)
            --end
        end

        keyP["errorCode"]=messageBytes[16]
		
		--温度单位
		if(dataType == 0x05) then
			keyP["temperature_unit"] = bit.rshift(bit.band(messageBytes[9], 0x80),7)
		else
			keyP["temperature_unit"] = bit.rshift(bit.band(messageBytes[10], 0x04),2)
		end
		
		
		--防着凉
		keyP["preventCold"] = bit.rshift(bit.band(messageBytes[10], 0x20),5)

		--温度(低于17度)
		if(dataType == 0x05) then
			local temp = bit.rshift(bit.band(messageBytes[12], 0x3E),1)
			if (temp > 0 and temp <= 25)  then 
				keyP["temperature"] = temp + 12
			elseif(temp == 0)then
			else
				keyP["temperature"] = temp - 19
			end
		else
			local temp = bit.band(messageBytes[13], 0x1F)
			if (temp > 0 and temp <= 25)  then 
				keyP["temperature"] = temp + 12 
			elseif(temp == 0)then
			else
				keyP["temperature"] = temp - 19
			end
		end

		--屏显状态
		keyP["screenDisplayNowValue"] = bit.rshift(bit.band(messageBytes[14], 0x70),4)
		--舒省
		if (messageBytes[0] == 0xA0) then
			keyP["comfortPowerSave"] = bit.band(messageBytes[14], 0x01)
		else
			if(#binData >= 24) then
				keyP["comfortPowerSave"] = bit.band(messageBytes[22], 0x01)
			end
			
		end
		
		if(#binData >= 23) then
			--8度制热
			keyP["degree8_heat"] = bit.rshift(bit.band(messageBytes[21], 0x80),7)
		end
		
		--单独电辅热
		if(dataType == 0x05) then
			keyP["independent_ptc"] = bit.rshift(bit.band(messageBytes[11], 0x08),3)
		else
			keyP["independent_ptc"] = bit.rshift(bit.band(messageBytes[8], 0x40),6)
		end

		--新风滤网
		if(#binData >= 29) then
			keyP["fresh_filter_time_total"] = messageBytes[25] * 256 + messageBytes[24] 
			keyP["fresh_filter_time_use"] = messageBytes[27] * 256 + messageBytes[26] 
		end
    end
    if ((dataType==0x04 and messageBytes[0] == 0xA1)) then
        --本次开机运行时间
		keyP["currentWorkTime"] = bit.bor((bit.band(bit.lshift(messageBytes[9],8), 0xFF00)),(bit.band(messageBytes[10], 0x00FF))) * 60 * 24 + messageBytes[11] * 60 + messageBytes[12] 
		--计算方式由空调事业部黑继伟提供
        if (messageBytes[13]~=0x00 and messageBytes[13]~=0xff) then
            keyP["indoorTemperatureValue"] = (messageBytes[13]-50)/2
            keyP["smallIndoorTemperatureValue"]=bit.band(messageBytes[18],0xF);
        end
        if (messageBytes[14]~=0x00 and messageBytes[14]~=0xff) then
            keyP["outdoorTemperatureValue"]  = (messageBytes[14]-50)/2
            keyP["smallOutdoorTemperatureValue"]=bit.rshift(messageBytes[18],4);
        end
    end
	
	if ((dataType==0xA0 and messageBytes[0] == 0x00)) then
		keyP["machine_type"] = messageBytes[3]
	end
	

    if ((dataType==0x02 and messageBytes[0] == 0xB0)  or (dataType==0x03 and messageBytes[0] == 0xB1)) then
        --新协议，变长属性协议
		if(#binData < 8) then
			return nil
		end
		keyP["propertyNumber"] = messageBytes[1]
		local cursor = 2
        for i = 1,  keyP["propertyNumber"] do
			if (messageBytes[cursor + 0] == 0x49 and messageBytes[cursor + 1] == 0x00) then
				keyP["prevent_super_cool"] = messageBytes[cursor + 4]
				cursor = cursor + 9
			end
			if (messageBytes[cursor + 0] == 0x42 and messageBytes[cursor + 1] == 0x00) then
				if(messageBytes[cursor + 4] ~= nil)then
					keyP["prevent_straight_wind"] = messageBytes[cursor + 4]
				end
				print(keyP["prevent_straight_wind"])
				cursor = cursor + 5
			end
			if (messageBytes[cursor + 0] == 0x26 and messageBytes[cursor + 1] == 0x02) then
				keyP["auto_prevent_straight_wind"] = messageBytes[cursor + 4]	
				cursor = cursor + 5
			end
			if (messageBytes[cursor + 0] == 0x39 and messageBytes[cursor + 1] == 0x00) then
				keyP["self_clean"] = messageBytes[cursor + 4]	
				cursor = cursor + 5
			end
			if (messageBytes[cursor + 0] == 0x32 and messageBytes[cursor + 1] == 0x00) then
			    if (messageBytes[cursor + 4] == 0x01) then 
					keyP["wind_straight"] = 0x01
				end
				if (messageBytes[cursor + 4] == 0x02) then 
					keyP["wind_avoid"] = 0x01
					keyP["yb_wind_avoid"] = 0x02
				end	
				if (messageBytes[cursor + 4] == 0x00) then 
					keyP["wind_straight"] = 0x00
					keyP["wind_avoid"] = 0x00
                    keyP["yb_wind_avoid"] = 0x00					
				end
				cursor = cursor + 5
			end
			if (messageBytes[cursor + 0] == 0x33 and messageBytes[cursor + 1] == 0x00) then
				keyP["wind_avoid"] = messageBytes[cursor + 4]	
				cursor = cursor + 5
			end
			if (messageBytes[cursor + 0] == 0x34 and messageBytes[cursor + 1] == 0x00) then
				keyP["intelligent_wind"] = messageBytes[cursor + 4]	
				cursor = cursor + 5
			end
			if (messageBytes[cursor + 0] == 0x3A and messageBytes[cursor + 1] == 0x00) then
				keyP["child_prevent_cold_wind"] = messageBytes[cursor + 4]	
				cursor = cursor + 5
			end
			if (messageBytes[cursor + 0] == 0x18 and messageBytes[cursor + 1] == 0x00) then			
				if (messageBytes[cursor + 3] == 0x02) then
					keyP["no_wind_sense_level"] = messageBytes[cursor + 5]
				    cursor = cursor + 6
				else
				    keyP["no_wind_sense"] = messageBytes[cursor + 4]
				    cursor = cursor + 5
				end
			end
			if (messageBytes[cursor + 0] == 0x1B and messageBytes[cursor + 1] == 0x02) then
				keyP["little_angel"] = messageBytes[cursor + 4]	
				cursor = cursor + 5
			end
			if (messageBytes[cursor + 0] == 0x21 and messageBytes[cursor + 1] == 0x00) then
				keyP["cool_hot_sense"] = messageBytes[cursor + 4]	
				cursor = cursor + 12
			end
			if (messageBytes[cursor + 0] == 0x29 and messageBytes[cursor + 1] == 0x00) then
				keyP["security"] = messageBytes[cursor + 4]
				if(messageBytes[cursor + 4] == 2) then
					keyP["security"] = 0
				end
				if(messageBytes[cursor + 4] == 3) then
					keyP["security"] = 1
				end
				cursor = cursor + 5
			end
			if (messageBytes[cursor + 0] == 0x4E and messageBytes[cursor + 1] == 0x00) then
				keyP["even_wind"] = messageBytes[cursor + 4]
				cursor = cursor + 5
			end
			if (messageBytes[cursor + 0] == 0x4F and messageBytes[cursor + 1] == 0x00) then
				keyP["single_tuyere"] = messageBytes[cursor + 4]
				cursor = cursor + 5
			end
			if (messageBytes[cursor + 0] == 0x4C and messageBytes[cursor + 1] == 0x00) then
				keyP["extreme_wind"] = messageBytes[cursor + 4]
				keyP["extreme_wind_level"] = messageBytes[cursor + 5]
				cursor = cursor + 6
			end
			if (messageBytes[cursor + 0] == 0x20 and messageBytes[cursor + 1] == 0x00) then
				keyP["voice_control"] = messageBytes[cursor + 4]
				keyP["voice_control_new"] = messageBytes[cursor + 4]
				cursor = cursor + 24
			end
			if (messageBytes[cursor + 0] == 0x01 and messageBytes[cursor + 1] == 0x02) then
				keyP["pre_cool_hot"] = messageBytes[cursor + 4]
				cursor = cursor + 5
			end
			if (messageBytes[cursor + 0] == 0x4A and messageBytes[cursor + 1] == 0x00) then
				keyP["water_washing_manual"] = messageBytes[cursor + 4]
				keyP["water_washing"] = messageBytes[cursor + 5]
				keyP["water_washing_time"] = messageBytes[cursor + 6]
				keyP["water_washing_stage"] = messageBytes[cursor + 7]
				cursor = cursor + 8
			end
			if (messageBytes[cursor + 0] == 0x4B and messageBytes[cursor + 1] == 0x00) then
				keyP["fresh_air"] = messageBytes[cursor + 4]
				keyP["fresh_air_fan_speed"] = messageBytes[cursor + 5]
				keyP["fresh_air_temp"] = messageBytes[cursor + 6]
				cursor = cursor + 7
			end
			if (messageBytes[cursor + 0] == 0x51 and messageBytes[cursor + 1] == 0x00) then
				keyP["parent_control"] = messageBytes[cursor + 4]
				keyP["parent_control_temp_up"] = messageBytes[cursor + 5]
				keyP["parent_control_temp_down"] = messageBytes[cursor + 6]
				cursor = cursor + 9
			end
			if (messageBytes[cursor + 0] == 0x43 and messageBytes[cursor + 1] == 0x00) then
				if (messageBytes[cursor + 4] == 0x01 or messageBytes[cursor + 4] == 0x00) then 
					keyP["gentle_wind_sense"] = 0x01
					keyP["prevent_straight_wind"] = 0x01
					keyP["fa_no_wind_sense"] = 0x01
				end
				if (messageBytes[cursor + 4] == 0x02) then 
					keyP["gentle_wind_sense"] = 0x01
					keyP["prevent_straight_wind"] = 0x02
					keyP["fa_no_wind_sense"] = 0x02
				end
				if (messageBytes[cursor + 4] == 0x03) then 
					keyP["gentle_wind_sense"] = 0x03
					keyP["prevent_straight_wind"] = 0x01
					keyP["fa_no_wind_sense"] = 0x03
				end
				if (messageBytes[cursor + 4] == 0x04) then 
					keyP["prevent_straight_wind"] = 0x01
					keyP["gentle_wind_sense"] = 0x01
					keyP["fa_no_wind_sense"] = 0x04
				end
				cursor = cursor + 5
			end
			if (messageBytes[cursor + 0] == 0x30 and messageBytes[cursor + 1] == 0x00) then
				keyP["nobody_energy_save"] = messageBytes[cursor + 4]
				cursor = cursor + 10
			end
			if (messageBytes[cursor + 0] == 0x09 and messageBytes[cursor + 1] == 0x04) then
				keyP["filter_level"] = messageBytes[cursor + 5]
				keyP["filter_value"] = messageBytes[cursor + 14]
				cursor = cursor + 17
			end
			if (messageBytes[cursor + 0] == 0x58 and messageBytes[cursor + 1] == 0x00) then
				keyP["prevent_straight_wind_lr"] = messageBytes[cursor + 4]
				keyP["prevent_straight_wind_select"] = messageBytes[cursor + 4]
				cursor = cursor + 5
			end
			if (messageBytes[cursor + 0] == 0x0B and messageBytes[cursor + 1] == 0x02) then
				keyP["pm25_value"] = messageBytes[cursor + 6] * 256 + messageBytes[cursor + 5]
				cursor = cursor + 7
			end
			if (messageBytes[cursor + 0] == 0x50 and messageBytes[cursor + 1] == 0x00) then
				keyP["water_pump"] = messageBytes[cursor + 4]
				cursor = cursor + 5
			end
			if (messageBytes[cursor + 0] == 0x31 and messageBytes[cursor + 1] == 0x00) then
				keyP["intelligent_control"] = messageBytes[cursor + 4]
				cursor = cursor + 5
			end
			if (messageBytes[cursor + 0] == 0x24 and messageBytes[cursor + 1] == 0x00) then
				keyP["volume_control"] = messageBytes[cursor + 5]
				cursor = cursor + 8
			end
			if (messageBytes[cursor + 0] == 0x09 and messageBytes[cursor + 1] == 0x00) then
				keyP["wind_swing_ud_angle"] = messageBytes[cursor + 4]
				cursor = cursor + 5
			end
			if (messageBytes[cursor + 0] == 0x0A and messageBytes[cursor + 1] == 0x00) then
				keyP["wind_swing_lr_angle"] = messageBytes[cursor + 4]
				cursor = cursor + 5
			end
			if (messageBytes[cursor + 0] == 0x44 and messageBytes[cursor + 1] == 0x00) then
				keyP["face_register"] = messageBytes[cursor + 4]
				cursor = cursor + 5
			end
			if (messageBytes[cursor + 0] == 0x1A and messageBytes[cursor + 1] == 0x00) then
				if(messageBytes[cursor + 3] == 0x00)then
					cursor = cursor + 4
				else
					cursor = cursor + 5
				end
				
			end
			if (messageBytes[cursor + 0] == 0x25 and messageBytes[cursor + 1] == 0x02) then
				keyP["cool_temp_down"] = messageBytes[cursor + 4]
				keyP["cool_temp_up"] = messageBytes[cursor + 5]
				keyP["auto_temp_down"] = messageBytes[cursor + 6]
				keyP["auto_temp_up"] = messageBytes[cursor + 7]
				keyP["heat_temp_down"] = messageBytes[cursor + 8]
				keyP["heat_temp_up"] = messageBytes[cursor + 9]
				cursor = cursor + 11
			end
			if (messageBytes[cursor + 0] == 0x27 and messageBytes[cursor + 1] == 0x02) then
				keyP["remote_control_lock"] = messageBytes[cursor + 4]
				keyP["remote_control_lock_control"] = messageBytes[cursor + 5]
				cursor = cursor + 6
			end
			if (messageBytes[cursor + 0] == 0x28 and messageBytes[cursor + 1] == 0x02) then
				keyP["operating_time"] = bit.bor(messageBytes[cursor + 4],bit.bor(bit.lshift(messageBytes[cursor + 5],8),bit.lshift(messageBytes[cursor + 6], 16)))
				cursor = cursor + 7
			end
			if (messageBytes[cursor + 0] == 0x15 and messageBytes[cursor + 1] == 0x00) then
				keyP["indoor_humidity"] =  messageBytes[cursor + 4]
				cursor = cursor + 5
			end
			if (messageBytes[cursor + 0] == 0x67 and messageBytes[cursor + 1] == 0x00) then
				keyP["jet_cool"] =  messageBytes[cursor + 4]
				cursor = cursor + 5
			end
			if (messageBytes[cursor + 0] == 0x34 and messageBytes[cursor + 1] == 0x02) then
				keyP["body_check"] =  messageBytes[cursor + 4]
				cursor = cursor + 5
			end
			if (messageBytes[cursor + 0] == 0x48 and messageBytes[cursor + 1] == 0x00) then
				keyP["rate_select"] =  messageBytes[cursor + 4]
				cursor = cursor + 5
			end
			if (messageBytes[cursor + 0] == 0x30 and messageBytes[cursor + 1] == 0x02) then
				keyP["main_horizontal_guide_strip_1"] =  messageBytes[cursor + 4]
				keyP["main_horizontal_guide_strip_2"] =  messageBytes[cursor + 5]
				keyP["main_horizontal_guide_strip_3"] =  messageBytes[cursor + 6]
				keyP["main_horizontal_guide_strip_4"] =  messageBytes[cursor + 7]
				cursor = cursor + 8
			end
			if (messageBytes[cursor + 0] == 0x31 and messageBytes[cursor + 1] == 0x02) then
				keyP["sup_horizontal_guide_strip_1"] =  messageBytes[cursor + 4]
				keyP["sup_horizontal_guide_strip_2"] =  messageBytes[cursor + 5]
				keyP["sup_horizontal_guide_strip_3"] =  messageBytes[cursor + 6]
				keyP["sup_horizontal_guide_strip_4"] =  messageBytes[cursor + 7]
				cursor = cursor + 8
			end
			if (messageBytes[cursor + 0] == 0x32 and messageBytes[cursor + 1] == 0x02) then
				keyP["twins_machine"] =  messageBytes[cursor + 4]
				cursor = cursor + 5
			end
			if (messageBytes[cursor + 0] == 0x33 and messageBytes[cursor + 1] == 0x02) then
				if(messageBytes[cursor + 3] == 0x00)then
					cursor = cursor + 4
				else
					keyP["guide_strip_type"] =  messageBytes[cursor + 4]
					cursor = cursor + 5
				end
			end
			if (messageBytes[cursor + 0] == 0x2C and messageBytes[cursor + 1] == 0x02) then
				keyP["sound"] =  messageBytes[cursor + 4]
				cursor = cursor + 5
			end
			if (messageBytes[cursor + 0] == 0x1E and messageBytes[cursor + 1] == 0x02) then
				keyP["anion"] =  messageBytes[cursor + 4]
				cursor = cursor + 5
			end
			if (messageBytes[cursor + 0] == 0xE3 and messageBytes[cursor + 1] == 0x00) then
				keyP["ieco_number"] =  messageBytes[cursor + 4]
				keyP["ieco_switch"] =  messageBytes[cursor + 5]
				--keyP["ieco_target_rate"] =  messageBytes[cursor + 6]
				--keyP["ieco_indoor_wind_speed"] =  messageBytes[cursor + 7]
				--keyP["ieco_outdoor_wind_speed"] =  bit.bor(messageBytes[cursor + 8],bit.bor(bit.lshift(messageBytes[cursor + 9],8)))
				--keyP["ieco_expansion_valve"] =  messageBytes[cursor + 10]
				cursor = cursor + 6
			end
			if (messageBytes[cursor + 0] == 0xE0 and messageBytes[cursor + 1] == 0x00) then
				keyP["ieco_frame"] =  messageBytes[cursor + 4]
				keyP["ieco_target_rate"] = bit.bor(messageBytes[cursor + 5],bit.bor(bit.lshift(messageBytes[cursor + 6],8)))
				keyP["ieco_indoor_wind_speed_level"] =  messageBytes[cursor + 7]
				keyP["ieco_indoor_wind_speed"] =  bit.bor(messageBytes[cursor + 8],bit.bor(bit.lshift(messageBytes[cursor + 9],8)))
				keyP["ieco_outdoor_wind_speed_level"] =  messageBytes[cursor + 10]
				keyP["ieco_outdoor_wind_speed"] =  bit.bor(messageBytes[cursor + 11],bit.bor(bit.lshift(messageBytes[cursor + 12],8)))
				keyP["ieco_expansion_valve"] =  messageBytes[cursor + 13]
				cursor = cursor + 14
			end
			if (messageBytes[cursor + 0] == 0x59 and messageBytes[cursor + 1] == 0x00) then
				keyP["wind_around"] = messageBytes[cursor + 4]
				keyP["wind_around_ud"] = messageBytes[cursor + 5]
				cursor = cursor + 6
			end
			if (messageBytes[cursor + 0] == 0x8D and messageBytes[cursor + 1] == 0x00) then
				keyP["mito_cool"] =  (messageBytes[cursor + 4] - 50) / 2
				cursor = cursor + 5
			end
			if (messageBytes[cursor + 0] == 0x8E and messageBytes[cursor + 1] == 0x00) then
				keyP["mito_heat"] =  (messageBytes[cursor + 4] - 50) / 2
				cursor = cursor + 5
			end
			if (messageBytes[cursor + 0] == 0x8F and messageBytes[cursor + 1] == 0x00) then
				keyP["dr_time_min"] = messageBytes[cursor + 4]
				keyP["dr_time_hour"] = messageBytes[cursor + 5]
				cursor = cursor + 6
			end
			if (messageBytes[cursor + 0] == 0x90 and messageBytes[cursor + 1] == 0x00) then
				keyP["has_cool_heat_amount"] = messageBytes[cursor + 4]
				keyP["t2_heat"] = messageBytes[cursor + 5]
				keyP["tp_heat"] = messageBytes[cursor + 6]
				keyP["k1_value"] = messageBytes[cursor + 7]
				keyP["k2_value"] = messageBytes[cursor + 8]
				keyP["k3_value"] = messageBytes[cursor + 9]
				keyP["k4_value"] = messageBytes[cursor + 10]
				keyP["cool_strong_wind_speed"] = bit.bor(messageBytes[cursor + 11],bit.bor(bit.lshift(messageBytes[cursor + 12],8)))
				keyP["cool_strong_wind_amount"] = bit.bor(messageBytes[cursor + 13],bit.bor(bit.lshift(messageBytes[cursor + 14],8)))
				cursor = cursor + 15
			end
			if (messageBytes[cursor + 0] == 0x91 and messageBytes[cursor + 1] == 0x00) then
				keyP["has_icheck"] = messageBytes[cursor + 4]
				cursor = cursor + 5
			end
			if (messageBytes[cursor + 0] == 0x98 and messageBytes[cursor + 1] == 0x00) then
				keyP["cvp"] = messageBytes[cursor + 4]
				cursor = cursor + 5
			end
			
        end
	end
	
	if(messageBytes[0] == 0xC1) then
	

		if(messageBytes[3] == 0x44) then
			
			keyP["real_time_power_10"] = (bcd2Int(messageBytes[16]) + bcd2Int(messageBytes[17])/100 + bcd2Int(messageBytes[18])/10000)*10000
			
			--keyP["real_time_power_10"] = tonumber((messageBytes[16] + messageBytes[17]/100 + messageBytes[18]/10000),10)
			
			keyP["real_time_power"] = bit.bor(bit.bor(bit.lshift(messageBytes[16],16),bit.lshift(messageBytes[17],8)),messageBytes[18]) 
			
			--keyP["real_time_power_10"] = bit.bor(bit.bor(bit.lshift(tonumber(messageBytes[16],16),16),bit.lshift(tonumber(messageBytes[17],16),8)),tonumber(messageBytes[18],16))
			
			
		
		
		end
		
		if(bit.band(messageBytes[3],0x0F) == 0x05) then
			keyP["current_humidity"] = messageBytes[4]
		end
	
	end
	if ((dataType==0x05 and messageBytes[0] == 0xB5)) then
		keyP["propertyNumber"] = messageBytes[1]
		local cursor = 1
		for i = 1,  keyP["propertyNumber"] do
			if (messageBytes[cursor + 1] == 0x7E and messageBytes[cursor + 2] == 0x00) then
				keyP["propertyNumber"] = 0
				keyP["powerValue"] = bit.band(messageBytes[cursor + 5], 0x01)
				keyP["modeValue"] = bit.band(messageBytes[cursor + 6], 0xE0)
				
				if(dataType==0x05) then
					--CA机型 11447、11451、11453、11455、11457、11459、11525、11527、11533、11535
					if deviceSN8=="11447" or deviceSN8=="11451" or deviceSN8=="11453" or deviceSN8=="11455" or deviceSN8=="11457" or deviceSN8=="11459" or deviceSN8=="11525" or deviceSN8=="11527" or deviceSN8=="11533" or deviceSN8=="11535" then
						keyP["temperature"] = bit.rshift(bit.band(messageBytes[cursor + 5], 0x7C), 2) + 0x0C
						keyP["smallTemperature"] = bit.rshift(bit.band(messageBytes[cursor + 5], 0x02), 1)
					else
						keyP["temperature"] = bit.rshift(bit.band(messageBytes[cursor + 5], 0x3E), 1) + 0x0C
						keyP["smallTemperature"] = bit.rshift(bit.band(messageBytes[cursor + 5], 0x40), 6)
					end
				end
				
				keyP["fanspeedValue"] = bit.band(messageBytes[cursor + 7], 0x7F)

				if (bit.band(messageBytes[cursor + 8], keyB["BYTE_START_TIMER_SWITCH_ON"]) == keyB["BYTE_START_TIMER_SWITCH_ON"]) then
					keyP["openTimerSwitch"] = keyB["BYTE_START_TIMER_SWITCH_ON"]
				else
				   keyP["openTimerSwitch"] = keyB["BYTE_START_TIMER_SWITCH_OFF"]
				end

				if (bit.band(messageBytes[cursor + 9], keyB["BYTE_CLOSE_TIMER_SWITCH_ON"]) == keyB["BYTE_CLOSE_TIMER_SWITCH_ON"]) then
					keyP["closeTimerSwitch"] = keyB["BYTE_CLOSE_TIMER_SWITCH_ON"]
				else
					keyP["closeTimerSwitch"] = keyB["BYTE_CLOSE_TIMER_SWITCH_OFF"]
				end

				keyP["closeHour"] = bit.rshift(bit.band(messageBytes[cursor + 9], 0x7F), 2)
				
				keyP["closeStepMintues"] = bit.band(messageBytes[cursor + 9], 0x03)
				
				keyP["closeMin"] = 15 - bit.band(messageBytes[cursor + 10], 0x0f)
				
				keyP["closeTime"] = keyP["closeHour"] * 60 + keyP["closeStepMintues"] * 15 + keyP["closeMin"]

				keyP["openHour"] = bit.rshift(bit.band(messageBytes[cursor + 8], 0x7F), 2)
				
				keyP["openStepMintues"] = bit.band(messageBytes[cursor + 8], 0x03)
				
				keyP["openMin"] = 15 - bit.rshift(bit.band(messageBytes[cursor + 10], 0xf0),4)
				
				keyP["openTime"] = keyP["openHour"] * 60 + keyP["openStepMintues"] * 15 + keyP["openMin"]

				keyP["strongWindValue"] = bit.band(messageBytes[cursor + 12], 0x20)
				
				keyP["power_saving"] = bit.band(messageBytes[cursor + 12], 0x08)
				
				keyP["comfortableSleepValue"] = bit.band(messageBytes[cursor + 12], 0x03)
				
				keyP["comfortableSleepSwitch"] = bit.band(messageBytes[cursor + 12], 0x40)
				
				if(dataType==0x05) then
					keyP["comfortableSleepSwitch"] = bit.band(messageBytes[cursor + 18], 0x01)
					keyP["naturalWind"] = bit.band(messageBytes[cursor + 14], 0x40)
					keyP["screenDisplayNowValue"] = bit.band(messageBytes[cursor + 15], 0x07)
					keyP["pmv"] = bit.rshift(bit.band(messageBytes[cursor + 15], 0xF0),4)* 0.5 - 3.5
					keyP["swingLRValueUnder"] = bit.band(messageBytes[cursor + 13], 0x40)
				end
				
				keyP["PTCValue"] = bit.band(messageBytes[cursor + 13], 0x08)
				
				keyP["purifierValue"] = bit.band(messageBytes[cursor + 13], 0x20)
				keyP["inner_purifier"] = bit.rshift(bit.band(messageBytes[cursor + 13], 0x20),5)
				
				keyP["ecoValue"] = bit.lshift(bit.band(messageBytes[cursor + 13], 0x10), 3)
				
				keyP["dryValue"] = bit.band(messageBytes[cursor + 13], 0x04)
				
				
				keyP["swingLRValue"] = bit.band(messageBytes[cursor + 11], 0x03)
			
				
				keyP["wind_swing_lr_right"] = bit.band(messageBytes[cursor + 11], 0x01)
				keyP["wind_swing_lr_left"] = bit.band(messageBytes[cursor + 11], 0x02)
				
				keyP["swingUDValue"] = bit.band(messageBytes[cursor + 11], 0x0C)
				
				keyP["wind_swing_ud_right"] = bit.band(messageBytes[cursor + 11], 0x04)
				
				keyP["wind_swing_ud_left"] = bit.band(messageBytes[cursor + 11], 0x08)
				
				
				keyP["swingLRUnderSwitch"] = bit.band(messageBytes[cursor + 23], 0x80)	
				keyP["errorCode"]=messageBytes[cursor + 20]
				
				
				
				--是否踢被子
				keyP["kickQuilt"] = bit.rshift(bit.band(messageBytes[cursor + 14], 0x04),2)
				
				--防着凉
				keyP["preventCold"] = bit.rshift(bit.band(messageBytes[cursor + 14], 0x08),3)
			
				--温度(低于17度)
				local temp = bit.rshift(bit.band(messageBytes[cursor + 16], 0x3E),1)
				if (temp > 0 and temp <= 25)  then 
					keyP["temperature"] = temp + 12 
				end
				if(messageBytes[cursor + 4] == 0xA0) then
					keyP["arom_old"] = bit.rshift(bit.band(messageBytes[cursor + 25], 0x80),7)

				end

				--舒省
				keyP["comfortPowerSave"] = bit.band(messageBytes[cursor + 18], 0x01)
				
				
				keyP["rewarming_dry"] = bit.rshift(bit.band(messageBytes[cursor + 27], 0x02),1)		   
				
				if(#binData >= 24) then
					keyP["wind_speed_right"] = bit.band(messageBytes[cursor + 28], 0x7F)
					
				end
				
				
				if(#binData >= 26) then
					keyP["indoor_co2"] = bit.bor(bit.lshift(messageBytes[cursor + 30], 8), messageBytes[cursor + 29])
					keyP["whirl_wind_right"] = bit.rshift(bit.band(messageBytes[cursor + 31], 0x08),3)
					keyP["whirl_wind_left"] = bit.rshift(bit.band(messageBytes[cursor + 31], 0x04),2)
					
					
					
				end	
				keyP["self_clean"] = bit.rshift(bit.band(messageBytes[cursor + 12],0x04),2)
				keyP["prevent_super_cool"] = bit.rshift(bit.band(messageBytes[cursor + 22],0x40),6)
				keyP["no_wind_sense_left"] = bit.band(messageBytes[cursor + 31], 0x01) + 1
				keyP["no_wind_sense_right"] = bit.rshift(bit.band(messageBytes[cursor + 31], 0x02),1) + 1
				keyP["moisturizing"] = bit.rshift(bit.band(messageBytes[cursor + 31], 0x80),7)
				keyP["linkage"] = bit.rshift(bit.band(messageBytes[cursor + 31], 0x20),5)
				keyP["linkage_sync"] = bit.rshift(bit.band(messageBytes[cursor + 31], 0x40),6)
				keyP["no_wind_sense"] = bit.rshift(bit.band(messageBytes[cursor + 18],0x08),3)
				keyP["prevent_straight_wind"] = bit.rshift(bit.band(messageBytes[cursor + 18],0x40),6)
				
				
				keyP["wind_swing_ud_angle"] = bit.band(messageBytes[cursor + 21],0x0F)
				keyP["degerming"] = bit.rshift(bit.band(messageBytes[cursor + 23], 0x02),1)
				
				
				
				if(messageBytes[cursor + 3] >= 33) then
					keyP["fresh_air_mode"] = bit.band(messageBytes[cursor + 37],0x0F)
					keyP["fresh_air_mode_two"] = bit.rshift(bit.band(messageBytes[cursor + 37],0x30),4)
					keyP["inner_purifier_mode"] = bit.rshift(bit.band(messageBytes[cursor + 37],0x40),6)
					keyP["moisturizing_fan_speed"] = messageBytes[cursor + 36]
					keyP["fresh_air_fan_speed"] = messageBytes[cursor + 38]
					keyP["inner_purifier_fan_speed"] = messageBytes[cursor + 39]
					keyP["indoor_humidity"] = messageBytes[cursor + 40]
					keyP["five_dimension_mode"] = bit.band(messageBytes[cursor + 41],0x03)
					keyP["total_status_switch"] = bit.rshift(bit.band(messageBytes[cursor + 41],0x04),2)
					keyP["wind_no_linkage"] = bit.rshift(bit.band(messageBytes[cursor + 41],0x10),4)
				end
				keyP["ieco_switch"] = bit.rshift(bit.band(messageBytes[cursor + 45], 0x10), 4)
				keyP["linkage_fan_speed"] = bit.band(messageBytes[cursor + 42],0x7F)
				keyP["indoorTemperatureValue"] = messageBytes[cursor + 44]
				keyP["smallIndoorTemperatureValue"] = bit.band(messageBytes[cursor + 45],0x0F)
				

				keyP["fresh_air"] = bit.rshift(bit.band(messageBytes[cursor + 22],0x80),7)
				keyP["ptc_default_rule"] = bit.rshift(bit.band(messageBytes[cursor + 27], 0x20),5)
				keyP["light_sensitive"] = bit.rshift(bit.band(messageBytes[cursor + 27], 0xC0),6)

				--新风滤网
				if(#binData >= 29) then
					keyP["fresh_filter_time_total"] = messageBytes[cursor + 29] * 256 + messageBytes[cursor + 28] 
					keyP["fresh_filter_time_use"] = messageBytes[cursor + 31] * 256 + messageBytes[cursor + 30] 
					keyP["fresh_filter_timeout"] = bit.rshift(bit.band(messageBytes[cursor + 17], 0x40),6)
					
				end
				keyP["fresh_filter_time_use"] = messageBytes[cursor + 20] * 256 + messageBytes[cursor + 19]
				
				
				cursor = cursor + 42
			end
		end
	end
    if ((dataType==0x03 and messageBytes[0] == 0xB5)) then
        --新协议，变长属性协议
		if(#binData < 4) then
			return nil
		end
		keyP["propertyNumber"] = messageBytes[1]
		local cursor = 2
        for i = 1,  keyP["propertyNumber"] do
			
			if (messageBytes[cursor + 0] == 0x14 and messageBytes[cursor + 1] == 0x02) then
				keyP["b5_mode"] = messageBytes[cursor + 3]
				cursor = cursor + 4
			end
			if (messageBytes[cursor + 0] == 0x1a and messageBytes[cursor + 1] == 0x02) then
				keyP["b5_strong_wind"] = messageBytes[cursor + 3]
				cursor = cursor + 4
			end
			if (messageBytes[cursor + 0] == 0x10 and messageBytes[cursor + 1] == 0x02) then
				keyP["b5_wind_speed"] = messageBytes[cursor + 3]	
				cursor = cursor + 4
			end
			if (messageBytes[cursor + 0] == 0x1f and messageBytes[cursor + 1] == 0x02) then
				keyP["b5_humidity"] = messageBytes[cursor + 3]
				cursor = cursor + 4
			end
			if (messageBytes[cursor + 0] == 0x25 and messageBytes[cursor + 1] == 0x02) then
				keyP["b5_temperature_0"] = messageBytes[cursor + 3]	
				keyP["b5_temperature_1"] = messageBytes[cursor + 4]	
				keyP["b5_temperature_2"] = messageBytes[cursor + 5]	
				keyP["b5_temperature_3"] = messageBytes[cursor + 6]	
				keyP["b5_temperature_4"] = messageBytes[cursor + 7]	
				keyP["b5_temperature_5"] = messageBytes[cursor + 8]	
				keyP["b5_temperature_6"] = messageBytes[cursor + 9]	
				cursor = cursor + 10
			end
			if (messageBytes[cursor + 0] == 0x12 and messageBytes[cursor + 1] == 0x02) then
				keyP["b5_eco"] = messageBytes[cursor + 3]	
				cursor = cursor + 4
			end
			if (messageBytes[cursor + 0] == 0x17 and messageBytes[cursor + 1] == 0x02) then
				keyP["b5_filter_remind"] = messageBytes[cursor + 3]	
				cursor = cursor + 4
			end
			if (messageBytes[cursor + 0] == 0x21 and messageBytes[cursor + 1] == 0x02) then
				keyP["b5_filter_check"] = messageBytes[cursor + 3]	
				cursor = cursor + 4
			end
			if (messageBytes[cursor + 0] == 0x22 and messageBytes[cursor + 1] == 0x02) then
				keyP["b5_fahrenheit"] = messageBytes[cursor + 3]	
				cursor = cursor + 4
			end
			if (messageBytes[cursor + 0] == 0x13 and messageBytes[cursor + 1] == 0x02) then
				keyP["b5_8_heat"] = messageBytes[cursor + 3]	
				cursor = cursor + 4
			end
			if (messageBytes[cursor + 0] == 0x16 and messageBytes[cursor + 1] == 0x02) then
				keyP["b5_electricity"] = messageBytes[cursor + 3]	
				cursor = cursor + 4
			end
			if (messageBytes[cursor + 0] == 0x19 and messageBytes[cursor + 1] == 0x02) then
				keyP["b5_ptc"] = messageBytes[cursor + 3]	
				cursor = cursor + 4
			end
			if (messageBytes[cursor + 0] == 0x32 and messageBytes[cursor + 1] == 0x00) then
				keyP["b5_wind_straight"] = messageBytes[cursor + 3]	
				cursor = cursor + 4
			end
			if (messageBytes[cursor + 0] == 0x33 and messageBytes[cursor + 1] == 0x00) then
				keyP["b5_wind_avoid"] = messageBytes[cursor + 3]	
				cursor = cursor + 4
			end
			if (messageBytes[cursor + 0] == 0x15 and messageBytes[cursor + 1] == 0x02) then
				keyP["b5_wind_swing"] = messageBytes[cursor + 3]	
				cursor = cursor + 4
			end
			if (messageBytes[cursor + 0] == 0x18 and messageBytes[cursor + 1] == 0x00) then
				keyP["b5_no_wind_sense"] = messageBytes[cursor + 3]	
				cursor = cursor + 4
			end
			if (messageBytes[cursor + 0] == 0x24 and messageBytes[cursor + 1] == 0x02) then
				keyP["b5_screen_display"] = messageBytes[cursor + 3]	
				cursor = cursor + 4
			end
			if (messageBytes[cursor + 0] == 0x1e and messageBytes[cursor + 1] == 0x02) then
				keyP["b5_anion"] = messageBytes[cursor + 3]	
				cursor = cursor + 4
			end
			if (messageBytes[cursor + 0] == 0x39 and messageBytes[cursor + 1] == 0x00) then
				keyP["b5_self_clean"] = messageBytes[cursor + 3]	
				cursor = cursor + 4
			end
			
			if (messageBytes[cursor + 0] == 0x30 and messageBytes[cursor + 1] == 0x00) then
				keyP["b5_nobody_energy_save"] = messageBytes[cursor + 3]	
				cursor = cursor + 4
			end
			if (messageBytes[cursor + 0] == 0x42 and messageBytes[cursor + 1] == 0x00) then
				keyP["b5_prevent_straight_wind"] = messageBytes[cursor + 3]
				cursor = cursor + 4
			end
			if (messageBytes[cursor + 0] == 0x67 and messageBytes[cursor + 1] == 0x00) then
				keyP["b5_jet_cool"] = messageBytes[cursor + 3]				
				cursor = cursor + 4
			end
			if (messageBytes[cursor + 0] == 0x34 and messageBytes[cursor + 1] == 0x02) then
				keyP["b5_body_check"] = messageBytes[cursor + 3]	
				cursor = cursor + 4
			end
			if (messageBytes[cursor + 0] == 0x48 and messageBytes[cursor + 1] == 0x00) then
				keyP["b5_rate_select"] = messageBytes[cursor + 3]	
				cursor = cursor + 4
			end
			if (messageBytes[cursor + 0] == 0x43 and messageBytes[cursor + 1] == 0x00) then
				if(messageBytes[cursor + 3]	== 1)then
					keyP["b5_prevent_straight_wind"] = messageBytes[cursor + 3]	
					keyP["b5_fa_no_wind_sense"] = messageBytes[cursor + 3]
					keyP["prevent_straight_wind_flag"] = 43
				end
				cursor = cursor + 4
			end
			if (messageBytes[cursor + 0] == 0x09 and messageBytes[cursor + 1] == 0x00) then	
				keyP["b5_wind_swing_ud_angle"] = messageBytes[cursor + 3]
				cursor = cursor + 4
			end
			if (messageBytes[cursor + 0] == 0x4B and messageBytes[cursor + 1] == 0x00) then
				keyP["b5_fresh_air"] =  messageBytes[cursor + 3]
				cursor = cursor + 4
			end
			if (messageBytes[cursor + 0] == 0x0A and messageBytes[cursor + 1] == 0x00) then
				keyP["b5_wind_swing_lr_angle"] = messageBytes[cursor + 3]
				cursor = cursor + 4
			end
			if (messageBytes[cursor + 0] == 0x30 and messageBytes[cursor + 1] == 0x02) then
				keyP["b5_main_horizontal_guide_strip_1"] =  messageBytes[cursor + 3]
				keyP["b5_main_horizontal_guide_strip_2"] =  messageBytes[cursor + 4]
				keyP["b5_main_horizontal_guide_strip_3"] =  messageBytes[cursor + 5]
				keyP["b5_main_horizontal_guide_strip_4"] =  messageBytes[cursor + 6]
				cursor = cursor + 7
			end
			if (messageBytes[cursor + 0] == 0x31 and messageBytes[cursor + 1] == 0x02) then
				keyP["b5_sup_horizontal_guide_strip_1"] =  messageBytes[cursor + 3]
				keyP["b5_sup_horizontal_guide_strip_2"] =  messageBytes[cursor + 4]
				keyP["b5_sup_horizontal_guide_strip_3"] =  messageBytes[cursor + 5]
				keyP["b5_sup_horizontal_guide_strip_4"] =  messageBytes[cursor + 6]
				cursor = cursor + 7
			end
			if (messageBytes[cursor + 0] == 0x32 and messageBytes[cursor + 1] == 0x02) then
				keyP["b5_twins_machine"] =  messageBytes[cursor + 3]
				cursor = cursor + 4
			end
			if (messageBytes[cursor + 0] == 0x33 and messageBytes[cursor + 1] == 0x02) then
				keyP["b5_guide_strip_type"] =  messageBytes[cursor + 3]
				cursor = cursor + 4
			end
			if (messageBytes[cursor + 0] == 0x2C and messageBytes[cursor + 1] == 0x02) then
				keyP["b5_sound"] =  messageBytes[cursor + 3]
				cursor = cursor + 4
			end
			if (messageBytes[cursor + 0] == 0x1E and messageBytes[cursor + 1] == 0x02) then
				keyP["b5_anion"] = messageBytes[cursor + 3]
				cursor = cursor + 4
			end
			
			if (messageBytes[cursor + 0] == 0x59 and messageBytes[cursor + 1] == 0x00) then
				keyP["b5_wind_around"] = messageBytes[cursor + 3]
				cursor = cursor + 4
			end
			if (messageBytes[cursor + 0] == 0x51 and messageBytes[cursor + 1] == 0x00) then
				keyP["b5_parent_control"] = messageBytes[cursor + 3]
				cursor = cursor + 4
			end
			if (messageBytes[cursor + 0] == 0x58 and messageBytes[cursor + 1] == 0x00) then
				keyP["b5_prevent_straight_wind_select"] = messageBytes[cursor + 3]
				cursor = cursor + 4
			end
			if (messageBytes[cursor + 0] == 0xE3 and messageBytes[cursor + 1] == 0x00) then
				keyP["b5_ieco_switch"] = messageBytes[cursor + 3]
				cursor = cursor + 4
			end
			if (messageBytes[cursor + 0] == 0x91 and messageBytes[cursor + 1] == 0x00) then
				keyP["b5_has_icheck"] = messageBytes[cursor + 3]
				cursor = cursor + 4
			end
			if (messageBytes[cursor + 0] == 0x93 and messageBytes[cursor + 1] == 0x00) then
				keyP["b5_emergent_heat_wind"] = messageBytes[cursor + 3]
				cursor = cursor + 4
			end
			if (messageBytes[cursor + 0] == 0x94 and messageBytes[cursor + 1] == 0x00) then
				keyP["b5_heat_ptc_wind"] = messageBytes[cursor + 3]
				cursor = cursor + 4
			end
			if (messageBytes[cursor + 0] == 0x98 and messageBytes[cursor + 1] == 0x00) then
				keyP["b5_cvp"] = messageBytes[cursor + 3]
				cursor = cursor + 4
			end
		end
    end
end

local function  getTotalMsg(bodyData,cType)
    local bodyLength = #bodyData 
	
    local msgLength = bodyLength + keyB["BYTE_PROTOCOL_LENGTH"] + 1
	
    local msgBytes = {}
	
    for i = 0, msgLength do
        msgBytes[i] = 0
    end
     
    --构造消息部分
    msgBytes[0] = keyB["BYTE_PROTOCOL_HEAD"]
	
    msgBytes[1] = bodyLength + keyB["BYTE_PROTOCOL_LENGTH"] + 1
	
    msgBytes[2] = keyB["BYTE_DEVICE_TYPE"]
	
    if (keyP["propertyNumber"] > 0) then
		msgBytes[8] = 0x02
	end
    msgBytes[9] = cType
	
    -- body
    for i = 0, bodyLength do
        msgBytes[i + keyB["BYTE_PROTOCOL_LENGTH"]] = bodyData[i]
    end
        
    msgBytes[msgLength] = makeSum(msgBytes, 1, msgLength - 1)

    local msgFinal = {}
    
    for i = 1, msgLength + 1  do
        msgFinal[i] = msgBytes[i - 1]
    end
    return msgFinal
end

--json转二进制，可传入原状态
function jsonToData(jsonCmd)
    if (#jsonCmd == 0) then
        return nil
    end
    
    local infoM = {}
    local bodyBytes = {}
	local prevent_temp = 0
    
    local json = decode(jsonCmd)
    deviceSubType = json["deviceinfo"]["deviceSubType"]
    local deviceSN=json["deviceinfo"]["deviceSN"]
    if deviceSN~=nil then
        deviceSN8=string.sub(deviceSN,13,17)
    end

    local query = json["query"]
    local control = json["control"]
    local status = json["status"]
    
    --当前是查询指令，构造固定的二进制即可
    if (query) then
        --构造消息 body 部分
        local queryType = nil
        if (type(query) == "table") then
            queryType = query["query_type"]
        end
        if (queryType == nil) then
            for i = 0, 21 do
                bodyBytes[i] = 0
            end

            bodyBytes[0] = 0x41

            bodyBytes[1] = 0x81

            bodyBytes[3] = 0xFF

            math.randomseed(tostring(os.time()*#bodyBytes):reverse():sub(1, 7))
            math.random()
            bodyBytes[20] = math.random(1, 254)

            bodyBytes[21] = crc8_854(bodyBytes, 0, 20)

            infoM = getTotalMsg(bodyBytes,keyB["BYTE_QUERYL_REQUEST"])
        elseif (queryType == "power"
                or queryType == "purifier"
                or queryType == "mode"
                or queryType == "temperature"
                or queryType == "small_temperature"
                or queryType == "buzzer"
                or queryType == "wind_swing_lr"
                or queryType == "wind_swing_lr_under"
                or queryType == "wind_swing_ud"
                or queryType == "wind_speed"
                or queryType == "power_on_timer"
                or queryType == "power_off_timer"
                or queryType == "power_on_time_value"
                or queryType == "power_off_time_value"
                or queryType == "indoor_temperature"
                or queryType == "outdoor_temperature"
                or queryType == "eco"
                or queryType == "kick_quilt"
                or queryType == "prevent_cold"
                or queryType == "dry"
                or queryType == "ptc"
                or queryType == "screen_display"
                or queryType == "screen_display_now"
                or queryType == "strong_wind"
                or queryType == "tubro"
                or queryType == "current_work_time"
                or queryType == "comfort_power_save"
				or queryType == "comfort_sleep"
				or queryType == "natural_wind"
				or queryType == "power_saving"
				or queryType == "fresh_filter_time_total"
				or queryType == "fresh_filter_time_use"
				or queryType == "fresh_filter_timeout"
				or queryType == "fresh_filter_timeout_ae2"
				or queryType == "independent_ptc"
        ) then
            for i = 0, 21 do
                bodyBytes[i] = 0
            end

            bodyBytes[0] = 0x41

            bodyBytes[1] = 0x81

            bodyBytes[3] = 0xFF

            math.randomseed(tostring(os.time()*#bodyBytes):reverse():sub(1, 7))
            math.random()
            bodyBytes[20] = math.random(1, 254)

            bodyBytes[21] = crc8_854(bodyBytes, 0, 20)

            infoM = getTotalMsg(bodyBytes,keyB["BYTE_QUERYL_REQUEST"])
		elseif (queryType == "a0_query") then
			--for i = 0, 21 do
                --bodyBytes[i] = 0
            --end
			--infoM = getTotalMsg(bodyBytes,0xa0)
			infoM[1] = 0xaa
            infoM[2] = 0x0a
            infoM[3] = 0xac
            infoM[4] = 0x00
            infoM[5] = 0x00
            infoM[6] = 0x00
            infoM[7] = 0x00
            infoM[8] = 0x00
            infoM[9] = 0x03
            infoM[10] = 0xa0
            infoM[11] = 0xa7
        elseif (queryType == "all_first_frame") then
            infoM[1] = 0xaa
            infoM[2] = 0x0e
            infoM[3] = 0xac
            infoM[4] = 0x00
            infoM[5] = 0x00
            infoM[6] = 0x00
            infoM[7] = 0x00
            infoM[8] = 0x00
            infoM[9] = 0x03
            infoM[10] = 0x03
            infoM[11] = 0xb5
            infoM[12] = 0x01
            infoM[13] = 0x00
            --infoM[14] = 0x4d
			infoM[14] = crc8_854(infoM, 11, 13)
            infoM[15] = 0x3d
			--infoM[15] = crc8_854(infoM, 11, 14)
        elseif (queryType == "all_second_frame") then
            infoM[1] = 0xaa
            infoM[2] = 0x0f
            infoM[3] = 0xac
            infoM[4] = 0x00
            infoM[5] = 0x00
            infoM[6] = 0x00
            infoM[7] = 0x00
            infoM[8] = 0x00
            infoM[9] = 0x03
            infoM[10] = 0x03
            infoM[11] = 0xb5
            infoM[12] = 0x01
            infoM[13] = 0x01
            infoM[14] = 0x01
            infoM[15] = 0x21
            infoM[16] = 0x66
		elseif (queryType == "group_data_four") then
            for i = 0, 21 do
                bodyBytes[i] = 0
            end

            bodyBytes[0] = 0x41

            bodyBytes[1] = 0x21

            bodyBytes[2] = 0x01
			
			bodyBytes[3] = 0x44
			
            math.randomseed(tostring(os.time()*#bodyBytes):reverse():sub(1, 7))
            math.random()
            bodyBytes[20] = math.random(1, 254)

            bodyBytes[21] = crc8_854(bodyBytes, 0, 20)

            infoM = getTotalMsg(bodyBytes,keyB["BYTE_QUERYL_REQUEST"])
		elseif (queryType == "group_data_five") then
            for i = 0, 21 do
                bodyBytes[i] = 0
            end

            bodyBytes[0] = 0x41

            bodyBytes[1] = 0x21

            bodyBytes[2] = 0x01
			
			bodyBytes[3] = 0x45
			
            math.randomseed(tostring(os.time()*#bodyBytes):reverse():sub(1, 7))
            math.random()
            bodyBytes[20] = math.random(1, 254)

            bodyBytes[21] = crc8_854(bodyBytes, 0, 20)

            infoM = getTotalMsg(bodyBytes,keyB["BYTE_QUERYL_REQUEST"])
        else
            bodyBytes[0] = 0xB1
            local propertyNum = 0

			local queryList = {}
            if (string.match(queryType,",")==",") then
				queryList  = splitStrByChar(queryType,",")
			else
				table.insert(queryList, queryType)
			end

			for v in values(queryList) do
				queryType = v
				if (queryType == "no_wind_sense") then
					bodyBytes[1 + propertyNum * 2 + 1] = 0x18
					bodyBytes[1 + propertyNum * 2 + 2] = 0x00
					propertyNum = propertyNum + 1
				end
				
				if (queryType == "fa_no_wind_sense") then
				    bodyBytes[1 + propertyNum * 2 + 1] = 0x43
					bodyBytes[1 + propertyNum * 2 + 2] = 0x00
					propertyNum = propertyNum + 1
				end
				if (queryType == "cool_hot_sense") then
					bodyBytes[1 + propertyNum * 2 + 1] = 0x21
					bodyBytes[1 + propertyNum * 2 + 2] = 0x00
					propertyNum = propertyNum + 1
				end
				if (queryType == "nobody_energy_save") then
					bodyBytes[1 + propertyNum * 2 + 1] = 0x30
					bodyBytes[1 + propertyNum * 2 + 2] = 0x00
					propertyNum = propertyNum + 1
				end
				if (queryType == "self_clean") then
					bodyBytes[1 + propertyNum * 2 + 1] = 0x39
					bodyBytes[1 + propertyNum * 2 + 2] = 0x00
					propertyNum = propertyNum + 1
				end
				if (queryType == "child_prevent_cold_wind") then
					bodyBytes[1 + propertyNum * 2 + 1] = 0x3A
					bodyBytes[1 + propertyNum * 2 + 2] = 0x00
					propertyNum = propertyNum + 1
				end
				if (queryType == "error_code_query") then
					bodyBytes[1 + propertyNum * 2 + 1] = 0x3F
					bodyBytes[1 + propertyNum * 2 + 2] = 0x00
					propertyNum = propertyNum + 1
				end
				if (queryType == "mode_query") then
					bodyBytes[1 + propertyNum * 2 + 1] = 0x41
					bodyBytes[1 + propertyNum * 2 + 2] = 0x00
					propertyNum = propertyNum + 1
				end
				if (queryType == "prevent_straight_wind") then
					if(prevent_temp == 0) then
						prevent_temp = 1
					end
				end
				if (queryType == "prevent_straight_wind_flag") then
					bodyBytes[1 + propertyNum * 2 + 1] = 0x43
					bodyBytes[1 + propertyNum * 2 + 2] = 0x00
					propertyNum = propertyNum + 1
					prevent_temp = 2
				end
				if (queryType == "prevent_super_cool") then
					bodyBytes[1 + propertyNum * 2 + 1] = 0x49
					bodyBytes[1 + propertyNum * 2 + 2] = 0x00
					propertyNum = propertyNum + 1
				end
				if (queryType == "high_temperature_monitor") then
					bodyBytes[1 + propertyNum * 2 + 1] = 0x47
					bodyBytes[1 + propertyNum * 2 + 2] = 0x00
					propertyNum = propertyNum + 1
				end
				if (queryType == "rate_select") then
					bodyBytes[1 + propertyNum * 2 + 1] = 0x48
					bodyBytes[1 + propertyNum * 2 + 2] = 0x00
					propertyNum = propertyNum + 1
				end
				if (queryType == "intelligent_wind") then
					bodyBytes[1 + propertyNum * 2 + 1] = 0x34
					if (deviceSN8 == "50939" or deviceSN8 == "51001" or deviceSN8 == "Z1304" or deviceSN8 == "Z1259" or deviceSN8 == "Z2272") then
						bodyBytes[1 + propertyNum * 2 + 1] = 0x33
					end
					bodyBytes[1 + propertyNum * 2 + 2] = 0x00
					propertyNum = propertyNum + 1
				end
				if (queryType == "wind_straight" or queryType == "yb_wind_avoid") then
					bodyBytes[1 + propertyNum * 2 + 1] = 0x32
					bodyBytes[1 + propertyNum * 2 + 2] = 0x00
					propertyNum = propertyNum + 1
				end
				if (queryType == "wind_avoid") then
					bodyBytes[1 + propertyNum * 2 + 1] = 0x33
					if (deviceSN8 == "50939" or deviceSN8 == "51001" or deviceSN8 == "Z1304" or deviceSN8 == "Z1259" or deviceSN8 == "Z2272") then
						bodyBytes[1 + propertyNum * 2 + 1] = 0x32
					end
					bodyBytes[1 + propertyNum * 2 + 2] = 0x00
					propertyNum = propertyNum + 1
				end
				if (queryType == "auto_prevent_straight_wind") then
					bodyBytes[1 + propertyNum * 2 + 1] = 0x26
					bodyBytes[1 + propertyNum * 2 + 2] = 0x02
					propertyNum = propertyNum + 1
				end
				if (queryType == "security") then
					bodyBytes[1 + propertyNum * 2 + 1] = 0x29
					bodyBytes[1 + propertyNum * 2 + 2] = 0x00
					propertyNum = propertyNum + 1
				end
				if (queryType == "even_wind") then
					bodyBytes[1 + propertyNum * 2 + 1] = 0x4E
					bodyBytes[1 + propertyNum * 2 + 2] = 0x00
					propertyNum = propertyNum + 1
				end
				if (queryType == "single_tuyere") then
					bodyBytes[1 + propertyNum * 2 + 1] = 0x4F
					bodyBytes[1 + propertyNum * 2 + 2] = 0x00
					propertyNum = propertyNum + 1
				end
				if (queryType == "extreme_wind") then
					bodyBytes[1 + propertyNum * 2 + 1] = 0x4C
					bodyBytes[1 + propertyNum * 2 + 2] = 0x00
					propertyNum = propertyNum + 1
				end
				if (queryType == "voice_control") then
					bodyBytes[1 + propertyNum * 2 + 1] = 0x20
					bodyBytes[1 + propertyNum * 2 + 2] = 0x00
					propertyNum = propertyNum + 1
				end
				if (queryType == "pre_cool_hot") then
					bodyBytes[1 + propertyNum * 2 + 1] = 0x01
					bodyBytes[1 + propertyNum * 2 + 2] = 0x02
					propertyNum = propertyNum + 1
				end
				if (queryType == "water_washing") then
					bodyBytes[1 + propertyNum * 2 + 1] = 0x4A
					bodyBytes[1 + propertyNum * 2 + 2] = 0x00
					propertyNum = propertyNum + 1
				end
				if (queryType == "fresh_air") then
					bodyBytes[1 + propertyNum * 2 + 1] = 0x4B
					bodyBytes[1 + propertyNum * 2 + 2] = 0x00
					propertyNum = propertyNum + 1
				end
				if (queryType == "parent_control") then
					bodyBytes[1 + propertyNum * 2 + 1] = 0x51
					bodyBytes[1 + propertyNum * 2 + 2] = 0x00
					propertyNum = propertyNum + 1
				end
				if (queryType == "filter_value") then
					bodyBytes[1 + propertyNum * 2 + 1] = 0x09
					bodyBytes[1 + propertyNum * 2 + 2] = 0x04
					propertyNum = propertyNum + 1
				end
				if (queryType == "wind_swing_ud_angle") then
					bodyBytes[1 + propertyNum * 2 + 1] = 0x09
					bodyBytes[1 + propertyNum * 2 + 2] = 0x00
					propertyNum = propertyNum + 1
				end
				if (queryType == "wind_swing_lr_angle") then
					bodyBytes[1 + propertyNum * 2 + 1] = 0x0A
					bodyBytes[1 + propertyNum * 2 + 2] = 0x00
					propertyNum = propertyNum + 1
				end
				
				if (queryType == "pm25_value") then
					bodyBytes[1 + propertyNum * 2 + 1] = 0x0B
					bodyBytes[1 + propertyNum * 2 + 2] = 0x02
					propertyNum = propertyNum + 1
				end
				if (queryType == "water_pump") then
					bodyBytes[1 + propertyNum * 2 + 1] = 0x50
					bodyBytes[1 + propertyNum * 2 + 2] = 0x00
					propertyNum = propertyNum + 1
				end
				if (queryType == "intelligent_control") then
					bodyBytes[1 + propertyNum * 2 + 1] = 0x31
					bodyBytes[1 + propertyNum * 2 + 2] = 0x00
					propertyNum = propertyNum + 1
				end
				if (queryType == "volume_control") then
					bodyBytes[1 + propertyNum * 2 + 1] = 0x24
					bodyBytes[1 + propertyNum * 2 + 2] = 0x00
					propertyNum = propertyNum + 1
				end
				if (queryType == "voice_control_new") then
					bodyBytes[1 + propertyNum * 2 + 1] = 0x20
					bodyBytes[1 + propertyNum * 2 + 2] = 0x00
					propertyNum = propertyNum + 1
				end
				if (queryType == "face_register") then
					bodyBytes[1 + propertyNum * 2 + 1] = 0x44
					bodyBytes[1 + propertyNum * 2 + 2] = 0x00
					propertyNum = propertyNum + 1
				end
				if (queryType == "cool_temp_down" or queryType == "cool_temp_up" or queryType == "auto_temp_down" or queryType == "auto_temp_up" or queryType == "heat_temp_down" or queryType == "heat_temp_up") then
					bodyBytes[1 + propertyNum * 2 + 1] = 0x25
					bodyBytes[1 + propertyNum * 2 + 2] = 0x02
					propertyNum = propertyNum + 1
				end
				if (queryType == "remote_control_lock") then
					bodyBytes[1 + propertyNum * 2 + 1] = 0x27
					bodyBytes[1 + propertyNum * 2 + 2] = 0x02
					propertyNum = propertyNum + 1
				end
				if (queryType == "operating_time") then
					bodyBytes[1 + propertyNum * 2 + 1] = 0x28
					bodyBytes[1 + propertyNum * 2 + 2] = 0x02
					propertyNum = propertyNum + 1
				end
				if (queryType == "indoor_humidity") then
					bodyBytes[1 + propertyNum * 2 + 1] = 0x15
					bodyBytes[1 + propertyNum * 2 + 2] = 0x00
					propertyNum = propertyNum + 1
				end
				if (queryType == "jet_cool") then
					bodyBytes[1 + propertyNum * 2 + 1] = 0x67
					bodyBytes[1 + propertyNum * 2 + 2] = 0x00
					propertyNum = propertyNum + 1
				end
				if (queryType == "body_check") then
					bodyBytes[1 + propertyNum * 2 + 1] = 0x34
					bodyBytes[1 + propertyNum * 2 + 2] = 0x02
					propertyNum = propertyNum + 1
				end
				if (queryType == "main_horizontal_guide_strip_1" or queryType == "main_horizontal_guide_strip_2" or queryType == "main_horizontal_guide_strip_3" or queryType == "main_horizontal_guide_strip_4") then
					bodyBytes[1 + propertyNum * 2 + 1] = 0x30
					bodyBytes[1 + propertyNum * 2 + 2] = 0x02
					propertyNum = propertyNum + 1
				end
				if (queryType == "sup_horizontal_guide_strip_1" or queryType == "sup_horizontal_guide_strip_2" or queryType == "sup_horizontal_guide_strip_3" or queryType == "sup_horizontal_guide_strip_4") then
					bodyBytes[1 + propertyNum * 2 + 1] = 0x31
					bodyBytes[1 + propertyNum * 2 + 2] = 0x02
					propertyNum = propertyNum + 1
				end
				if (queryType == "twins_machine") then
					bodyBytes[1 + propertyNum * 2 + 1] = 0x32
					bodyBytes[1 + propertyNum * 2 + 2] = 0x02
					propertyNum = propertyNum + 1
				end
				if (queryType == "guide_strip_type") then
					bodyBytes[1 + propertyNum * 2 + 1] = 0x33
					bodyBytes[1 + propertyNum * 2 + 2] = 0x02
					propertyNum = propertyNum + 1
				end
				if (queryType == "sound") then
					bodyBytes[1 + propertyNum * 2 + 1] = 0x2C
					bodyBytes[1 + propertyNum * 2 + 2] = 0x02
					propertyNum = propertyNum + 1
				end
				if (queryType == "anion") then
					bodyBytes[1 + propertyNum * 2 + 1] = 0x1E
					bodyBytes[1 + propertyNum * 2 + 2] = 0x02
					propertyNum = propertyNum + 1
				end
				if (queryType == "ieco_switch") then
					bodyBytes[1 + propertyNum * 2 + 1] = 0xE3
					bodyBytes[1 + propertyNum * 2 + 2] = 0x00
					propertyNum = propertyNum + 1
				end
				if (queryType == "wind_around") then
					bodyBytes[1 + propertyNum * 2 + 1] = 0x59
					bodyBytes[1 + propertyNum * 2 + 2] = 0x00
					propertyNum = propertyNum + 1
				end
				if (queryType == "prevent_straight_wind_select" or queryType == "prevent_straight_wind_lr") then
					bodyBytes[1 + propertyNum * 2 + 1] = 0x58
					bodyBytes[1 + propertyNum * 2 + 2] = 0x00
					propertyNum = propertyNum + 1
				end
				if (queryType == "mito_cool") then
					bodyBytes[1 + propertyNum * 2 + 1] = 0x8D
					bodyBytes[1 + propertyNum * 2 + 2] = 0x00
					propertyNum = propertyNum + 1
				end
				if (queryType == "mito_heat") then
					bodyBytes[1 + propertyNum * 2 + 1] = 0x8E
					bodyBytes[1 + propertyNum * 2 + 2] = 0x00
					propertyNum = propertyNum + 1
				end
				if (queryType == "dr_time" or queryType == "dr_time_hour") then
					bodyBytes[1 + propertyNum * 2 + 1] = 0x8F
					bodyBytes[1 + propertyNum * 2 + 2] = 0x00
					propertyNum = propertyNum + 1
				end
				if (queryType == "has_cool_heat_amount") then
					bodyBytes[1 + propertyNum * 2 + 1] = 0x90
					bodyBytes[1 + propertyNum * 2 + 2] = 0x00
					propertyNum = propertyNum + 1
				end
				if (queryType == "has_icheck") then
					bodyBytes[1 + propertyNum * 2 + 1] = 0x91
					bodyBytes[1 + propertyNum * 2 + 2] = 0x00
					propertyNum = propertyNum + 1
				end
				if (queryType == "cvp") then
					bodyBytes[1 + propertyNum * 2 + 1] = 0x98
					bodyBytes[1 + propertyNum * 2 + 2] = 0x00
					propertyNum = propertyNum + 1
				end
			
			end
			if(prevent_temp == 1) then
				bodyBytes[1 + propertyNum * 2 + 1] = 0x42
				bodyBytes[1 + propertyNum * 2 + 2] = 0x00
				propertyNum = propertyNum + 1
			end
            bodyBytes[1] = propertyNum

            math.randomseed(tostring(os.time()*#bodyBytes):reverse():sub(1, 7))
            math.random()
            bodyBytes[1 + propertyNum * 2 + 1] = math.random(1, 254)

            bodyBytes[1 + propertyNum * 2 + 2] = crc8_854(bodyBytes, 0, 1 + propertyNum * 2 + 1)

            infoM = getTotalMsg(bodyBytes,keyB["BYTE_QUERYL_REQUEST"])
        end
    elseif (control) then
        --先将原始状态转换为属性
        if (status) then
            jsonToModel(status,"status")
        end
        keyP["ieco_status"] = nil
        --将用户控制 json 转换为属性
        if (control) then
			if(control[keyT["KEY_SCREEN_DISPLAY"]] ~= nil) then
				for i = 0, 22 do
					bodyBytes[i] = 0
				end
				bodyBytes[0] = 0x41
				bodyBytes[1] = 0x61
				if(control[keyT["KEY_BUZZER"]] ~= nil and control[keyT["KEY_BUZZER"]] == "off") then
					bodyBytes[1] = 0x61
				end
				bodyBytes[3] = 0xFF
				bodyBytes[4] = 0x02
				bodyBytes[5] = 0x00
				bodyBytes[6] = 0x02
				bodyBytes[7] = 0x00
				math.randomseed(tostring(os.time()*#bodyBytes):reverse():sub(1, 7))
				math.random()
				bodyBytes[21] = math.random(1, 254)
				bodyBytes[22] = crc8_854(bodyBytes, 0, 21)
				infoM = getTotalMsg(bodyBytes,keyB["BYTE_QUERYL_REQUEST"])
				--table 转换成 string 之后返回
				local ret = table2string(infoM)
				ret = string2hexstring(ret)
				return ret
			end
            jsonToModel(control,"control")
			if(control["ptc"] ~= nil and (control["ptc"] == "on" or control["ptc"] == "off")) then 
				keyP["PTCForceValue"] = 1
			else 
				keyP["PTCForceValue"] = 0
			end
        end


        --构造消息 body 部分
        if (keyP["propertyNumber"] == 0) then
		--常规协议 
		for i = 0, 25 do
            bodyBytes[i] = 0
        end
		
        bodyBytes[0] = keyB["BYTE_CONTROL_CMD"]
		
        bodyBytes[1] = bit.bor(bit.bor(keyP["powerValue"], keyB["BYTE_CLIENT_MODE_MOBILE"]), bit.bor(keyB["BYTE_TIMER_METHOD_REL"], keyP["buzzerValue"]))
		
        --bodyBytes[2] = bit.bor(bit.band(keyP["modeValue"], 0xE0), bit.band(0x0F, (keyP["temperature"] - 0x10)))
		if(keyP["temperature"] >= 16)then
			bodyBytes[2] = bit.bor(bit.bor(bit.band(keyP["modeValue"], 0xE0), bit.band(0x0F, (keyP["temperature"] - 0x10))),bit.lshift(bit.band(keyP["smallTemperature"], 0x01),4))
		else
			bodyBytes[2] = bit.bor(bit.bor(bit.band(keyP["modeValue"], 0xE0), 0),bit.lshift(bit.band(keyP["smallTemperature"], 0x01),4))
		end
        bodyBytes[3] = bit.bor(keyP["fanspeedValue"], keyB["BYTE_TIMER_SWITCH_ON"])

        if (keyP["closeTime"] == nil) then
            keyP["closeTime"] = 0
        end
		
        keyP["closeHour"] = math.floor(keyP["closeTime"] / 60)
		
        keyP["closeStepMintues"] = math.floor((keyP["closeTime"] % 60) / 15)
		
        keyP["closeMin"] = math.floor(((keyP["closeTime"] % 60) % 15))

        if (keyP["openTime"] == nil) then
            keyP["openTime"] = 0
        end
		
        keyP["openHour"] = math.floor(keyP["openTime"] / 60)
		
        keyP["openStepMintues"] = math.floor((keyP["openTime"] % 60) / 15)
		
        keyP["openMin"] = math.floor(((keyP["openTime"] % 60) % 15))

        if (keyP["openTimerSwitch"] == keyB["BYTE_START_TIMER_SWITCH_ON"]) then
            bodyBytes[4] = bit.bor(bit.bor(keyP["openTimerSwitch"], bit.lshift(keyP["openHour"], 2)), keyP["openStepMintues"])
        elseif (keyP["openTimerSwitch"] == keyB["BYTE_START_TIMER_SWITCH_OFF"] ) then
            bodyBytes[4] = 0x7F
        end

        if (keyP["closeTimerSwitch"] == keyB["BYTE_CLOSE_TIMER_SWITCH_ON"]) then
            bodyBytes[5] = bit.bor(bit.bor(keyP["closeTimerSwitch"], bit.lshift(keyP["closeHour"], 2)), keyP["closeStepMintues"])
        elseif (keyP["closeTimerSwitch"] == keyB["BYTE_CLOSE_TIMER_SWITCH_OFF"]) then
            bodyBytes[5] = 0x7F
        end

        bodyBytes[6] = bit.bor(bit.lshift((15 - keyP["openMin"]), 4), (15 - keyP["closeMin"]))

        bodyBytes[7] = bit.bor(bit.bor(keyP["swingLRValue"], keyP["swingUDValue"]), 0x30)
		
        bodyBytes[8] = bit.bor(bit.bor(keyP["strongWindValue"], keyP["comfortableSleepValue"]), keyP["power_saving"])
		
        bodyBytes[9] = bit.bor(bit.bor(bit.bor(keyP["purifierValue"], keyP["ecoValue"]), bit.bor(keyP["dryValue"], keyP["PTCValue"])),keyP["comfortableSleepSwitch"])
		if ((keyP["PTCForceValue"] ~= nil) and (keyP["PTCForceValue"] == 1)) then
			bodyBytes[9] = bit.bor(bodyBytes[9], 0x10)
		end
        bodyBytes[10] = bit.lshift(bit.band(keyP["preventCold"], 0x01), 3)
		bodyBytes[10] = bit.bor(keyP["sleep_status"], bodyBytes[10])
		if(keyP["temperature_unit"] ~= nil) then
			bodyBytes[10] = bit.bor(bit.lshift(bit.band(keyP["temperature_unit"],0x01), 2), bodyBytes[10])
		end	
		
		if(keyP["common_filter_reset"] ~= nil) then 
			bodyBytes[10] = bit.bor(keyP["common_filter_reset"], bodyBytes[10])
		end
		if(keyP["tubroValue"] ~= nil) then 
			bodyBytes[10] = bit.bor(keyP["tubroValue"], bodyBytes[10])
		end
		
		if(keyP["comfortableSleepValue"] == keyB["BYTE_SLEEP_ON"] and comfortByte == nil) then 
		    if(keyP["modeValue"] == keyB["BYTE_MODE_HEAT"]) then
		        firstHourTemp = checkBoundary(keyP["temperature"] - 1, 17, 30)
			    otherHourTemp = checkBoundary(keyP["temperature"] - 2, 17, 30)
		    else
		        firstHourTemp = checkBoundary(keyP["temperature"] + 1, 17, 30)
			    otherHourTemp = checkBoundary(keyP["temperature"] + 2, 17, 30)
		    end
		
		    bodyBytes[11] = bit.bor(firstHourTemp -17,bit.lshift((otherHourTemp -17), 4))
		    bodyBytes[12] = bit.bor(otherHourTemp -17,bit.lshift((otherHourTemp -17), 4))
		    bodyBytes[13] = bit.bor(otherHourTemp -17,bit.lshift((otherHourTemp -17), 4))
		    bodyBytes[14] = bit.bor(otherHourTemp -17,bit.lshift((otherHourTemp -17), 4))
		    bodyBytes[15] = bit.bor(otherHourTemp -17,bit.lshift((otherHourTemp -17), 4))
		
		    if(keyP["smallTemperature"] ~= 0) then 
		        bodyBytes[16] = 0xFF
				bodyBytes[17] = bit.bor(keyP["comfortableSleepTime"], 0x30)
			else
			    bodyBytes[17] = keyP["comfortableSleepTime"]
			end
			
		elseif(keyP["comfortableSleepValue"] == keyB["BYTE_SLEEP_ON"] and comfortByte ~= nil) then
		    bodyBytes[11] = bit.bor(checkBoundary(comfortByte[1], 17, 30) -17,bit.lshift((checkBoundary(comfortByte[2], 17, 30) -17), 4))
		    bodyBytes[12] = bit.bor(checkBoundary(comfortByte[3], 17, 30) -17,bit.lshift((checkBoundary(comfortByte[4], 17, 30) -17), 4))
		    bodyBytes[13] = bit.bor(checkBoundary(comfortByte[5], 17, 30) -17,bit.lshift((comfortByte[6] -17), 4))
		    bodyBytes[14] = bit.bor(checkBoundary(comfortByte[7], 17, 30) -17,bit.lshift((comfortByte[8] -17), 4))
		    bodyBytes[15] = bit.bor(checkBoundary(comfortByte[9], 17, 30) -17,bit.lshift((comfortByte[10] -17), 4))
		   
		    if(keyP["smallTemperature"] ~= 0) then 
		        bodyBytes[16] = 0xFF
				bodyBytes[17] = bit.bor(keyP["comfortableSleepTime"], 0x30)
		    else
			    bodyBytes[17] = keyP["comfortableSleepTime"]
		    end
	
		end
		if(keyP["pmv"] ~= nil) then
			local pmvValue = (keyP["pmv"] + 3.5) * 2 
			bodyBytes[17] = bit.bor( bit.lshift(bit.band(pmvValue,0x08), 4), bodyBytes[17])
			bodyBytes[18] = bit.bor( bit.lshift(bit.band(pmvValue,0x07), 5), bodyBytes[18])
		end
		if(keyP["naturalWind"] ~= nil) then 
			bodyBytes[17] = bit.bor(keyP["naturalWind"], bodyBytes[17])
		end

		if (keyP["temperature"] < 17 or keyP["temperature"] > 30) then
			if((keyP["temperature"] >= 13 and keyP["temperature"] < 17) or (keyP["temperature"] <= 38 and keyP["temperature"] > 30))then
				bodyBytes[18] = bit.bor( bit.band(0x1F, (keyP["temperature"] - 12)), bodyBytes[18])
			else
				bodyBytes[18] = bit.bor( bit.band(0x1F, (keyP["temperature"] + 19)), bodyBytes[18])
			end
		end
		
		if((keyP["modeValue"] == keyB["BYTE_MODE_SMART_DRY"] or keyP["modeValue"] == keyB["BYTE_MODE_DRY"]) and keyP["smartDryValue"] ~= nil) then
			bodyBytes[19] = bit.bor( bit.band(0x7F,keyP["smartDryValue"]), bodyBytes[19])
		end
	
		if(keyP["swingLRUnderSwitch"] ~= nil) then
			bodyBytes[19] = bit.bor(keyP["swingLRUnderSwitch"], bodyBytes[19])
		end
		if(keyP["swingLRValueUnder"] ~= nil) then
			bodyBytes[20] = bit.bor(keyP["swingLRValueUnder"], bodyBytes[20])
        end
		if(keyP["degree8_heat"] ~= nil) then
			bodyBytes[21] = bit.lshift(bit.band(keyP["degree8_heat"], 0x01), 7)
		end

		if(keyP["comfortPowerSave"] ~= nil) then
			if (keyP["comfortPowerSave"] == keyB["BYTE_COMFORT_POWER_SAVE_ON"]) then
				bodyBytes[22] = 0x01
			elseif (keyP["comfortPowerSave"] == keyB["BYTE_COMFORT_POWER_SAVE_OFF"] ) then
				bodyBytes[22] = 0x00
			end
		end
        if(keyP["fresh_filter_reset"] ~= nil) then 
			bodyBytes[22] = bit.bor(keyP["fresh_filter_reset"], bodyBytes[22])
		end
		if(keyP["independent_ptc"] ~= nil) then 
			bodyBytes[22] = bit.bor(keyP["independent_ptc"], bodyBytes[22])
		end
		math.randomseed(tostring(os.time()*#bodyBytes):reverse():sub(1, 7))
        math.random()
        bodyBytes[24] = math.random(1, 254)
		
        bodyBytes[25] = crc8_854(bodyBytes, 0, 24)
		
		
			
		else
			--新协议，属性变长协议
			bodyBytes[0] = keyB["BYTE_CONTROL_PROPERTY_CMD"]
			bodyBytes[1] = keyP["propertyNumber"]
			local cursor = 2
			if(keyP["prevent_super_cool"] ~= nil) then
				bodyBytes[cursor + 0] = 0x49
                bodyBytes[cursor + 1] = 0x00
                bodyBytes[cursor + 2] = 0x05
                bodyBytes[cursor + 3] = keyP["prevent_super_cool"]
                bodyBytes[cursor + 4] = 0xFF
                bodyBytes[cursor + 5] = 0xFF
                bodyBytes[cursor + 6] = 0xFF
                bodyBytes[cursor + 7] = 0xFF
                cursor = cursor + 8
			end
			if(keyP["prevent_straight_wind"] ~= nil) then
					bodyBytes[cursor + 0] = 0x42
					if(keyP["prevent_straight_wind_flag"] ~=nil and keyP["prevent_straight_wind_flag"] == 43) then
						bodyBytes[cursor + 0] = 0x43
					end
					bodyBytes[cursor + 1] = 0x00 	
					bodyBytes[cursor + 2] = 0x01 	
					bodyBytes[cursor + 3] = keyP["prevent_straight_wind"]
					cursor = cursor + 4
			end
			if(keyP["auto_prevent_straight_wind"] ~= nil) then
				bodyBytes[cursor + 0] = 0x26 	
				bodyBytes[cursor + 1] = 0x02 	
				bodyBytes[cursor + 2] = 0x01 	
				bodyBytes[cursor + 3] = keyP["auto_prevent_straight_wind"]
				cursor = cursor + 4
			end
			if(keyP["self_clean"] ~= nil) then
				bodyBytes[cursor + 0] = 0x39 	
				bodyBytes[cursor + 1] = 0x00 	
				bodyBytes[cursor + 2] = 0x01 	
				bodyBytes[cursor + 3] = keyP["self_clean"]
				cursor = cursor + 4
			end
			if(keyP["gentle_wind_sense"] ~= nil) then
				bodyBytes[cursor + 0] = 0x43 	
				bodyBytes[cursor + 1] = 0x00 	
				bodyBytes[cursor + 2] = 0x01 	
				bodyBytes[cursor + 3] = keyP["gentle_wind_sense"]
				cursor = cursor + 4
			end
			if(keyP["wind_straight"] ~= nil) then
				bodyBytes[cursor + 0] = 0x32 	
				bodyBytes[cursor + 1] = 0x00 	
				bodyBytes[cursor + 2] = 0x01 	
				bodyBytes[cursor + 3] = keyP["wind_straight"]
				cursor = cursor + 4
			end
			if(keyP["yb_wind_avoid"] ~= nil) then
				bodyBytes[cursor + 0] = 0x32 	
				bodyBytes[cursor + 1] = 0x00 	
				bodyBytes[cursor + 2] = 0x01 	
				bodyBytes[cursor + 3] = keyP["yb_wind_avoid"]
				cursor = cursor + 4
			end
			if(keyP["wind_avoid"] ~= nil) then
			    --YB100特殊处理
				if (deviceSN8 == "50939" or deviceSN8 == "51001" or deviceSN8 == "Z1304" or deviceSN8 == "Z1259" or deviceSN8 == "Z2272") then
					bodyBytes[cursor + 0] = 0x32		
				    bodyBytes[cursor + 1] = 0x00 	
				    bodyBytes[cursor + 2] = 0x01
                    if(keyP["wind_avoid"] == 0x01) then
                        bodyBytes[cursor + 3] = 0x02
                    else						
				        bodyBytes[cursor + 3] = 0x00
					end
				    cursor = cursor + 4
                else			
				    bodyBytes[cursor + 0] = 0x33		
				    bodyBytes[cursor + 1] = 0x00 	
				    bodyBytes[cursor + 2] = 0x01 	
				    bodyBytes[cursor + 3] = keyP["wind_avoid"]
				    cursor = cursor + 4
				end
			end
			if(keyP["intelligent_wind"] ~= nil) then
				bodyBytes[cursor + 0] = 0x34 	
				bodyBytes[cursor + 1] = 0x00 	
				bodyBytes[cursor + 2] = 0x01 	
				bodyBytes[cursor + 3] = keyP["intelligent_wind"]
				cursor = cursor + 4
			end
			if(keyP["no_wind_sense"] ~= nil) then
				--FA100特殊处理
				if (deviceSN8 == "12035"or deviceSN8 == "12037" or deviceSN8 == "Z1312" or deviceSN8 == "Z1262" or deviceSN8 == "12179" or deviceSN8 == "Z1261") then
					bodyBytes[cursor + 0] = 0x43 	
					bodyBytes[cursor + 1] = 0x00 	
					bodyBytes[cursor + 2] = 0x01
					bodyBytes[cursor + 3] = 0x00
					if (keyP["no_wind_sense"] == 1) then
						bodyBytes[cursor + 3] = 0x04
					elseif (keyP["no_wind_sense"] == 0) then 
						bodyBytes[cursor + 3] = 0x01
					end
					cursor = cursor + 4
				elseif (deviceSN8 == "51023") then
					bodyBytes[cursor + 0] = 0x18 	
					bodyBytes[cursor + 1] = 0x00 	
					bodyBytes[cursor + 2] = 0x02 	
					bodyBytes[cursor + 3] = keyP["no_wind_sense"]
					bodyBytes[cursor + 4] = keyP["no_wind_sense_level"]
					cursor = cursor + 5
                else
	                bodyBytes[cursor + 0] = 0x18 	
					bodyBytes[cursor + 1] = 0x00 	
					bodyBytes[cursor + 2] = 0x01 	
					bodyBytes[cursor + 3] = keyP["no_wind_sense"]
					cursor = cursor + 4			
				end
			end
			if(keyP["fa_no_wind_sense"] ~= nil) then
				bodyBytes[cursor + 0] = 0x43 	
				bodyBytes[cursor + 1] = 0x00 	
				bodyBytes[cursor + 2] = 0x01
				bodyBytes[cursor + 3] = keyP["fa_no_wind_sense"]
				cursor = cursor + 4	
			end
			if(keyP["child_prevent_cold_wind"] ~= nil) then
				bodyBytes[cursor + 0] = 0x3A 	
				bodyBytes[cursor + 1] = 0x00 	
				bodyBytes[cursor + 2] = 0x01 	
				bodyBytes[cursor + 3] = keyP["child_prevent_cold_wind"]
				cursor = cursor + 4
			end
			if(keyP["little_angel"] ~= nil) then
				bodyBytes[cursor + 0] = 0x1B 	
				bodyBytes[cursor + 1] = 0x02 	
				bodyBytes[cursor + 2] = 0x01 	
				bodyBytes[cursor + 3] = keyP["little_angel"]
				cursor = cursor + 4
			end
			if(keyP["cool_hot_sense"] ~= nil) then
				bodyBytes[cursor + 0] = 0x21 	
				bodyBytes[cursor + 1] = 0x00 	
				bodyBytes[cursor + 2] = 0x08 	
				bodyBytes[cursor + 3] = keyP["cool_hot_sense"]
				bodyBytes[cursor + 4] = 0x00
				bodyBytes[cursor + 5] = 0x00
				bodyBytes[cursor + 6] = 0x00
				bodyBytes[cursor + 7] = 0x00
				bodyBytes[cursor + 8] = 0x00
				bodyBytes[cursor + 9] = 0x00
				bodyBytes[cursor + 10] = 0x00
				cursor = cursor + 11
			end
			if(keyP["even_wind"] ~= nil) then
				bodyBytes[cursor + 0] = 0x4E
				bodyBytes[cursor + 1] = 0x00
				bodyBytes[cursor + 2] = 0x01
				bodyBytes[cursor + 3] = keyP["even_wind"]
				cursor = cursor + 4
			end
			if(keyP["single_tuyere"] ~= nil) then
				bodyBytes[cursor + 0] = 0x4F
				bodyBytes[cursor + 1] = 0x00
				bodyBytes[cursor + 2] = 0x01
				bodyBytes[cursor + 3] = keyP["single_tuyere"]
				cursor = cursor + 4
			end
			if(keyP["extreme_wind"] ~= nil) then
				bodyBytes[cursor + 0] = 0x4C
				bodyBytes[cursor + 1] = 0x00
				bodyBytes[cursor + 2] = 0x02
				bodyBytes[cursor + 3] = keyP["extreme_wind"]
				bodyBytes[cursor + 4] = 0x01
				cursor = cursor + 5
			end
			if(keyP["security"] ~= nil) then
				bodyBytes[cursor + 0] = 0x29
				bodyBytes[cursor + 1] = 0x00
				bodyBytes[cursor + 2] = 0x01
				bodyBytes[cursor + 3] = keyP["security"]
				cursor = cursor + 4
			end
			if(keyP["voice_control"] ~= nil) then
				bodyBytes[cursor + 0] = 0x20
				bodyBytes[cursor + 1] = 0x00
				bodyBytes[cursor + 2] = 0x09
				bodyBytes[cursor + 3] = keyP["voice_control"]
				bodyBytes[cursor + 4] = 0xFF
				bodyBytes[cursor + 5] = 0xFF
				bodyBytes[cursor + 6] = 0xFF
				bodyBytes[cursor + 7] = 0xFF
				bodyBytes[cursor + 8] = 0xFF
				bodyBytes[cursor + 9] = 0xFF
				bodyBytes[cursor + 10] = 0xFF
				bodyBytes[cursor + 11] = 0xFF
				cursor = cursor + 12
			end
			if(keyP["pre_cool_hot"] ~= nil) then
				bodyBytes[cursor + 0] = 0x01
				bodyBytes[cursor + 1] = 0x02
				bodyBytes[cursor + 2] = 0x01
				bodyBytes[cursor + 3] = keyP["pre_cool_hot"]
				cursor = cursor + 4
			end
			if(keyP["water_washing"] ~= nil) then
				bodyBytes[cursor + 0] = 0x4A
				bodyBytes[cursor + 1] = 0x00
				bodyBytes[cursor + 2] = 0x04
				bodyBytes[cursor + 3] = keyP["water_washing_manual"]
				bodyBytes[cursor + 4] = keyP["water_washing"]
				bodyBytes[cursor + 5] = keyP["water_washing_time"]
				bodyBytes[cursor + 6] = 0xFF
				cursor = cursor + 7
			end
			if(keyP["fresh_air"] ~= nil) then
				bodyBytes[cursor + 0] = 0x4B
				bodyBytes[cursor + 1] = 0x00
				bodyBytes[cursor + 2] = 0x03
				bodyBytes[cursor + 3] = keyP["fresh_air"]
				bodyBytes[cursor + 4] = keyP["fresh_air_fan_speed"]
				bodyBytes[cursor + 5] = 0xFF
				cursor = cursor + 6
			end
			if(keyP["parent_control"] ~= nil) then
				bodyBytes[cursor + 0] = 0x51
				bodyBytes[cursor + 1] = 0x00
				bodyBytes[cursor + 2] = 0x05
				bodyBytes[cursor + 3] = keyP["parent_control"]
				bodyBytes[cursor + 4] = keyP["parent_control_temp_up"]
				bodyBytes[cursor + 5] = keyP["parent_control_temp_down"]
				bodyBytes[cursor + 6] = 0xFF
				bodyBytes[cursor + 7] = 0xFF
				cursor = cursor + 8
			end
			if(keyP["buzzerValue"] ~= nil) then
                bodyBytes[cursor + 0] = 0x1A
                bodyBytes[cursor + 1] = 0x00
                bodyBytes[cursor + 2] = 0x01
                bodyBytes[cursor + 3] = 0x00
                if(keyP["buzzerValue"] == 0x40) then
                    bodyBytes[cursor + 3] = 0x01
                end
                cursor = cursor + 4
                bodyBytes[1] = keyP["propertyNumber"] + 1
            end
			if(keyP["wind_swing_ud_angle"] ~= nil) then
				bodyBytes[cursor + 0] = 0x09
				bodyBytes[cursor + 1] = 0x00
				bodyBytes[cursor + 2] = 0x01
				bodyBytes[cursor + 3] = keyP["wind_swing_ud_angle"]
				cursor = cursor + 4
			end
			if(keyP["wind_swing_lr_angle"] ~= nil) then
				bodyBytes[cursor + 0] = 0x0A
				bodyBytes[cursor + 1] = 0x00
				bodyBytes[cursor + 2] = 0x01
				bodyBytes[cursor + 3] = keyP["wind_swing_lr_angle"]
				cursor = cursor + 4
			end
			if(keyP["nobody_energy_save"] ~= nil) then
                bodyBytes[cursor + 0] = 0x30
                bodyBytes[cursor + 1] = 0x00
                bodyBytes[cursor + 2] = 0x06
                bodyBytes[cursor + 3] = keyP["nobody_energy_save"]
                bodyBytes[cursor + 4] = 0x00
                bodyBytes[cursor + 5] = 0x00
                bodyBytes[cursor + 6] = 0x00
                bodyBytes[cursor + 7] = 0x00
                bodyBytes[cursor + 8] = 0x00
                cursor = cursor + 9 
                bodyBytes[1] = keyP["propertyNumber"] + 1
            end
			if(keyP["prevent_straight_wind_lr"] ~= nil) then
                bodyBytes[cursor + 0] = 0x58
                bodyBytes[cursor + 1] = 0x00
                bodyBytes[cursor + 2] = 0x01
                bodyBytes[cursor + 3] = keyP["prevent_straight_wind_lr"]
                cursor = cursor + 4
                bodyBytes[1] = keyP["propertyNumber"] + 1
            end
			if(keyP["water_pump"] ~= nil) then
                bodyBytes[cursor + 0] = 0x50
                bodyBytes[cursor + 1] = 0x00
                bodyBytes[cursor + 2] = 0x01
                bodyBytes[cursor + 3] = keyP["water_pump"]
                cursor = cursor + 4
                bodyBytes[1] = keyP["propertyNumber"] + 1
            end
			if(keyP["intelligent_control"] ~= nil) then
                bodyBytes[cursor + 0] = 0x31
                bodyBytes[cursor + 1] = 0x00
                bodyBytes[cursor + 2] = 0x01
                bodyBytes[cursor + 3] = keyP["intelligent_control"]
                cursor = cursor + 4
                bodyBytes[1] = keyP["propertyNumber"] + 1
            end
			if(keyP["volume_control"] ~= nil) then
                bodyBytes[cursor + 0] = 0x24
                bodyBytes[cursor + 1] = 0x00
                bodyBytes[cursor + 2] = 0x04
                bodyBytes[cursor + 3] = 0x02
                bodyBytes[cursor + 4] = keyP["volume_control"]
                bodyBytes[cursor + 5] = 0xFF
                bodyBytes[cursor + 6] = 0xFF
                cursor = cursor + 7
                bodyBytes[1] = keyP["propertyNumber"] + 1
            end
			if(keyP["voice_control_new"] ~= nil) then
				bodyBytes[cursor + 0] = 0x20
				bodyBytes[cursor + 1] = 0x00
				bodyBytes[cursor + 2] = 0x14
				bodyBytes[cursor + 3] = keyP["voice_control_new"]
				bodyBytes[cursor + 4] = 0xFF
				bodyBytes[cursor + 5] = 0xFF
				bodyBytes[cursor + 6] = 0xFF
				bodyBytes[cursor + 7] = 0xFF
				bodyBytes[cursor + 8] = 0xFF
				bodyBytes[cursor + 9] = 0xFF
				bodyBytes[cursor + 10] = 0xFF
				bodyBytes[cursor + 11] = 0xFF
				bodyBytes[cursor + 12] = 0xFF
				bodyBytes[cursor + 13] = 0xFF
				bodyBytes[cursor + 14] = 0xFF
				bodyBytes[cursor + 15] = 0xFF
				bodyBytes[cursor + 16] = 0xFF
				bodyBytes[cursor + 17] = 0xFF
				bodyBytes[cursor + 18] = 0xFF
				bodyBytes[cursor + 19] = 0xFF
				bodyBytes[cursor + 20] = 0xFF
				bodyBytes[cursor + 21] = 0xFF
				bodyBytes[cursor + 22] = 0xFF
				cursor = cursor + 23
			end
			if(keyP["cool_temp_down"] ~= nil or keyP["cool_temp_up"] ~= nil or keyP["auto_temp_down"] ~= nil or keyP["auto_temp_up"] ~= nil or keyP["heat_temp_down"] ~= nil or keyP["heat_temp_up"] ~= nil) then
			    bodyBytes[cursor + 0] = 0x25
				bodyBytes[cursor + 1] = 0x02
				bodyBytes[cursor + 2] = 0x07
				bodyBytes[cursor + 3] = keyP["cool_temp_down"]
				bodyBytes[cursor + 4] = keyP["cool_temp_up"]
				bodyBytes[cursor + 5] = keyP["auto_temp_down"]
				bodyBytes[cursor + 6] = keyP["auto_temp_up"]
				bodyBytes[cursor + 7] = keyP["heat_temp_down"]
				bodyBytes[cursor + 8] = keyP["heat_temp_up"]
				bodyBytes[cursor + 9] = 0x00
				cursor = cursor + 10
			end
			if(keyP["remote_control_lock"] ~= nil) then
				bodyBytes[cursor + 0] = 0x27
				bodyBytes[cursor + 1] = 0x02
				bodyBytes[cursor + 2] = 0x02
				bodyBytes[cursor + 3] = keyP["remote_control_lock"]
				bodyBytes[cursor + 4] = keyP["remote_control_lock_control"]
				cursor = cursor + 5
			end
			if(keyP["operating_time"] ~= nil) then
				bodyBytes[cursor + 0] = 0x28
				bodyBytes[cursor + 1] = 0x02
				bodyBytes[cursor + 2] = 0x03
				bodyBytes[cursor + 3] = bit.band(keyP["operating_time"], 0xff)
				bodyBytes[cursor + 4] = bit.band(bit.rshift(keyP["operating_time"], 8), 0xff)
				bodyBytes[cursor + 5] = bit.band(bit.rshift(keyP["operating_time"], 16), 0xff)
				cursor = cursor + 6
			end
			if(keyP["jet_cool"] ~= nil) then
                bodyBytes[cursor + 0] = 0x67
                bodyBytes[cursor + 1] = 0x00
                bodyBytes[cursor + 2] = 0x01
                bodyBytes[cursor + 3] = keyP["jet_cool"]
                cursor = cursor + 4
            end
			if(keyP["rate_select"] ~= nil) then
                bodyBytes[cursor + 0] = 0x48
                bodyBytes[cursor + 1] = 0x00
                bodyBytes[cursor + 2] = 0x01
                bodyBytes[cursor + 3] = keyP["rate_select"]
                cursor = cursor + 4
            end
			if(keyP["main_strip_control"] ~= nil) then
                bodyBytes[cursor + 0] = 0x30
                bodyBytes[cursor + 1] = 0x02
                bodyBytes[cursor + 2] = 0x04
                bodyBytes[cursor + 3] = keyP["main_horizontal_guide_strip_1"]
				bodyBytes[cursor + 4] = keyP["main_horizontal_guide_strip_2"]
				bodyBytes[cursor + 5] = keyP["main_horizontal_guide_strip_3"]
				bodyBytes[cursor + 6] = keyP["main_horizontal_guide_strip_4"]
                cursor = cursor + 7
            end
			if(keyP["sup_strip_control"] ~= nil) then
                bodyBytes[cursor + 0] = 0x31
                bodyBytes[cursor + 1] = 0x02
                bodyBytes[cursor + 2] = 0x04
                bodyBytes[cursor + 3] = keyP["sup_horizontal_guide_strip_1"]
				bodyBytes[cursor + 4] = keyP["sup_horizontal_guide_strip_2"]
				bodyBytes[cursor + 5] = keyP["sup_horizontal_guide_strip_3"]
				bodyBytes[cursor + 6] = keyP["sup_horizontal_guide_strip_4"]
                cursor = cursor + 7
            end
			if(keyP["sound"] ~= nil) then
				bodyBytes[cursor + 0] = 0x2C
				bodyBytes[cursor + 1] = 0x02
				bodyBytes[cursor + 2] = 0x01
				bodyBytes[cursor + 3] = keyP["sound"]
				cursor = cursor + 4
			end
			if(keyP["anion"] ~= nil) then
				bodyBytes[cursor + 0] = 0x1E
				bodyBytes[cursor + 1] = 0x02
				bodyBytes[cursor + 2] = 0x01
				bodyBytes[cursor + 3] = keyP["anion"]
				cursor = cursor + 4
			end
			if(keyP["prevent_straight_wind_select"] ~= nil) then
				bodyBytes[cursor + 0] = 0x58
				bodyBytes[cursor + 1] = 0x00
				bodyBytes[cursor + 2] = 0x01
				bodyBytes[cursor + 3] = keyP["prevent_straight_wind_select"]
				cursor = cursor + 4
			end
			if(keyP["wind_around"] ~= nil) then
                bodyBytes[cursor + 0] = 0x59
                bodyBytes[cursor + 1] = 0x00
                bodyBytes[cursor + 2] = 0x02
                bodyBytes[cursor + 3] = keyP["wind_around"]
                bodyBytes[cursor + 4] = 0
				if(keyP["wind_around_ud"] ~= nil) then
					bodyBytes[cursor + 4] = keyP["wind_around_ud"]
				end
                cursor = cursor + 5
            end
			if(keyP["ieco_status"] == 1)then
				bodyBytes[cursor + 0] = 0xE3
				bodyBytes[cursor + 1] = 0x00
				bodyBytes[cursor + 2] = 0x0D
				bodyBytes[cursor + 3] = keyP["ieco_frame"]
				bodyBytes[cursor + 4] = keyP["ieco_number"]
				bodyBytes[cursor + 5] = keyP["ieco_switch"]
				bodyBytes[cursor + 6] = bit.band(keyP["ieco_target_rate"], 0xff)
				bodyBytes[cursor + 7] = bit.band(bit.rshift(keyP["ieco_target_rate"], 8), 0xff)
				bodyBytes[cursor + 8] = keyP["ieco_indoor_wind_speed_level"]
				bodyBytes[cursor + 9] = bit.band(keyP["ieco_indoor_wind_speed"], 0xff)
				bodyBytes[cursor + 10] = bit.band(bit.rshift(keyP["ieco_indoor_wind_speed"], 8), 0xff)
				bodyBytes[cursor + 11] = keyP["ieco_outdoor_wind_speed_level"]
				bodyBytes[cursor + 12] = bit.band(keyP["ieco_outdoor_wind_speed"], 0xff)
				bodyBytes[cursor + 13] = bit.band(bit.rshift(keyP["ieco_outdoor_wind_speed"], 8), 0xff)
				bodyBytes[cursor + 14] = bit.band(keyP["ieco_expansion_valve"], 0xff)
				bodyBytes[cursor + 15] = bit.band(bit.rshift(keyP["ieco_expansion_valve"], 8), 0xff)
				cursor = cursor + 16
			end
			if(keyP["mito_cool"] ~= nil) then
				bodyBytes[cursor + 0] = 0x8D
				bodyBytes[cursor + 1] = 0x00
				bodyBytes[cursor + 2] = 0x01
				bodyBytes[cursor + 3] = keyP["mito_cool"] * 2 + 50
				cursor = cursor + 4
			end
			if(keyP["mito_heat"] ~= nil) then
				bodyBytes[cursor + 0] = 0x8E
				bodyBytes[cursor + 1] = 0x00
				bodyBytes[cursor + 2] = 0x01
				bodyBytes[cursor + 3] = keyP["mito_heat"] * 2 + 50
				cursor = cursor + 4
			end
			if(keyP["dr_time_hour"] ~= nil or keyP["dr_time_min"] ~= nil) then
				bodyBytes[cursor + 0] = 0x8F
				bodyBytes[cursor + 1] = 0x00
				bodyBytes[cursor + 2] = 0x02
				bodyBytes[cursor + 3] = keyP["dr_time_min"]
				bodyBytes[cursor + 4] = keyP["dr_time_hour"]
				cursor = cursor + 5
			end
			if(keyP["cvp"] ~= nil) then
				bodyBytes[cursor + 0] = 0x98
				bodyBytes[cursor + 1] = 0x00
				bodyBytes[cursor + 2] = 0x01
				bodyBytes[cursor + 3] = keyP["cvp"]
				cursor = cursor + 4
			end
		
	        math.randomseed(tostring(os.time()*#bodyBytes):reverse():sub(1, 7))
			math.random()
			bodyBytes[cursor] = math.random(1, 254)
		
			bodyBytes[cursor + 1] = crc8_854(bodyBytes, 0, cursor)
		end
        --构造消息部分
        infoM = getTotalMsg(bodyBytes,keyB["BYTE_CONTROL_REQUEST"])
    end
	keyP["propertyNumber"] = 0
	keyP["prevent_super_cool"] = nil 
	keyP["prevent_straight_wind"] = nil 
	keyP["auto_prevent_straight_wind"] = nil 
	keyP["wind_straight"] = nil 
	keyP["wind_avoid"] = nil 
	keyP["yb_wind_avoid"] = nil
	keyP["intelligent_wind"] = nil 
	keyP["self_clean"] = nil 
	keyP["no_wind_sense"] = nil 
	keyP["no_wind_sense_level"] = nil
	keyP["child_prevent_cold_wind"] = nil 
	keyP["little_angel"] = nil 
	keyP["cool_hot_sense"] = nil 
	keyP["gentle_wind_sense"] = nil 
	keyP["security"] = nil
	keyP["even_wind"] = nil
	keyP["single_tuyere"] = nil
	keyP["extreme_wind"] = nil
	keyP["extreme_wind_level"] = nil
	keyP["voice_control"] = nil
	keyP["pre_cool_hot"] = nil
	keyP["water_washing"] = nil
	keyP["fresh_air"] = nil
	keyP["fa_prevent_straight_wind"] = nil
	keyP["parent_control"] = nil
	keyP["parent_control_temp_up"] = nil
	keyP["parent_control_temp_down"] = nil
	keyP["nobody_energy_save"] = nil
	keyP["filter_value"] = nil
	keyP["filter_level"] = nil
	keyP["prevent_straight_wind_lr"] = nil
	keyP["pm25_value"] = nil
	keyP["water_pump"] = nil
	keyP["intelligent_control"] = nil
	keyP["wind_swing_ud_angle"] = nil
	keyP["wind_swing_lr_angle"] = nil
	keyP["volume_control"] = nil
	keyP["voice_control_new"] = nil
	keyP["face_register"] = nil
	keyP["cool_temp_up"] = nil
	keyP["cool_temp_down"] = nil
	keyP["auto_temp_up"] = nil
	keyP["auto_temp_down"] = nil
	keyP["heat_temp_up"] = nil
	keyP["heat_temp_down"] = nil
	keyP["remote_control_lock"] = nil
	keyP["remote_control_lock_control"] = nil
	keyP["operating_time"] = nil
	keyP["fa_no_wind_sense"] = nil
	keyP["indoor_humidity"] = nil
	keyP["prevent_straight_wind_flag"] = nil
	keyP["rate_select"] = nil
	keyP["sound"] = nil
	keyP["b5_parent_control"] = nil
	keyP["ieco_status"] = nil
	keyP["wind_around"] = nil
	keyP["wind_around_ud"] = nil
	keyP["b5_wind_around"] = nil
	keyP["prevent_straight_wind_select"] = nil
	keyP["b5_prevent_straight_wind_select"] = nil
	keyP["cvp"] = nil
	keyP["b5_cvp"] = nil
	propertyPre = nil
	
    --table 转换成 string 之后返回
    local ret = table2string(infoM)
    ret = string2hexstring(ret)
	return ret
end


--二进制转json
function dataToJson(jsonCmd)
	
    init_keyP()
	if (not jsonCmd) then
        return nil
    end
    
    local json = decode(jsonCmd)
    local deviceinfo = json["deviceinfo"]
    deviceSubType = deviceinfo["deviceSubType"]
    local deviceSN=json["deviceinfo"]["deviceSN"]
    if deviceSN~=nil then
        deviceSN8=string.sub(deviceSN,13,17)
    end

    local status = json["status"]
    if (status) then
        jsonToModel(status,"status")
    end

    local binData = json["msg"]["data"]
    local info = {}
    local msgBytes = {}
    local bodyBytes = {}
    local msgLength = 0
    local bodyLength = 0
    
    info = string2table(binData)

    local streams = {}
    dataType=info[10];
	streams["protocolType"] = info[9]

    for i = 1, #info do
        msgBytes[i - 1] = info[i]
    end
    
    msgLength = msgBytes[1]
    bodyLength = msgLength - keyB["BYTE_PROTOCOL_LENGTH"] - 1

	streams["b5_next_frame"] = info[msgLength - 2]
    
	--获取 body 部分
    for i = 0, bodyLength do
        bodyBytes[i] = msgBytes[i + keyB["BYTE_PROTOCOL_LENGTH"]]
    end
    
    --将二进制状态解析为属性值
    binToModel(bodyBytes,deviceSN8)
    
    --将属性值转换为最终 table
	
    --版本
    streams[keyT["KEY_VERSION"]] = keyV["VALUE_VERSION"]

    if (keyP["propertyNumber"] == 0) then
    --处理常规协议
	
	--电源
    if (keyP["powerValue"] ~= nil) then
		if (keyP["powerValue"] == keyB["BYTE_POWER_ON"]) then
			streams[keyT["KEY_POWER"]] = keyV["VALUE_FUNCTION_ON"]
		elseif (keyP["powerValue"] == keyB["BYTE_POWER_OFF"]) then
			streams[keyT["KEY_POWER"]] = keyV["VALUE_FUNCTION_OFF"]
		end
	end
    
    --模式
    if (keyP["modeValue"] ~= nil) then
		if (keyP["modeValue"] == keyB["BYTE_MODE_HEAT"]) then
			streams[keyT["KEY_MODE"]] = keyV["VALUE_MODE_HEAT"]
		elseif (keyP["modeValue"] == keyB["BYTE_MODE_COOL"]) then
			streams[keyT["KEY_MODE"]] = keyV["VALUE_MODE_COOL"]
		elseif (keyP["modeValue"] == keyB["BYTE_MODE_AUTO"]) then
			streams[keyT["KEY_MODE"]] = keyV["VALUE_MODE_AUTO"]
		elseif (keyP["modeValue"] == keyB["BYTE_MODE_DRY"]) then
			streams[keyT["KEY_MODE"]] = keyV["VALUE_MODE_DRY"]
			if(keyP["smartDryValue"] ~= nil and keyP["smartDryValue"] >= 30 and  keyP["smartDryValue"] <= 101) then
				streams[keyT["KEY_SMART_DRY"]] = keyP["smartDryValue"]
			end
		elseif (keyP["modeValue"] == keyB["BYTE_MODE_FAN"]) then
			streams[keyT["KEY_MODE"]] = keyV["VALUE_MODE_FAN"]
		elseif (keyP["modeValue"] == keyB["BYTE_MODE_SMART_DRY"]) then
			streams[keyT["KEY_MODE"]] = keyV["VALUE_MODE_SMART_DRY"]
			if(keyP["smartDryValue"] ~= nil and keyP["smartDryValue"] >= 30 and  keyP["smartDryValue"] <= 101) then
				streams[keyT["KEY_SMART_DRY"]] = keyP["smartDryValue"]
			end
		end
	end
    
    --净化
	if (keyP["purifierValue"] ~= nil) then
		if (keyP["purifierValue"] == keyB["BYTE_PURIFIER_ON"]) then
			streams[keyT["KEY_PURIFIER"]] = keyV["VALUE_FUNCTION_ON"]
		elseif (keyP["purifierValue"] == keyB["BYTE_PURIFIER_OFF"]) then
			streams[keyT["KEY_PURIFIER"]] = keyV["VALUE_FUNCTION_OFF"]
		end
	end
    
    --ECO
	if (keyP["ecoValue"] ~= nil) then
		if (keyP["ecoValue"] == keyB["BYTE_ECO_ON"]) then
			streams[keyT["KEY_ECO"]] = keyV["VALUE_FUNCTION_ON"]
		elseif (keyP["ecoValue"] == keyB["BYTE_ECO_OFF"]) then
			streams[keyT["KEY_ECO"]] = keyV["VALUE_FUNCTION_OFF"]
		end
	end
    
    --干燥
	if ((keyP["dryValue"] ~= nil) and (keyP["modeValue"] ~= nil)) then
		if (keyP["dryValue"] == keyB["BYTE_DRY_ON"]) then
			streams[keyT["KEY_DRY"]] = keyV["VALUE_FUNCTION_ON"]
		else
			streams[keyT["KEY_DRY"]] = keyV["VALUE_FUNCTION_OFF"]
		end
	end
    
    --风速
	if (keyP["fanspeedValue"] ~= nil) then
		streams[keyT["KEY_FANSPEED"]] = keyP["fanspeedValue"]
	end

    --室外温度
	if ((keyP["outdoorTemperatureValue"] ~= nil) and (keyP["smallOutdoorTemperatureValue"] ~= nil)) then
		streams[keyV["VALUE_OUTDOOR_TEMPERATURE"]] = keyP["outdoorTemperatureValue"] +keyP["smallOutdoorTemperatureValue"]/10
    end

    --室内温度
	if ((keyP["indoorTemperatureValue"] ~= nil) and (keyP["smallIndoorTemperatureValue"] ~= nil)) then
		streams[keyV["VALUE_INDOOR_TEMPERATURE"]] = keyP["indoorTemperatureValue"]+keyP["smallIndoorTemperatureValue"]/10
    end

    --上下扫风
	if (keyP["swingUDValue"] ~= nil) then
		if (keyP["swingUDValue"] == keyB["BYTE_SWING_UD_ON"]) then
			streams[keyT["KEY_SWING_UD"]] = keyV["VALUE_FUNCTION_ON"]
		elseif (keyP["swingUDValue"] == keyB["BYTE_SWING_UD_OFF"]) then
			streams[keyT["KEY_SWING_UD"]] = keyV["VALUE_FUNCTION_OFF"]
		end
	end
    
    --左右扫风
	if (keyP["swingLRValue"] ~= nil) then
		if (keyP["swingLRValue"] == keyB["BYTE_SWING_LR_ON"]) then
			streams[keyT["KEY_SWING_LR"]] = keyV["VALUE_FUNCTION_ON"]
		elseif (keyP["swingLRValue"] == keyB["BYTE_SWING_LR_OFF"]) then
			streams[keyT["KEY_SWING_LR"]] = keyV["VALUE_FUNCTION_OFF"]
		end
	end
	
	--下左右扫风
	if (keyP["swingLRUnderSwitch"] == keyB["BYTE_SWING_LR_UNDER_ENABLE"]) then
        if (keyP["swingLRValueUnder"] == keyB["BYTE_SWING_LR_UNDER_ON"]) then
            streams[keyT["KEY_SWING_LR_UNDER"]] = keyV["VALUE_FUNCTION_ON"]
        elseif (keyP["swingLRValueUnder"] == keyB["BYTE_SWING_LR_UNDER_OFF"]) then
            streams[keyT["KEY_SWING_LR_UNDER"]] = keyV["VALUE_FUNCTION_OFF"]
        end
    else
        streams[keyT["KEY_SWING_LR_UNDER"]] = streams[keyT["KEY_SWING_LR"]]
    end
    
    --电辅热
	if ((keyP["PTCValue"] ~= nil) and (keyP["modeValue"] ~= nil )) then
		if (keyP["PTCValue"] == keyB["BYTE_PTC_ON"]) and ((keyP["modeValue"] == keyB["BYTE_MODE_AUTO"]) or (keyP["modeValue"] == keyB["BYTE_MODE_HEAT"])) then
			streams[keyT["KEY_PTC"]] = keyV["VALUE_FUNCTION_ON"]
		elseif (keyP["PTCValue"] == keyB["BYTE_PTC_OFF"]) then
			streams[keyT["KEY_PTC"]] = keyV["VALUE_FUNCTION_OFF"]
		end
	end
	
	--单独电辅热
	if (keyP["independent_ptc"] ~= nil) then
		if (keyP["independent_ptc"] == 0x01) then
			streams["independent_ptc"] = keyV["VALUE_FUNCTION_ON"]
		elseif (keyP["independent_ptc"] == 0x00) then
			streams["independent_ptc"] = keyV["VALUE_FUNCTION_OFF"]
		end
	end
	
	--定时开
	if (keyP["openTimerSwitch"] ~= nil) then
		if (keyP["openTimerSwitch"] == keyB["BYTE_START_TIMER_SWITCH_ON"]) then
			streams[keyT["KEY_TIME_ON"]] = keyV["VALUE_FUNCTION_ON"]
		elseif (keyP["openTimerSwitch"] == keyB["BYTE_START_TIMER_SWITCH_OFF"]) then
				streams[keyT["KEY_TIME_ON"]] = keyV["VALUE_FUNCTION_OFF"]
		end
	end

	--定时关
	if (keyP["closeTimerSwitch"] ~= nil) then
		if (keyP["closeTimerSwitch"] == keyB["BYTE_CLOSE_TIMER_SWITCH_ON"]) then
			streams[keyT["KEY_TIME_OFF"]] = keyV["VALUE_FUNCTION_ON"]
		elseif (keyP["closeTimerSwitch"] == keyB["BYTE_CLOSE_TIMER_SWITCH_OFF"]) then
			streams[keyT["KEY_TIME_OFF"]] = keyV["VALUE_FUNCTION_OFF"]
		end
	end
    
    --定时关机时间
	if (keyP["closeTimerSwitch"] ~= nil) then
		if (keyP["closeTimerSwitch"] == keyB["BYTE_CLOSE_TIMER_SWITCH_OFF"]) then
			streams[keyT["KEY_CLOSE_TIME"]] = 0
		else
			streams[keyT["KEY_CLOSE_TIME"]] = keyP["closeTime"]
		end
	end

    --定时开机时间
	if (keyP["openTimerSwitch"] ~= nil) then
		if (keyP["openTimerSwitch"] == keyB["BYTE_START_TIMER_SWITCH_OFF"]) then
			streams[keyT["KEY_OPEN_TIME"]] = 0
		else
			streams[keyT["KEY_OPEN_TIME"]] = keyP["openTime"]
		end
	end
    
    --本次开机运行时间
	if(keyP["currentWorkTime"] ~= nil) then
		streams[keyT["KEY_CURRENT_WORK_TIME"]] = keyP["currentWorkTime"]
	end

	--强劲
	if (keyP["strongWindValue"] ~= nil) then
		if (keyP["strongWindValue"] == keyB["BYTE_STRONG_WIND_ON"]) then
			streams[keyT["KEY_STRONG_WIND"]] = keyV["VALUE_FUNCTION_ON"]
		elseif (keyP["strongWindValue"] == keyB["BYTE_STRONG_WIND_OFF"]) then
			streams[keyT["KEY_STRONG_WIND"]] = keyV["VALUE_FUNCTION_OFF"]
		end
	end

	--tubro(AB、AE强劲)
	if (keyP["tubroValue"] ~= nil) then
		if (keyP["tubroValue"] == 0x02) then
			streams[keyT["KEY_TUBRO"]] = keyV["VALUE_FUNCTION_ON"]
		elseif (keyP["tubroValue"] == 0x00) then
			streams[keyT["KEY_TUBRO"]] = keyV["VALUE_FUNCTION_OFF"]
		end
	end
	
	--省电
	if (keyP["power_saving"] ~= nil) then
		if (keyP["power_saving"] == 0x08) then
			streams["power_saving"] = keyV["VALUE_FUNCTION_ON"]
		elseif (keyP["power_saving"] == 0x00) then
			streams["power_saving"] = keyV["VALUE_FUNCTION_OFF"]
		end
	end
    
	--温度
	if(keyP["temperature"] ~= nil) then
		streams[keyT["KEY_TEMPERATURE"] ]= keyP["temperature"]
	end

	--温度小数位
	if(keyP["smallTemperature"] ~= nil) then
		if(keyP["smallTemperature"] == 0x01) then
			streams["small_temperature"] = 0.5
		else
			streams["small_temperature"] = 0
		end
	end

	--华氏温度处理
	if(keyP["temperature_unit"] ~= nil ) then
		if(keyP["temperature_unit"] == 1) then
			streams[keyT["KEY_TEMPERATURE"] ]= convert_to_F(keyP["temperature"] + streams["small_temperature"])
			streams["small_temperature"] = 0
			streams["temperature_unit"] = 1
		else
			streams["temperature_unit"] = 0
		end
	end

    streams[keyT["KEY_ERROR_CODE"]]=keyP["errorCode"]
	
	--是否踢被子
	if(keyP["kickQuilt"] ~= nil) then
		if(keyP["kickQuilt"] == 0x00) then
			streams["kick_quilt"] = "off"
		elseif(keyP["kickQuilt"] == 0x01) then
			streams["kick_quilt"] = "on"
		end
	end
	
	--舒省
	if(keyP["comfortPowerSave"] ~= nil) then
		if(keyP["comfortPowerSave"] == 0x00) then
			streams["comfort_power_save"] = "off"
		elseif(keyP["comfortPowerSave"] == 0x01) then
			streams["comfort_power_save"] = "on"
		end
	end

	--无风感
	if(keyP["no_wind_sense"] ~= nil) then
		streams["no_wind_sense"] = keyP["no_wind_sense"]
	end
	
	--远近无风感
	if(keyP["fa_no_wind_sense"] ~= nil) then
		streams["fa_no_wind_sense"] = keyP["fa_no_wind_sense"]
	end
	
	--无风感等级
	if(keyP["no_wind_sense_level"] ~= nil) then
	    streams["no_wind_sense_level"] = keyP["no_wind_sense_level"]
	end

		
	--防着凉
	if(keyP["preventCold"] ~= nil) then
		if(keyP["preventCold"] == 0x00) then
			streams["prevent_cold"] = "off"
		elseif(keyP["preventCold"] == 0x01) then
			streams["prevent_cold"] = "on"
		end
	end
		
	--8度制热
	if(keyP["degree8_heat"] ~= nil) then
	    streams["degree8_heat"] = keyP["degree8_heat"]
	end
	
	--舒睡
	if(keyP["comfortableSleepValue"] ~= nil) then
	    if(keyP["comfortableSleepValue"] == 0x00 and keyP["comfortableSleepSwitch"] == 0x00) then
		    streams["comfort_sleep"] = "off"
		elseif(keyP["comfortableSleepValue"] == 0x03 and keyP["comfortableSleepSwitch"] == 0x40) then
		    streams["comfort_sleep"] = "on"
		end
	end
	
	--屏显状态
	if(keyP["screenDisplayNowValue"] ~= nil) then
		if(keyP["screenDisplayNowValue"] == 0x07) then
			streams["screen_display_now"] = "off"
		else
			streams["screen_display_now"] = "on"
		end
	end
	
	--自然风
	if(keyP["naturalWind"] ~= nil) then
		if(keyP["naturalWind"] == 0x02) then
			streams["natural_wind"] = "on"
		elseif(keyP["naturalWind"] == 0x00) then
			streams["natural_wind"] = "off"
		end
	end
	
	--pmv
	if(keyP["pmv"] ~= nil) then
		streams["pmv"] = keyP["pmv"]
	end
	
	--新风滤网总时长
	if(keyP["fresh_filter_time_total"] ~= nil) then
		streams["fresh_filter_time_total"] = keyP["fresh_filter_time_total"]
	end
	
	--新风滤网使用时长
	if(keyP["fresh_filter_time_use"] ~= nil) then
		streams["fresh_filter_time_use"] = keyP["fresh_filter_time_use"]
	end
	
	--新风滤网超时标志
	if(keyP["fresh_filter_timeout"] ~= nil) then
		streams["fresh_filter_timeout"] = keyP["fresh_filter_timeout"]
	end
	--新风滤网超时标志AE2
	if(keyP["fresh_filter_timeout_ae2"] ~= nil) then
		streams["fresh_filter_timeout_ae2"] = keyP["fresh_filter_timeout_ae2"]
	end
	
	if(keyP["real_time_power"] ~= nil) then
		streams["real_time_power"] = keyP["real_time_power"]
	end
	if(keyP["real_time_power_10"] ~= nil) then
		streams["real_time_power_10"] = keyP["real_time_power_10"]
	end
	if(keyP["current_humidity"] ~= nil) then
		streams["current_humidity"] = keyP["current_humidity"]
	end
	if(keyP["sleep_status"] ~= nil) then
		streams["sleep_status"] = keyP["sleep_status"]
	end
	if(keyP["machine_type"] ~= nil) then
		streams["machine_type"] = keyP["machine_type"]
	end

	else
		--新协议，变长属性控制协议
		if(keyP["prevent_super_cool"] ~= nil) then
			if(keyP["prevent_super_cool"] == 0x00) then
				streams["prevent_super_cool"] = "off"
			elseif(keyP["prevent_super_cool"] == 0x01) then
				streams["prevent_super_cool"] = "on"
			end
		end
		if(keyP["prevent_straight_wind"] ~= nil) then
			streams["prevent_straight_wind"] = keyP["prevent_straight_wind"]
		end
		if(keyP["prevent_straight_wind_flag"] ~= nil) then
			streams["prevent_straight_wind_flag"] = keyP["prevent_straight_wind_flag"]
		end
		if(keyP["fa_no_wind_sense"] ~= nil) then
			streams["fa_no_wind_sense"] = keyP["fa_no_wind_sense"]
		end
		if(keyP["auto_prevent_straight_wind"] ~= nil) then
			if(keyP["auto_prevent_straight_wind"] == 0x00) then
				streams["auto_prevent_straight_wind"] = "off"
			elseif(keyP["auto_prevent_straight_wind"] == 0x01) then
				streams["auto_prevent_straight_wind"] = "on"
			end
		end
		if(keyP["self_clean"] ~= nil) then
			if(keyP["self_clean"] == 0x00) then
				streams["self_clean"] = "off"
			elseif(keyP["self_clean"] == 0x01) then
				streams["self_clean"] = "on"
			end
		end
		if(keyP["wind_straight"] ~= nil) then
			if(keyP["wind_straight"] == 0x00) then
				streams["wind_straight"] = "off"
			elseif(keyP["wind_straight"] == 0x01) then
				streams["wind_straight"] = "on"
			end
		end
		if(keyP["yb_wind_avoid"] ~= nil) then
			if(keyP["yb_wind_avoid"] == 0x00) then
				streams["yb_wind_avoid"] = "off"
			elseif(keyP["yb_wind_avoid"] == 0x02) then
				streams["yb_wind_avoid"] = "on"
			end
		end
		if(keyP["wind_avoid"] ~= nil) then
			if(keyP["wind_avoid"] == 0x00) then
				streams["wind_avoid"] = "off"
			elseif(keyP["wind_avoid"] == 0x01 or keyP["wind_avoid"] == 0x02) then
				streams["wind_avoid"] = "on"
			end
		end
		if(keyP["intelligent_wind"] ~= nil) then
			if(keyP["intelligent_wind"] == 0x00) then
				streams["intelligent_wind"] = "off"
			elseif(keyP["intelligent_wind"] == 0x01) then
				streams["intelligent_wind"] = "on"
			end
		end
		if(keyP["child_prevent_cold_wind"] ~= nil) then
			if(keyP["child_prevent_cold_wind"] == 0x00) then
				streams["child_prevent_cold_wind"] = "off"
			elseif(keyP["child_prevent_cold_wind"] == 0x01) then
				streams["child_prevent_cold_wind"] = "on"
			end
		end
		if(keyP["no_wind_sense"] ~= nil) then
			streams["no_wind_sense"] = keyP["no_wind_sense"]
		end
		if(keyP["no_wind_sense_level"] ~= nil) then
	        streams["no_wind_sense_level"] = keyP["no_wind_sense_level"]
	    end
		if(keyP["little_angel"] ~= nil) then
			if(keyP["little_angel"] == 0x00) then
				streams["little_angel"] = "off"
			elseif(keyP["little_angel"] == 0x01) then
				streams["little_angel"] = "on"
			end
		end
		if(keyP["cool_hot_sense"] ~= nil) then
			if(keyP["cool_hot_sense"] == 0x00) then
				streams["cool_hot_sense"] = "off"
			elseif(keyP["cool_hot_sense"] == 0x01) then
				streams["cool_hot_sense"] = "on"
			end
		end
		if(keyP["gentle_wind_sense"] ~= nil) then
			if(keyP["gentle_wind_sense"] == 0x01) then
				streams["gentle_wind_sense"] = "off"
			elseif(keyP["gentle_wind_sense"] == 0x03) then
				streams["gentle_wind_sense"] = "on"
			end
		end
		if(keyP["security"] ~= nil) then 
			if(keyP["security"] == 0x00) then 
			streams["security"] = "off" 
			elseif(keyP["security"] == 0x01) then 
			streams["security"] = "on"
			end
		end
		if(keyP["even_wind"] ~= nil) then 
			if(keyP["even_wind"] == 0x00) then 
			streams["even_wind"] = "off" 
			elseif(keyP["even_wind"] == 0x01) then 
			streams["even_wind"] = "on"
			end
		end
		if(keyP["single_tuyere"] ~= nil) then 
			if(keyP["single_tuyere"] == 0x00) then 
			streams["single_tuyere"] = "off" 
			elseif(keyP["single_tuyere"] == 0x01) then 
			streams["single_tuyere"] = "on"
			end
		end
		if(keyP["extreme_wind"] ~= nil) then 
			if(keyP["extreme_wind"] == 0x00) then 
			streams["extreme_wind"] = "off" 
			elseif(keyP["extreme_wind"] == 0x01) then 
			streams["extreme_wind"] = "on"
			end
			
			streams["extreme_wind_level"] =  keyP["extreme_wind_level"]
		end
		if(keyP["wind_swing_ud_angle"] ~= nil) then 
			streams["wind_swing_ud_angle"] = keyP["wind_swing_ud_angle"]
		end
		if(keyP["wind_swing_lr_angle"] ~= nil) then 
			streams["wind_swing_lr_angle"] = keyP["wind_swing_lr_angle"]
		end
		if(keyP["voice_control"] ~= nil) then 
			if(keyP["voice_control"] == 0x00) then 
			streams["voice_control"] = "off" 
			elseif(keyP["voice_control"] == 0x03) then 
			streams["voice_control"] = "on"
			end
		end
		if(keyP["pre_cool_hot"] ~= nil) then 
			if(keyP["pre_cool_hot"] == 0x00) then 
			streams["pre_cool_hot"] = "off" 
			elseif(keyP["pre_cool_hot"] == 0x01) then 
			streams["pre_cool_hot"] = "on"
			end
		end
		if(keyP["water_washing"] ~= nil) then 
			if(keyP["water_washing"] == 0x01) then 
			streams["water_washing"] = "on" 
			elseif(keyP["water_washing"] == 0x00) then 
			streams["water_washing"] = "off"
			end
			
			streams["water_washing_manual"] = keyP["water_washing_manual"]
			streams["water_washing_time"] = keyP["water_washing_time"]
			streams["water_washing_stage"] = keyP["water_washing_stage"]
		end
		if(keyP["fresh_air"] ~= nil) then 
			if(keyP["fresh_air"] == 0x00) then 
			streams["fresh_air"] = "off" 
			elseif(keyP["fresh_air"] == 0x01) then 
			streams["fresh_air"] = "on"
			end
			
			streams["fresh_air_fan_speed"] = keyP["fresh_air_fan_speed"]
			streams["fresh_air_temp"] = keyP["fresh_air_temp"]
		end
		if(keyP["parent_control"] ~= nil) then 
			if(keyP["parent_control"] == 0x00) then 
			streams["parent_control"] = "off" 
			elseif(keyP["parent_control"] == 0x01) then 
			streams["parent_control"] = "on"
			end
			
			streams["parent_control_temp_up"] = keyP["parent_control_temp_up"]
			streams["parent_control_temp_down"] = keyP["parent_control_temp_down"]
		end
		if(keyP["nobody_energy_save"] ~= nil) then 
			if(keyP["nobody_energy_save"] == 0x00) then 
			streams["nobody_energy_save"] = "off" 
			elseif(keyP["nobody_energy_save"] == 0x01) then 
			streams["nobody_energy_save"] = "on"
			end
		end
		if(keyP["filter_value"] ~= nil) then 
			streams["filter_value"] = keyP["filter_value"]
			streams["filter_level"] = keyP["filter_level"]
		end
		if(keyP["prevent_straight_wind_lr"] ~= nil) then 
			streams["prevent_straight_wind_lr"] = keyP["prevent_straight_wind_lr"]
		end
		if(keyP["pm25_value"] ~= nil) then 
			streams["pm25_value"] = keyP["pm25_value"]
		end
		if(keyP["water_pump"] ~= nil) then 
			if(keyP["water_pump"] == 0x00) then 
			streams["water_pump"] = "off" 
			elseif(keyP["water_pump"] == 0x01) then 
			streams["water_pump"] = "on"
			end
		end
		if(keyP["intelligent_control"] ~= nil) then 
			if(keyP["intelligent_control"] == 0x00) then 
			streams["intelligent_control"] = "off" 
			elseif(keyP["intelligent_control"] == 0x01) then 
			streams["intelligent_control"] = "on"
			end
		end
		if(keyP["volume_control"] ~= nil) then 
			streams["volume_control"] = keyP["volume_control"]
		end
		if(keyP["voice_control_new"] ~= nil) then 
			streams["voice_control_new"] = keyP["voice_control_new"]
		end
		if(keyP["face_register"] ~= nil) then 
			streams["face_register"] = keyP["face_register"]
		end
		if(keyP["cool_temp_up"] ~= nil) then 
	        streams["cool_temp_up"] = keyP["cool_temp_up"]
		end
		if(keyP["cool_temp_down"] ~= nil) then 
			streams["cool_temp_down"] = keyP["cool_temp_down"]
		end
		if(keyP["auto_temp_up"] ~= nil) then 
			streams["auto_temp_up"] = keyP["auto_temp_up"]
		end
		if(keyP["auto_temp_down"] ~= nil) then 
			streams["auto_temp_down"] = keyP["auto_temp_down"]
		end
		if(keyP["heat_temp_up"] ~= nil) then 
			streams["heat_temp_up"] = keyP["heat_temp_up"]
		end
		if(keyP["heat_temp_down"] ~= nil) then 
			streams["heat_temp_down"] = keyP["heat_temp_down"]
		end
		if(keyP["remote_control_lock"] ~= nil) then
		    streams["remote_control_lock"] = keyP["remote_control_lock"]
		end
		if(keyP["remote_control_lock_control"] ~= nil) then
		     streams["remote_control_lock_control"] = keyP["remote_control_lock_control"]
		end
		if(keyP["operating_time"] ~= nil) then
		    streams["operating_time"] = keyP["operating_time"]
		end
		if(keyP["indoor_humidity"] ~= nil) then
		    streams["indoor_humidity"] = keyP["indoor_humidity"]
		end
		if(keyP["rate_select"] ~= nil) then
		    streams["rate_select"] = keyP["rate_select"]
		end
		if(keyP["main_horizontal_guide_strip_2"] ~= nil) then
		    streams["main_horizontal_guide_strip_2"] = keyP["main_horizontal_guide_strip_2"]
		end
		if(keyP["main_horizontal_guide_strip_1"] ~= nil) then
		    streams["main_horizontal_guide_strip_1"] = keyP["main_horizontal_guide_strip_1"]
		end
		if(keyP["main_horizontal_guide_strip_3"] ~= nil) then
		    streams["main_horizontal_guide_strip_3"] = keyP["main_horizontal_guide_strip_3"]
		end
		if(keyP["main_horizontal_guide_strip_4"] ~= nil) then
		    streams["main_horizontal_guide_strip_4"] = keyP["main_horizontal_guide_strip_4"]
		end
		if(keyP["sup_horizontal_guide_strip_1"] ~= nil) then
		    streams["sup_horizontal_guide_strip_1"] = keyP["sup_horizontal_guide_strip_1"]
		end
		if(keyP["sup_horizontal_guide_strip_2"] ~= nil) then
		    streams["sup_horizontal_guide_strip_2"] = keyP["sup_horizontal_guide_strip_2"]
		end
		if(keyP["sup_horizontal_guide_strip_3"] ~= nil) then
		    streams["sup_horizontal_guide_strip_3"] = keyP["sup_horizontal_guide_strip_3"]
		end
		if(keyP["sup_horizontal_guide_strip_4"] ~= nil) then
		    streams["sup_horizontal_guide_strip_4"] = keyP["sup_horizontal_guide_strip_4"]
		end
		if(keyP["twins_machine"] ~= nil) then
		    streams["twins_machine"] = keyP["twins_machine"]
		end
		if(keyP["guide_strip_type"] ~= nil) then
		    streams["guide_strip_type"] = keyP["guide_strip_type"]
		end
		if(keyP["b5_mode"] ~= nil) then
		    streams["b5_mode"] = keyP["b5_mode"]
		end
		if(keyP["b5_strong_wind"] ~= nil) then
		    streams["b5_strong_wind"] = keyP["b5_strong_wind"]
		end
		if(keyP["b5_wind_speed"] ~= nil) then
		    streams["b5_wind_speed"] = keyP["b5_wind_speed"]
		end
		if(keyP["b5_humidity"] ~= nil) then
		    streams["b5_humidity"] = keyP["b5_humidity"]
		end
		if(keyP["b5_temperature_0"] ~= nil) then
		    streams["b5_temperature_0"] = keyP["b5_temperature_0"]
		end
		if(keyP["b5_temperature_1"] ~= nil) then
		    streams["b5_temperature_1"] = keyP["b5_temperature_1"]
		end
		if(keyP["b5_temperature_2"] ~= nil) then
		    streams["b5_temperature_2"] = keyP["b5_temperature_2"]
		end
		if(keyP["b5_temperature_3"] ~= nil) then
		    streams["b5_temperature_3"] = keyP["b5_temperature_3"]
		end
		if(keyP["b5_temperature_4"] ~= nil) then
		    streams["b5_temperature_4"] = keyP["b5_temperature_4"]
		end
		if(keyP["b5_temperature_5"] ~= nil) then
		    streams["b5_temperature_5"] = keyP["b5_temperature_5"]
		end
		if(keyP["b5_temperature_6"] ~= nil) then
		    streams["b5_temperature_6"] = keyP["b5_temperature_6"]
		end
		if(keyP["b5_eco"] ~= nil) then
		    streams["b5_eco"] = keyP["b5_eco"]
		end
		if(keyP["b5_filter_remind"] ~= nil) then
		    streams["b5_filter_remind"] = keyP["b5_filter_remind"]
		end
		if(keyP["b5_filter_check"] ~= nil) then
		    streams["b5_filter_check"] = keyP["b5_filter_check"]
		end
		if(keyP["b5_fahrenheit"] ~= nil) then
		    streams["b5_fahrenheit"] = keyP["b5_fahrenheit"]
		end
		if(keyP["b5_8_heat"] ~= nil) then
		    streams["b5_8_heat"] = keyP["b5_8_heat"]
		end
		if(keyP["b5_electricity"] ~= nil) then
		    streams["b5_electricity"] = keyP["b5_electricity"]
		end
		if(keyP["b5_ptc"] ~= nil) then
		    streams["b5_ptc"] = keyP["b5_ptc"]
		end
		if(keyP["b5_wind_straight"] ~= nil) then
		    streams["b5_wind_straight"] = keyP["b5_wind_straight"]
		end
		if(keyP["b5_wind_avoid"] ~= nil) then
		    streams["b5_wind_avoid"] = keyP["b5_wind_avoid"]
		end
		if(keyP["b5_wind_swing"] ~= nil) then
		    streams["b5_wind_swing"] = keyP["b5_wind_swing"]
		end
		if(keyP["b5_no_wind_sense"] ~= nil) then
		    streams["b5_no_wind_sense"] = keyP["b5_no_wind_sense"]
		end
		if(keyP["b5_screen_display"] ~= nil) then
		    streams["b5_screen_display"] = keyP["b5_screen_display"]
		end
		if(keyP["b5_anion"] ~= nil) then
		    streams["b5_anion"] = keyP["b5_anion"]
		end
		if(keyP["b5_self_clean"] ~= nil) then
		    streams["b5_self_clean"] = keyP["b5_self_clean"]
		end
		if(keyP["b5_fa_no_wind_sense"] ~= nil) then
		    streams["b5_fa_no_wind_sense"] = keyP["b5_fa_no_wind_sense"]
		end
		if(keyP["b5_nobody_energy_save"] ~= nil) then
		    streams["b5_nobody_energy_save"] = keyP["b5_nobody_energy_save"]
		end
		if(keyP["b5_prevent_straight_wind"] ~= nil) then
		    streams["b5_prevent_straight_wind"] = keyP["b5_prevent_straight_wind"]
		end
		if(keyP["jet_cool"] ~= nil) then
		    streams["jet_cool"] = keyP["jet_cool"]
		end
		if(keyP["b5_jet_cool"] ~= nil) then
		    streams["b5_jet_cool"] = keyP["b5_jet_cool"]
		end
		if(keyP["body_check"] ~= nil) then
		    streams["body_check"] = keyP["body_check"]
		end
		if(keyP["b5_body_check"] ~= nil) then
		    streams["b5_body_check"] = keyP["b5_body_check"]
		end
		if(keyP["b5_rate_select"] ~= nil) then
		    streams["b5_rate_select"] = keyP["b5_rate_select"]
		end
		if(keyP["b5_fresh_air"] ~= nil) then
		    streams["b5_fresh_air"] = keyP["b5_fresh_air"]
		end
		if(keyP["b5_wind_swing_lr_angle"] ~= nil) then
		    streams["b5_wind_swing_lr_angle"] = keyP["b5_wind_swing_lr_angle"]
		end
		if(keyP["b5_wind_swing_ud_angle"] ~= nil) then
		    streams["b5_wind_swing_ud_angle"] = keyP["b5_wind_swing_ud_angle"]
		end
		if(keyP["b5_main_horizontal_guide_strip_1"] ~= nil) then
		    streams["b5_main_horizontal_guide_strip_1"] = keyP["b5_main_horizontal_guide_strip_1"]
		end
		if(keyP["b5_main_horizontal_guide_strip_2"] ~= nil) then
		    streams["b5_main_horizontal_guide_strip_2"] = keyP["b5_main_horizontal_guide_strip_2"]
		end
		if(keyP["b5_main_horizontal_guide_strip_3"] ~= nil) then
		    streams["b5_main_horizontal_guide_strip_3"] = keyP["b5_main_horizontal_guide_strip_3"]
		end
		if(keyP["b5_main_horizontal_guide_strip_4"] ~= nil) then
		    streams["b5_main_horizontal_guide_strip_4"] = keyP["b5_main_horizontal_guide_strip_4"]
		end
		if(keyP["b5_sup_horizontal_guide_strip_3"] ~= nil) then
		    streams["b5_sup_horizontal_guide_strip_3"] = keyP["b5_sup_horizontal_guide_strip_3"]
		end
		if(keyP["b5_sup_horizontal_guide_strip_4"] ~= nil) then
		    streams["b5_sup_horizontal_guide_strip_4"] = keyP["b5_sup_horizontal_guide_strip_4"]
		end
		if(keyP["b5_sup_horizontal_guide_strip_2"] ~= nil) then
		    streams["b5_sup_horizontal_guide_strip_2"] = keyP["b5_sup_horizontal_guide_strip_2"]
		end
		if(keyP["b5_sup_horizontal_guide_strip_1"] ~= nil) then
		    streams["b5_sup_horizontal_guide_strip_1"] = keyP["b5_sup_horizontal_guide_strip_1"]
		end
		if(keyP["b5_twins_machine"] ~= nil) then
		    streams["b5_twins_machine"] = keyP["b5_twins_machine"]
		end
		if(keyP["b5_guide_strip_type"] ~= nil) then
		    streams["b5_guide_strip_type"] = keyP["b5_guide_strip_type"]
		end
		if(keyP["sound"] ~= nil) then
		    streams["sound"] = keyP["sound"]
		end
		if(keyP["b5_sound"] ~= nil) then
		    streams["b5_sound"] = keyP["b5_sound"]
		end
		if(keyP["anion"] ~= nil) then
		    streams["anion"] = keyP["anion"]
		end
		if(keyP["b5_anion"] ~= nil) then
		    streams["b5_anion"] = keyP["b5_anion"]
		end
		if(keyP["b5_parent_control"] ~= nil) then
		    streams["b5_parent_control"] = keyP["b5_parent_control"]
		end
		if(keyP["b5_ieco_switch"] ~= nil) then
		    streams["b5_ieco_switch"] = keyP["b5_ieco_switch"]
		end
		if(keyP["ieco_switch"] ~= nil) then
		    streams["ieco_switch"] = keyP["ieco_switch"]
		end
		if(keyP["ieco_target_rate"] ~= nil) then
		    streams["ieco_target_rate"] = keyP["ieco_target_rate"]
		end
		if(keyP["ieco_indoor_wind_speed"] ~= nil) then
		    streams["ieco_indoor_wind_speed"] = keyP["ieco_indoor_wind_speed"]
		end
		if(keyP["ieco_outdoor_wind_speed"] ~= nil) then
		    streams["ieco_outdoor_wind_speed"] = keyP["ieco_outdoor_wind_speed"]
		end
		if(keyP["ieco_expansion_valve"] ~= nil) then
		    streams["ieco_expansion_valve"] = keyP["ieco_expansion_valve"]
		end
		if(keyP["ieco_frame"] ~= nil) then
		    streams["ieco_frame"] = keyP["ieco_frame"]
		end
		if(keyP["ieco_number"] ~= nil) then
		    streams["ieco_number"] = keyP["ieco_number"]
		end
		if(keyP["wind_around"] ~= nil) then
		    streams["wind_around"] = keyP["wind_around"]
		end
		if(keyP["wind_around_ud"] ~= nil) then
		    streams["wind_around_ud"] = keyP["wind_around_ud"]
		end
		if(keyP["b5_wind_around"] ~= nil) then
		    streams["b5_wind_around"] = keyP["b5_wind_around"]
		end
		if(keyP["prevent_straight_wind_select"] ~= nil) then
		    streams["prevent_straight_wind_select"] = keyP["prevent_straight_wind_select"]
		end
		if(keyP["b5_prevent_straight_wind_select"] ~= nil) then
		    streams["b5_prevent_straight_wind_select"] = keyP["b5_prevent_straight_wind_select"]
		end
		if(keyP["mito_cool"] ~= nil) then
		    streams["mito_cool"] = keyP["mito_cool"]
		end
		if(keyP["mito_heat"] ~= nil) then
		    streams["mito_heat"] = keyP["mito_heat"]
		end
		if(keyP["dr_time"] ~= nil) then
		    streams["dr_time"] = keyP["dr_time"]
		end
		if(keyP["dr_time_hour"] ~= nil) then
		    streams["dr_time_hour"] = keyP["dr_time_hour"]
		end
		if(keyP["dr_time_min"] ~= nil) then
		    streams["dr_time_min"] = keyP["dr_time_min"]
		end
		if(keyP["has_cool_heat_amount"] ~= nil) then
		    streams["has_cool_heat_amount"] = keyP["has_cool_heat_amount"]
		end
		if(keyP["t2_heat"] ~= nil) then
		    streams["t2_heat"] = keyP["t2_heat"]
		end
		if(keyP["tp_heat"] ~= nil) then
		    streams["tp_heat"] = keyP["tp_heat"]
		end
		if(keyP["k1_value"] ~= nil) then
		    streams["k1_value"] = keyP["k1_value"]
		end
		if(keyP["k2_value"] ~= nil) then
		    streams["k2_value"] = keyP["k2_value"]
		end
		if(keyP["k3_value"] ~= nil) then
		    streams["k3_value"] = keyP["k3_value"]
		end
		if(keyP["k4_value"] ~= nil) then
		    streams["k4_value"] = keyP["k4_value"]
		end
		if(keyP["cool_strong_wind_speed"] ~= nil) then
		    streams["cool_strong_wind_speed"] = keyP["cool_strong_wind_speed"]
		end
		if(keyP["cool_strong_wind_amount"] ~= nil) then
		    streams["cool_strong_wind_amount"] = keyP["cool_strong_wind_amount"]
		end
		if(keyP["has_icheck"] ~= nil) then
		    streams["has_icheck"] = keyP["has_icheck"]
		end
		if(keyP["b5_has_icheck"] ~= nil) then
		    streams["b5_has_icheck"] = keyP["b5_has_icheck"]
		end
		if(keyP["b5_emergent_heat_wind"] ~= nil) then
		    streams["b5_emergent_heat_wind"] = keyP["b5_emergent_heat_wind"]
		end
		if(keyP["b5_heat_ptc_wind"] ~= nil) then
		    streams["b5_heat_ptc_wind"] = keyP["b5_heat_ptc_wind"]
		end
		if(keyP["cvp"] ~= nil) then
		    streams["cvp"] = keyP["cvp"]
		end
		if(keyP["b5_cvp"] ~= nil) then
		    streams["b5_cvp"] = keyP["b5_cvp"]
		end
	end
	keyP["propertyNumber"] = 0
	keyP["prevent_super_cool"] = nil 
	keyP["prevent_straight_wind"] = nil 
	keyP["auto_prevent_straight_wind"] = nil 
	keyP["prevent_straight_wind_flag"] = nil
	keyP["wind_straight"] = nil 
	keyP["wind_avoid"] = nil 
	keyP["yb_wind_avoid"] = nil
	keyP["intelligent_wind"] = nil 
	keyP["self_clean"] = nil 
	keyP["no_wind_sense"] = nil 
	keyP["no_wind_sense_level"] = nil
	keyP["fn_no_wind_sense"] = nil
	keyP["child_prevent_cold_wind"] = nil 
	keyP["little_angel"] = nil 
	keyP["cool_hot_sense"] = nil 
	keyP["gentle_wind_sense"] = nil 
	keyP["prevent_straight_wind_fa"] = nil 
	keyP["no_wind_sense_fa"] = nil 
	keyP["security"] = nil 
	keyP["even_wind"] = nil
	keyP["single_tuyere"] = nil
	keyP["extreme_wind"] = nil
	keyP["extreme_wind_level"] = nil
	keyP["voice_control"] = nil
	keyP["pre_cool_hot"] = nil
	keyP["water_washing"] = nil
	keyP["fresh_air"] = nil
	keyP["fa_prevent_straight_wind"] = nil
	keyP["parent_control"] = nil
	keyP["parent_control_temp_up"] = nil
	keyP["parent_control_temp_down"] = nil
	keyP["nobody_energy_save"] = nil
	keyP["filter_value"] = nil
	keyP["filter_level"] = nil
	keyP["prevent_straight_wind_lr"] = nil
	keyP["pm25_value"] = nil
	keyP["water_pump"] = nil
	keyP["intelligent_control"] = nil
	keyP["volume_control"] = nil
	keyP["voice_control_new"] = nil
	keyP["wind_swing_ud_angle"] = nil
	keyP["wind_swing_lr_angle"] = nil
	keyP["face_register"] = nil
	keyP["cool_temp_up"] = nil
	keyP["cool_temp_down"] = nil
	keyP["auto_temp_up"] = nil
	keyP["auto_temp_down"] = nil
	keyP["heat_temp_up"] = nil
	keyP["heat_temp_down"] = nil
	keyP["remote_control_lock"] = nil
	keyP["remote_control_lock_control"] = nil
	keyP["operating_time"] = nil
	keyP["indoor_humidity"] = nil
	keyP["rate_select"] = nil
	keyP["b5_mode"] = nil
	keyP["b5_strong_wind"] = nil
	keyP["b5_wind_speed"] = nil
	keyP["b5_humidity"] = nil
	keyP["b5_temperature_0"] = nil
	keyP["b5_temperature_1"] = nil
	keyP["b5_temperature_2"] = nil
	keyP["b5_temperature_3"] = nil
	keyP["b5_temperature_4"] = nil
	keyP["b5_temperature_5"] = nil
	keyP["b5_temperature_6"] = nil
	keyP["b5_eco"] = nil
	keyP["b5_filter_remind"] = nil
	keyP["b5_filter_check"] = nil
	keyP["b5_fahrenheit"] = nil
	keyP["b5_8_heat"] = nil
	keyP["b5_electricity"] = nil
	keyP["b5_ptc"] = nil
	keyP["b5_wind_straight"] = nil
	keyP["b5_wind_avoid"] = nil
	keyP["b5_wind_swing"] = nil
	keyP["b5_no_wind_sense"] = nil
	keyP["b5_screen_display"] = nil
	keyP["b5_anion"] = nil
	keyP["b5_self_clean"] = nil
	keyP["b5_fa_no_wind_sense"] = nil
	keyP["b5_nobody_energy_save"] = nil
	keyP["b5_prevent_straight_wind"] = nil
	keyP["real_time_power"] = nil
	keyP["real_time_power_10"] = nil
	keyP["current_humidity"] = nil
	keyP["jet_cool"] = nil
	keyP["b5_jet_cool"] = nil
	keyP["body_check"] = nil
	keyP["b5_body_check"] = nil
	keyP["b5_rate_select"] = nil
	keyP["b5_fresh_air"] = nil
	keyP["b5_wind_swing_lr_angle"] = nil
	keyP["b5_wind_swing_ud_angle"] = nil
	keyP["main_horizontal_guide_strip_1"] = nil
	keyP["main_horizontal_guide_strip_2"] = nil
	keyP["main_horizontal_guide_strip_3"] = nil
	keyP["main_horizontal_guide_strip_4"] = nil
	keyP["sup_horizontal_guide_strip_1"] = nil
	keyP["sup_horizontal_guide_strip_2"] = nil
	keyP["sup_horizontal_guide_strip_3"] = nil
	keyP["sup_horizontal_guide_strip_4"] = nil
	keyP["twins_machine"] = nil
	keyP["guide_strip_type"] = nil
	keyP["b5_main_horizontal_guide_strip_1"] = nil
	keyP["b5_main_horizontal_guide_strip_2"] = nil
	keyP["b5_main_horizontal_guide_strip_3"] = nil
	keyP["b5_main_horizontal_guide_strip_4"] = nil
	keyP["b5_sup_horizontal_guide_strip_1"] = nil
	keyP["b5_sup_horizontal_guide_strip_2"] = nil
	keyP["b5_sup_horizontal_guide_strip_3"] = nil
	keyP["b5_sup_horizontal_guide_strip_4"] = nil
	keyP["b5_twins_machine"] = nil
	keyP["b5_guide_strip_type"] = nil
	keyP["b5_sound"] = nil
	keyP["sound"] = nil
	keyP["b5_anion"] = nil
	keyP["anion"] = nil
	keyP["machine_type"] = nil
	keyP["independent_ptc"] = nil
	keyP["fa_no_wind_sense"] = nil
	keyP["b5_parent_control"] = nil
	keyP["ieco_switch"] = nil
	keyP["ieco_target_rate"] = nil
	keyP["ieco_indoor_wind_speed"] = nil
	keyP["ieco_outdoor_wind_speed"] = nil
	keyP["ieco_expansion_valve"] = nil
	keyP["ieco_frame"] = nil
	keyP["ieco_number"] = nil
	keyP["b5_ieco_switch"] = nil
	keyP["wind_around"] = nil
	keyP["wind_around_ud"] = nil
	keyP["b5_wind_around"] = nil
	keyP["prevent_straight_wind_select"] = nil
	keyP["b5_prevent_straight_wind_select"] = nil
	keyP["mito_cool"] = nil
	keyP["mito_heat"] = nil
	keyP["dr_time"] = nil
	keyP["dr_time_hour"] = nil
	keyP["dr_time_min"] = nil
    keyP["t2_heat"] = nil
	keyP["tp_heat"] = nil
	keyP["k1_value"] = nil
	keyP["k2_value"] = nil
	keyP["k3_value"] = nil
	keyP["k4_value"] = nil
	keyP["cool_strong_wind_speed"] = nil
	keyP["cool_strong_wind_amount"] = nil
	keyP["has_cool_heat_amount"] = nil
	keyP["has_icheck"] = nil
	keyP["b5_has_icheck"] = nil
	keyP["b5_emergent_heat_wind"] = nil
	keyP["b5_heat_ptc_wind"] = nil
	keyP["cvp"] = nil
	keyP["b5_cvp"] = nil
	local retTable = {}
    retTable["status"] = streams
    local ret = encode(retTable)
    return ret
end


