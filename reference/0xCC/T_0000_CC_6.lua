local JSON = require 'cjson'
local KEY_VERSION = 'version'
local KEY_CMD_TYPE = 'cmd_type'
local KEY_POWER = 'power'
local KEY_MODE = 'mode'
local KEY_WIND_SPEED = 'wind_speed'
local KEY_TEMPERATURE = 'temperature'
local KEY_SMALL_TEMPERATURE = 'small_temperature'
local KEY_CONTROL_FAN_SPEED = 'control_fan_speed'
local KEY_PTC_SETTING = 'ptc_setting'
local KEY_PTC_POWER = 'ptc'
local KEY_EXHAUST = 'exhaust'
local KEY_WIND_UD = 'wind_swing_ud'
local KEY_ECO = 'eco'
local KEY_WIND_SWING_LR = 'wind_swing_lr'
local KEY_WIND_SWING_UD_SITE = 'wind_swing_ud_site'
local KEY_WIND_SWING_LR_SITE = 'wind_swing_lr_site'
local KEY_POWER_OFF_TIME = 'power_off_time_value'
local KEY_POWER_ON_TIME = 'power_on_time_value'
local KEY_SLEEP_SWITCH = 'sleep_switch'
local KEY_DIGIT_DISPLAY_SWITCH = 'digit_display_switch'
local KEY_INDOOR_TEMPERATURE = 'indoor_temperature'
local KEY_EVAPORATOR_ENTRANCE_TEMPERATURE = 'evaporator_entrance_temperature'
local KEY_EVAPORATOR_EXIT_TEMPERATURE = 'evaporator_exit_temperature'
local KEY_ERROR_FROM_MACHINE_STYLE = 'error_from_machine_style'
local KEY_ERROR_CODE = 'error_code'

local VALUE_VERSION = '6'
local VALUE_CMD_COMMON = 'cmd_common'
local VALUE_CMD_LOCK = 'cmd_lock'
local VALUE_CMD_SMART = 'cmd_smart'
local VALUE_CMD_QUERY_COMMON = 'cmd_query_common'
local VALUE_CMD_NOT_SUPPORT = 'cmd_not_support'
local VALUE_MODE_AUTO = 'auto'
local VALUE_MODE_COOL = 'cool'
local VALUE_MODE_HEAT = 'heat'
local VALUE_MODE_DRY = 'dry'
local VALUE_MODE_FAN = 'fan'
local VALUE_WIND_AUTO = 'auto'
local VALUE_WIND_POWER = 'power'
local VALUE_WIND_SUPER_HIGH = 'super_high'
local VALUE_WIND_HIGH = 'high'
local VALUE_WIND_MIDDLE = 'middle'
local VALUE_WIND_LOW = 'low'
local VALUE_WIND_MICRON = 'micron'
local VALUE_WIND_SLEEP = 'sleep'
local VALUE_PTC_SETTING_AUTO = 'ptc_setting_auto'
local VALUE_PTC_SETTING_ON = 'ptc_setting_on'
local VALUE_PTC_SETTING_OFF = 'ptc_setting_off'
local VALUE_ON = 'on'
local VALUE_OFF = 'off'
local VALUE_SWING_UD_NO_SITE = 'swing_ud_no_site'
local VALUE_SWING_UD_SITE1 = 'swing_ud_site_1'
local VALUE_SWING_UD_SITE2 = 'swing_ud_site_2'
local VALUE_SWING_UD_SITE3 = 'swing_ud_site_3'
local VALUE_SWING_UD_SITE4 = 'swing_ud_site_4'
local VALUE_SWING_UD_SITE5 = 'swing_ud_site_5'
local VALUE_SWING_UD_SITE6 = 'swing_ud_site_6'
local VALUE_SWING_LR_NO_SITE = 'swing_lr_no_site'
local VALUE_SWING_LR_SITE1 = 'swing_lr_site_1'
local VALUE_SWING_LR_SITE2 = 'swing_lr_site_2'
local VALUE_SWING_LR_SITE3 = 'swing_lr_site_3'
local VALUE_SWING_LR_SITE4 = 'swing_lr_site_4'
local VALUE_SWING_LR_SITE5 = 'swing_lr_site_5'
local VALUE_SWING_LR_SITE6 = 'swing_lr_site_6'
local VALUE_ERROR_FROM_OUTSIDE_MACHINE = 'error_from_outside_machine'
local VALUE_ERROR_FROM_INSIDE_MACHINE = 'error_from_inside_machine'

local BYTE_DEVICE_TYPE = 0xCC
local BYTE_CONTROL_REQUEST = 0x02
local BYTE_QUERY_STATUS_REQUEST = 0x03
local BYTE_PROTOCOL_HEAD = 0xAA
local BYTE_PROTOCOL_LENGTH = 0x0A
local BYTE_CMD_COMMON = 0xC3
local BYTE_CMD_LOCK = 0xB0
local BYTE_CMD_SMART = 0xE0
local BYTE_CMD_QUERY_COMMON = 0x01
local BYTE_CMD_NOT_SUPPORT = 0xD0
local BYTE_POWER_ON = 0x80
local BYTE_POWER_OFF = 0x00
local BYTE_MODE_AUTO = 0x10
local BYTE_MODE_COOL = 0x08
local BYTE_MODE_HEAT = 0x04
local BYTE_MODE_DRY = 0x02
local BYTE_MODE_FAN = 0x01
local BYTE_FANSPEED_AUTO = 0x80
local BYTE_FANSPEED_POWER = 0x40
local BYTE_FANSPEED_SUPER_HIGH = 0x20
local BYTE_FANSPEED_HIGH = 0x10
local BYTE_FANSPEED_MID = 0x08
local BYTE_FANSPEED_LOW = 0x04
local BYTE_FANSPEED_MICRON = 0x02
local BYTE_FANSPEED_SLEEP = 0x01
local BYTE_TEMPERATURE_MIN = 0x11
local BYTE_TEMPERATURE_MAX = 0x1E
local BYTE_PTC_SETTING_AUTO = 0x00
local BYTE_PTC_SETTING_ON = 0x10
local BYTE_PTC_SETTING_OFF = 0x20
local BYTE_PTC_POWER_ON = 0x02
local BYTE_PTC_POWER_OFF = 0x00
local BYTE_EXHAUST_ON = 0x08
local BYTE_EXHAUST_OFF = 0x00
local BYTE_SWING_UD_ON = 0x04
local BYTE_SWING_UD_OFF = 0x00
local BYTE_SWING_UD_NO_SITE = 0x00
local BYTE_SWING_UD_SITE1 = 0x01
local BYTE_SWING_UD_SITE2 = 0x02
local BYTE_SWING_UD_SITE3 = 0x03
local BYTE_SWING_UD_SITE4 = 0x04
local BYTE_SWING_UD_SITE5 = 0x05
local BYTE_SWING_UD_SITE6 = 0x06
local BYTE_ECO_ON = 0x01
local BYTE_ECO_OFF = 0x00
local BYTE_SWING_LR_ON = 0x01
local BYTE_SWING_LR_OFF = 0x00
local BYTE_SWING_LR_NO_SITE = 0x00
local BYTE_SWING_LR_SITE1 = 0x01
local BYTE_SWING_LR_SITE2 = 0x02
local BYTE_SWING_LR_SITE3 = 0x03
local BYTE_SWING_LR_SITE4 = 0x04
local BYTE_SWING_LR_SITE5 = 0x05
local BYTE_SWING_LR_SITE6 = 0x06
local BYTE_SLEEP_ON = 0x10
local BYTE_SLEEP_OFF = 0x00
local BYTE_DIGIT_DISPLAY_ON = 0x08
local BYTE_DIGIT_DISPLAY_OFF = 0x00

local cmdType
local powerValue
local modeValue
local fanspeedValue
local controlFanspeedValue
local temperatureValue
local swingUDSwitchValue
local ecoSwitchValue
local swingLRSwitchValue
local swingUDSiteValue = 0
local swingLRSiteValue = 0
local temperatureDecimals
local totlaTemperature
local PTCSettingValue = 0
local PTCValue = 0
local ecoValue = 0
local exhaustValue = 0
local sleepSwitchValue
local digitDisplaySwitchValue
local closeTime
local openTime
local indoorTemperature
local evaporatorEntranceTemp
local evaporatorExitTemp
local errorCodeMachineStyle
local errorHigh
local errorLow
local errorCode = 0
local isCanDecimals = 0
local dataType = 0

function jsonToModel(jsonCmd)
    local streams = jsonCmd
    if (streams[KEY_CMD_TYPE] == VALUE_CMD_COMMON) then
        cmdType = BYTE_CMD_COMMON
    elseif (streams[KEY_CMD_TYPE] == VALUE_CMD_LOCK) then
        cmdType = BYTE_CMD_LOCK
    elseif (streams[KEY_CMD_TYPE] == VALUE_CMD_SMART) then
        cmdType = BYTE_CMD_SMART
    end
    if (streams[KEY_POWER] == VALUE_ON) then
        powerValue = BYTE_POWER_ON
    elseif (streams[KEY_POWER] == VALUE_OFF) then
        powerValue = BYTE_POWER_OFF
    end
    if (streams[KEY_MODE] == VALUE_MODE_AUTO) then
        modeValue = BYTE_MODE_AUTO
    elseif (streams[KEY_MODE] == VALUE_MODE_COOL) then
        modeValue = BYTE_MODE_COOL
    elseif (streams[KEY_MODE] == VALUE_MODE_HEAT) then
        modeValue = BYTE_MODE_HEAT
    elseif (streams[KEY_MODE] == VALUE_MODE_DRY) then
        modeValue = BYTE_MODE_DRY
    elseif (streams[KEY_MODE] == VALUE_MODE_FAN) then
        modeValue = BYTE_MODE_FAN
    end
    if (streams[KEY_PTC_SETTING] == VALUE_PTC_SETTING_AUTO) then
        PTCSettingValue = BYTE_PTC_SETTING_AUTO
    elseif (streams[KEY_PTC_SETTING] == VALUE_PTC_SETTING_ON) then
        PTCSettingValue = BYTE_PTC_SETTING_ON
    elseif (streams[KEY_PTC_SETTING] == VALUE_PTC_SETTING_OFF) then
        PTCSettingValue = BYTE_PTC_SETTING_OFF
    end
    if (streams[KEY_EXHAUST] == VALUE_ON) then
        exhaustValue = BYTE_EXHAUST_ON
    elseif (streams[KEY_EXHAUST] == VALUE_OFF) then
        exhaustValue = BYTE_EXHAUST_OFF
    end
    if (streams[KEY_ECO] == VALUE_ON) then
        ecoValue = BYTE_ECO_ON
    elseif (streams[KEY_ECO] == VALUE_OFF) then
        ecoValue = BYTE_ECO_OFF
    end
    if (streams[KEY_WIND_UD] == VALUE_ON) then
        swingUDSwitchValue = BYTE_SWING_UD_ON
    elseif (streams[KEY_WIND_UD] == VALUE_OFF) then
        swingUDSwitchValue = BYTE_SWING_UD_OFF
    end
    if (streams[KEY_WIND_SWING_UD_SITE] == VALUE_SWING_UD_NO_SITE) then
        swingUDSiteValue = BYTE_SWING_UD_NO_SITE
    elseif (streams[KEY_WIND_SWING_UD_SITE] == VALUE_SWING_UD_SITE1) then
        swingUDSiteValue = BYTE_SWING_UD_SITE1
    elseif (streams[KEY_WIND_SWING_UD_SITE] == VALUE_SWING_UD_SITE2) then
        swingUDSiteValue = BYTE_SWING_UD_SITE2
    elseif (streams[KEY_WIND_SWING_UD_SITE] == VALUE_SWING_UD_SITE3) then
        swingUDSiteValue = BYTE_SWING_UD_SITE3
    elseif (streams[KEY_WIND_SWING_UD_SITE] == VALUE_SWING_UD_SITE4) then
        swingUDSiteValue = BYTE_SWING_UD_SITE4
    elseif (streams[KEY_WIND_SWING_UD_SITE] == VALUE_SWING_UD_SITE5) then
        swingUDSiteValue = BYTE_SWING_UD_SITE5
    elseif (streams[KEY_WIND_SWING_UD_SITE] == VALUE_SWING_UD_SITE6) then
        swingUDSiteValue = BYTE_SWING_UD_SITE6
    end
    if (streams[KEY_WIND_SWING_LR] == VALUE_ON) then
        swingLRSwitchValue = BYTE_SWING_LR_ON
    elseif (streams[KEY_WIND_SWING_LR] == VALUE_OFF) then
        swingLRSwitchValue = BYTE_SWING_LR_OFF
    end
    if (streams[KEY_WIND_SWING_LR_SITE] == VALUE_SWING_UD_NO_SITE) then
        swingLRSiteValue = BYTE_SWING_LR_NO_SITE
    elseif (streams[KEY_WIND_SWING_LR_SITE] == VALUE_SWING_UD_SITE1) then
        swingLRSiteValue = BYTE_SWING_LR_SITE1
    elseif (streams[KEY_WIND_SWING_LR_SITE] == VALUE_SWING_UD_SITE2) then
        swingLRSiteValue = BYTE_SWING_LR_SITE2
    elseif (streams[KEY_WIND_SWING_LR_SITE] == VALUE_SWING_UD_SITE3) then
        swingLRSiteValue = BYTE_SWING_LR_SITE3
    elseif (streams[KEY_WIND_SWING_LR_SITE] == VALUE_SWING_UD_SITE4) then
        swingLRSiteValue = BYTE_SWING_LR_SITE4
    elseif (streams[KEY_WIND_SWING_LR_SITE] == VALUE_SWING_UD_SITE5) then
        swingLRSiteValue = BYTE_SWING_LR_SITE5
    elseif (streams[KEY_WIND_SWING_LR_SITE] == VALUE_SWING_UD_SITE6) then
        swingLRSiteValue = BYTE_SWING_LR_SITE6
    end
    if (streams[KEY_SLEEP_SWITCH] == VALUE_ON) then
        sleepSwitchValue = BYTE_SLEEP_ON
    elseif (streams[KEY_SLEEP_SWITCH] == VALUE_OFF) then
        sleepSwitchValue = BYTE_SLEEP_OFF
    end
    if (streams[KEY_DIGIT_DISPLAY_SWITCH] == VALUE_ON) then
        digitDisplaySwitchValue = BYTE_DIGIT_DISPLAY_ON
    elseif (streams[KEY_DIGIT_DISPLAY_SWITCH] == VALUE_OFF) then
        digitDisplaySwitchValue = BYTE_DIGIT_DISPLAY_OFF
    end
    if (streams[KEY_WIND_SPEED] == VALUE_WIND_AUTO) then
        fanspeedValue = BYTE_FANSPEED_AUTO
    elseif (streams[KEY_WIND_SPEED] == VALUE_WIND_POWER) then
        fanspeedValue = BYTE_FANSPEED_POWER
    elseif (streams[KEY_WIND_SPEED] == VALUE_WIND_SUPER_HIGH) then
        fanspeedValue = BYTE_FANSPEED_SUPER_HIGH
    elseif (streams[KEY_WIND_SPEED] == VALUE_WIND_HIGH) then
        fanspeedValue = BYTE_FANSPEED_HIGH
    elseif (streams[KEY_WIND_SPEED] == VALUE_WIND_MIDDLE) then
        fanspeedValue = BYTE_FANSPEED_MID
    elseif (streams[KEY_WIND_SPEED] == VALUE_WIND_LOW) then
        fanspeedValue = BYTE_FANSPEED_LOW
    elseif (streams[KEY_WIND_SPEED] == VALUE_WIND_MICRON) then
        fanspeedValue = BYTE_FANSPEED_MICRON
    elseif (streams[KEY_WIND_SPEED] == VALUE_WIND_SLEEP) then
        fanspeedValue = BYTE_FANSPEED_SLEEP
    end
    if (streams[KEY_TEMPERATURE] ~= nil) then
        temperatureValue = checkBoundary(streams[KEY_TEMPERATURE], 17, 30)
    end
    if (streams[KEY_SMALL_TEMPERATURE] ~= nil) then
        temperatureDecimals = checkBoundary(streams[KEY_SMALL_TEMPERATURE], 0, 0.9)
    end
    controlFanspeedValue = 0xFF
    if (streams[KEY_POWER_OFF_TIME] ~= nil) then
        closeTime = string2Int(streams[KEY_POWER_OFF_TIME])
    end
    if (streams[KEY_POWER_ON_TIME] ~= nil) then
        openTime = string2Int(streams[streams[KEY_POWER_ON_TIME]])
    end
end
local function binToModel(binData)
    if (#binData < 23) then
        return nil
    end
    local messageBytes = binData
    if (dataType == 0x02 or dataType == 0x03 or dataType == 0x04 or dataType == 0x05) then
        cmdType = messageBytes[0]
        if ((cmdType == BYTE_CMD_COMMON) or (cmdType == BYTE_CMD_QUERY_COMMON)) then
            powerValue = bit.band(messageBytes[1], 0x80)
            modeValue = bit.band(messageBytes[1], 0x1F)
            fanspeedValue = messageBytes[2]
            temperatureValue = messageBytes[3]
            indoorTemperature = messageBytes[4]
            evaporatorEntranceTemp = messageBytes[5]
            evaporatorExitTemp = messageBytes[6]
            swingUDSiteValue = messageBytes[9]
            openTime = messageBytes[10]
            closeTime = messageBytes[11]
            exhaustValue = bit.band(messageBytes[13], 0x08)
            swingUDSwitchValue = bit.band(messageBytes[13], 0x04)
            PTCValue = bit.band(messageBytes[13], 0x02)
            ecoValue = bit.band(messageBytes[13], 0x01)
            PTCSettingValue = bit.band(messageBytes[14], 0x60)
            sleepSwitchValue = bit.band(messageBytes[14], 0x10)
            digitDisplaySwitchValue = bit.band(messageBytes[14], 0x08)
            swingLRSwitchValue = bit.band(messageBytes[14], 0x01)
            controlFanspeedValue = 0xFF
            swingLRSiteValue = messageBytes[17]
            temperatureDecimals = messageBytes[19]
            errorCodeMachineStyle = bit.band(messageBytes[18], 0x80)
            errorHigh = bit.band(messageBytes[18], 0x7F)
            errorLow = messageBytes[15]
            isCanDecimals = bit.rshift(bit.band(messageBytes[14], 0x80), 7)
        elseif (cmdType == BYTE_CMD_LOCK) then
            lockWindLevel = messageBytes[1]
            errorCode = messageBytes[4]
            if (messageBytes[5] ~= 0xFF) then
                lockCoolTemp = messageBytes[5]
            end
            if (messageBytes[6] ~= 0xFF) then
                lockCoolTemp = messageBytes[6]
            end
        elseif (cmdType == BYTE_CMD_SMART) then
            smartFunction = messageBytes[1]
        elseif (cmdType == BYTE_CMD_NOT_SUPPORT) then
            return nil
        end
    end
end

function jsonToData(jsonCmd)
    if (#jsonCmd == 0) then
        return nil
    end
    local infoM = {}
    local bodyBytes = {}
    local json = decode(jsonCmd)
    local deviceSubType = json['deviceinfo']['deviceSubType']
    if (deviceSubType == 1) then
    end
    local query = json['query']
    local control = json['control']
    local status = json['status']
    if (query) then
        for i = 0, 23 do
            bodyBytes[i] = 0
        end
        bodyBytes[0] = 0x01
        math.randomseed(tostring(os.time()):reverse():sub(1, 6))
        bodyBytes[22] = math.random(0, 100)
        bodyBytes[23] = crc8_854(bodyBytes, 0, 22)
        infoM = getTotalMsg(bodyBytes, BYTE_QUERY_STATUS_REQUEST)
    elseif (control) then
        if (status) then
            jsonToModel(status)
        end
        if (control) then
            jsonToModel(control)
        end
        for i = 0, 23 do
            bodyBytes[i] = 0
        end
        bodyBytes[0] = 0xC3
        bodyBytes[1] = bit.bor(bit.band(powerValue, 0x80), bit.band(modeValue, 0x1F))
        bodyBytes[2] = fanspeedValue
        bodyBytes[3] = temperatureValue
        if ((openTime == nil) or (openTime == 3825)) then
            openTime = 0
        end
        bodyBytes[4] = math.floor(openTime / 15)
        if ((closeTime == nil) or (closeTime == 3825)) then
            closeTime = 0
        end
        bodyBytes[5] = math.floor(closeTime / 15)
        bodyBytes[6] = bit.bor(
                bit.bor(bit.band(ecoValue, 0x01), bit.band(swingUDSwitchValue, 0x04)),
                bit.bor(bit.band(exhaustValue, 0x08), bit.band(PTCSettingValue, 0x30))
        )
        bodyBytes[7] = 0xFF
        bodyBytes[8] = bit.bor(
                bit.bor(bit.band(sleepSwitchValue, 0x10), bit.band(digitDisplaySwitchValue, 0x08)),
                bit.band(swingLRSwitchValue, 0x01)
        )
        bodyBytes[9] = swingLRSiteValue
        bodyBytes[10] = swingUDSiteValue
        bodyBytes[11] = temperatureDecimals * 10
        math.randomseed(tostring(os.time()):reverse():sub(1, 6))
        bodyBytes[22] = math.random(0, 100)
        bodyBytes[23] = crc8_854(bodyBytes, 0, 22)
        infoM = getTotalMsg(bodyBytes, BYTE_CONTROL_REQUEST)
    end
    local ret = table2string(infoM)
    ret = string2hexstring(ret)
    return ret
end

function getTotalMsg(bodyData, cType)
    local bodyLength = #bodyData
    local msgLength = bodyLength + BYTE_PROTOCOL_LENGTH + 1
    local msgBytes = {}
    for i = 0, msgLength do
        msgBytes[i] = 0
    end
    msgBytes[0] = BYTE_PROTOCOL_HEAD
    msgBytes[1] = bodyLength + BYTE_PROTOCOL_LENGTH + 1
    msgBytes[2] = BYTE_DEVICE_TYPE
    msgBytes[9] = cType
    for i = 0, bodyLength do
        msgBytes[i + BYTE_PROTOCOL_LENGTH] = bodyData[i]
    end
    msgBytes[msgLength] = makeSum(msgBytes, 1, msgLength - 1)
    local msgFinal = {}
    for i = 1, msgLength + 1 do
        msgFinal[i] = msgBytes[i - 1]
    end
    return msgFinal
end

function dataToJson(jsonCmd)
    if (not jsonCmd) then
        return nil
    end
    local json = decode(jsonCmd)
    local deviceinfo = json['deviceinfo']
    local deviceSubType = deviceinfo['deviceSubtype']
    if (deviceSubType == 1) then
    end
    local status = json['status']
    if (status) then
        jsonToModel(status)
    end
    local binData = json['msg']['data']
    local info = {}
    local msgBytes = {}
    local bodyBytes = {}
    local msgLength = 0
    local bodyLength = 0
    info = string2table(binData)
    dataType = info[10]
    for i = 1, #info do
        msgBytes[i - 1] = info[i]
    end
    msgLength = msgBytes[1]
    bodyLength = msgLength - BYTE_PROTOCOL_LENGTH - 1
    for i = 0, bodyLength do
        bodyBytes[i] = msgBytes[i + BYTE_PROTOCOL_LENGTH]
    end
    binToModel(bodyBytes)
    local streams = {}
    streams[KEY_VERSION] = VALUE_VERSION
    if (cmdType == BYTE_CMD_COMMON) then
        streams[KEY_CMD_TYPE] = VALUE_CMD_COMMON
    elseif (cmdType == BYTE_CMD_LOCK) then
        streams[KEY_CMD_TYPE] = VALUE_CMD_LOCK
    elseif (cmdType == BYTE_CMD_SMART) then
        streams[KEY_CMD_TYPE] = VALUE_CMD_SMART
    elseif (cmdType == BYTE_CMD_QUERY_COMMON) then
        streams[KEY_CMD_TYPE] = VALUE_CMD_QUERY_COMMON
    elseif (cmdType == BYTE_CMD_NOT_SUPPORT) then
        streams[KEY_CMD_TYPE] = VALUE_CMD_NOT_SUPPORT
    end
    if ((cmdType == BYTE_CMD_COMMON) or (cmdType == BYTE_CMD_QUERY_COMMON)) then
        if (powerValue == BYTE_POWER_ON) then
            streams[KEY_POWER] = VALUE_ON
        elseif (powerValue == BYTE_POWER_OFF) then
            streams[KEY_POWER] = VALUE_OFF
        end
        if (modeValue == BYTE_MODE_AUTO) then
            streams[KEY_MODE] = VALUE_MODE_AUTO
        elseif (modeValue == BYTE_MODE_COOL) then
            streams[KEY_MODE] = VALUE_MODE_COOL
        elseif (modeValue == BYTE_MODE_HEAT) then
            streams[KEY_MODE] = VALUE_MODE_HEAT
        elseif (modeValue == BYTE_MODE_DRY) then
            streams[KEY_MODE] = VALUE_MODE_DRY
        elseif (modeValue == BYTE_MODE_FAN) then
            streams[KEY_MODE] = VALUE_MODE_FAN
        end
        if (fanspeedValue == BYTE_FANSPEED_AUTO) then
            streams[KEY_WIND_SPEED] = VALUE_WIND_AUTO
        elseif (fanspeedValue == BYTE_FANSPEED_POWER) then
            streams[KEY_WIND_SPEED] = VALUE_WIND_POWER
        elseif (fanspeedValue == BYTE_FANSPEED_SUPER_HIGH) then
            streams[KEY_WIND_SPEED] = VALUE_WIND_SUPER_HIGH
        elseif (fanspeedValue == BYTE_FANSPEED_HIGH) then
            streams[KEY_WIND_SPEED] = VALUE_WIND_HIGH
        elseif (fanspeedValue == BYTE_FANSPEED_MID) then
            streams[KEY_WIND_SPEED] = VALUE_WIND_MIDDLE
        elseif (fanspeedValue == BYTE_FANSPEED_LOW) then
            streams[KEY_WIND_SPEED] = VALUE_WIND_LOW
        elseif (fanspeedValue == BYTE_FANSPEED_MICRON) then
            streams[KEY_WIND_SPEED] = VALUE_WIND_MICRON
        elseif (fanspeedValue == BYTE_FANSPEED_SLEEP) then
            streams[KEY_WIND_SPEED] = VALUE_WIND_SLEEP
        end
        streams[KEY_TEMPERATURE] = int2String(temperatureValue)
        streams[KEY_INDOOR_TEMPERATURE] = int2String((indoorTemperature - 40) / 2)
        streams[KEY_EVAPORATOR_ENTRANCE_TEMPERATURE] = int2String((evaporatorEntranceTemp - 40) / 2)
        streams[KEY_EVAPORATOR_EXIT_TEMPERATURE] = int2String((evaporatorExitTemp - 40) / 2)
        if (swingUDSiteValue == BYTE_SWING_UD_NO_SITE) then
            streams[KEY_WIND_SWING_UD_SITE] = VALUE_SWING_UD_NO_SITE
        elseif (swingUDSiteValue == BYTE_SWING_UD_SITE1) then
            streams[KEY_WIND_SWING_UD_SITE] = VALUE_SWING_UD_SITE1
        elseif (swingUDSiteValue == BYTE_SWING_UD_SITE2) then
            streams[KEY_WIND_SWING_UD_SITE] = VALUE_SWING_UD_SITE2
        elseif (swingUDSiteValue == BYTE_SWING_UD_SITE3) then
            streams[KEY_WIND_SWING_UD_SITE] = VALUE_SWING_UD_SITE3
        elseif (swingUDSiteValue == BYTE_SWING_UD_SITE4) then
            streams[KEY_WIND_SWING_UD_SITE] = VALUE_SWING_UD_SITE4
        elseif (swingUDSiteValue == BYTE_SWING_UD_SITE5) then
            streams[KEY_WIND_SWING_UD_SITE] = VALUE_SWING_UD_SITE5
        elseif (swingUDSiteValue == BYTE_SWING_UD_SITE6) then
            streams[KEY_WIND_SWING_UD_SITE] = VALUE_SWING_UD_SITE6
        end
        streams[KEY_POWER_ON_TIME] = int2String(openTime * 15)
        streams[KEY_POWER_OFF_TIME] = int2String(closeTime * 15)
        if (exhaustValue == BYTE_EXHAUST_ON) then
            streams[KEY_EXHAUST] = VALUE_ON
        elseif (exhaustValue == BYTE_EXHAUST_OFF) then
            streams[KEY_EXHAUST] = VALUE_OFF
        end
        if (swingUDSwitchValue == BYTE_SWING_UD_ON) then
            streams[KEY_WIND_UD] = VALUE_ON
        elseif (swingUDSwitchValue == BYTE_SWING_UD_OFF) then
            streams[KEY_WIND_UD] = VALUE_OFF
        end
        if (ecoValue == BYTE_ECO_ON) then
            streams[KEY_ECO] = VALUE_ON
        elseif (ecoValue == BYTE_ECO_OFF) then
            streams[KEY_ECO] = VALUE_OFF
        end
        if (sleepSwitchValue == BYTE_SLEEP_ON) then
            streams[KEY_SLEEP_SWITCH] = VALUE_ON
        elseif (sleepSwitchValue == BYTE_SLEEP_OFF) then
            streams[KEY_SLEEP_SWITCH] = VALUE_OFF
        end
        if (digitDisplaySwitchValue == BYTE_DIGIT_DISPLAY_ON) then
            streams[KEY_DIGIT_DISPLAY_SWITCH] = VALUE_ON
        elseif (digitDisplaySwitchValue == BYTE_DIGIT_DISPLAY_OFF) then
            streams[KEY_DIGIT_DISPLAY_SWITCH] = VALUE_OFF
        end
        if (swingLRSwitchValue == BYTE_SWING_LR_ON) then
            streams[KEY_WIND_SWING_LR] = VALUE_ON
        elseif (swingLRSwitchValue == BYTE_SWING_LR_OFF) then
            streams[KEY_WIND_SWING_LR] = VALUE_OFF
        end
        streams[KEY_CONTROL_FAN_SPEED] = controlFanspeedValue
        if (swingLRSiteValue == BYTE_SWING_LR_NO_SITE) then
            streams[KEY_WIND_SWING_LR_SITE] = VALUE_SWING_LR_NO_SITE
        elseif (swingLRSiteValue == BYTE_SWING_LR_SITE1) then
            streams[KEY_WIND_SWING_LR_SITE] = VALUE_SWING_LR_SITE1
        elseif (swingLRSiteValue == BYTE_SWING_LR_SITE2) then
            streams[KEY_WIND_SWING_LR_SITE] = VALUE_SWING_LR_SITE2
        elseif (swingLRSiteValue == BYTE_SWING_LR_SITE3) then
            streams[KEY_WIND_SWING_LR_SITE] = VALUE_SWING_LR_SITE3
        elseif (swingLRSiteValue == BYTE_SWING_LR_SITE4) then
            streams[KEY_WIND_SWING_LR_SITE] = VALUE_SWING_LR_SITE4
        elseif (swingLRSiteValue == BYTE_SWING_LR_SITE5) then
            streams[KEY_WIND_SWING_LR_SITE] = VALUE_SWING_LR_SITE5
        elseif (swingLRSiteValue == BYTE_SWING_LR_SITE6) then
            streams[KEY_WIND_SWING_LR_SITE] = VALUE_SWING_LR_SITE6
        end
        streams[KEY_SMALL_TEMPERATURE] = int2String(temperatureDecimals / 10)
        if (isCanDecimals == 0x00) then
            streams['support_decimals'] = 'on'
        elseif (isCanDecimals == 0x01) then
            streams['support_decimals'] = 'off'
        end
        if (errorCodeMachineStyle == 0x80) then
            streams[KEY_ERROR_FROM_MACHINE_STYLE] = VALUE_ERROR_FROM_OUTSIDE_MACHINE
        elseif (errorCodeMachineStyle == 0x00) then
            streams[KEY_ERROR_FROM_MACHINE_STYLE] = VALUE_ERROR_FROM_INSIDE_MACHINE
        end
        streams[KEY_ERROR_CODE] = int2String(errorHigh * 255 + errorLow)
        if (PTCSettingValue == 0x00) then
            streams[KEY_PTC_SETTING] = VALUE_PTC_SETTING_AUTO
        elseif (PTCSettingValue == 0x20) then
            streams[KEY_PTC_SETTING] = VALUE_PTC_SETTING_ON
        elseif (PTCSettingValue == 0x40) then
            streams[KEY_PTC_SETTING] = VALUE_PTC_SETTING_OFF
        end
        if (PTCValue == 0x02) then
            streams[KEY_PTC_POWER] = VALUE_ON
        elseif (PTCValue == 0x00) then
            streams[KEY_PTC_POWER] = VALUE_OFF
        end
    elseif (cmdType == BYTE_CMD_LOCK) then
    elseif (cmdType == BYTE_CMD_SMART) then
    end
    local retTable = {}
    retTable['status'] = streams
    local ret = encode(retTable)
    return ret
end

function print_lua_table(lua_table, indent)
    indent = indent or 0
    for k, v in pairs(lua_table) do
        if type(k) == 'string' then
            k = string.format('%q', k)
        end
        local szSuffix = ''
        if type(v) == 'table' then
            szSuffix = '{'
        end
        local szPrefix = string.rep('    ', indent)
        formatting = szPrefix .. '[' .. k .. ']' .. ' = ' .. szSuffix
        if type(v) == 'table' then
            print(formatting)
            print_lua_table(v, indent + 1)
            print(szPrefix .. '},')
        else
            local szValue = ''
            if type(v) == 'string' then
                szValue = string.format('%q', v)
            else
                szValue = tostring(v)
            end
            print(formatting .. szValue .. ',')
        end
    end
end

function checkBoundary(data, min, max)
    if (not data) then
        data = 0
    end
    data = tonumber(data)
    if (data == nil) then
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

function string2Int(data)
    if (not data) then
        data = tonumber('0')
    end
    data = tonumber(data)
    if (data == nil) then
        data = 0
    end
    return data
end

function int2String(data)
    if (not data) then
        data = tostring(0)
    end
    data = tostring(data)
    if (data == nil) then
        data = '0'
    end
    return data
end

function table2string(cmd)
    local ret = ''
    local i
    for i = 1, #cmd do
        ret = ret .. string.char(cmd[i])
    end
    return ret
end

function string2table(hexstr)
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

function string2hexstring(str)
    local ret = ''
    for i = 1, #str do
        ret = ret .. string.format('%02x', str:byte(i))
    end
    return ret
end

function encode(cmd)
    local tb
    if JSON == nil then
        JSON = require 'cjson'
    end
    tb = JSON.encode(cmd)
    return tb
end

function decode(cmd)
    local tb
    if JSON == nil then
        JSON = require 'cjson'
    end
    tb = JSON.decode(cmd)
    return tb
end

function makeSum(tmpbuf, start_pos, end_pos)
    local resVal = 0
    for si = start_pos, end_pos do
        resVal = resVal + tmpbuf[si]
        if resVal > 0xff then
            resVal = bit.band(resVal, 0xff)
        end
    end
    resVal = 255 - resVal + 1
    return resVal
end
local crc8_854_table = {
    0,
    94,
    188,
    226,
    97,
    63,
    221,
    131,
    194,
    156,
    126,
    32,
    163,
    253,
    31,
    65,
    157,
    195,
    33,
    127,
    252,
    162,
    64,
    30,
    95,
    1,
    227,
    189,
    62,
    96,
    130,
    220,
    35,
    125,
    159,
    193,
    66,
    28,
    254,
    160,
    225,
    191,
    93,
    3,
    128,
    222,
    60,
    98,
    190,
    224,
    2,
    92,
    223,
    129,
    99,
    61,
    124,
    34,
    192,
    158,
    29,
    67,
    161,
    255,
    70,
    24,
    250,
    164,
    39,
    121,
    155,
    197,
    132,
    218,
    56,
    102,
    229,
    187,
    89,
    7,
    219,
    133,
    103,
    57,
    186,
    228,
    6,
    88,
    25,
    71,
    165,
    251,
    120,
    38,
    196,
    154,
    101,
    59,
    217,
    135,
    4,
    90,
    184,
    230,
    167,
    249,
    27,
    69,
    198,
    152,
    122,
    36,
    248,
    166,
    68,
    26,
    153,
    199,
    37,
    123,
    58,
    100,
    134,
    216,
    91,
    5,
    231,
    185,
    140,
    210,
    48,
    110,
    237,
    179,
    81,
    15,
    78,
    16,
    242,
    172,
    47,
    113,
    147,
    205,
    17,
    79,
    173,
    243,
    112,
    46,
    204,
    146,
    211,
    141,
    111,
    49,
    178,
    236,
    14,
    80,
    175,
    241,
    19,
    77,
    206,
    144,
    114,
    44,
    109,
    51,
    209,
    143,
    12,
    82,
    176,
    238,
    50,
    108,
    142,
    208,
    83,
    13,
    239,
    177,
    240,
    174,
    76,
    18,
    145,
    207,
    45,
    115,
    202,
    148,
    118,
    40,
    171,
    245,
    23,
    73,
    8,
    86,
    180,
    234,
    105,
    55,
    213,
    139,
    87,
    9,
    235,
    181,
    54,
    104,
    138,
    212,
    149,
    203,
    41,
    119,
    244,
    170,
    72,
    22,
    233,
    183,
    85,
    11,
    136,
    214,
    52,
    106,
    43,
    117,
    151,
    201,
    74,
    20,
    246,
    168,
    116,
    42,
    200,
    150,
    21,
    75,
    169,
    247,
    182,
    232,
    10,
    84,
    215,
    137,
    107,
    53
}
function crc8_854(dataBuf, start_pos, end_pos)
    local crc = 0
    for si = start_pos, end_pos do
        crc = crc8_854_table[bit.band(bit.bxor(crc, dataBuf[si]), 0xFF) + 1]
    end
    return crc
end
