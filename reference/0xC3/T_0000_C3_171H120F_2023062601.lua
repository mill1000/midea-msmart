-- 集中采暖A&P系列线控器+WIFI协议解析
-- author: sunpeng,nieyj
-- email :sunpeng9@midea.com
-- date  : 2023-05-06
-- 命名规范: 全大写字母为常量
-- 修改记录
-- 2022-10-9  在两联供-T_0000_CF_000H120H_8.lua基础上修改文件名T_0000_C3_171H120F_1.lua
-- 2022-10-18 dataToJson修改能量参数中电量值,热量值;
-- 2022-10-20 1.V01版本基础上修改参数命名,数字放后,2.修改控制指令createControlCmd函数字节1-bit.band改为bit.bor;
-- 2022-10-21 修改silence_set_state为silence_on_state,增加eco_on_state，boostertbh_en；
-- 2022-10-24 修改totalelectricity0等计算方式，LUA5.1不支持位‘<<’直接操作；
-- 2022-11-02/03 增加protocol_newfunction_en字段,杀菌指令设置和查询,区域2定时信息(日定时、周定时，Holiday home)；
-- 2022-11-08 增加安装设定参数查询指令；
-- 2022-11-11/12 增加主机机组运行参数查询指令,线控器参数查询；
-- 2022-11-15 增加安装设定参数控制指令，当前可控制参数见协议中对应指令绿色底纹部分；
-- 2022-11-16 修订线控器参数查询指令，增加历史故障和服务商电话信息；
-- 2022-11-22 修订1.线控器查询参数-0x04外出休假,增加功能开关；2.线控器安装设定，线控器参数指令部分定义字段(key)，七处
-- 2022-11-23 修订'run_mode'为‘run_mode_set’，修订消息体子指令-0x01基本控制 增加区域1/2 温度曲线选择,0x07 ECO命令，增加ECO温度曲线；；
-- 2022-11-25 根据"protocol_newfunction_en"区分on-表示新版本，off-旧版本(不支持区域2控制解析)；当前LUA兼容已投产机型；
-- 2022-11-25 增加机组参数主动上报指令解析0x04-05，修改反馈控制回复解析问题；
-- 2022-11-30 增加机组参数主动上报指令解析0x04-05 系统能耗分析参数上报，安装设定参数指令增加上报时间设置；
-- 2022-12-1  增加机组参数主动上报指令解析0x04-05 pwmPumpOut参数,解决控制下发模式'dhw'解析异常；
-- 2022-12-2  删掉上报0402-解析"MSG_TYPE_UP_POWER2"，现有电控设备正常不会上报0402，但市场上报0402数据不清楚对应什么协议；
-- 2022-12-5  区分区域1/2 设定水温设定温度最大，最小值字段；
-- 2022-12-19 根据"protocol_newfunction_en"区分查询回复指令软件是否支持区域2定时信息，兼容已投产机型,protocol_newfunction_en为on-支持区域2定时信息；
-- 2023-01-31 室温设定温度room_temp_set，room_max_set_temp，room_min_set_temp，timeT4FreshC,timeT4FreshH,tPumpiDelay发送值=实际值*2改为LUA脚本处理，上行除以2，下行乘以2,同理gasCost，eleCost；
-- 2023-02-07 增加上行有符号整数数据处理； 
-- 2023-02-08 增加增加主动上报命令子类型字段msg_up_type； 
-- 2023-02-08 控制指令下发protocol_newfunction_en控制下发ON，针对新升级WIFI电控软件(V50A及以后)解析，off为兼容已投产软件(V49A)解析.
-- 2023-03-01 增加区分模式的能耗分析参数数据上报，系统支持能耗分析计算标志
-- 2023-03-06 1.安装设定参数指令增加 tbhEnFunc，2.新增控制指令增加protocol_newfunction_en对应字节解析，区分兼容新老插件;3.增加机组类型字段machVersion
-- 2023-03-12 1.protocol_newfunction_en 代表支持WiFi通讯协议V1.2-20230312版本，通过查询电控回复长度确认协议；2.修改04外出休假指令-byte 1新增开关标志位为byte8。
-- 2023-03-14 上版本boostertbh_en是否支持控制TBH解析误删，补充；
-- 2023-03-25 1.修改fanSpeed属性*10，2.powerIbh1,powerIbh2,powerTbh数据转化处理，3.有符号温度值数据处理，4.tbhEnFunc控制设定修改,5.增加房间温控器roomTherSetModeEn,dualroomThermostatEn设定
-- 2023-03-29 新增制热，冷，制热水模式 日、周、月、年  能耗数据。
-- 2023-04-15 增加 tank_actual_temp 参数处理
-- 2023-04-26 增加 线控器能耗分析设置-HMIEnergyAnaSetEN 参数上报
-- 2023-05-06 增加 线控器能耗分析设置-HMIEnergyAnaSetEN 参数基本参数回复，和主动上报
local JSON = require "cjson"
-- 版本号
local JSON_VERSION = "20"

-- bit0
local BIT0 = 0x01
-- bit1
local BIT1 = 0x02
-- bit2
local BIT2 = 0x04
-- bit3
local BIT3 = 0x08
-- bit4
local BIT4 = 0x10
-- bit5
local BIT5 = 0x20
-- bit6
local BIT6 = 0x40
-- bit7
local BIT7 = 0x80

--------------------------------------------------------------------- 通讯，均为整形变量 -----------------------
local cmdTable = {
	-- 设备类型(0xC3-集中采暖控制器,0xCF-中央空调暖家)
	["DEVICE_TYPE"] = 0xC3,
	-- M-smart协议头
	["PROTOCOL_HEAD"] = 0xAA,
	-- M-smart协议头长度
	["PROTOCOL_LENGTH"] = 0x0A,

	-- 设备控制命令
	["MSG_TYPE_CONTROL"] = 0x02,
	-- 设备控制命令-基本控制命令
	["MSG_TYPE_CONTROL_BASIC"] = 0x01,
	-- 设备控制命令-日定时控制命令
	["MSG_TYPE_CONTROL_DAY_TIMER"] = 0x02,
	-- 设备控制命令-周定时控制命令
	["MSG_TYPE_CONTROL_WEEKS_TIMER"] = 0x03,
	-- 设备控制命令-外出休假控制命令
	["MSG_TYPE_CONTROL_HOLIDAY_AWAY"] = 0x04,
	-- 设备控制命令-静音控制命令
	["MSG_TYPE_CONTROL_SILENCE"] = 0x05,
	-- 设备控制命令-在家休假控制命令
	["MSG_TYPE_CONTROL_HOLIDAY_HOME"] = 0x06,
	-- 设备控制命令-ECO控制命令
	["MSG_TYPE_CONTROL_ECO"] = 0x07,
	-- 设备控制命令-安装设定参数控制命令
	["MSG_TYPE_CONTROL_INSTALL"] = 0x08,
	-- 设备控制命令-杀菌控制命令
	["MSG_TYPE_CONTROL_DISINFECT"] = 0x09,

	-- 设备查询命令
	["MSG_TYPE_QUERY"] = 0x03,
	-- 设备查询命令-基本控制命令
	["MSG_TYPE_QUERY_BASIC"] = 0x01,
	-- 设备查询命令-日定时控制命令
	["MSG_TYPE_QUERY_DAY_TIME"] = 0x02,
	-- 设备查询命令-周定时控制命令
	["MSG_TYPE_QUERY_WEEKS_TIME"] = 0x03,
	-- 设备查询命令-外出休假控制命令
	["MSG_TYPE_QUERY_HOLIDAY_AWAY"] = 0x04,
	-- 设备查询命令-静音控制命令
	["MSG_TYPE_QUERY_SILENCE"] = 0x05,
	-- 设备查询命令-在家休假控制命令
	["MSG_TYPE_QUERY_HOLIDAY_HOME"] = 0x06,
	-- 设备查询命令-ECO设置查询
	["MSG_TYPE_QUERY_ECO"] = 0x07,
	-- 设备查询命令-安装设定参数查询命令03-0x08
	["MSG_TYPE_QUERY_INSTALL"] = 0x08,
	-- 设备查询命令-DISINFECT设置查询
	["MSG_TYPE_QUERY_DISINFECT"] = 0x09,
	-- 设备查询命令-线控器设置/计算参数查询
	["MSG_TYPE_QUERY_HMIPARA"] = 0x0a,
	-- 设备查询命令-主机机组运行参数查询
	["MSG_TYPE_QUERY_UNITPARA"] = 0x10,

	-- 设备运行参数上报，无须应答
	["MSG_TYPE_UP"] = 0x04,
	-- 设备运行参数上报-基本运行参数
	["MSG_TYPE_UP_BASIC"] = 0x01,
	--设备运行参数上报-能量消耗上报
	--["MSG_TYPE_UP_POWER2"] = 0x02,
	["MSG_TYPE_UP_POWER3"] = 0x03,
	["MSG_TYPE_UP_POWER4"] = 0x04,
	["MSG_TYPE_UP_UNITPARA"] = 0x05,
}
--------------------------------------------------------------------- 变量单位，此表值不可变 -----------------------------
local unitTable = {
	-- 控制命令
	["str_control"] = "control",
	-- 查询命令
	["str_query"] = "query",
	-- 状态命令
	["str_status"] = "status",
	-- 控制类型
	["str_control_type"] = "control_type",
	-- 查询类型
	["str_query_type"] = "query_type",
	-- 数值无效
	["u8_invalid"] = 0xff,
	["str_u8_invalid"] = "0xff",
	["s8_invalid"] = 0x7f,
	["str_s8_invalid"] = "0x7f",
	-- 自动
	["auto"] = 1,
	["str_auto"] = "auto",
	-- 制冷
	["cool"] = 2,
	["str_cool"] = "cool",
	-- 制热
	["heat"] = 3,
	["str_heat"] = "heat",
	-- 制热水
	["dhw"] = 5,
	["str_dhw"] = "dhw",
	-- 关
	["off"] = 0,
	["str_off"] = "off",
	-- 开
	["on"] = 1,
	["str_on"] = "on",
	-- 风盘
	["fan_coil"] = 0,
	["str_fan_coil"] = "fan_coil",
	-- 散热器
	["radiatior"] = 1,
	["str_radiatior"] = "radiatior",
	-- 地暖
	["floor_heat"] = 2,
	["str_floor_heat"] = "floor_heat",
	-- 等级1
	["level_1"] = 0,
	["str_level_1"] = "level_1",
	-- 等级2
	["level_2"] = 0,
	["str_level_2"] = "level_2",
	-- 气温
	["room_temperature_type"] = 0,
	["str_room_temperature_type"] = "room_temperature_type",
	-- 水温
	["water_temperature_type"] = 1,
	["str_water_temperature_type"] = "water_temperature_type",
}
--------------------------------------------------------------------- 定义属性变量--------------------
-- 变量列表
local myTable = {
	---------------------- 网络校时 ------------------------------------
	["time_sync"] = 0,
	---------------------- 基本控制指令 ------------------------------------
	-- 区域1开/关机	0:关   1:开
	["zone1_power_state"] = 0,
	-- 区域2开/关机	0:关   1:开
	["zone2_power_state"] = 0,
	-- 制热水开/关机	0:关   1:开
	["dhw_power_state"] = 0,
	-- 区域1气候曲线 开/关机	0:关   1:开
	["zone1_curve_state"] = 0,
	-- 区域2气候曲线 开/关机	0:关   1:开
	["zone2_curve_state"] = 0,

	-- 强制TBH 开/关机	0:关   1:开
	["forcetbh_state"] = 0,
	-- 快速制热水 开/关机	0:关   1:开
	["fastdhw_state"] = 0,
	--远程开关  0:关   1:开
	["remote_onoff"] = 0,

	-- 制热模式使能	0:无效    1:有效
	["heat_enable"] = 0,
	-- 制冷模式使能	0:无效    1:有效
	["cool_enable"] = 0,
	-- 制热水模式使能	0:无效    1:有效
	["dhw_enable"] = 0,
	-- 双区域使能	0:无效    1:有效
	["double_zone_enable"] = 0,
	-- 区域1温度类型选择	0:气温    1:水温
	["zone1_temp_type"] = 0,
	-- 区域2温度类型选择	0:气温    1:水温
	["zone2_temp_type"] = 0,
	--支持房间温控器使能标志
	["room_thermalen_state"] = 0,--sp
	--房间温控器使能标志
	["room_thermalmode_state"] = 0,--sp

	-- Schedule定时图标	0:关   1:开
	["time_set_state"] = 0,
	-- Slient图标开启	0:关   1:开
	["silence_on_state"] = 0,
	-- Holiday ON 运行图标	0:关   1:开
	["holiday_on_state"] = 0,
	-- eco ON 运行图标	0:关   1:开
	["eco_on_state"] = 0,
	-- 区域1末端类型	0:风盘  1:散热器  2:地暖
	["zone1_terminal_type"] = 0,
	-- 区域2末端类型	0:风盘  1:散热器  2:地暖
	["zone2_terminal_type"] = 0,

	-- 设定模式	1: 自动  2:制冷  3:制热
	["run_mode_set"] = 2,
	-- 自动模式下线控器运行模式
	["runmode_under_auto"] = 2,
	-- 区域1水温设定温度	单位:1 ℃
	["zone1_temp_set"] = 24,
	-- 区域2水温设定温度
	["zone2_temp_set"] = 24,
	-- 制热水设定温度	单位:1℃
	["dhw_temp_set"] = 24,
	-- 室温设定温度	单位:单位:0.5 ℃
	["room_temp_set"] = 48,

	-- 区域1制热 设定温度最大值（水温/气温）	单位:1 ℃
	["zone1_heat_max_set_temp"] = 0,
	-- 区域1制热设定温度最小值（水温/气温）	单位:1 ℃
	["zone1_heat_min_set_temp"] = 0,
	-- 区域1制冷设定温度最大值（水温/气温）	单位:1 ℃
	["zone1_cool_max_set_temp"] = 0,
	-- 区域1制冷设定温度最小值（水温/气温）	单位:1 ℃
	["zone1_cool_min_set_temp"] = 0,
	-- 区域2制热 设定温度最大值（水温/气温）	单位:1 ℃
	["zone2_heat_max_set_temp"] = 0,
	-- 区域2制热设定温度最小值（水温/气温）	单位:1 ℃
	["zone2_heat_min_set_temp"] = 0,
	-- 区域2制冷设定温度最大值（水温/气温）	单位:1 ℃
	["zone2_cool_max_set_temp"] = 0,
	-- 区域2制冷设定温度最小值（水温/气温）	单位:1 ℃
	["zone2_cool_min_set_temp"] = 0,
	-- 室温Ta设定温度最大值 单位:0.5 ℃
	["room_max_set_temp"] = 0,
	-- 室温Ta设定温度最小值（水温/气温）单位:0.5 ℃
	["room_min_set_temp"] = 0,
    --制热水（生活热水）设定温度最大值
    ["dhw_max_set_temp"] = 0,
    --制热水（生活热水）设定温度最小值
    ["dhw_min_set_temp"] = 0,
    -- 水箱实际温度  单位:1 ℃（有符号型）故障数据0xFF
    ["tank_actual_temp"] = 0,
	-- 当前故障序号
	["error_code"] = 0,
    --当前协议是否支持杀菌功能，区域2定时信息等新功能
    ["protocol_newfunction_en"] = 0,
	-- 是否支持控制TBH使能标志
	["boostertbh_en"] = 0,
    --区域1温度曲线选择
    ["zone1_curve_type"] = 3,
    --区域2温度曲线选择
    ["zone2_curve_type"] = 3,

    --主动上报命令子类型23-2-8
    ["msg_up_type"] = 0,
    
	---------------------- 日定时控制命令 ----------------------------------
	-- 日定时定时1-6使能标志
	["daytimer_timer1en"] = 0,
	["daytimer_timer2en"] = 0,
	["daytimer_timer3en"] = 0,
	["daytimer_timer4en"] = 0,
	["daytimer_timer5en"] = 0,
	["daytimer_timer6en"] = 0,
	-- 日定时定时1-6设定模式
	["daytimer_timer1_mode"] = 0,
	["daytimer_timer2_mode"] = 0,
	["daytimer_timer3_mode"] = 0,
	["daytimer_timer4_mode"] = 0,
	["daytimer_timer5_mode"] = 0,
	["daytimer_timer6_mode"] = 0,
	-- 日定时日定时1-6设定温度
	["daytimer_timer1_temp"] = 0,
	["daytimer_timer2_temp"] = 0,
	["daytimer_timer3_temp"] = 0,
	["daytimer_timer4_temp"] = 0,
	["daytimer_timer5_temp"] = 0,
	["daytimer_timer6_temp"] = 0,
	-- 日定时定时1-6开始时间
	["daytimer_timer1_openhour"] = 0,
	["daytimer_timer1_openmin"] = 0,
	["daytimer_timer2_openhour"] = 0,
	["daytimer_timer2_openmin"] = 0,
	["daytimer_timer3_openhour"] = 0,
	["daytimer_timer3_openmin"] = 0,
	["daytimer_timer4_openhour"] = 0,
	["daytimer_timer4_openmin"] = 0,
	["daytimer_timer5_openhour"] = 0,
	["daytimer_timer5_openmin"] = 0,
	["daytimer_timer6_openhour"] = 0,
	["daytimer_timer6_openmin"] = 0,
	-- 日定时定时1-6结束时间
	["daytimer_timer1_closehour"] = 0,
	["daytimer_timer1_closemin"] = 0,
	["daytimer_timer2_closehour"] = 0,
	["daytimer_timer2_closemin"] = 0,
	["daytimer_timer3_closehour"] = 0,
	["daytimer_timer3_closemin"] = 0,
	["daytimer_timer4_closehour"] = 0,
	["daytimer_timer4_closemin"] = 0,
	["daytimer_timer5_closehour"] = 0,
	["daytimer_timer5_closemin"] = 0,
	["daytimer_timer6_closehour"] = 0,
	["daytimer_timer6_closemin"] = 0,

    -- 日定时区域2-zone2定时1-6使能标志
	["zone2daytimer_timer1en"] = 0,
	["zone2daytimer_timer2en"] = 0,
	["zone2daytimer_timer3en"] = 0,
	["zone2daytimer_timer4en"] = 0,
	["zone2daytimer_timer5en"] = 0,
	["zone2daytimer_timer6en"] = 0,
	-- 日定时区域2-zone2定时1-6设定模式
	["zone2daytimer_timer1_mode"] = 0,
	["zone2daytimer_timer2_mode"] = 0,
	["zone2daytimer_timer3_mode"] = 0,
	["zone2daytimer_timer4_mode"] = 0,
	["zone2daytimer_timer5_mode"] = 0,
	["zone2daytimer_timer6_mode"] = 0,
	-- 日定时区域2-zone2日定时1-6设定温度
	["zone2daytimer_timer1_temp"] = 0,
	["zone2daytimer_timer2_temp"] = 0,
	["zone2daytimer_timer3_temp"] = 0,
	["zone2daytimer_timer4_temp"] = 0,
	["zone2daytimer_timer5_temp"] = 0,
	["zone2daytimer_timer6_temp"] = 0,
	-- 日定时区域2-zone2定时1-6开始时间
	["zone2daytimer_timer1_openhour"] = 0,
	["zone2daytimer_timer1_openmin"] = 0,
	["zone2daytimer_timer2_openhour"] = 0,
	["zone2daytimer_timer2_openmin"] = 0,
	["zone2daytimer_timer3_openhour"] = 0,
	["zone2daytimer_timer3_openmin"] = 0,
	["zone2daytimer_timer4_openhour"] = 0,
	["zone2daytimer_timer4_openmin"] = 0,
	["zone2daytimer_timer5_openhour"] = 0,
	["zone2daytimer_timer5_openmin"] = 0,
	["zone2daytimer_timer6_openhour"] = 0,
	["zone2daytimer_timer6_openmin"] = 0,
	-- 日定时区域2-zone2定时1-6结束时间
	["zone2daytimer_timer1_closehour"] = 0,
	["zone2daytimer_timer1_closemin"] = 0,
	["zone2daytimer_timer2_closehour"] = 0,
	["zone2daytimer_timer2_closemin"] = 0,
	["zone2daytimer_timer3_closehour"] = 0,
	["zone2daytimer_timer3_closemin"] = 0,
	["zone2daytimer_timer4_closehour"] = 0,
	["zone2daytimer_timer4_closemin"] = 0,
	["zone2daytimer_timer5_closehour"] = 0,
	["zone2daytimer_timer5_closemin"] = 0,
	["zone2daytimer_timer6_closehour"] = 0,
	["zone2daytimer_timer6_closemin"] = 0,
	---------------------- 周定时控制命令 ----------------------------------
	-- 当前设置星期(读写)
	["weektimer_setday"] = 0,
	-- 当前设置星期(只读，查询)
	["weektimer_weeken"] = 0,
	-- 周定时定时1-6段使能标志
	["weektimer_timer1en"] = 0,
	["weektimer_timer2en"] = 0,
	["weektimer_timer3en"] = 0,
	["weektimer_timer4en"] = 0,
	["weektimer_timer5en"] = 0,
	["weektimer_timer6en"] = 0,
	-- 周定时定时1-6设定模式
	["weektimer_timer1_mode"] = 0,
	["weektimer_timer2_mode"] = 0,
	["weektimer_timer3_mode"] = 0,
	["weektimer_timer4_mode"] = 0,
	["weektimer_timer5_mode"] = 0,
	["weektimer_timer6_mode"] = 0,
	-- 周定时定时1-6设定温度
	["weektimer_timer1_temp"] = 0,
	["weektimer_timer2_temp"] = 0,
	["weektimer_timer3_temp"] = 0,
	["weektimer_timer4_temp"] = 0,
	["weektimer_timer5_temp"] = 0,
	["weektimer_timer6_temp"] = 0,
	-- 周定时定时1-6开始时间
	["weektimer_timer1_openhour"] = 0,
	["weektimer_timer1_openmin"] = 0,
	["weektimer_timer2_openhour"] = 0,
	["weektimer_timer2_openmin"] = 0,
	["weektimer_timer3_openhour"] = 0,
	["weektimer_timer3_openmin"] = 0,
	["weektimer_timer4_openhour"] = 0,
	["weektimer_timer4_openmin"] = 0,
	["weektimer_timer5_openhour"] = 0,
	["weektimer_timer5_openmin"] = 0,
	["weektimer_timer6_openhour"] = 0,
	["weektimer_timer6_openmin"] = 0,
	-- 周定时定时1-6结束时间
	["weektimer_timer1_closehour"] = 0,
	["weektimer_timer1_closemin"] = 0,
	["weektimer_timer2_closehour"] = 0,
	["weektimer_timer2_closemin"] = 0,
	["weektimer_timer3_closehour"] = 0,
	["weektimer_timer3_closemin"] = 0,
	["weektimer_timer4_closehour"] = 0,
	["weektimer_timer4_closemin"] = 0,
	["weektimer_timer5_closehour"] = 0,
	["weektimer_timer5_closemin"] = 0,
	["weektimer_timer6_closehour"] = 0,
	["weektimer_timer6_closemin"] = 0,

    -- 当前设置区域2星期(读写)
	["zone2weektimer_setday"] = 0,
	-- 当前设置区域2星期(只读，查询)
	["zone2weektimer_weeken"] = 0,
	-- 周定时区域2定时1-6段段使能标志
	["zone2weektimer_timer1en"] = 0,
	["zone2weektimer_timer2en"] = 0,
	["zone2weektimer_timer3en"] = 0,
	["zone2weektimer_timer4en"] = 0,
	["zone2weektimer_timer5en"] = 0,
	["zone2weektimer_timer6en"] = 0,
	-- 周定时区域2定时1-6段设定模式
	["zone2weektimer_timer1_mode"] = 0,
	["zone2weektimer_timer2_mode"] = 0,
	["zone2weektimer_timer3_mode"] = 0,
	["zone2weektimer_timer4_mode"] = 0,
	["zone2weektimer_timer5_mode"] = 0,
	["zone2weektimer_timer6_mode"] = 0,
	-- 周定时区域2定时1-6段设定温度
	["zone2weektimer_timer1_temp"] = 0,
	["zone2weektimer_timer2_temp"] = 0,
	["zone2weektimer_timer3_temp"] = 0,
	["zone2weektimer_timer4_temp"] = 0,
	["zone2weektimer_timer5_temp"] = 0,
	["zone2weektimer_timer6_temp"] = 0,
	-- 周定时区域2定时1-6段开始时间
	["zone2weektimer_timer1_openhour"] = 0,
	["zone2weektimer_timer1_openmin"] = 0,
	["zone2weektimer_timer2_openhour"] = 0,
	["zone2weektimer_timer2_openmin"] = 0,
	["zone2weektimer_timer3_openhour"] = 0,
	["zone2weektimer_timer3_openmin"] = 0,
	["zone2weektimer_timer4_openhour"] = 0,
	["zone2weektimer_timer4_openmin"] = 0,
	["zone2weektimer_timer5_openhour"] = 0,
	["zone2weektimer_timer5_openmin"] = 0,
	["zone2weektimer_timer6_openhour"] = 0,
	["zone2weektimer_timer6_openmin"] = 0,
	-- 周定时区域2定时1-6段结束时间
	["zone2weektimer_timer1_closehour"] = 0,
	["zone2weektimer_timer1_closemin"] = 0,
	["zone2weektimer_timer2_closehour"] = 0,
	["zone2weektimer_timer2_closemin"] = 0,
	["zone2weektimer_timer3_closehour"] = 0,
	["zone2weektimer_timer3_closemin"] = 0,
	["zone2weektimer_timer4_closehour"] = 0,
	["zone2weektimer_timer4_closemin"] = 0,
	["zone2weektimer_timer5_closehour"] = 0,
	["zone2weektimer_timer5_closemin"] = 0,
	["zone2weektimer_timer6_closehour"] = 0,
	["zone2weektimer_timer6_closemin"] = 0,

	---------------------- 外出休假控制命令----------------------------------
	["holidayaway_state"] = 0,
	["holidayaway_heat_state"] = 0,
	["holidayaway_dhw_state"] = 0,
	["holidayaway_disinfect_state"] = 0,
	["holidayaway_startyear"] = 0,
	["holidayaway_startmonth"] = 0,
	["holidayaway_startdate"] = 0,
	["holidayaway_endyear"] = 0,
	["holidayaway_endmonth"] = 0,
	["holidayaway_enddate"] = 0,
	---------------------- 静音功能控制 ----------------------------------
	-- 静音功能开关
	["silence_function_state"] = 0,
	-- 静音等级
	["silence_function_level"] = 0,
	-- 静音定时1
	["silence_timer1_state"] = 0,
	["silence_timer1_starthour"] = 0,
	["silence_timer1_startmin"] = 0,
	["silence_timer1_endhour"] = 0,
	["silence_timer1_endmin"] = 0,
	-- 静音定时2
	["silence_timer2_state"] = 0,
	["silence_timer2_starthour"] = 0,
	["silence_timer2_startmin"] = 0,
	["silence_timer2_endhour"] = 0,
	["silence_timer2_endmin"] = 0,
	---------------------- 在家休假HOLIDAY HOME控制命令  2022-10-13 ----------------------------------
	["holidayhome_state"] = 0,
	["holidayhome_startyear"] = 0,
	["holidayhome_startmonth"] = 0,
	["holidayhome_startdate"] = 0,
	["holidayhome_endyear"] = 0,
	["holidayhome_endmonth"] = 0,
	["holidayhome_enddate"] = 0,
	-- HOLIDAY HOME定时1-6使能标志
	["holhometimer_timer1en"] = 0,
	["holhometimer_timer2en"] = 0,
	["holhometimer_timer3en"] = 0,
	["holhometimer_timer4en"] = 0,
	["holhometimer_timer5en"] = 0,
	["holhometimer_timer6en"] = 0,
	-- HOLIDAY HOME定时定时1-6设定模式
	["holhometimer_timer1_mode"] = 0,
	["holhometimer_timer2_mode"] = 0,
	["holhometimer_timer3_mode"] = 0,
	["holhometimer_timer4_mode"] = 0,
	["holhometimer_timer5_mode"] = 0,
	["holhometimer_timer6_mode"] = 0,
	-- HOLIDAY HOME定时日定时1-6设定温度
	["holhometimer_timer1_temp"] = 0,
	["holhometimer_timer2_temp"] = 0,
	["holhometimer_timer3_temp"] = 0,
	["holhometimer_timer4_temp"] = 0,
	["holhometimer_timer5_temp"] = 0,
	["holhometimer_timer6_temp"] = 0,
	-- HOLIDAY HOME定时定时1-6开始时间
	["holhometimer_timer1_openhour"] = 0,
	["holhometimer_timer1_openmin"] = 0,
	["holhometimer_timer2_openhour"] = 0,
	["holhometimer_timer2_openmin"] = 0,
	["holhometimer_timer3_openhour"] = 0,
	["holhometimer_timer3_openmin"] = 0,
	["holhometimer_timer4_openhour"] = 0,
	["holhometimer_timer4_openmin"] = 0,
	["holhometimer_timer5_openhour"] = 0,
	["holhometimer_timer5_openmin"] = 0,
	["holhometimer_timer6_openhour"] = 0,
	["holhometimer_timer6_openmin"] = 0,
	-- HOLIDAY HOME定时定时1-6结束时间
	["holhometimer_timer1_closehour"] = 0,
	["holhometimer_timer1_closemin"] = 0,
	["holhometimer_timer2_closehour"] = 0,
	["holhometimer_timer2_closemin"] = 0,
	["holhometimer_timer3_closehour"] = 0,
	["holhometimer_timer3_closemin"] = 0,
	["holhometimer_timer4_closehour"] = 0,
	["holhometimer_timer4_closemin"] = 0,
	["holhometimer_timer5_closehour"] = 0,
	["holhometimer_timer5_closemin"] = 0,
	["holhometimer_timer6_closehour"] = 0,
	["holhometimer_timer6_closemin"] = 0,

    -- HOLIDAY HOME区域2日定时1-6使能标志
	["zone2holhometimer_timer1en"] = 0,
	["zone2holhometimer_timer2en"] = 0,
	["zone2holhometimer_timer3en"] = 0,
	["zone2holhometimer_timer4en"] = 0,
	["zone2holhometimer_timer5en"] = 0,
	["zone2holhometimer_timer6en"] = 0,
	-- HOLIDAY HOME区域2日定时定时1-6设定模式
	["zone2holhometimer_timer1_mode"] = 0,
	["zone2holhometimer_timer2_mode"] = 0,
	["zone2holhometimer_timer3_mode"] = 0,
	["zone2holhometimer_timer4_mode"] = 0,
	["zone2holhometimer_timer5_mode"] = 0,
	["zone2holhometimer_timer6_mode"] = 0,
	-- HOLIDAY HOME区域2日定时日定时1-6设定温度
	["zone2holhometimer_timer1_temp"] = 0,
	["zone2holhometimer_timer2_temp"] = 0,
	["zone2holhometimer_timer3_temp"] = 0,
	["zone2holhometimer_timer4_temp"] = 0,
	["zone2holhometimer_timer5_temp"] = 0,
	["zone2holhometimer_timer6_temp"] = 0,
	-- HOLIDAY HOME区域2日定时定时1-6开始时间
	["zone2holhometimer_timer1_openhour"] = 0,
	["zone2holhometimer_timer1_openmin"] = 0,
	["zone2holhometimer_timer2_openhour"] = 0,
	["zone2holhometimer_timer2_openmin"] = 0,
	["zone2holhometimer_timer3_openhour"] = 0,
	["zone2holhometimer_timer3_openmin"] = 0,
	["zone2holhometimer_timer4_openhour"] = 0,
	["zone2holhometimer_timer4_openmin"] = 0,
	["zone2holhometimer_timer5_openhour"] = 0,
	["zone2holhometimer_timer5_openmin"] = 0,
	["zone2holhometimer_timer6_openhour"] = 0,
	["zone2holhometimer_timer6_openmin"] = 0,
	-- HOLIDAY HOME区域2日定时定时1-6结束时间
	["zone2holhometimer_timer1_closehour"] = 0,
	["zone2holhometimer_timer1_closemin"] = 0,
	["zone2holhometimer_timer2_closehour"] = 0,
	["zone2holhometimer_timer2_closemin"] = 0,
	["zone2holhometimer_timer3_closehour"] = 0,
	["zone2holhometimer_timer3_closemin"] = 0,
	["zone2holhometimer_timer4_closehour"] = 0,
	["zone2holhometimer_timer4_closemin"] = 0,
	["zone2holhometimer_timer5_closehour"] = 0,
	["zone2holhometimer_timer5_closemin"] = 0,
	["zone2holhometimer_timer6_closehour"] = 0,
	["zone2holhometimer_timer6_closemin"] = 0,

	---------------------- ECO功能控制-07命令 22-10-13----------------------------------
	-- ECO功能开关
	["eco_function_state"] = 0,
	-- ECO定时开关状态
	["eco_timer_state"] = 0,
	-- ECO定时1
	["eco_timer_starthour"] = 0,
	["eco_timer_startmin"] = 0,
	["eco_timer_endhour"] = 0,
	["eco_timer_endmin"] = 0,
    ["eco_curve_type"] = 3,

	---------------------- 杀菌功能控制/查询命令-09命令 22-10-13----------------------------------
	-- 杀菌开/关机	  0:关   1:开
	["disinfect_function_state"] = 0,
	-- 机组杀菌运行状态	0:关   1:开
	["disinfect_run_state"] = 0,
    -- 杀菌设置日期	  0:关   1:开
	["disinfect_setweekday"] = 0,
 	-- 杀菌开启 时	0:关   1:开
    ["disinfect_starthour"] = 0,
    --杀菌开启 分	  0:关   1:开
    ["disinfect_startmin"] = 0,


	---------------------- 主动上报能量参数04-03/04 22-10-14----------------------------------
	-- 制热运行状态0:关   1:开
	["isheatrun0"] = 0,
	-- 制冷运行状态 0:关   1:开
	["iscoolrun0"] = 0,
	-- 制热水DHW运行状态 0:关   1:开
	["isdhwrun0"] = 0,
	-- TBH运行状态 0:关   1:开
	["istbhrun0"] = 0,
	-- IBH运行状态0:关   1:开
	["isibhrun0"] = 0,
	-- SMART GRID运行状态 0:关   1:开
	["issmartgrid0"] = 0,
	-- 高价电运行状态 0:关   1:开
	["ishighprices0"] = 0,
	-- 低价/免费电 运行状态 0:关   1:开
	["isbottomprices0"] = 0,
	--
	["totalelectricity0"] = 0,
	--
	["totalthermal0"] = 0,
	--
	["t4"] = 0,
	--
	["t1s"] = 0,
	--
	["t1s2"] = 0,
	--
	["t5s"] = 0,
	--
	["tas"] = 0,
	--
	["newt1s1"] = 0,
	--
	["newt1s2"] = 0,
	--
	["isonline0"] = 0,
	["isonline1"] = 0,
	["isonline2"] = 0,
	["isonline3"] = 0,
	["isonline4"] = 0,
	["isonline5"] = 0,
	["isonline6"] = 0,
	["isonline7"] = 0,
	["isonline8"] = 0,
	["isonline9"] = 0,
	["isonline10"] = 0,
	["isonline11"] = 0,
	["isonline12"] = 0,
	["isonline13"] = 0,
	["isonline14"] = 0,
	["isonline15"] = 0,

	["isheatrun1"] = 0,
	["isheatrun2"] = 0,
	["isheatrun3"] = 0,
	["isheatrun4"] = 0,
	["isheatrun5"] = 0,
	["isheatrun6"] = 0,
	["isheatrun7"] = 0,
	["isheatrun8"] = 0,
	["isheatrun9"] = 0,
	["isheatrun10"] = 0,
	["isheatrun11"] = 0,
	["isheatrun12"] = 0,
	["isheatrun13"] = 0,
	["isheatrun14"] = 0,
	["isheatrun15"] = 0,

	["iscoolrun1"] = 0,
	["iscoolrun2"] = 0,
	["iscoolrun3"] = 0,
	["iscoolrun4"] = 0,
	["iscoolrun5"] = 0,
	["iscoolrun6"] = 0,
	["iscoolrun7"] = 0,
	["iscoolrun8"] = 0,
	["iscoolrun9"] = 0,
	["iscoolrun10"] = 0,
	["iscoolrun11"] = 0,
	["iscoolrun12"] = 0,
	["iscoolrun13"] = 0,
	["iscoolrun14"] = 0,
	["iscoolrun15"] = 0,

	["isdhwrun1"] = 0,
	["isdhwrun2"] = 0,
	["isdhwrun3"] = 0,
	["isdhwrun4"] = 0,
	["isdhwrun5"] = 0,
	["isdhwrun6"] = 0,
	["isdhwrun7"] = 0,
	["isdhwrun8"] = 0,
	["isdhwrun9"] = 0,
	["isdhwrun10"] = 0,
	["isdhwrun11"] = 0,
	["isdhwrun12"] = 0,
	["isdhwrun13"] = 0,
	["isdhwrun14"] = 0,
	["isdhwrun15"] = 0,

	["istbhrun1"] = 0,
	["istbhrun2"] = 0,
	["istbhrun3"] = 0,
	["istbhrun4"] = 0,
	["istbhrun5"] = 0,
	["istbhrun6"] = 0,
	["istbhrun7"] = 0,
	["istbhrun8"] = 0,
	["istbhrun9"] = 0,
	["istbhrun10"] = 0,
	["istbhrun11"] = 0,
	["istbhrun12"] = 0,
	["istbhrun13"] = 0,
	["istbhrun14"] = 0,
	["istbhrun15"] = 0,

	["isibhrun1"] = 0,
	["isibhrun2"] = 0,
	["isibhrun3"] = 0,
	["isibhrun4"] = 0,
	["isibhrun5"] = 0,
	["isibhrun6"] = 0,
	["isibhrun7"] = 0,
	["isibhrun8"] = 0,
	["isibhrun9"] = 0,
	["isibhrun10"] = 0,
	["isibhrun11"] = 0,
	["isibhrun12"] = 0,
	["isibhrun13"] = 0,
	["isibhrun14"] = 0,
	["isibhrun15"] = 0,

	["totalelectricity1"] = 0,
	["totalelectricity2"] = 0,
	["totalelectricity3"] = 0,
	["totalelectricity4"] = 0,
	["totalelectricity5"] = 0,
	["totalelectricity6"] = 0,
	["totalelectricity7"] = 0,
	["totalelectricity8"] = 0,
	["totalelectricity9"] = 0,
	["totalelectricity10"] = 0,
	["totalelectricity11"] = 0,
	["totalelectricity12"] = 0,
	["totalelectricity13"] = 0,
	["totalelectricity14"] = 0,
	["totalelectricity15"] = 0,

	["totalthermal1"] = 0,
	["totalthermal2"] = 0,
	["totalthermal3"] = 0,
	["totalthermal4"] = 0,
	["totalthermal5"] = 0,
	["totalthermal6"] = 0,
	["totalthermal7"] = 0,
	["totalthermal8"] = 0,
	["totalthermal9"] = 0,
	["totaltherma10"] = 0,
	["totalthermal11"] = 0,
	["totalthermal12"] = 0,
	["totalthermal13"] = 0,
	["totalthermal14"] = 0,
	["totalthermal15"] = 0,

	["isibh2run1 "] = 0,
	["isibh2run2 "] = 0,
	["isibh2run3 "] = 0,
	["isibh2run4 "] = 0,
	["isibh2run5 "] = 0,
	["isibh2run6 "] = 0,
	["isibh2run7 "] = 0,
	["isibh2run8 "] = 0,
	["isibh2run9 "] = 0,
	["isibh2run10 "] = 0,
	["isibh2run11 "] = 0,
	["isibh2run12 "] = 0,
	["isibh2run13 "] = 0,
	["isibh2run14 "] = 0,
	["isibh2run15 "] = 0,

	["voltage0"] = 0,
	["voltage1"] = 0,
	["voltage2"] = 0,
	["voltage3"] = 0,
	["voltage4"] = 0,
	["voltage5"] = 0,
	["voltage6"] = 0,
	["voltage7"] = 0,
	["voltage8"] = 0,
	["voltage9"] = 0,
	["voltage10"] = 0,
	["voltage11"] = 0,
	["voltage12"] = 0,
	["voltage13"] = 0,
	["voltage14"] = 0,
	["voltage15"] = 0,

	["power_ibh1"] = 0,
	["power_ibh2"] = 0,
	["power_tbh"] = 0,
	---------------------- 安装设定参数控制查询-08命令 22-10-13----------------------------------
    ["dhwEnable"] = 0,
    ["boostertbhEn"] = 0,
    ["disinfectEnable"] = 0,
    ["dhwPumpEnable"] = 0,
    ["dhwPriorityTime"] = 0,
    ["dhwPumpDIEnable"] = 0,
    ["coolEnable"] = 0,
    ["fgZone1CoolTempHigh"] = 0,
    ["heatEnable"] = 0,
    ["fgZone1HeatTempHigh"] = 0,
    ["pumpiSliModeEn"] = 0,
    ["roomSensorEn"] = 0,
    ["roomTherEn"] = 0,
    ["roomTherSetModeEn"] = 0,
    ["dualroomThermostatEn"] = 0,
    ["fgdhwPriorEn"] = 0,
    ["acsEnable "] = 0,
    ["dhwHeaterAhsEn"] = 0,
    ["tempPcbEn"] = 0,
    ["tbt2ProbeEn"] = 0,
    ["pipeExceed10m"] = 0,
    ["solarCn18En"] = 0,
    ["fgOwnSolarEn"] = 0,
    ["fgInputDhwHeater"] = 0,
    ["smartgridEn"] = 0,
    ["t1bProbeEn"] = 0,
    ["fgZone2CoolTempHigh"] = 0,
    ["fgZone2HeatTempHigh"] = 0,
    ["doubleZoneEn"] = 0,
    ["fgTaProbeIdu"] = 0,
    ["tbt1ProbeEn"] = 0,
    ["fgIbhInTank"] = 0,
	["roomTherType"] = 0,
    ["dT5On"] = 5,
    ["dT1S5"] = 10,
    ["tIntervaDhw"] = 0,
    ["t4Dhwmax"] = 43,
    ["t4Dhwmin"] = 0xF6,
    ["tTBHdelay"] = 0,
    ["dT5STBHoff"] = 0,
    ["t4TBHon"] = 5,
    ["t5sDI"] = 0,
    ["tDImax"] = 0,
    ["tDIhightemp"] = 0,
    ["tIntervalC"] = 0,
    ["dT1SC"] = 5,
    ["dTSC"] = 2,
    ["t4Cmax"] = 43,
    ["t4Cmin"] = 20,
    ["tIntervalH"] = 0,
    ["dT1SH"] = 5,
    ["dTSH"] = 2,
    ["t4Hmax"] = 25,
    ["t4Hmin"] = 0XF1,
    ["t4IBHon"] = 0XFB,
    ["dT1IBHon"] = 0,
    ["tIBHdelay"] = 0,
    ["tIBH12delay"] = 0,
    ["t4AHSon"] = 0,
    ["dT1AHSon"] = 0,
    ["dT1AHSoff"] = 0,
    ["tAHSdelay"] = 0,
    ["tDHWHPmax"] = 0,
    ["tDHWHPrestrict"] = 0,
    ["t4autocmin"] = 25,
    ["t4autohmax"] = 17,
    ["t1sHolHeat"] = 0,
    ["t5SHolDhw"] = 0,
    ["perStart"] = 0,
    ["timeAdjust"] = 0,
    ["dTbt2"] = 0,
    ["powerIbh1"] = 0,
    ["powerIbh2"] = 0,
    ["powerTbh"] = 0,
    ["ecoHeatT1s"] = 0,
    ["ecoHeatTs"] = 0,
    ["tDryup"] = 0,
    ["tDrypeak"] = 0,
    ["tdrydown"] = 0,
    ["tempDrypeak"] = 0,
    ["timePreheatFloor"] = 0,
    ["t1SPreheatFloor"] = 0,
    ["t1SetC1"] = 10,
    ["t1SetC2"] = 16,
    ["t4C1"] = 35,
    ["t4C2"] = 25,
    ["t1SetH1"] = 35,
    ["t1SetH2"] = 28,
    ["t4H1"] = 0XFB,
    ["t4H2"] = 7,
    ["typeVolLmt"] = 0,
    ["timeT4FreshC"] = 0,
    ["timeT4FreshH"] = 0,
    ["tPumpiDelay"] = 0,
    ["deltaTsloar"] = 0,
    ["solarFunction"] = 0,
    ["enSwitchPDC"] = 0,
    ["gasCost"] = 0,
    ["eleCost"] = 0,
    ["ahsSetTempMax"] = 0,
    ["ahsSetTempMin"] = 0,
    ["ahsSetTempMaxVolt"] = 0,
    ["ahsSetTempMinVolt"] = 0,
    ["t2AntiSVRun"] = 0,
    ["dftPortFuncEn"] = 0,
    ["t1AntiPump"] = 0,
    ["t2AntiPumpRun"] = 0,
    ["t1AntiLockSV"] = 0,
    ["tbhEnFunc"] = 0,
    ["ibhEnFunc"] = 0,
    ["ahsEnFunc"] = 0,
    ["ahsPumpiControl"] = 0,
    ["modeSetPri"] = 0,
    ["pumpType"] = 0,
    ["pumpiSilentOutput"] = 0,
    ["timeReportSet"] = 10,
    ---------------------- 线控器参数查询-0x0A命令 22-10-13----------------------------------
    ["hmiVersionNum"] = 0,
    ["compRunCurTime0"] = 0,
    ["compRunTotalTime0"] = 0,
    ["fanRunTotalTime0"] = 0,
    ["pumpiRunTotalTime0"] = 0,
    ["ibh1RunTotalTime0"] = 0,
    ["ibh2RunTotalTime0"] = 0,
    ["tbhRunTotalTime0"] = 0,
    ["ahsRunTotalTime0"] = 0,
    ["arrayServiceTel0"] = 0,
    ["arrayServiceTel1"] = 0,
    ["arrayServiceTel2"] = 0,
    ["arrayServiceTel3"] = 0,
    ["arrayServiceTel4"] = 0,
    ["arrayServiceTel5"] = 0,
    ["arrayServiceTel6"] = 0,
    ["arrayServiceTel7"] = 0,
    ["arrayServiceTel8"] = 0,
    ["arrayServiceTel9"] = 0,
    ["arrayServiceTel10"] = 0,
    ["arrayServiceTel11"] = 0,
    ["arrayServiceTel12"] = 0,
    ["ArrayServiceCel0"] = 0,
    ["ArrayServiceCel1"] = 0,
    ["ArrayServiceCel2"] = 0,
    ["ArrayServiceCel3"] = 0,
    ["ArrayServiceCel4"] = 0,
    ["ArrayServiceCel5"] = 0,
    ["ArrayServiceCel6"] = 0,
    ["ArrayServiceCel7"] = 0,
    ["ArrayServiceCel8"] = 0,
    ["ArrayServiceCel9"] = 0,
    ["ArrayServiceCel10"] = 0,
    ["ArrayServiceCel11"] = 0,
    ["ArrayServiceCel12"] = 0,
    ["u8warnTotal"] = 0,
    ["codeErrProt1"] = 0,
    ["warnAddress1"] = 0,
    ["warnHour1"] = 0,
    ["warnMin1"] = 0,
    ["warnYear1"] = 0,
    ["warnMonth1"] = 0,
    ["warnDate1"] = 0,
    ["codeErrProt2"] = 0,
    ["warnAddress2"] = 0,
    ["warnHour2"] = 0,
    ["warnMin2"] = 0,
    ["warnYear2"] = 0,
    ["warnMonth2"] = 0,
    ["warnDate2"] = 0,
    ["codeErrProt3"] = 0,
    ["warnAddress3"] = 0,
    ["warnHour3"] = 0,
    ["warnMin3"] = 0,
    ["warnYear3"] = 0,
    ["warnMonth3"] = 0,
    ["warnDate3"] = 0,
    ["codeErrProt4"] = 0,
    ["warnAddress4"] = 0,
    ["warnHour4"] = 0,
    ["warnMin4"] = 0,
    ["warnYear4"] = 0,
    ["warnMonth4"] = 0,
    ["warnDate4"] = 0,
    ["codeErrProt5"] = 0,
    ["warnAddress5"] = 0,
    ["warnHour5"] = 0,
    ["warnMin5"] = 0,
    ["warnYear5"] = 0,
    ["warnMonth5"] = 0,
    ["warnDate5"] = 0,
    ["codeErrProt6"] = 0,
    ["warnAddress6"] = 0,
    ["warnHour6"] = 0,
    ["warnMin6"] = 0,
    ["warnYear6"] = 0,
    ["warnMonth6"] = 0,
    ["warnDate6"] = 0,
    ["codeErrProt7"] = 0,
    ["warnAddress7"] = 0,
    ["warnHour7"] = 0,
    ["warnMin7"] = 0,
    ["warnYear7"] = 0,
    ["warnMonth7"] = 0,
    ["warnDate7"] = 0,
    ["codeErrProt8"] = 0,
    ["warnAddress8"] = 0,
    ["warnHour8"] = 0,
    ["warnMin8"] = 0,
    ["warnYear8"] = 0,
    ["warnMonth8"] = 0,
    ["warnDate8"] = 0,


    ---------------------- 主机运行参数查询-0x10命令 22-10-13----------------------------------
	["compRunFreq"]  =  0,
	["unitModeRun"]  =  0,
	["fanSpeed"]  =  0,
	["machVersion"]  =  0,    
	["capacityNeed"]  =  0,
	["fgCapacityNeed"]  =  0,
	["tempset"]  =  0,
	["tempT3"]  =  0,
	["tempT4"]  =  0,
	["tempTp"]  =  0,
	["tempTwin"]  =  0,
	["tempTwout"]  =  0,
	["tempTsolar"]  =  0,
	["hydboxSubtype"]  =  0,
	["fgUSBInfoConnect"]  =  0,
	["usbIndexMax"]  =  0,
	["p6ErrCode"]  =  0,
	["oduCompCurrent"]  =  0,
	["oduVoltage"]  =  0,
	["exvCurrent"]  =  0,
	["oduModel"]  =  0,
	["unitonlineNum"]  =  0,
	["currentCode"]  =  0,
	["u8Code1"]  =  0,
	["u8Code2"]  =  0,
	["u8Code3"]  =  0,
	["fgReqParaSet"]  =  0,
	["fgReqVerAsk"]  =  0,
	["fgReqSNAsk"]  =  0,
	["fgUnitLockSignal"]  =  0,
	["fgEVUSignal"]  =  0,
	["fgSGSignal"]  =  0,
	["fgTankAntiFreeze"]  =  0,
	["fgSolarInput"]  =  0,
	["fgRoomTherCoolRun"]  =  0,
	["fgRoomTherHeatRun"]  =  0,
	["fgOutDoorTestMode"]  =  0,
	["fgRemoteOnOff"]  =  0,
	["fgBackOil"]  =  0,
	["fgAntiFreezeRun"]  =  0,
	["fgDefrost"]  =  0,
	["fgIsSlaveUnit"]  =  0,
	["fgTBHEnable"]  =  0,
	["fgAHSIsOwn"]  =  0,
	["fgCapTestEnable"]  =  0,
	["fgT1BSensorEnable"]  =  0,
	["fgAHSDHWMode"]  =  0,
	["fgIBH1Enable"]  =  0,
	["fgT1SensorEnable"]  =  0,
	["fgEdgeVersionType"]  =  0,
	["fgFactReqTherHeatOn"]  =  0,
	["fgDHWRun"]  =  0,
	["fgHeatRun"]  =  0,
	["fgCoolRun"]  =  0,
	["fgFactReqTherCoolOn"]  =  0,
	["fgFactReqSolarOn"]  =  0,
	["fgFactoryRun"]  =  0,
	["fgDefValveOn"]  =  0,
	["fgAHSValveOn"]  =  0,
	["fgRunValveOn"]  =  0,
	["fgAlmValveOn"]  =  0,
	["fgPumpSolarOn"]  =  0,
	["fgHeat4ValveOn"]  =  0,
	["fgSV3Output"]  =  0,
	["fgMixedPumpValveOn"]  =  0,
	["fgPumpDHWOn"]  =  0,
	["fgPumpOOn"]  =  0,
	["fgSV2On"]  =  0,
	["fgSV1On"]  =  0,
	["fgPumpIOutput"]  =  0,
	["fgTBHOutput"]  =  0,
	["fgIBH2Output"]  =  0,
	["fgIBH1Output"]  =  0,
	["tempT1"]  =  0,
	["tempTw2"]  =  0,
	["tempT2"]  =  0,
	["tempT2b"]  =  0,
	["tempT5"]  =  0,
	["tempTa"]  =  0,
	["tempTbt1"]  =  0,
	["tempTbt2"]  =  0,
	["hydroboxCapacity"]  =  0,
	["pressureHigh"]  =  0,
	["pressureLow"]  =  0,
	["tempTh"]  =  0,
	["machineType"]  =  0,
	["oduTargetFre"]  =  0,
	["dcCurrent"]  =  0,
	["dcVoltage"]  =  0,
	["tempTf"]  =  0,
	["iduT1s1"]  =  0,
	["iduT1s2"]  =  0,
	["waterFlow"]  =  0,
	["oduPlanVolLmt"]  =  0,
	["currentUnitCapacity"]  =  0,
	["spheraAHSVoltage"]  =  0,
	["tempT4Aver"]  =  0,
	["waterPressure"]  =  0,
	["roomRelHum"]  =  0,
	["pwmPumpOut"]  =  0,
	["fgUnitStopT4Out"]  =  0,
	["heatElecTotConsum0"]  =  0,
	["heatTotCapacity0"]  =  0,
	["instantPower0"]  =  0,
	["instantRenewPower0"]  =  0,
	["totalRenewPower0"]  =  0,
	["iduVersionNum"]  =  0,
	["oduVersionNum"]  =  0,
	["iduSNCode0"]  =  0,
	["iduSNCode1"]  =  0,
	["iduSNCode2"]  =  0,
	["iduSNCode3"]  =  0,
	["iduSNCode4"]  =  0,
	["iduSNCode5"]  =  0,
	["iduSNCode6"]  =  0,
	["iduSNCode7"]  =  0,
	["iduSNCode8"]  =  0,
	["iduSNCode9"]  =  0,
	["iduSNCode10"]  =  0,
	["iduSNCode11"]  =  0,
	["iduSNCode12"]  =  0,
	["iduSNCode13"]  =  0,
	["iduSNCode14"]  =  0,
	["iduSNCode15"]  =  0,
	["iduSNCode16"]  =  0,
	["iduSNCode17"]  =  0,
	["iduSNCode18"]  =  0,
	["iduSNCode19"]  =  0,
	["iduSNCode20"]  =  0,
	["iduSNCode21"]  =  0,
	["iduSNCode22"]  =  0,
	["iduSNCode23"]  =  0,
	["iduSNCode24"]  =  0,
	["iduSNCode25"]  =  0,
	["iduSNCode26"]  =  0,
	["iduSNCode27"]  =  0,
	["iduSNCode28"]  =  0,
	["iduSNCode29"]  =  0,
	["iduSNCode30"]  =  0,
	["iduSNCode31"]  =  0,
	["oduSNCode0"]  =  0,
	["oduSNCode1"]  =  0,
	["oduSNCode2"]  =  0,
	["oduSNCode3"]  =  0,
	["oduSNCode4"]  =  0,
	["oduSNCode5"]  =  0,
	["oduSNCode6"]  =  0,
	["oduSNCode7"]  =  0,
	["oduSNCode8"]  =  0,
	["oduSNCode9"]  =  0,
	["oduSNCode10"]  =  0,
	["oduSNCode11"]  =  0,
	["oduSNCode12"]  =  0,
	["oduSNCode13"]  =  0,
	["oduSNCode14"]  =  0,
	["oduSNCode15"]  =  0,
	["oduSNCode16"]  =  0,
	["oduSNCode17"]  =  0,
	["oduSNCode18"]  =  0,
	["oduSNCode19"]  =  0,
	["oduSNCode20"]  =  0,
	["oduSNCode21"]  =  0,
	["oduSNCode22"]  =  0,
	["oduSNCode23"]  =  0,
	["oduSNCode24"]  =  0,
	["oduSNCode25"]  =  0,
	["oduSNCode26"]  =  0,
	["oduSNCode27"]  =  0,
	["oduSNCode28"]  =  0,
	["oduSNCode29"]  =  0,
	["oduSNCode30"]  =  0,
	["oduSNCode31"]  =  0,
	["hmiSNCode0"]  =  0,
	["hmiSNCode1"]  =  0,
	["hmiSNCode2"]  =  0,
	["hmiSNCode3"]  =  0,
	["hmiSNCode4"]  =  0,
	["hmiSNCode5"]  =  0,
	["hmiSNCode6"]  =  0,
	["hmiSNCode7"]  =  0,
	["hmiSNCode8"]  =  0,
	["hmiSNCode9"]  =  0,
	["hmiSNCode10"]  =  0,
	["hmiSNCode11"]  =  0,
	["hmiSNCode12"]  =  0,
	["hmiSNCode13"]  =  0,
	["hmiSNCode14"]  =  0,
	["hmiSNCode15"]  =  0,
	["hmiSNCode16"]  =  0,
	["hmiSNCode17"]  =  0,
	["hmiSNCode18"]  =  0,
	["hmiSNCode19"]  =  0,
	["hmiSNCode20"]  =  0,
	["hmiSNCode21"]  =  0,
	["hmiSNCode22"]  =  0,
	["hmiSNCode23"]  =  0,
	["hmiSNCode24"]  =  0,
	["hmiSNCode25"]  =  0,
	["hmiSNCode26"]  =  0,
	["hmiSNCode27"]  =  0,
	["hmiSNCode28"]  =  0,
	["hmiSNCode29"]  =  0,
	["hmiSNCode30"]  =  0,
	["hmiSNCode31"]  =  0,

	["SysInstantHPCapacity"]  =  0,
	["SysInstantRenewPower"]  =  0,
	["SysInstantPower"]  =  0,
	["SysInstantCopEER"]  =  0,
	["SysTotalHPCapacity"]  =  0,
	["SysTotalHeatCapacity"]  =  0,
	["SysTotalRenewPower"]  =  0,
	["SysTotalPowerConsum"]  =  0,
	["SysTotalHeatElecConsum"]  =  0,
	["SysTotalCOPEER"]  =  0,
    --2023-03-02
    ["SysEnergyAnaEN"]  =  0,
    ["HMIEnergyAnaSetEN"]  =  0,
    ["SysHeatInsHPCapacity"]  =  0,
    ["SysHeatInsRenewPower"]  =  0,
    ["SysHeatInsPower"]  =  0,
    ["SysHeatInsCopEER"]  =  0,
    ["SysHeatCapacity"]  =  0,
    ["SysHeatRenewPower"]  =  0,
    ["SysHeatElecConsum"]  =  0,
    ["SysHeatCOPEER"]  =  0,
    ["SysCoolInsHPCapacity"]  =  0,
    ["SysCoolInsRenewPower"]  =  0,
    ["SysCoolInsPower"]  =  0,
    ["SysCoolInsCopEER"]  =  0,
    ["SysCoolCapacity"]  =  0,
    ["SysCoolRenewPower"]  =  0,
    ["SysCoolElecConsum"]  =  0,
    ["SysCoolCOPEER"]  =  0,
    ["SysDhwInsHPCapacity"]  =  0,
    ["SysDhwInsRenewPower"]  =  0,
    ["SysDhwInsPower"]  =  0,
    ["SysDhwInsCopEER"]  =  0,
    ["SysDhwCapacity"]  =  0,
    ["SysDhwRenewPower"]  =  0,
    ["SysDhwElecConsum"]  =  0,
    ["SysDhwCOPEER"]  =  0,
    --2023-3-29 新增制热，冷，制热水 日、周、月、年  能耗数据  
    ["SysHeatDayCapacity"]  =  0,
    ["SysHeatDayRenewPower"]  =  0,
    ["SysHeatDayElecConsum"]  =  0,
    ["SysHeatDayCOPEER"]  =  0,
    
    ["SysHeatWeekCapacity"]  =  0,
    ["SysHeatWeekRenewPower"]  =  0,
    ["SysHeatWeekElecConsum"]  =  0,
    ["SysHeatWeekCOPEER"]  =  0,
    
    ["SysHeatMonthCapacity"]  =  0,
    ["SysHeatMonthRenewPower"]  =  0,
    ["SysHeatMonthElecConsum"]  =  0,
    ["SysHeatMonthCOPEER"]  =  0,
    
    ["SysHeatYearCapacity"]  =  0,
    ["SysHeatYearRenewPower"]  =  0,
    ["SysHeatYearElecConsum"]  =  0,
    ["SysHeatYearCOPEER"]  =  0,
    
    ["SysCoolDayCapacity"]  =  0,
    ["SysCoolDayRenewPower"]  =  0,
    ["SysCoolDayElecConsum"]  =  0,
    ["SysCoolDayCOPEER"]  =  0,
    
    ["SysCoolWeekCapacity"]  =  0,
    ["SysCoolWeekRenewPower"]  =  0,
    ["SysCoolWeekElecConsum"]  =  0,
    ["SysCoolWeekCOPEER"]  =  0,
    
    ["SysCoolMonthCapacity"]  =  0,
    ["SysCoolMonthRenewPower"]  =  0,
    ["SysCoolMonthElecConsum"]  =  0,
    ["SysCoolMonthCOPEER"]  =  0,
    
    ["SysCoolYearCapacity"]  =  0,
    ["SysCoolYearRenewPower"]  =  0,
    ["SysCoolYearElecConsum"]  =  0,
    ["SysCoolYearCOPEER"]  =  0,
    
    ["SysDhwDayCapacity"]  =  0,
    ["SysDhwDayRenewPower"]  =  0,
    ["SysDhwDayElecConsum"]  =  0,
    ["SysDhwDayCOPEER"]  =  0,
    
    ["SysDhwWeekCapacity"]  =  0,
    ["SysDhwWeekRenewPower"]  =  0,
    ["SysDhwWeekElecConsum"]  =  0,
    ["SysDhwWeekCOPEER"]  =  0,
    
    ["SysDhwMonthCapacity"]  =  0,
    ["SysDhwMonthRenewPower"]  =  0,
    ["SysDhwMonthElecConsum"]  =  0,
    ["SysDhwMonthCOPEER"]  =  0,
    
    ["SysDhwYearCapacity"]  =  0,
    ["SysDhwYearRenewPower"]  =  0,
    ["SysDhwYearElecConsum"]  =  0,
    ["SysDhwYearCOPEER"]  =  0,

	
}



---------------公共的函数---------------

-- 打印 table 表
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
        local formatting = szPrefix .. "[" .. k .. "]" .. " = " .. szSuffix

        if type(v) == "table" then
            print(formatting)

            print_lua_table(v, indent + 1)

            print(szPrefix .. "},")
        else
            local szValue = ""

            if type(v) == "string" then
                szValue = string.format("%q", v)
            else
                szValue = tostring(v)
            end

            print(formatting .. szValue .. ",")
        end
    end
end

-- 检查取值是否超过边界
local function checkBoundary(data, min, max)
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

-- String转int
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

-- int转String
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

-- table 转 string
local function table2string(cmd)
    local ret = ""
    local i

    for i = 1, #cmd do
        ret = ret .. string.char(cmd[i])
    end

    return ret
end

-- 十六进制 string 转 table
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

-- 十六进制 string 输出
local function string2hexstring(str)
    local ret = ""

    for i = 1, #str do
        ret = ret .. string.format("%02x", str:byte(i))
    end

    return ret
end

-- table 转 json
local function encode(cmd)
    local tb

    if JSON == nil then
        JSON = require "cjson"
    end

    tb = JSON.encode(cmd)

    return tb
end

-- json 转 table
local function decode(cmd)
    local tb

    if JSON == nil then
        JSON = require "cjson"
    end

    tb = JSON.decode(cmd)

    return tb
end

-- CRC表
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

-- CRC校验
local function crc8_854(dataBuf, start_pos, end_pos)
    local crc = 0

    for si = start_pos, end_pos do
        crc = crc8_854_table[bit.band(bit.bxor(crc, dataBuf[si]), 0xFF) + 1]
    end

    return crc
end

-- sum校验
local function makeSum(tmpbuf, start_pos, end_pos)
	local resVal = 0
	for si = start_pos, end_pos do
		resVal = resVal + tmpbuf[si]
	end
	resVal = bit.bnot(resVal)+1
	resVal = bit.band(resVal, 0x00ff)
	return resVal
end

---------------通讯处理函数---------------

-- 根据消息体+消息体类型，构造成协议帧，并返回
local function getTotalMsg(bodyData,cType)
    local bodyLength = #bodyData --变长

    local msgLength = bodyLength + cmdTable["PROTOCOL_LENGTH"] + 1 --变长

    local msgBytes = {}

    for i = 0, msgLength do  --变长
        msgBytes[i] = 0
    end

    -- 构造消息部分
    msgBytes[0] = cmdTable["PROTOCOL_HEAD"]

    msgBytes[1] = bodyLength + cmdTable["PROTOCOL_LENGTH"] + 1

    msgBytes[2] = cmdTable["DEVICE_TYPE"]

    msgBytes[9] = cType

    -- body
    for i = 0, bodyLength do
        msgBytes[i + cmdTable["PROTOCOL_LENGTH"]] = bodyData[i]
    end

    msgBytes[msgLength] = makeSum(msgBytes, 1, msgLength - 1)

    local msgFinal = {}

    for i = 1, msgLength + 1  do
        msgFinal[i] = msgBytes[i - 1]
    end
    return msgFinal
end

-- 判定键是否为 on,off 类型
local function isStrOnOff(strKey)
	if ("zone1_power_state" == strKey) or
		("zone2_power_state" == strKey) or
		("dhw_power_state" == strKey) or
		("zone1_curve_state" == strKey) or
		("zone2_curve_state" == strKey) or
		("forcetbh_state" == strKey) or
		("fastdhw_state" == strKey) or

		("heat_enable" == strKey) or
		("cool_enable" == strKey) or
		("dhw_enable" == strKey) or
		("double_zone_enable" == strKey) or
		("silence_on_state" == strKey) or
		("holiday_on_state" == strKey) or
		("eco_on_state" == strKey) or
		("remote_onoff" == strKey) or
		("room_thermalen_state" == strKey) or
		("room_thermalmode_state" == strKey) or
		("time_set_state" == strKey) or
        ("protocol_newfunction_en" == strKey) or
		("boostertbh_en" == strKey) or
		("daytimer_timer1en" == strKey) or
		("daytimer_timer2en" == strKey) or
		("daytimer_timer3en" == strKey) or
		("daytimer_timer4en" == strKey) or
		("daytimer_timer5en" == strKey) or
		("daytimer_timer6en" == strKey) or
        --区域2日定时
        ("zone2daytimer_timer1en" == strKey) or
		("zone2daytimer_timer2en" == strKey) or
		("zone2daytimer_timer3en" == strKey) or
		("zone2daytimer_timer4en" == strKey) or
		("zone2daytimer_timer5en" == strKey) or
		("zone2daytimer_timer6en" == strKey) or
        --周定时段使能
		("weektimer_timer1en" == strKey) or
		("weektimer_timer2en" == strKey) or
		("weektimer_timer3en" == strKey) or
		("weektimer_timer4en" == strKey) or
		("weektimer_timer5en" == strKey) or
		("weektimer_timer6en" == strKey) or
        --周定时区域2时段
		("zone2weektimer_timer1en" == strKey) or
		("zone2weektimer_timer2en" == strKey) or
		("zone2weektimer_timer3en" == strKey) or
		("zone2weektimer_timer4en" == strKey) or
		("zone2weektimer_timer5en" == strKey) or
		("zone2weektimer_timer6en" == strKey) or

		("holidayaway_state" == strKey) or
		("holidayaway_heat_state" == strKey) or
		("holidayaway_dhw_state" == strKey) or
		("holidayaway_disinfect_state" == strKey) or
		("silence_function_state" == strKey) or
		("silence_timer1_state" == strKey) or
		("silence_timer2_state" == strKey) or
		("holidayhome_state" == strKey) or
        --在家休假
		("holhometimer_timer1en" == strKey) or
		("holhometimer_timer2en" == strKey) or
		("holhometimer_timer3en" == strKey) or
		("holhometimer_timer4en" == strKey) or
		("holhometimer_timer5en" == strKey) or
		("holhometimer_timer6en" == strKey) or
        --在家休假区域2
        ("zone2holhometimer_timer1en" == strKey) or
        ("zone2holhometimer_timer2en" == strKey) or
        ("zone2holhometimer_timer3en" == strKey) or
        ("zone2holhometimer_timer4en" == strKey) or
        ("zone2holhometimer_timer5en" == strKey) or
        ("zone2holhometimer_timer6en" == strKey) or

		("eco_function_state" == strKey) or
		("eco_timer_state" == strKey) or
        -- DISINFECT
        ("disinfect_function_state" == strKey) or
		("disinfect_run_state" == strKey) or
        --能量消耗参数on/off类型
		("isheatrun0" == strKey) or
		("iscoolrun0" == strKey) or
		("isdhwrun0" == strKey) or
		("istbhrun0" == strKey) or
		("isibhrun0" == strKey) or
		("issmartgrid0" == strKey) or
		("ishighprices0" == strKey) or
		("isbottomprices0" == strKey) or

		("isonline0" == strKey) or
		("isonline1" == strKey) or
		("isonline2" == strKey) or
		("isonline3" == strKey) or
		("isonline4" == strKey) or
		("isonline5" == strKey) or
		("isonline6" == strKey) or
		("isonline7" == strKey) or
		("isonline8" == strKey) or
		("isonline9" == strKey) or
		("isonline10" == strKey) or
		("isonline11" == strKey) or
		("isonline12" == strKey) or
		("isonline13" == strKey) or
		("isonline14" == strKey) or
		("isonline15" == strKey) or
		("isheatrun1" == strKey) or
		("isheatrun2" == strKey) or
		("isheatrun3" == strKey) or
		("isheatrun4" == strKey) or
		("isheatrun5" == strKey) or
		("isheatrun6" == strKey) or
		("isheatrun7" == strKey) or
		("isheatrun8" == strKey) or
		("isheatrun9" == strKey) or
		("isheatrun10" == strKey) or
		("isheatrun11" == strKey) or
		("isheatrun12" == strKey) or
		("isheatrun13" == strKey) or
		("isheatrun14" == strKey) or
		("isheatrun15" == strKey) or
		("iscoolrun1" == strKey) or
		("iscoolrun2" == strKey) or
		("iscoolrun3" == strKey) or
		("iscoolrun4" == strKey) or
		("iscoolrun5" == strKey) or
		("iscoolrun6" == strKey) or
		("iscoolrun7" == strKey) or
		("iscoolrun8" == strKey) or
		("iscoolrun9" == strKey) or
		("iscoolrun10" == strKey) or
		("iscoolrun11" == strKey) or
		("iscoolrun12" == strKey) or
		("iscoolrun13" == strKey) or
		("iscoolrun14" == strKey) or
		("iscoolrun15" == strKey) or
		("isdhwrun1" == strKey) or
		("isdhwrun2" == strKey) or
		("isdhwrun3" == strKey) or
		("isdhwrun4" == strKey) or
		("isdhwrun5" == strKey) or
		("isdhwrun6" == strKey) or
		("isdhwrun7" == strKey) or
		("isdhwrun8" == strKey) or
		("isdhwrun9" == strKey) or
		("isdhwrun10" == strKey) or
		("isdhwrun11" == strKey) or
		("isdhwrun12" == strKey) or
		("isdhwrun13" == strKey) or
		("isdhwrun14" == strKey) or
		("isdhwrun15" == strKey) or
		("istbhrun1" == strKey) or
		("istbhrun2" == strKey) or
		("istbhrun3" == strKey) or
		("istbhrun4" == strKey) or
		("istbhrun5" == strKey) or
		("istbhrun6" == strKey) or
		("istbhrun7" == strKey) or
		("istbhrun8" == strKey) or
		("istbhrun9" == strKey) or
		("istbhrun10" == strKey) or
		("istbhrun11" == strKey) or
		("istbhrun12" == strKey) or
		("istbhrun13" == strKey) or
		("istbhrun14" == strKey) or
		("istbhrun15" == strKey) or

		("isibhrun1" == strKey) or
		("isibhrun2" == strKey) or
		("isibhrun3" == strKey) or
		("isibhrun4" == strKey) or
		("isibhrun5" == strKey) or
		("isibhrun6" == strKey) or
		("isibhrun7" == strKey) or
		("isibhrun8" == strKey) or
		("isibhrun9" == strKey) or
		("isibhrun10" == strKey) or
		("isibhrun11" == strKey) or
		("isibhrun12" == strKey) or
		("isibhrun13" == strKey) or
		("isibhrun14" == strKey) or
		("isibhrun15" == strKey) or

		("isibh2run1 " == strKey) or
		("isibh2run2 " == strKey) or
		("isibh2run3 " == strKey) or
		("isibh2run4 " == strKey) or
		("isibh2run5 " == strKey) or
		("isibh2run6 " == strKey) or
		("isibh2run7 " == strKey) or
		("isibh2run8 " == strKey) or
		("isibh2run9 " == strKey) or
		("isibh2run10 " == strKey) or
		("isibh2run11 " == strKey) or
		("isibh2run12 " == strKey) or
		("isibh2run13 " == strKey) or
		("isibh2run14 " == strKey) or
		("isibh2run15 " == strKey) or
	    --安装设定参数查询0x08
        ("dhwEnable" == strKey) or
        ("boostertbhEn" == strKey) or
        ("disinfectEnable" == strKey) or
        ("dhwPumpEnable" == strKey) or
        ("dhwPriorityTime" == strKey) or
        ("dhwPumpDIEnable" == strKey) or
        ("coolEnable" == strKey) or
        ("fgZone1CoolTempHigh" == strKey) or
        ("heatEnable" == strKey) or
        ("fgZone1HeatTempHigh" == strKey) or
        ("pumpiSliModeEn" == strKey) or
        ("roomSensorEn" == strKey) or
        ("roomTherEn" == strKey) or
        ("roomTherSetModeEn" == strKey) or
        ("dualroomThermostatEn" == strKey) or
        ("fgdhwPriorEn" == strKey) or
        ("acsEnable" == strKey) or
        ("dhwHeaterAhsEn" == strKey) or
        ("tempPcbEn" == strKey) or
        ("tbt2ProbeEn" == strKey) or
        ("pipeExceed10m" == strKey) or
        ("solarCn18En" == strKey) or
        ("fgOwnSolarEn" == strKey) or
        ("fgInputDhwHeater" == strKey) or
        ("smartgridEn" == strKey) or
        ("t1bProbeEn" == strKey) or
        ("fgZone2CoolTempHigh" == strKey) or
        ("fgZone2HeatTempHigh" == strKey) or
        ("doubleZoneEn" == strKey) or
        ("fgTaProbeIdu" == strKey) or
        ("tbt1ProbeEn" == strKey) or
        ("fgIbhInTank" == strKey) or
		--("tbhEnFunc" == strKey) or
        --0x10主机查询参数 on/off
		("fgReqParaSet" ==  strKey)  or
		("fgReqVerAsk" ==  strKey)  or
		("fgReqSNAsk" ==  strKey)  or
		("fgUnitLockSignal" ==  strKey)  or
		("fgEVUSignal" ==  strKey)  or
		("fgSGSignal" ==  strKey)  or
		("fgTankAntiFreeze" ==  strKey)  or
		("fgSolarInput" ==  strKey)  or
		("fgRoomTherCoolRun" ==  strKey)  or
		("fgRoomTherHeatRun" ==  strKey)  or
		("fgOutDoorTestMode" ==  strKey)  or
		("fgRemoteOnOff" ==  strKey)  or
		("fgBackOil" ==  strKey)  or
		("fgAntiFreezeRun" ==  strKey)  or
		("fgDefrost" ==  strKey)  or
		("fgIsSlaveUnit" ==  strKey)  or
		("fgTBHEnable" ==  strKey)  or
		("fgAHSIsOwn" ==  strKey)  or
		("fgCapTestEnable" ==  strKey)  or
		("fgT1BSensorEnable" ==  strKey)  or
		("fgAHSDHWMode" ==  strKey)  or
		("fgIBH1Enable" ==  strKey)  or
		("fgT1SensorEnable" ==  strKey)  or
		("fgEdgeVersionType" ==  strKey)  or
		("fgFactReqTherHeatOn" ==  strKey)  or
		("fgDHWRun" ==  strKey)  or
		("fgHeatRun" ==  strKey)  or
		("fgCoolRun" ==  strKey)  or
		("fgFactReqTherCoolOn" ==  strKey)  or
		("fgFactReqSolarOn" ==  strKey)  or
		("fgFactoryRun" ==  strKey)  or
		("fgDefValveOn" ==  strKey)  or
		("fgAHSValveOn" ==  strKey)  or
		("fgRunValveOn" ==  strKey)  or
		("fgAlmValveOn" ==  strKey)  or
		("fgPumpSolarOn" ==  strKey)  or
		("fgHeat4ValveOn" ==  strKey)  or
		("fgSV3Output" ==  strKey)  or
		("fgMixedPumpValveOn" ==  strKey)  or
		("fgPumpDHWOn" ==  strKey)  or
		("fgPumpOOn" ==  strKey)  or
		("fgSV2On" ==  strKey)  or
		("fgSV1On" ==  strKey)  or
		("fgPumpIOutput" ==  strKey)  or
		("fgTBHOutput" ==  strKey)  or
		("fgIBH2Output" ==  strKey)  or
		("fgIBH1Output" ==  strKey) or
        ("HMIEnergyAnaSetEN" ==  strKey) or
		("SysEnergyAnaEN" ==  strKey)
		then
		return true
	else
		return false
	end
end

-- 判定键是否为 on,off,0xff 类型
local function isStrOnOffInvalid(strKey)
	if ("pre_heat" == strKey) then
		return true
	else
		return false
	end
end

-- 判定键是否为 auto,cool,heat 类型
local function isStrMode(strKey)
	if ("run_mode_set" == strKey) or
		("runmode_under_auto" == strKey) or
        --日定时模式
		("daytimer_timer1_mode" == strKey) or
		("daytimer_timer2_mode" == strKey) or
		("daytimer_timer3_mode" == strKey) or
		("daytimer_timer4_mode" == strKey) or
		("daytimer_timer5_mode" == strKey) or
		("daytimer_timer6_mode" == strKey) or
          --区域2日定时模式
        ("zone2daytimer_timer1_mode" == strKey) or
		("zone2daytimer_timer2_mode" == strKey) or
		("zone2daytimer_timer3_mode" == strKey) or
		("zone2daytimer_timer4_mode" == strKey) or
		("zone2daytimer_timer5_mode" == strKey) or
		("zone2daytimer_timer6_mode" == strKey) or
        --周定时模式
		("weektimer_timer1_mode" == strKey) or
		("weektimer_timer2_mode" == strKey) or
		("weektimer_timer3_mode" == strKey) or
		("weektimer_timer4_mode" == strKey) or
		("weektimer_timer5_mode" == strKey) or
		("weektimer_timer6_mode" == strKey)	or
        --周定时区域2模式
		("zone2weektimer_timer1_mode" == strKey) or
		("zone2weektimer_timer2_mode" == strKey) or
		("zone2weektimer_timer3_mode" == strKey) or
		("zone2weektimer_timer4_mode" == strKey) or
		("zone2weektimer_timer5_mode" == strKey) or
		("zone2weektimer_timer6_mode" == strKey) or

		("holhometimer_timer1_mode" == strKey) or
		("holhometimer_timer2_mode" == strKey) or
		("holhometimer_timer3_mode" == strKey) or
		("holhometimer_timer4_mode" == strKey) or
		("holhometimer_timer5_mode" == strKey) or
		("holhometimer_timer6_mode" == strKey) or
		--holhome 区域2
        ("zone2holhometimer_timer1_mode" == strKey) or
		("zone2holhometimer_timer2_mode" == strKey) or
		("zone2holhometimer_timer3_mode" == strKey) or
		("zone2holhometimer_timer4_mode" == strKey) or
		("zone2holhometimer_timer5_mode" == strKey) or
		("zone2holhometimer_timer6_mode" == strKey)
		then
		return true
	else
		return false
	end
end
-- 判定键是否为 气温,水温控制 类型
local function isStrWaterRoomType(strKey)
	if ("zone1_temp_type" == strKey) or
		("zone2_temp_type" == strKey) then
		return true
	else
		return false
	end
end
-- 判定键是否为 末端类型 类型
local function isStrTerminalType(strKey)
	if ("zone1_terminal_type" == strKey) or
		("zone2_terminal_type" == strKey) then
		return true
	else
		return false
	end
end

-- 判定键是否为 等级 类型
local function isStrLevelType(strKey)
	if ("silence_function_level" == strKey) then
		return true
	else
		return false
	end
end

--单字节字符串有符号整形数据负数转换
local function isStrSignedByteType(strKey)
	if ("t4" == strKey) or
	("tempT3" == strKey) or
	("tempT4" == strKey) or
	("tempTp" == strKey) or
	("tempTwin" == strKey) or
	("tempTwout" == strKey) or
	("tempT1" == strKey) or
	("tempTw2" == strKey) or
	("tempT2" == strKey) or
	("tempT2b" == strKey) or
	("tempT5" == strKey) or
	("tempTh" == strKey) or
	("tempTa" == strKey) or
	("tank_actual_temp" == strKey) or
	("tempTh" == strKey) 
	then
	--	("zone2_terminal_type" == strKey) then
		return true
	else
		return false
	end
end

--双字节字节有符号整形数据
local function isStrSignedDoubleByteType(strKey)
	if ("t4Dhwmin" == strKey) or
	   ("t4TBHon" == strKey) or
	   ("t4Cmin" == strKey) or
	   ("t4Hmin" == strKey) or
       ("t4IBHon" == strKey) or
       ("t4AHSon" == strKey) or
	   ("dT1AHSoff" == strKey) or
	   ("t4C1" == strKey) or
	   ("t4C2" == strKey) or
	   ("t4H1" == strKey) or
	   ("t4H2" == strKey) or
	   ("t4Cmin" == strKey) or
	   ("t4Hmin" == strKey) or

		("t4IBHon" == strKey) 
        then
		return true
	else
		return false
	end
end
-- 更新 intvalue 值至 整型变量 myTable[strKey] 及 字符型变量 pvar_out[strKey]中
-- pvar_out[strKey] 为输出类型
-- 若 myTable[strKey] 为位变量，则 bitx 对应 value 的位, 否则为 nil
local function binToModel(pvar_out, strKey, intvalue, bitx)
	local _intvalue = intvalue
	local _strvalue = ""

	if myTable[strKey] ~= nil then
		if isStrOnOff(strKey) then
			if bitx ~= nil then
				if (bit.band(_intvalue, bitx) > 0) then
					_intvalue = unitTable["on"]
					_strvalue = unitTable["str_on"]
				else
					_intvalue = unitTable["off"]
					_strvalue = unitTable["str_off"]
				end
			end
		elseif isStrMode(strKey) then
			if unitTable["auto"] == _intvalue then
				_strvalue = unitTable["str_auto"]
			elseif unitTable["cool"] == _intvalue then
				_strvalue = unitTable["str_cool"]
			elseif unitTable["heat"] == _intvalue then
				_strvalue = unitTable["str_heat"]
            elseif unitTable["dhw"] == _intvalue then
				_strvalue = unitTable["str_dhw"]
			end
		elseif isStrLevelType(strKey) then
			if bitx ~= nil then
				if ((bit.band(_intvalue, bitx)) > 0) then
					_intvalue = unitTable["level_2"]
					_strvalue = unitTable["str_level_2"]
				else
					_intvalue = unitTable["level_1"]
					_strvalue = unitTable["str_level_1"]
				end
			end
		elseif isStrWaterRoomType(strKey) then
			if bitx ~= nil then
				if ((bit.band(_intvalue, bitx)) > 0) then
					_intvalue = unitTable["water_temperature_type"]
					_strvalue = unitTable["str_water_temperature_type"]
				else
					_intvalue = unitTable["room_temperature_type"]
					_strvalue = unitTable["str_room_temperature_type"]
				end
			end
		elseif "zone1_terminal_type" == strKey then
			--_intvalue = (_intvalue >>4) & 0x03 --取intvalue bit4,5;注意测试 bit.rshift(bit.band(messageBytes[2], 0x30),4)、(_intvalue >>4) & 0x03
			_intvalue = bit.rshift(bit.band(_intvalue, 0x30),4)
			if unitTable["fan_coil"] == _intvalue then
				_strvalue = unitTable["str_fan_coil"]
			elseif unitTable["floor_heat"] == _intvalue then
				_strvalue = unitTable["str_floor_heat"]
			elseif unitTable["radiatior"] == _intvalue then
				_strvalue = unitTable["str_radiatior"]
			end
		elseif "zone2_terminal_type" == strKey then
			--_intvalue = (_intvalue >>6) & 0x03   --取intvalue bit6,7;注意测试 bit.rshift(bit.band(messageBytes[2], 0xC0),6)
			_intvalue = bit.rshift(bit.band(_intvalue, 0xC0),6)
			if unitTable["fan_coil"] == _intvalue then
				_strvalue = unitTable["str_fan_coil"]
			elseif unitTable["floor_heat"] == _intvalue then
				_strvalue = unitTable["str_floor_heat"]
			elseif unitTable["radiatior"] == _intvalue then
				_strvalue = unitTable["str_radiatior"]
			end
		elseif isStrOnOffInvalid(strKey) then
			if bitx ~= nil then
				if (bit.band(_intvalue, bitx) > 0) then
					_intvalue = unitTable["on"]
					_strvalue = unitTable["str_on"]
				else
					_intvalue = unitTable["off"]
					_strvalue = unitTable["str_off"]
				end
			end
		elseif "pre_heat_flag" == strKey then
			if bitx ~= nil then
				if (bit.band(_intvalue, bitx) > 0) then -- 特殊处理，1为无效，0为有效
					_intvalue = unitTable["off"]
					_strvalue = unitTable["str_off"]
				else
					_intvalue = unitTable["on"]
					_strvalue = unitTable["str_on"]
				end
			end
        elseif isStrSignedByteType(strKey) then  
            --2023-2-7
			if intvalue > 127 then
				_intvalue = intvalue - 256
            else
                _intvalue = intvalue 
            end
            _strvalue = int2String(_intvalue)   
        elseif isStrSignedDoubleByteType(strKey) then  
			if intvalue > 32768 then
				_intvalue = intvalue - 65536
            else
                _intvalue = intvalue 
            end    
            _strvalue = int2String(_intvalue)   
		else
			_strvalue = int2String(intvalue) -- 数值类型，将数值转为字符
		end

		-- 更新参数值
		pvar_out[strKey] = _strvalue
		myTable[strKey] = _intvalue
	end
end

-- 更新 pvar[strKey] 值至 myTable[strKey] 中
-- 若 myTable[strKey] 为位变量，则 bitx 对应 value 的位, 否则为 nil
local function modelToBin(pvar, strKey, bitx)
	local _strValue = pvar[strKey]
	if isStrOnOff(strKey) then
		if bitx ~= nil then
			if(_strValue == unitTable["str_on"]) then
				myTable[strKey] = bitx
			elseif(_strValue == unitTable["str_off"]) then
				myTable[strKey] = 0
			end
		end
	elseif isStrMode(strKey) then
		if _strValue == unitTable["str_auto"] then
			myTable[strKey] = unitTable["auto"]
		elseif _strValue == unitTable["str_cool"] then
			myTable[strKey] = unitTable["cool"]
		elseif _strValue == unitTable["str_heat"] then
			myTable[strKey] = unitTable["heat"]
		elseif _strValue == unitTable["str_dhw"] then
			myTable[strKey] = unitTable["dhw"] 
		end
	elseif isStrLevelType(strKey) then
		if bitx ~= nil then
			if(_strValue == unitTable["str_level_2"]) then
				myTable[strKey] = bitx
			elseif(_strValue == unitTable["str_level_1"]) then
				myTable[strKey] = unitTable["off"]
			end
		end
	elseif isStrOnOffInvalid(strKey) then
		if bitx ~= nil then
			if(_strValue == unitTable["str_on"]) then
				myTable[strKey] = bitx
			elseif(_strValue == unitTable["str_off"]) then
				myTable[strKey] = unitTable["off"]
			else
				myTable[strKey] = unitTable["u8_invalid"]
			end
		end
	else
		if _strValue ~= nil then
            local _prop_val = string2Int(_strValue)
            if _prop_val < 0 then
                _prop_val = bit.lshift(0x1, 1 * 8) + _prop_val
            end
			myTable[strKey] = _prop_val
		end
	end
end

-- 根据 json 属性变量转存至 myTable
-- 用于解析云字符含义
local function jsonToModel(jsonCmd)
    local _controlcmd = jsonCmd
	-- 基本控制
	--protocol_newfunction_en控制下发ON，针对新升级WIFI电控软件解析，off为兼容已投产软件解析.
	modelToBin(_controlcmd, "protocol_newfunction_en", BIT0)

	modelToBin(_controlcmd, "zone1_power_state", BIT0)
	modelToBin(_controlcmd, "zone2_power_state", BIT1)
	modelToBin(_controlcmd, "dhw_power_state", BIT2)

	modelToBin(_controlcmd, "run_mode_set", nil)
	modelToBin(_controlcmd, "zone1_temp_set", nil)
	modelToBin(_controlcmd, "zone2_temp_set", nil)
	modelToBin(_controlcmd, "dhw_temp_set", nil)
	modelToBin(_controlcmd, "room_temp_set", nil)

	modelToBin(_controlcmd, "zone1_curve_state", BIT0)
	modelToBin(_controlcmd, "zone2_curve_state", BIT1)
	modelToBin(_controlcmd, "forcetbh_state", BIT2)
	modelToBin(_controlcmd, "fastdhw_state", BIT3)
    modelToBin(_controlcmd, "zone1_curve_type", nil)
    modelToBin(_controlcmd, "zone2_curve_type", nil)

	-- 日定时1
	modelToBin(_controlcmd, "daytimer_timer1en", BIT0)
	modelToBin(_controlcmd, "daytimer_timer1_mode", nil)
	modelToBin(_controlcmd, "daytimer_timer1_temp", nil)
	modelToBin(_controlcmd, "daytimer_timer1_openhour", nil)
	modelToBin(_controlcmd, "daytimer_timer1_openmin", nil)
	modelToBin(_controlcmd, "daytimer_timer1_closehour", nil)
	modelToBin(_controlcmd, "daytimer_timer1_closemin", nil)
	-- 日定时2
	modelToBin(_controlcmd, "daytimer_timer2en", BIT1)
	modelToBin(_controlcmd, "daytimer_timer2_mode", nil)
	modelToBin(_controlcmd, "daytimer_timer2_temp", nil)
	modelToBin(_controlcmd, "daytimer_timer2_openhour", nil)
	modelToBin(_controlcmd, "daytimer_timer2_openmin", nil)
	modelToBin(_controlcmd, "daytimer_timer2_closehour", nil)
	modelToBin(_controlcmd, "daytimer_timer2_closemin", nil)
	-- 日定时3
	modelToBin(_controlcmd, "daytimer_timer3en", BIT2)
	modelToBin(_controlcmd, "daytimer_timer3_mode", nil)
	modelToBin(_controlcmd, "daytimer_timer3_temp", nil)
	modelToBin(_controlcmd, "daytimer_timer3_openhour", nil)
	modelToBin(_controlcmd, "daytimer_timer3_openmin", nil)
	modelToBin(_controlcmd, "daytimer_timer3_closehour", nil)
	modelToBin(_controlcmd, "daytimer_timer3_closemin", nil)
	-- 日定时4
	modelToBin(_controlcmd, "daytimer_timer4en", BIT3)
	modelToBin(_controlcmd, "daytimer_timer4_mode", nil)
	modelToBin(_controlcmd, "daytimer_timer4_temp", nil)
	modelToBin(_controlcmd, "daytimer_timer4_openhour", nil)
	modelToBin(_controlcmd, "daytimer_timer4_openmin", nil)
	modelToBin(_controlcmd, "daytimer_timer4_closehour", nil)
	modelToBin(_controlcmd, "daytimer_timer4_closemin", nil)
	-- 日定时5
	modelToBin(_controlcmd, "daytimer_timer5en", BIT4)
	modelToBin(_controlcmd, "daytimer_timer5_mode", nil)
	modelToBin(_controlcmd, "daytimer_timer5_temp", nil)
	modelToBin(_controlcmd, "daytimer_timer5_openhour", nil)
	modelToBin(_controlcmd, "daytimer_timer5_openmin", nil)
	modelToBin(_controlcmd, "daytimer_timer5_closehour", nil)
	modelToBin(_controlcmd, "daytimer_timer5_closemin", nil)
	-- 日定时6
	modelToBin(_controlcmd, "daytimer_timer6en", BIT5)
	modelToBin(_controlcmd, "daytimer_timer6_mode", nil)
	modelToBin(_controlcmd, "daytimer_timer6_temp", nil)
	modelToBin(_controlcmd, "daytimer_timer6_openhour", nil)
	modelToBin(_controlcmd, "daytimer_timer6_openmin", nil)
	modelToBin(_controlcmd, "daytimer_timer6_closehour", nil)
	modelToBin(_controlcmd, "daytimer_timer6_closemin", nil)

    -- 区域2日定时1
	modelToBin(_controlcmd, "zone2daytimer_timer1en", BIT0)
	modelToBin(_controlcmd, "zone2daytimer_timer1_mode", nil)
	modelToBin(_controlcmd, "zone2daytimer_timer1_temp", nil)
	modelToBin(_controlcmd, "zone2daytimer_timer1_openhour", nil)
	modelToBin(_controlcmd, "zone2daytimer_timer1_openmin", nil)
	modelToBin(_controlcmd, "zone2daytimer_timer1_closehour", nil)
	modelToBin(_controlcmd, "zone2daytimer_timer1_closemin", nil)
	-- 日定时2
	modelToBin(_controlcmd, "zone2daytimer_timer2en", BIT1)
	modelToBin(_controlcmd, "zone2daytimer_timer2_mode", nil)
	modelToBin(_controlcmd, "zone2daytimer_timer2_temp", nil)
	modelToBin(_controlcmd, "zone2daytimer_timer2_openhour", nil)
	modelToBin(_controlcmd, "zone2daytimer_timer2_openmin", nil)
	modelToBin(_controlcmd, "zone2daytimer_timer2_closehour", nil)
	modelToBin(_controlcmd, "zone2daytimer_timer2_closemin", nil)
	-- 日定时3
	modelToBin(_controlcmd, "zone2daytimer_timer3en", BIT2)
	modelToBin(_controlcmd, "zone2daytimer_timer3_mode", nil)
	modelToBin(_controlcmd, "zone2daytimer_timer3_temp", nil)
	modelToBin(_controlcmd, "zone2daytimer_timer3_openhour", nil)
	modelToBin(_controlcmd, "zone2daytimer_timer3_openmin", nil)
	modelToBin(_controlcmd, "zone2daytimer_timer3_closehour", nil)
	modelToBin(_controlcmd, "zone2daytimer_timer3_closemin", nil)
	-- 日定时4
	modelToBin(_controlcmd, "zone2daytimer_timer4en", BIT3)
	modelToBin(_controlcmd, "zone2daytimer_timer4_mode", nil)
	modelToBin(_controlcmd, "zone2daytimer_timer4_temp", nil)
	modelToBin(_controlcmd, "zone2daytimer_timer4_openhour", nil)
	modelToBin(_controlcmd, "zone2daytimer_timer4_openmin", nil)
	modelToBin(_controlcmd, "zone2daytimer_timer4_closehour", nil)
	modelToBin(_controlcmd, "zone2daytimer_timer4_closemin", nil)
	-- 日定时5
	modelToBin(_controlcmd, "zone2daytimer_timer5en", BIT4)
	modelToBin(_controlcmd, "zone2daytimer_timer5_mode", nil)
	modelToBin(_controlcmd, "zone2daytimer_timer5_temp", nil)
	modelToBin(_controlcmd, "zone2daytimer_timer5_openhour", nil)
	modelToBin(_controlcmd, "zone2daytimer_timer5_openmin", nil)
	modelToBin(_controlcmd, "zone2daytimer_timer5_closehour", nil)
	modelToBin(_controlcmd, "zone2daytimer_timer5_closemin", nil)
	-- 日定时6
	modelToBin(_controlcmd, "zone2daytimer_timer6en", BIT5)
	modelToBin(_controlcmd, "zone2daytimer_timer6_mode", nil)
	modelToBin(_controlcmd, "zone2daytimer_timer6_temp", nil)
	modelToBin(_controlcmd, "zone2daytimer_timer6_openhour", nil)
	modelToBin(_controlcmd, "zone2daytimer_timer6_openmin", nil)
	modelToBin(_controlcmd, "zone2daytimer_timer6_closehour", nil)
	modelToBin(_controlcmd, "zone2daytimer_timer6_closemin", nil)


	-- 周定时星期设置标志
	modelToBin(_controlcmd, "weektimer_setday", nil)
	    -- 周定时1
	modelToBin(_controlcmd, "weektimer_timer1en", BIT0)
	modelToBin(_controlcmd, "weektimer_timer1_mode", nil)
	modelToBin(_controlcmd, "weektimer_timer1_temp", nil)
	modelToBin(_controlcmd, "weektimer_timer1_openhour", nil)
	modelToBin(_controlcmd, "weektimer_timer1_openmin", nil)
	modelToBin(_controlcmd, "weektimer_timer1_closehour", nil)
	modelToBin(_controlcmd, "weektimer_timer1_closemin", nil)
	    -- 周定时2
	modelToBin(_controlcmd, "weektimer_timer2en", BIT1)
	modelToBin(_controlcmd, "weektimer_timer2_mode", nil)
	modelToBin(_controlcmd, "weektimer_timer2_temp", nil)
	modelToBin(_controlcmd, "weektimer_timer2_openhour", nil)
	modelToBin(_controlcmd, "weektimer_timer2_openmin", nil)
	modelToBin(_controlcmd, "weektimer_timer2_closehour", nil)
	modelToBin(_controlcmd, "weektimer_timer2_closemin", nil)
	    -- 周定时3
	modelToBin(_controlcmd, "weektimer_timer3en", BIT2)
	modelToBin(_controlcmd, "weektimer_timer3_mode", nil)
	modelToBin(_controlcmd, "weektimer_timer3_temp", nil)
	modelToBin(_controlcmd, "weektimer_timer3_openhour", nil)
	modelToBin(_controlcmd, "weektimer_timer3_openmin", nil)
	modelToBin(_controlcmd, "weektimer_timer3_closehour", nil)
	modelToBin(_controlcmd, "weektimer_timer3_closemin", nil)
	    -- 周定时4
	modelToBin(_controlcmd, "weektimer_timer4en", BIT3)
	modelToBin(_controlcmd, "weektimer_timer4_mode", nil)
	modelToBin(_controlcmd, "weektimer_timer4_temp", nil)
	modelToBin(_controlcmd, "weektimer_timer4_openhour", nil)
	modelToBin(_controlcmd, "weektimer_timer4_openmin", nil)
	modelToBin(_controlcmd, "weektimer_timer4_closehour", nil)
	modelToBin(_controlcmd, "weektimer_timer4_closemin", nil)
	    -- 周定时5
	modelToBin(_controlcmd, "weektimer_timer5en", BIT4)
	modelToBin(_controlcmd, "weektimer_timer5_mode", nil)
	modelToBin(_controlcmd, "weektimer_timer5_temp", nil)
	modelToBin(_controlcmd, "weektimer_timer5_openhour", nil)
	modelToBin(_controlcmd, "weektimer_timer5_openmin", nil)
	modelToBin(_controlcmd, "weektimer_timer5_closehour", nil)
	modelToBin(_controlcmd, "weektimer_timer5_closemin", nil)
	    -- 周定时6
	modelToBin(_controlcmd, "weektimer_timer6en", BIT5)
	modelToBin(_controlcmd, "weektimer_timer6_mode", nil)
	modelToBin(_controlcmd, "weektimer_timer6_temp", nil)
	modelToBin(_controlcmd, "weektimer_timer6_openhour", nil)
	modelToBin(_controlcmd, "weektimer_timer6_openmin", nil)
	modelToBin(_controlcmd, "weektimer_timer6_closehour", nil)
	modelToBin(_controlcmd, "weektimer_timer6_closemin", nil)
    -- 区域2周定时星期设置标志
	modelToBin(_controlcmd, "zone2weektimer_setday", nil)
        -- 区域2周定时1
    modelToBin(_controlcmd, "zone2weektimer_timer1en", BIT0)
    modelToBin(_controlcmd, "zone2weektimer_timer1_mode", nil)
    modelToBin(_controlcmd, "zone2weektimer_timer1_temp", nil)
    modelToBin(_controlcmd, "zone2weektimer_timer1_openhour", nil)
    modelToBin(_controlcmd, "zone2weektimer_timer1_openmin", nil)
    modelToBin(_controlcmd, "zone2weektimer_timer1_closehour", nil)
    modelToBin(_controlcmd, "zone2weektimer_timer1_closemin", nil)
        -- 区域2周定时2
    modelToBin(_controlcmd, "zone2weektimer_timer2en", BIT1)
    modelToBin(_controlcmd, "zone2weektimer_timer2_mode", nil)
    modelToBin(_controlcmd, "zone2weektimer_timer2_temp", nil)
    modelToBin(_controlcmd, "zone2weektimer_timer2_openhour", nil)
    modelToBin(_controlcmd, "zone2weektimer_timer2_openmin", nil)
    modelToBin(_controlcmd, "zone2weektimer_timer2_closehour", nil)
    modelToBin(_controlcmd, "zone2weektimer_timer2_closemin", nil)
        -- 区域2周定时3
    modelToBin(_controlcmd, "zone2weektimer_timer3en", BIT2)
    modelToBin(_controlcmd, "zone2weektimer_timer3_mode", nil)
    modelToBin(_controlcmd, "zone2weektimer_timer3_temp", nil)
    modelToBin(_controlcmd, "zone2weektimer_timer3_openhour", nil)
    modelToBin(_controlcmd, "zone2weektimer_timer3_openmin", nil)
    modelToBin(_controlcmd, "zone2weektimer_timer3_closehour", nil)
    modelToBin(_controlcmd, "zone2weektimer_timer3_closemin", nil)
        -- 区域2周定时4
    modelToBin(_controlcmd, "zone2weektimer_timer4en", BIT3)
    modelToBin(_controlcmd, "zone2weektimer_timer4_mode", nil)
    modelToBin(_controlcmd, "zone2weektimer_timer4_temp", nil)
    modelToBin(_controlcmd, "zone2weektimer_timer4_openhour", nil)
    modelToBin(_controlcmd, "zone2weektimer_timer4_openmin", nil)
    modelToBin(_controlcmd, "zone2weektimer_timer4_closehour", nil)
    modelToBin(_controlcmd, "zone2weektimer_timer4_closemin", nil)
        -- 区域2周定时5
    modelToBin(_controlcmd, "zone2weektimer_timer5en", BIT4)
    modelToBin(_controlcmd, "zone2weektimer_timer5_mode", nil)
    modelToBin(_controlcmd, "zone2weektimer_timer5_temp", nil)
    modelToBin(_controlcmd, "zone2weektimer_timer5_openhour", nil)
    modelToBin(_controlcmd, "zone2weektimer_timer5_openmin", nil)
    modelToBin(_controlcmd, "zone2weektimer_timer5_closehour", nil)
    modelToBin(_controlcmd, "zone2weektimer_timer5_closemin", nil)
        -- 区域2周定时6
    modelToBin(_controlcmd, "zone2weektimer_timer6en", BIT5)
    modelToBin(_controlcmd, "zone2weektimer_timer6_mode", nil)
    modelToBin(_controlcmd, "zone2weektimer_timer6_temp", nil)
    modelToBin(_controlcmd, "zone2weektimer_timer6_openhour", nil)
    modelToBin(_controlcmd, "zone2weektimer_timer6_openmin", nil)
    modelToBin(_controlcmd, "zone2weektimer_timer6_closehour", nil)
    modelToBin(_controlcmd, "zone2weektimer_timer6_closemin", nil)

	-- 外出休假HOLIDAY AWAY
	modelToBin(_controlcmd, "holidayaway_state", BIT0)
	modelToBin(_controlcmd, "holidayaway_startyear", nil)
	modelToBin(_controlcmd, "holidayaway_startmonth", nil)
	modelToBin(_controlcmd, "holidayaway_startdate", nil)
	modelToBin(_controlcmd, "holidayaway_endyear", nil)
	modelToBin(_controlcmd, "holidayaway_endmonth", nil)
	modelToBin(_controlcmd, "holidayaway_enddate", nil)
    modelToBin(_controlcmd, "holidayaway_heat_state", BIT0)
	modelToBin(_controlcmd, "holidayaway_dhw_state", BIT1)
	modelToBin(_controlcmd, "holidayaway_disinfect_state", BIT2)
	-- 静音控制
	modelToBin(_controlcmd, "silence_function_state", BIT0)
	modelToBin(_controlcmd, "silence_function_level", BIT1)
	modelToBin(_controlcmd, "silence_timer1_state", BIT2)
	modelToBin(_controlcmd, "silence_timer2_state", BIT3)
	modelToBin(_controlcmd, "silence_timer1_starthour", nil)
	modelToBin(_controlcmd, "silence_timer1_startmin", nil)
	modelToBin(_controlcmd, "silence_timer1_endhour", nil)
	modelToBin(_controlcmd, "silence_timer1_endmin", nil)
	modelToBin(_controlcmd, "silence_timer2_starthour", nil)
	modelToBin(_controlcmd, "silence_timer2_startmin", nil)
	modelToBin(_controlcmd, "silence_timer2_endhour", nil)
	modelToBin(_controlcmd, "silence_timer2_endmin", nil)
	-- 在家休假HOLIDAY HOME
	modelToBin(_controlcmd, "holidayhome_state", BIT0)
	modelToBin(_controlcmd, "holidayhome_startyear", nil)
	modelToBin(_controlcmd, "holidayhome_startmonth", nil)
	modelToBin(_controlcmd, "holidayhome_startdate", nil)
	modelToBin(_controlcmd, "holidayhome_endyear", nil)
	modelToBin(_controlcmd, "holidayhome_endmonth", nil)
	modelToBin(_controlcmd, "holidayhome_enddate", nil)
	-- HOLIDAY HOME定时1
	modelToBin(_controlcmd, "holhometimer_timer1en", BIT0)
	modelToBin(_controlcmd, "holhometimer_timer1_mode", nil)
	modelToBin(_controlcmd, "holhometimer_timer1_temp", nil)
	modelToBin(_controlcmd, "holhometimer_timer1_openhour", nil)
	modelToBin(_controlcmd, "holhometimer_timer1_openmin", nil)
	modelToBin(_controlcmd, "holhometimer_timer1_closehour", nil)
	modelToBin(_controlcmd, "holhometimer_timer1_closemin", nil)
	-- HOLIDAY HOME日定时2
	modelToBin(_controlcmd, "holhometimer_timer2en", BIT1)
	modelToBin(_controlcmd, "holhometimer_timer2_mode", nil)
	modelToBin(_controlcmd, "holhometimer_timer2_temp", nil)
	modelToBin(_controlcmd, "holhometimer_timer2_openhour", nil)
	modelToBin(_controlcmd, "holhometimer_timer2_openmin", nil)
	modelToBin(_controlcmd, "holhometimer_timer2_closehour", nil)
	modelToBin(_controlcmd, "holhometimer_timer2_closemin", nil)
	-- HOLIDAY HOME定时3
	modelToBin(_controlcmd, "holhometimer_timer3en", BIT2)
	modelToBin(_controlcmd, "holhometimer_timer3_mode", nil)
	modelToBin(_controlcmd, "holhometimer_timer3_temp", nil)
	modelToBin(_controlcmd, "holhometimer_timer3_openhour", nil)
	modelToBin(_controlcmd, "holhometimer_timer3_openmin", nil)
	modelToBin(_controlcmd, "holhometimer_timer3_closehour", nil)
	modelToBin(_controlcmd, "holhometimer_timer3_closemin", nil)
	-- HOLIDAY HOME日定时4
	modelToBin(_controlcmd, "holhometimer_timer4en", BIT3)
	modelToBin(_controlcmd, "holhometimer_timer4_mode", nil)
	modelToBin(_controlcmd, "holhometimer_timer4_temp", nil)
	modelToBin(_controlcmd, "holhometimer_timer4_openhour", nil)
	modelToBin(_controlcmd, "holhometimer_timer4_openmin", nil)
	modelToBin(_controlcmd, "holhometimer_timer4_closehour", nil)
	modelToBin(_controlcmd, "holhometimer_timer4_closemin", nil)
	-- HOLIDAY HOME日定时5
	modelToBin(_controlcmd, "holhometimer_timer5en", BIT4)
	modelToBin(_controlcmd, "holhometimer_timer5_mode", nil)
	modelToBin(_controlcmd, "holhometimer_timer5_temp", nil)
	modelToBin(_controlcmd, "holhometimer_timer5_openhour", nil)
	modelToBin(_controlcmd, "holhometimer_timer5_openmin", nil)
	modelToBin(_controlcmd, "holhometimer_timer5_closehour", nil)
	modelToBin(_controlcmd, "holhometimer_timer5_closemin", nil)
	-- HOLIDAY HOME日定时6
	modelToBin(_controlcmd, "holhometimer_timer6en", BIT5)
	modelToBin(_controlcmd, "holhometimer_timer6_mode", nil)
	modelToBin(_controlcmd, "holhometimer_timer6_temp", nil)
	modelToBin(_controlcmd, "holhometimer_timer6_openhour", nil)
	modelToBin(_controlcmd, "holhometimer_timer6_openmin", nil)
	modelToBin(_controlcmd, "holhometimer_timer6_closehour", nil)
	modelToBin(_controlcmd, "holhometimer_timer6_closemin", nil)

    -- HOLIDAY HOME区域2定时1
    modelToBin(_controlcmd, "zone2holhometimer_timer1en", BIT0)
    modelToBin(_controlcmd, "zone2holhometimer_timer1_mode", nil)
    modelToBin(_controlcmd, "zone2holhometimer_timer1_temp", nil)
    modelToBin(_controlcmd, "zone2holhometimer_timer1_openhour", nil)
    modelToBin(_controlcmd, "zone2holhometimer_timer1_openmin", nil)
    modelToBin(_controlcmd, "zone2holhometimer_timer1_closehour", nil)
    modelToBin(_controlcmd, "zone2holhometimer_timer1_closemin", nil)
    -- HOLIDAY HOME日区域2定时2
    modelToBin(_controlcmd, "zone2holhometimer_timer2en", BIT1)
    modelToBin(_controlcmd, "zone2holhometimer_timer2_mode", nil)
    modelToBin(_controlcmd, "zone2holhometimer_timer2_temp", nil)
    modelToBin(_controlcmd, "zone2holhometimer_timer2_openhour", nil)
    modelToBin(_controlcmd, "zone2holhometimer_timer2_openmin", nil)
    modelToBin(_controlcmd, "zone2holhometimer_timer2_closehour", nil)
    modelToBin(_controlcmd, "zone2holhometimer_timer2_closemin", nil)
    -- HOLIDAY HOME区域2定时3
    modelToBin(_controlcmd, "zone2holhometimer_timer3en", BIT2)
    modelToBin(_controlcmd, "zone2holhometimer_timer3_mode", nil)
    modelToBin(_controlcmd, "zone2holhometimer_timer3_temp", nil)
    modelToBin(_controlcmd, "zone2holhometimer_timer3_openhour", nil)
    modelToBin(_controlcmd, "zone2holhometimer_timer3_openmin", nil)
    modelToBin(_controlcmd, "zone2holhometimer_timer3_closehour", nil)
    modelToBin(_controlcmd, "zone2holhometimer_timer3_closemin", nil)
    -- HOLIDAY HOME日区域2定时4
    modelToBin(_controlcmd, "zone2holhometimer_timer4en", BIT3)
    modelToBin(_controlcmd, "zone2holhometimer_timer4_mode", nil)
    modelToBin(_controlcmd, "zone2holhometimer_timer4_temp", nil)
    modelToBin(_controlcmd, "zone2holhometimer_timer4_openhour", nil)
    modelToBin(_controlcmd, "zone2holhometimer_timer4_openmin", nil)
    modelToBin(_controlcmd, "zone2holhometimer_timer4_closehour", nil)
    modelToBin(_controlcmd, "zone2holhometimer_timer4_closemin", nil)
    -- HOLIDAY HOME日区域2定时5
    modelToBin(_controlcmd, "zone2holhometimer_timer5en", BIT4)
    modelToBin(_controlcmd, "zone2holhometimer_timer5_mode", nil)
    modelToBin(_controlcmd, "zone2holhometimer_timer5_temp", nil)
    modelToBin(_controlcmd, "zone2holhometimer_timer5_openhour", nil)
    modelToBin(_controlcmd, "zone2holhometimer_timer5_openmin", nil)
    modelToBin(_controlcmd, "zone2holhometimer_timer5_closehour", nil)
    modelToBin(_controlcmd, "zone2holhometimer_timer5_closemin", nil)
    -- HOLIDAY HOME日区域2定时6
    modelToBin(_controlcmd, "zone2holhometimer_timer6en", BIT5)
    modelToBin(_controlcmd, "zone2holhometimer_timer6_mode", nil)
    modelToBin(_controlcmd, "zone2holhometimer_timer6_temp", nil)
    modelToBin(_controlcmd, "zone2holhometimer_timer6_openhour", nil)
    modelToBin(_controlcmd, "zone2holhometimer_timer6_openmin", nil)
    modelToBin(_controlcmd, "zone2holhometimer_timer6_closehour", nil)
    modelToBin(_controlcmd, "zone2holhometimer_timer6_closemin", nil)
	-- ECO控制
	modelToBin(_controlcmd, "eco_function_state", BIT0)
	modelToBin(_controlcmd, "eco_timer_state", BIT1)
	modelToBin(_controlcmd, "eco_timer_starthour", nil)
	modelToBin(_controlcmd, "eco_timer_startmin", nil)
	modelToBin(_controlcmd, "eco_timer_endhour", nil)
	modelToBin(_controlcmd, "eco_timer_endmin", nil)
	modelToBin(_controlcmd, "eco_curve_type", nil)
    -- 杀菌控制
	modelToBin(_controlcmd, "disinfect_function_state", BIT0)
	modelToBin(_controlcmd, "disinfect_run_state", BIT1)
	modelToBin(_controlcmd, "disinfect_setweekday", nil)
	modelToBin(_controlcmd, "disinfect_starthour", nil)
	modelToBin(_controlcmd, "disinfect_startmin", nil)

	--安装设定控制
	modelToBin(_controlcmd, "dhwEnable", BIT7)
	modelToBin(_controlcmd, "boostertbhEn", BIT6)
	modelToBin(_controlcmd, "disinfectEnable", BIT5)
	modelToBin(_controlcmd, "dhwPumpEnable", BIT4)

	modelToBin(_controlcmd, "coolEnable", BIT1)
	modelToBin(_controlcmd, "heatEnable", BIT7)
	modelToBin(_controlcmd, "dualroomThermostatEn", BIT1)
	modelToBin(_controlcmd, "roomTherSetModeEn", BIT2)
	modelToBin(_controlcmd, "roomTherEn", BIT3)
	modelToBin(_controlcmd, "pipeExceed10m", BIT3)
	modelToBin(_controlcmd, "smartgridEn", BIT7)
	modelToBin(_controlcmd, "roomTherType", nil)
    modelToBin(_controlcmd, "dT5On", nil)
    modelToBin(_controlcmd, "dT1S5", nil)

    modelToBin(_controlcmd, "t4Dhwmax", nil)
    modelToBin(_controlcmd, "t4Dhwmin", nil)

    modelToBin(_controlcmd, "t4TBHon", nil)

    modelToBin(_controlcmd, "dT1SC", nil)
    modelToBin(_controlcmd, "dTSC", nil)
    modelToBin(_controlcmd, "t4Cmax", nil)
    modelToBin(_controlcmd, "t4Cmin", nil)

    modelToBin(_controlcmd, "dT1SH", nil)
    modelToBin(_controlcmd, "dTSH", nil)
    modelToBin(_controlcmd, "t4Hmax", nil)
    modelToBin(_controlcmd, "t4Hmin", nil)
    modelToBin(_controlcmd, "t4IBHon", nil)

    modelToBin(_controlcmd, "t4autocmin", nil)
    modelToBin(_controlcmd, "t4autohmax", nil)

    modelToBin(_controlcmd, "powerIbh1", nil)
    modelToBin(_controlcmd, "powerIbh2", nil)
    modelToBin(_controlcmd, "powerTbh", nil)

    modelToBin(_controlcmd, "t1SetC1", nil)
    modelToBin(_controlcmd, "t1SetC2", nil)
    modelToBin(_controlcmd, "t4C1", nil)
    modelToBin(_controlcmd, "t4C2", nil)
    modelToBin(_controlcmd, "t1SetH1", nil)
    modelToBin(_controlcmd, "t1SetH2", nil)
    modelToBin(_controlcmd, "t4H1", nil)
    modelToBin(_controlcmd, "t4H2", nil)
    modelToBin(_controlcmd, "typeVolLmt", nil)
	modelToBin(_controlcmd, "tbhEnFunc", nil)
	modelToBin(_controlcmd, "ibhEnFunc", nil)
	modelToBin(_controlcmd, "timeReportSet", nil)
end

-- 根据 myTable 生成查询指令
local function createQueryCmd(intQueryType, msg)
    local _bodyBytes = {}
	-- 构造消息 body 部分
	-- 查询命令类型
	_bodyBytes[0] = intQueryType
	if(intQueryType == cmdTable["MSG_TYPE_QUERY_BASIC"])  then
	elseif(intQueryType == cmdTable["MSG_TYPE_QUERY_DAY_TIME"])  then
	elseif(intQueryType == cmdTable["MSG_TYPE_QUERY_WEEKS_TIME"])  then
		if (msg["queryweekday"] ~= nil) then
			_bodyBytes[1] = string2Int(msg["queryweekday"])
			if (_bodyBytes[1] ~= BIT0) and
				(_bodyBytes[1] ~= BIT1) and
				(_bodyBytes[1] ~= BIT2) and
				(_bodyBytes[1] ~= BIT3) and
				(_bodyBytes[1] ~= BIT4) and
				(_bodyBytes[1] ~= BIT5) and
				(_bodyBytes[1] ~= BIT6) then
				_bodyBytes[1] = BIT0
			end
		else
			_bodyBytes[1] = BIT0
		end
        if (msg["zone2queryweekday"] ~= nil) then
			_bodyBytes[2] = string2Int(msg["zone2queryweekday"])
			if (_bodyBytes[2] ~= BIT0) and
				(_bodyBytes[2] ~= BIT1) and
				(_bodyBytes[2] ~= BIT2) and
				(_bodyBytes[2] ~= BIT3) and
				(_bodyBytes[2] ~= BIT4) and
				(_bodyBytes[2] ~= BIT5) and
				(_bodyBytes[2] ~= BIT6) then
				_bodyBytes[2] = BIT0
			end
		else
			_bodyBytes[2] = BIT0
		end
	elseif(intQueryType == cmdTable["MSG_TYPE_QUERY_HOLIDAY_AWAY"])  then
	elseif(intQueryType == cmdTable["MSG_TYPE_QUERY_SILENCE"])  then
	elseif(intQueryType == cmdTable["MSG_TYPE_QUERY_HOLIDAY_HOME"])  then
	elseif(intQueryType == cmdTable["MSG_TYPE_QUERY_ECO"])  then
    elseif(intQueryType == cmdTable["MSG_TYPE_QUERY_DISINFECT"])  then
    end
	return getTotalMsg(_bodyBytes, cmdTable["MSG_TYPE_QUERY"])
end

-- 根据 myTable 生成控制指令
local function createControlCmd(intControlType)
    local _bodyBytes = {}

	-- 指令类型
	_bodyBytes[0] = intControlType
	if(_bodyBytes[0]==cmdTable["MSG_TYPE_CONTROL_BASIC"]) then
		_bodyBytes[1] = 0
		_bodyBytes[1] = bit.bor(_bodyBytes[1], myTable["zone1_power_state"])
		_bodyBytes[1] = bit.bor(_bodyBytes[1], myTable["zone2_power_state"])
		_bodyBytes[1] = bit.bor(_bodyBytes[1], myTable["dhw_power_state"])

		_bodyBytes[2] = myTable["run_mode_set"]
		_bodyBytes[3] = myTable["zone1_temp_set"]
		_bodyBytes[4] = myTable["zone2_temp_set"]
		_bodyBytes[5] = myTable["dhw_temp_set"]
		_bodyBytes[6] = myTable["room_temp_set"]*2

		_bodyBytes[7] = 0
		_bodyBytes[7] = bit.bor(_bodyBytes[7], myTable["zone1_curve_state"])
		_bodyBytes[7] = bit.bor(_bodyBytes[7], myTable["zone2_curve_state"])
		_bodyBytes[7] = bit.bor(_bodyBytes[7], myTable["forcetbh_state"])
		_bodyBytes[7] = bit.bor(_bodyBytes[7], myTable["fastdhw_state"])
			if(1 == myTable["protocol_newfunction_en"])  then
				_bodyBytes[8] = myTable["zone1_curve_type"]
				_bodyBytes[9] = myTable["zone2_curve_type"]
			end
	elseif(_bodyBytes[0]==cmdTable["MSG_TYPE_CONTROL_DAY_TIMER"]) then
		-- 区域1日定时使能
		_bodyBytes[1] = 0
		_bodyBytes[1] = bit.bor(_bodyBytes[1], myTable["daytimer_timer1en"])
		_bodyBytes[1] = bit.bor(_bodyBytes[1], myTable["daytimer_timer2en"])
		_bodyBytes[1] = bit.bor(_bodyBytes[1], myTable["daytimer_timer3en"])
		_bodyBytes[1] = bit.bor(_bodyBytes[1], myTable["daytimer_timer4en"])
		_bodyBytes[1] = bit.bor(_bodyBytes[1], myTable["daytimer_timer5en"])
		_bodyBytes[1] = bit.bor(_bodyBytes[1], myTable["daytimer_timer6en"])
		-- 日定时1
		_bodyBytes[2] = myTable["daytimer_timer1_mode"]
		_bodyBytes[3] = myTable["daytimer_timer1_temp"]
		_bodyBytes[4] = myTable["daytimer_timer1_openhour"]
		_bodyBytes[5] = myTable["daytimer_timer1_openmin"]
		_bodyBytes[6] = myTable["daytimer_timer1_closehour"]
		_bodyBytes[7] = myTable["daytimer_timer1_closemin"]
		-- 日定时2
		_bodyBytes[8] = myTable["daytimer_timer2_mode"]
		_bodyBytes[9] = myTable["daytimer_timer2_temp"]
		_bodyBytes[10] = myTable["daytimer_timer2_openhour"]
		_bodyBytes[11] = myTable["daytimer_timer2_openmin"]
		_bodyBytes[12] = myTable["daytimer_timer2_closehour"]
		_bodyBytes[13] = myTable["daytimer_timer2_closemin"]
		-- 日定时3
		_bodyBytes[14] = myTable["daytimer_timer3_mode"]
		_bodyBytes[15] = myTable["daytimer_timer3_temp"]
		_bodyBytes[16] = myTable["daytimer_timer3_openhour"]
		_bodyBytes[17] = myTable["daytimer_timer3_openmin"]
		_bodyBytes[18] = myTable["daytimer_timer3_closehour"]
		_bodyBytes[19] = myTable["daytimer_timer3_closemin"]
		-- 日定时4
		_bodyBytes[20] = myTable["daytimer_timer4_mode"]
		_bodyBytes[21] = myTable["daytimer_timer4_temp"]
		_bodyBytes[22] = myTable["daytimer_timer4_openhour"]
		_bodyBytes[23] = myTable["daytimer_timer4_openmin"]
		_bodyBytes[24] = myTable["daytimer_timer4_closehour"]
		_bodyBytes[25] = myTable["daytimer_timer4_closemin"]
		-- 日定时5
		_bodyBytes[26] = myTable["daytimer_timer5_mode"]
		_bodyBytes[27] = myTable["daytimer_timer5_temp"]
		_bodyBytes[28] = myTable["daytimer_timer5_openhour"]
		_bodyBytes[29] = myTable["daytimer_timer5_openmin"]
		_bodyBytes[30] = myTable["daytimer_timer5_closehour"]
		_bodyBytes[31] = myTable["daytimer_timer5_closemin"]
		-- 日定时6
		_bodyBytes[32] = myTable["daytimer_timer6_mode"]
		_bodyBytes[33] = myTable["daytimer_timer6_temp"]
		_bodyBytes[34] = myTable["daytimer_timer6_openhour"]
		_bodyBytes[35] = myTable["daytimer_timer6_openmin"]
		_bodyBytes[36] = myTable["daytimer_timer6_closehour"]
		_bodyBytes[37] = myTable["daytimer_timer6_closemin"]
        --插件下发支持230312V1.2协议
        if(1 == myTable["protocol_newfunction_en"])  then
            -- 区域2日定时使能
            _bodyBytes[38] = 0
            _bodyBytes[38] = bit.bor(_bodyBytes[38], myTable["zone2daytimer_timer1en"])
            _bodyBytes[38] = bit.bor(_bodyBytes[38], myTable["zone2daytimer_timer2en"])
            _bodyBytes[38] = bit.bor(_bodyBytes[38], myTable["zone2daytimer_timer3en"])
            _bodyBytes[38] = bit.bor(_bodyBytes[38], myTable["zone2daytimer_timer4en"])
            _bodyBytes[38] = bit.bor(_bodyBytes[38], myTable["zone2daytimer_timer5en"])
            _bodyBytes[38] = bit.bor(_bodyBytes[38], myTable["zone2daytimer_timer6en"])
            -- 日定时1
            _bodyBytes[39] = myTable["zone2daytimer_timer1_mode"]
            _bodyBytes[40] = myTable["zone2daytimer_timer1_temp"]
            _bodyBytes[41] = myTable["zone2daytimer_timer1_openhour"]
            _bodyBytes[42] = myTable["zone2daytimer_timer1_openmin"]
            _bodyBytes[43] = myTable["zone2daytimer_timer1_closehour"]
            _bodyBytes[44] = myTable["zone2daytimer_timer1_closemin"]
            -- 日定时2
            _bodyBytes[45] = myTable["zone2daytimer_timer2_mode"]
            _bodyBytes[46] = myTable["zone2daytimer_timer2_temp"]
            _bodyBytes[47] = myTable["zone2daytimer_timer2_openhour"]
            _bodyBytes[48] = myTable["zone2daytimer_timer2_openmin"]
            _bodyBytes[49] = myTable["zone2daytimer_timer2_closehour"]
            _bodyBytes[50] = myTable["zone2daytimer_timer2_closemin"]
            -- 日定时3
            _bodyBytes[51] = myTable["zone2daytimer_timer3_mode"]
            _bodyBytes[52] = myTable["zone2daytimer_timer3_temp"]
            _bodyBytes[53] = myTable["zone2daytimer_timer3_openhour"]
            _bodyBytes[54] = myTable["zone2daytimer_timer3_openmin"]
            _bodyBytes[55] = myTable["zone2daytimer_timer3_closehour"]
            _bodyBytes[56] = myTable["zone2daytimer_timer3_closemin"]
            -- 日定时4
            _bodyBytes[57] = myTable["zone2daytimer_timer4_mode"]
            _bodyBytes[58] = myTable["zone2daytimer_timer4_temp"]
            _bodyBytes[59] = myTable["zone2daytimer_timer4_openhour"]
            _bodyBytes[60] = myTable["zone2daytimer_timer4_openmin"]
            _bodyBytes[61] = myTable["zone2daytimer_timer4_closehour"]
            _bodyBytes[62] = myTable["zone2daytimer_timer4_closemin"]
            -- 日定时5
            _bodyBytes[63] = myTable["zone2daytimer_timer5_mode"]
            _bodyBytes[64] = myTable["zone2daytimer_timer5_temp"]
            _bodyBytes[65] = myTable["zone2daytimer_timer5_openhour"]
            _bodyBytes[66] = myTable["zone2daytimer_timer5_openmin"]
            _bodyBytes[67] = myTable["zone2daytimer_timer5_closehour"]
            _bodyBytes[68] = myTable["zone2daytimer_timer5_closemin"]
            -- 日定时6
            _bodyBytes[69] = myTable["zone2daytimer_timer6_mode"]
            _bodyBytes[70] = myTable["zone2daytimer_timer6_temp"]
            _bodyBytes[71] = myTable["zone2daytimer_timer6_openhour"]
            _bodyBytes[72] = myTable["zone2daytimer_timer6_openmin"]
            _bodyBytes[73] = myTable["zone2daytimer_timer6_closehour"]
            _bodyBytes[74] = myTable["zone2daytimer_timer6_closemin"]
       end

	elseif(_bodyBytes[0]==cmdTable["MSG_TYPE_CONTROL_WEEKS_TIMER"]) then
		-- 周定时使能标志
		_bodyBytes[1] = bit.band(0x7f, myTable["weektimer_setday"])
		-- 周定时时间段使能标志
		_bodyBytes[2] = 0
		_bodyBytes[2] = bit.bor(_bodyBytes[2], myTable["weektimer_timer1en"])
		_bodyBytes[2] = bit.bor(_bodyBytes[2], myTable["weektimer_timer2en"])
		_bodyBytes[2] = bit.bor(_bodyBytes[2], myTable["weektimer_timer3en"])
		_bodyBytes[2] = bit.bor(_bodyBytes[2], myTable["weektimer_timer4en"])
		_bodyBytes[2] = bit.bor(_bodyBytes[2], myTable["weektimer_timer5en"])
		_bodyBytes[2] = bit.bor(_bodyBytes[2], myTable["weektimer_timer6en"])
		-- 周定时1
		_bodyBytes[3] = myTable["weektimer_timer1_mode"]
		_bodyBytes[4] = myTable["weektimer_timer1_temp"]
		_bodyBytes[5] = myTable["weektimer_timer1_openhour"]
		_bodyBytes[6] = myTable["weektimer_timer1_openmin"]
		_bodyBytes[7] = myTable["weektimer_timer1_closehour"]
		_bodyBytes[8] = myTable["weektimer_timer1_closemin"]
		--周定时2
		_bodyBytes[9] = myTable["weektimer_timer2_mode"]
		_bodyBytes[10] = myTable["weektimer_timer2_temp"]
		_bodyBytes[11] = myTable["weektimer_timer2_openhour"]
		_bodyBytes[12] = myTable["weektimer_timer2_openmin"]
		_bodyBytes[13] = myTable["weektimer_timer2_closehour"]
		_bodyBytes[14] = myTable["weektimer_timer2_closemin"]
		--周定时3
		_bodyBytes[15] = myTable["weektimer_timer3_mode"]
		_bodyBytes[16] = myTable["weektimer_timer3_temp"]
		_bodyBytes[17] = myTable["weektimer_timer3_openhour"]
		_bodyBytes[18] = myTable["weektimer_timer3_openmin"]
		_bodyBytes[19] = myTable["weektimer_timer3_closehour"]
		_bodyBytes[20] = myTable["weektimer_timer3_closemin"]
		--周定时4
		_bodyBytes[21] = myTable["weektimer_timer4_mode"]
		_bodyBytes[22] = myTable["weektimer_timer4_temp"]
		_bodyBytes[23] = myTable["weektimer_timer4_openhour"]
		_bodyBytes[24] = myTable["weektimer_timer4_openmin"]
		_bodyBytes[25] = myTable["weektimer_timer4_closehour"]
		_bodyBytes[26] = myTable["weektimer_timer4_closemin"]
		--周定时5
		_bodyBytes[27] = myTable["weektimer_timer5_mode"]
		_bodyBytes[28] = myTable["weektimer_timer5_temp"]
		_bodyBytes[29] = myTable["weektimer_timer5_openhour"]
		_bodyBytes[30] = myTable["weektimer_timer5_openmin"]
		_bodyBytes[31] = myTable["weektimer_timer5_closehour"]
		_bodyBytes[32] = myTable["weektimer_timer5_closemin"]
		--周定时6
		_bodyBytes[33] = myTable["weektimer_timer6_mode"]
		_bodyBytes[34] = myTable["weektimer_timer6_temp"]
		_bodyBytes[35] = myTable["weektimer_timer6_openhour"]
		_bodyBytes[36] = myTable["weektimer_timer6_openmin"]
		_bodyBytes[37] = myTable["weektimer_timer6_closehour"]
		_bodyBytes[38] = myTable["weektimer_timer6_closemin"]
        --插件下发支持230312V1.2协议
			if(1 == myTable["protocol_newfunction_en"])  then				
				-- 区域2周定时设置日期使能标志
				_bodyBytes[39] = bit.band(0x7f, myTable["zone2weektimer_setday"])
				-- 区域2周定时时间段使能标志
				_bodyBytes[40] = 0
				_bodyBytes[40] = bit.bor(_bodyBytes[40], myTable["zone2weektimer_timer1en"])
				_bodyBytes[40] = bit.bor(_bodyBytes[40], myTable["zone2weektimer_timer2en"])
				_bodyBytes[40] = bit.bor(_bodyBytes[40], myTable["zone2weektimer_timer3en"])
				_bodyBytes[40] = bit.bor(_bodyBytes[40], myTable["zone2weektimer_timer4en"])
				_bodyBytes[40] = bit.bor(_bodyBytes[40], myTable["zone2weektimer_timer5en"])
				_bodyBytes[40] = bit.bor(_bodyBytes[40], myTable["zone2weektimer_timer6en"])
				-- 区域2周定时1
				_bodyBytes[41] = myTable["zone2weektimer_timer1_mode"]
				_bodyBytes[42] = myTable["zone2weektimer_timer1_temp"]
				_bodyBytes[43] = myTable["zone2weektimer_timer1_openhour"]
				_bodyBytes[44] = myTable["zone2weektimer_timer1_openmin"]
				_bodyBytes[45] = myTable["zone2weektimer_timer1_closehour"]
				_bodyBytes[46] = myTable["zone2weektimer_timer1_closemin"]
				-- 区域2周定时2
				_bodyBytes[47] = myTable["zone2weektimer_timer2_mode"]
				_bodyBytes[48] = myTable["zone2weektimer_timer2_temp"]
				_bodyBytes[49] = myTable["zone2weektimer_timer2_openhour"]
				_bodyBytes[50] = myTable["zone2weektimer_timer2_openmin"]
				_bodyBytes[51] = myTable["zone2weektimer_timer2_closehour"]
				_bodyBytes[52] = myTable["zone2weektimer_timer2_closemin"]
				-- 区域2周定时3
				_bodyBytes[53] = myTable["zone2weektimer_timer3_mode"]
				_bodyBytes[54] = myTable["zone2weektimer_timer3_temp"]
				_bodyBytes[55] = myTable["zone2weektimer_timer3_openhour"]
				_bodyBytes[56] = myTable["zone2weektimer_timer3_openmin"]
				_bodyBytes[57] = myTable["zone2weektimer_timer3_closehour"]
				_bodyBytes[58] = myTable["zone2weektimer_timer3_closemin"]
				-- 区域2周定时4
				_bodyBytes[59] = myTable["zone2weektimer_timer4_mode"]
				_bodyBytes[60] = myTable["zone2weektimer_timer4_temp"]
				_bodyBytes[61] = myTable["zone2weektimer_timer4_openhour"]
				_bodyBytes[62] = myTable["zone2weektimer_timer4_openmin"]
				_bodyBytes[63] = myTable["zone2weektimer_timer4_closehour"]
				_bodyBytes[64] = myTable["zone2weektimer_timer4_closemin"]
				-- 区域2周定时5
				_bodyBytes[65] = myTable["zone2weektimer_timer5_mode"]
				_bodyBytes[66] = myTable["zone2weektimer_timer5_temp"]
				_bodyBytes[67] = myTable["zone2weektimer_timer5_openhour"]
				_bodyBytes[68] = myTable["zone2weektimer_timer5_openmin"]
				_bodyBytes[69] = myTable["zone2weektimer_timer5_closehour"]
				_bodyBytes[70] = myTable["zone2weektimer_timer5_closemin"]
				-- 区域2周定时6
				_bodyBytes[71] = myTable["zone2weektimer_timer6_mode"]
				_bodyBytes[72] = myTable["zone2weektimer_timer6_temp"]
				_bodyBytes[73] = myTable["zone2weektimer_timer6_openhour"]
				_bodyBytes[74] = myTable["zone2weektimer_timer6_openmin"]
				_bodyBytes[75] = myTable["zone2weektimer_timer6_closehour"]
				_bodyBytes[76] = myTable["zone2weektimer_timer6_closemin"]
			end
	elseif(_bodyBytes[0]==cmdTable["MSG_TYPE_CONTROL_HOLIDAY_AWAY"]) then
		_bodyBytes[1] = 0
		_bodyBytes[1] = bit.bor(_bodyBytes[1], myTable["holidayaway_state"])
		_bodyBytes[2] = myTable["holidayaway_startyear"]
		_bodyBytes[3] = myTable["holidayaway_startmonth"]
		_bodyBytes[4] = myTable["holidayaway_startdate"]
		_bodyBytes[5] = myTable["holidayaway_endyear"]
		_bodyBytes[6] = myTable["holidayaway_endmonth"]
		_bodyBytes[7] = myTable["holidayaway_enddate"]
        --插件下发支持230312V1.2协议
        if(1 == myTable["protocol_newfunction_en"])  then
            --支持新协议
            _bodyBytes[8] = 0				
            _bodyBytes[8] = bit.bor(_bodyBytes[8], myTable["holidayaway_heat_state"])
            _bodyBytes[8] = bit.bor(_bodyBytes[8], myTable["holidayaway_dhw_state"])
            _bodyBytes[8] = bit.bor(_bodyBytes[8], myTable["holidayaway_disinfect_state"])
        end	        
	elseif(_bodyBytes[0]==cmdTable["MSG_TYPE_CONTROL_SILENCE"]) then
		_bodyBytes[1] = 0
		_bodyBytes[1] = bit.bor(_bodyBytes[1], myTable["silence_function_state"])
		_bodyBytes[1] = bit.bor(_bodyBytes[1], myTable["silence_function_level"])
		_bodyBytes[1] = bit.bor(_bodyBytes[1], myTable["silence_timer1_state"])
		_bodyBytes[1] = bit.bor(_bodyBytes[1], myTable["silence_timer2_state"])
		-- 静音 定时1
		_bodyBytes[2] = myTable["silence_timer1_starthour"]
		_bodyBytes[3] = myTable["silence_timer1_startmin"]
		_bodyBytes[4] = myTable["silence_timer1_endhour"]
		_bodyBytes[5] = myTable["silence_timer1_endmin"]
		-- 静音 定时2
		_bodyBytes[6] = myTable["silence_timer2_starthour"]
		_bodyBytes[7] = myTable["silence_timer2_startmin"]
		_bodyBytes[8] = myTable["silence_timer2_endhour"]
		_bodyBytes[9] = myTable["silence_timer2_endmin"]
	elseif(_bodyBytes[0]==cmdTable["MSG_TYPE_CONTROL_HOLIDAY_HOME"]) then
		_bodyBytes[1] = myTable["holidayhome_state"]
		_bodyBytes[2] = myTable["holidayhome_startyear"]
		_bodyBytes[3] = myTable["holidayhome_startmonth"]
		_bodyBytes[4] = myTable["holidayhome_startdate"]
		_bodyBytes[5] = myTable["holidayhome_endyear"]
		_bodyBytes[6] = myTable["holidayhome_endmonth"]
		_bodyBytes[7] = myTable["holidayhome_enddate"]
	    -- holidayhome 定时段使能
		_bodyBytes[8] = 0
		_bodyBytes[8] = bit.bor(_bodyBytes[8], myTable["holhometimer_timer1en"])
		_bodyBytes[8] = bit.bor(_bodyBytes[8], myTable["holhometimer_timer2en"])
		_bodyBytes[8] = bit.bor(_bodyBytes[8], myTable["holhometimer_timer3en"])
		_bodyBytes[8] = bit.bor(_bodyBytes[8], myTable["holhometimer_timer4en"])
		_bodyBytes[8] = bit.bor(_bodyBytes[8], myTable["holhometimer_timer5en"])
		_bodyBytes[8] = bit.bor(_bodyBytes[8], myTable["holhometimer_timer6en"])
		-- holidayhome定时1
		_bodyBytes[9] = myTable["holhometimer_timer1_mode"]
		_bodyBytes[10] = myTable["holhometimer_timer1_temp"]
		_bodyBytes[11] = myTable["holhometimer_timer1_openhour"]
		_bodyBytes[12] = myTable["holhometimer_timer1_openmin"]
		_bodyBytes[13] = myTable["holhometimer_timer1_closehour"]
		_bodyBytes[14] = myTable["holhometimer_timer1_closemin"]
		-- holidayhome定时2
		_bodyBytes[15] = myTable["holhometimer_timer2_mode"]
		_bodyBytes[16] = myTable["holhometimer_timer2_temp"]
		_bodyBytes[17] = myTable["holhometimer_timer2_openhour"]
		_bodyBytes[18] = myTable["holhometimer_timer2_openmin"]
		_bodyBytes[19] = myTable["holhometimer_timer2_closehour"]
		_bodyBytes[20] = myTable["holhometimer_timer2_closemin"]
		-- holidayhome定时3
		_bodyBytes[21] = myTable["holhometimer_timer3_mode"]
		_bodyBytes[22] = myTable["holhometimer_timer3_temp"]
		_bodyBytes[23] = myTable["holhometimer_timer3_openhour"]
		_bodyBytes[24] = myTable["holhometimer_timer3_openmin"]
		_bodyBytes[25] = myTable["holhometimer_timer3_closehour"]
		_bodyBytes[26] = myTable["holhometimer_timer3_closemin"]
		-- holidayhome定时4
		_bodyBytes[27] = myTable["holhometimer_timer4_mode"]
		_bodyBytes[28] = myTable["holhometimer_timer4_temp"]
		_bodyBytes[29] = myTable["holhometimer_timer4_openhour"]
		_bodyBytes[30] = myTable["holhometimer_timer4_openmin"]
		_bodyBytes[31] = myTable["holhometimer_timer4_closehour"]
		_bodyBytes[32] = myTable["holhometimer_timer4_closemin"]
		-- holidayhome定时5
		_bodyBytes[33] = myTable["holhometimer_timer5_mode"]
		_bodyBytes[34] = myTable["holhometimer_timer5_temp"]
		_bodyBytes[35] = myTable["holhometimer_timer5_openhour"]
		_bodyBytes[36] = myTable["holhometimer_timer5_openmin"]
		_bodyBytes[37] = myTable["holhometimer_timer5_closehour"]
		_bodyBytes[38] = myTable["holhometimer_timer5_closemin"]
		-- holidayhome定时6
		_bodyBytes[39] = myTable["holhometimer_timer6_mode"]
		_bodyBytes[40] = myTable["holhometimer_timer6_temp"]
		_bodyBytes[41] = myTable["holhometimer_timer6_openhour"]
		_bodyBytes[42] = myTable["holhometimer_timer6_openmin"]
		_bodyBytes[43] = myTable["holhometimer_timer6_closehour"]
		_bodyBytes[44] = myTable["holhometimer_timer6_closemin"]
            --插件下发支持230312V1.2协议
			if(1 == myTable["protocol_newfunction_en"])  then				
				-- holidayhome 区域2定时段使能
				_bodyBytes[45] = 0
				_bodyBytes[45] = bit.bor(_bodyBytes[45], myTable["zone2holhometimer_timer1en"])
				_bodyBytes[45] = bit.bor(_bodyBytes[45], myTable["zone2holhometimer_timer2en"])
				_bodyBytes[45] = bit.bor(_bodyBytes[45], myTable["zone2holhometimer_timer3en"])
				_bodyBytes[45] = bit.bor(_bodyBytes[45], myTable["zone2holhometimer_timer4en"])
				_bodyBytes[45] = bit.bor(_bodyBytes[45], myTable["zone2holhometimer_timer5en"])
				_bodyBytes[45] = bit.bor(_bodyBytes[45], myTable["zone2holhometimer_timer6en"])
				-- holidayhome区域2定时1
				_bodyBytes[46] = myTable["zone2holhometimer_timer1_mode"]
				_bodyBytes[47] = myTable["zone2holhometimer_timer1_temp"]
				_bodyBytes[48] = myTable["zone2holhometimer_timer1_openhour"]
				_bodyBytes[49] = myTable["zone2holhometimer_timer1_openmin"]
				_bodyBytes[50] = myTable["zone2holhometimer_timer1_closehour"]
				_bodyBytes[51] = myTable["zone2holhometimer_timer1_closemin"]
				-- holidayhome区域2定时2
				_bodyBytes[52] = myTable["zone2holhometimer_timer2_mode"]
				_bodyBytes[53] = myTable["zone2holhometimer_timer2_temp"]
				_bodyBytes[54] = myTable["zone2holhometimer_timer2_openhour"]
				_bodyBytes[55] = myTable["zone2holhometimer_timer2_openmin"]
				_bodyBytes[56] = myTable["zone2holhometimer_timer2_closehour"]
				_bodyBytes[57] = myTable["zone2holhometimer_timer2_closemin"]
				-- holidayhome区域2定时3
				_bodyBytes[58] = myTable["zone2holhometimer_timer3_mode"]
				_bodyBytes[59] = myTable["zone2holhometimer_timer3_temp"]
				_bodyBytes[60] = myTable["zone2holhometimer_timer3_openhour"]
				_bodyBytes[61] = myTable["zone2holhometimer_timer3_openmin"]
				_bodyBytes[62] = myTable["zone2holhometimer_timer3_closehour"]
				_bodyBytes[63] = myTable["zone2holhometimer_timer3_closemin"]
				-- holidayhome区域2定时4
				_bodyBytes[64] = myTable["zone2holhometimer_timer4_mode"]
				_bodyBytes[65] = myTable["zone2holhometimer_timer4_temp"]
				_bodyBytes[66] = myTable["zone2holhometimer_timer4_openhour"]
				_bodyBytes[67] = myTable["zone2holhometimer_timer4_openmin"]
				_bodyBytes[68] = myTable["zone2holhometimer_timer4_closehour"]
				_bodyBytes[69] = myTable["zone2holhometimer_timer4_closemin"]
				-- holidayhome区域2定时5
				_bodyBytes[70] = myTable["zone2holhometimer_timer5_mode"]
				_bodyBytes[71] = myTable["zone2holhometimer_timer5_temp"]
				_bodyBytes[72] = myTable["zone2holhometimer_timer5_openhour"]
				_bodyBytes[73] = myTable["zone2holhometimer_timer5_openmin"]
				_bodyBytes[74] = myTable["zone2holhometimer_timer5_closehour"]
				_bodyBytes[75] = myTable["zone2holhometimer_timer5_closemin"]
				-- holidayhome区域2定时6
				_bodyBytes[76] = myTable["zone2holhometimer_timer6_mode"]
				_bodyBytes[77] = myTable["zone2holhometimer_timer6_temp"]
				_bodyBytes[78] = myTable["zone2holhometimer_timer6_openhour"]
				_bodyBytes[79] = myTable["zone2holhometimer_timer6_openmin"]
				_bodyBytes[80] = myTable["zone2holhometimer_timer6_closehour"]
				_bodyBytes[81] = myTable["zone2holhometimer_timer6_closemin"]
			end
	elseif(_bodyBytes[0]==cmdTable["MSG_TYPE_CONTROL_ECO"]) then
		_bodyBytes[1] = 0
		_bodyBytes[1] = bit.bor(_bodyBytes[1], myTable["eco_function_state"])
		_bodyBytes[1] = bit.bor(_bodyBytes[1], myTable["eco_timer_state"])
		-- ECO 定时1
		_bodyBytes[2] = myTable["eco_timer_starthour"]
		_bodyBytes[3] = myTable["eco_timer_startmin"]
		_bodyBytes[4] = myTable["eco_timer_endhour"]
		_bodyBytes[5] = myTable["eco_timer_endmin"]
            --插件下发支持230312V1.2协议    
			if(1 == myTable["protocol_newfunction_en"])  then
				--支持新协议
				_bodyBytes[6] = myTable["eco_curve_type"]
			end
    -- DISINFECT
    elseif(_bodyBytes[0]==cmdTable["MSG_TYPE_CONTROL_DISINFECT"]) then
		_bodyBytes[1] = 0
		_bodyBytes[1] = bit.bor(_bodyBytes[1], myTable["disinfect_function_state"])
		_bodyBytes[1] = bit.bor(_bodyBytes[1], myTable["disinfect_run_state"])
		_bodyBytes[2] = bit.band(0xff, myTable["disinfect_setweekday"])
		_bodyBytes[3] = myTable["disinfect_starthour"]
		_bodyBytes[4] = myTable["disinfect_startmin"]
	elseif(_bodyBytes[0]==cmdTable["MSG_TYPE_CONTROL_INSTALL"]) then
        _bodyBytes[1] = 0
		_bodyBytes[1] =  bit.bor(_bodyBytes[1], myTable["dhwEnable"])
		_bodyBytes[1] =  bit.bor(_bodyBytes[1], myTable["boostertbhEn"])
		_bodyBytes[1] =  bit.bor(_bodyBytes[1], myTable["disinfectEnable"])
		_bodyBytes[1] =  bit.bor(_bodyBytes[1], myTable["dhwPumpEnable"])
		_bodyBytes[1] =  bit.bor(_bodyBytes[1], myTable["coolEnable"])
		_bodyBytes[2] = 0
		_bodyBytes[2] =  bit.bor(_bodyBytes[2], myTable["heatEnable"])
		_bodyBytes[2] =  bit.bor(_bodyBytes[2], myTable["roomTherEn"])
		_bodyBytes[2] =  bit.bor(_bodyBytes[2], myTable["roomTherSetModeEn"])
		_bodyBytes[2] =  bit.bor(_bodyBytes[2], myTable["dualroomThermostatEn"])		
		_bodyBytes[3] = 0
		_bodyBytes[3] =  bit.bor(_bodyBytes[3], myTable["pipeExceed10m"])
		_bodyBytes[4] = 0
		_bodyBytes[4] =  bit.bor(_bodyBytes[4], myTable["smartgridEn"])
        _bodyBytes[5] = myTable["roomTherType"]
        _bodyBytes[6] = myTable["dT5On"]
        _bodyBytes[7] = 0
        _bodyBytes[8] = myTable["dT1S5"]
        _bodyBytes[9] = 255
        _bodyBytes[10] = 255
        _bodyBytes[11] = 0
        _bodyBytes[12] = myTable["t4Dhwmax"]
        _bodyBytes[13] = 0
        _bodyBytes[14] = myTable["t4Dhwmin"]
        _bodyBytes[15] = 255
        _bodyBytes[16] = 255
        _bodyBytes[17] = 255
        _bodyBytes[18] = 255
        _bodyBytes[19] = 0
        _bodyBytes[20] = myTable["t4TBHon"]
        _bodyBytes[21] = 255
        _bodyBytes[22] = 255
        _bodyBytes[23] = 255
        _bodyBytes[24] = 255
        _bodyBytes[25] = 255
        _bodyBytes[26] = 255
        _bodyBytes[27] = 255
        _bodyBytes[28] = 255
        _bodyBytes[29] = 0
        _bodyBytes[30] = myTable["dT1SC"]
        _bodyBytes[31] = 0
        _bodyBytes[32] = myTable["dTSC"]
        _bodyBytes[33] = 0
        _bodyBytes[34] = myTable["t4Cmax"]
        _bodyBytes[35] = 0
        _bodyBytes[36] = myTable["t4Cmin"]
        _bodyBytes[37] = 255
        _bodyBytes[38] = 255
        _bodyBytes[39] = 0
        _bodyBytes[40] = myTable["dT1SH"]
        _bodyBytes[41] = 0
        _bodyBytes[42] = myTable["dTSH"]
        _bodyBytes[43] = 0
        _bodyBytes[44] = myTable["t4Hmax"]
        _bodyBytes[45] = 0
        _bodyBytes[46] = myTable["t4Hmin"]
        _bodyBytes[47] = 0
        _bodyBytes[48] = myTable["t4IBHon"]
        _bodyBytes[49] = 255
        _bodyBytes[50] = 255
        _bodyBytes[51] = 255
        _bodyBytes[52] = 255
        _bodyBytes[53] = 255
        _bodyBytes[54] = 255
        _bodyBytes[55] = 255
        _bodyBytes[56] = 255
        _bodyBytes[57] = 255
        _bodyBytes[58] = 255
        _bodyBytes[59] = 255
        _bodyBytes[60] = 255
        _bodyBytes[61] = 255
        _bodyBytes[62] = 255
        _bodyBytes[63] = 255
        _bodyBytes[64] = 255
        _bodyBytes[65] = 255
        _bodyBytes[66] = 255
        _bodyBytes[67] = 0
        _bodyBytes[68] = myTable["t4autocmin"]
        _bodyBytes[69] = 0
        _bodyBytes[70] = myTable["t4autohmax"]
        _bodyBytes[71] = 255
        _bodyBytes[72] = 255
        _bodyBytes[73] = 255
        _bodyBytes[74] = 255
        _bodyBytes[75] = 255
        _bodyBytes[76] = 255
        _bodyBytes[77] = 255
        _bodyBytes[78] = 255
        _bodyBytes[79] = 255
        _bodyBytes[80] = 255
        _bodyBytes[81] = 0
        _bodyBytes[82] = myTable["powerIbh1"]*10
        _bodyBytes[83] = 0
        _bodyBytes[84] = myTable["powerIbh2"]*10
        _bodyBytes[85] = 0
        _bodyBytes[86] = myTable["powerTbh"]*10
        _bodyBytes[87] = 255
        _bodyBytes[88] = 255
        _bodyBytes[89] = 255
        _bodyBytes[90] = 255
        _bodyBytes[91] = 255
        _bodyBytes[92] = 255
        _bodyBytes[93] = 255
        _bodyBytes[94] = 255
        _bodyBytes[95] = 255
        _bodyBytes[96] = 255
        _bodyBytes[97] = 255
        _bodyBytes[98] = 255
        _bodyBytes[99] = 255
        _bodyBytes[100] = 255
        _bodyBytes[101] = 255
        _bodyBytes[102] = 255
        _bodyBytes[103] = 0
		_bodyBytes[103] =  bit.bor(_bodyBytes[103], myTable["ibhEnFunc"])

		_bodyBytes[104] = 0 
        _bodyBytes[104] = bit.bor(_bodyBytes[104], myTable["tbhEnFunc"])
        _bodyBytes[105] = myTable["timeReportSet"]
        _bodyBytes[106] = 255
        _bodyBytes[107] = 255
        _bodyBytes[108] = 255
        _bodyBytes[109] = 255
        _bodyBytes[110] = 255
        _bodyBytes[111] = 255
        _bodyBytes[112] = 255
        _bodyBytes[113] = 0
        _bodyBytes[114] = myTable["t1SetC1"]
        _bodyBytes[115] = 0
        _bodyBytes[116] = myTable["t1SetC2"]
        _bodyBytes[117] = 0
        _bodyBytes[117] = 0
        _bodyBytes[118] = myTable["t4C1"]
        _bodyBytes[119] = 0
        _bodyBytes[120] = myTable["t4C2"]
        _bodyBytes[121] = 0
        _bodyBytes[122] = myTable["t1SetH1"]
        _bodyBytes[123] = 0
        _bodyBytes[124] = myTable["t1SetH2"]
        _bodyBytes[125] = 0
        _bodyBytes[126] = myTable["t4H1"]
        _bodyBytes[127] = 0
        _bodyBytes[128] = myTable["t4H2"]
        _bodyBytes[129] = 0
        _bodyBytes[130] = myTable["typeVolLmt"]
        _bodyBytes[131] = 0xff
        _bodyBytes[132] = 0xff
        _bodyBytes[133] = 0xff
        _bodyBytes[134] = 0xff
        _bodyBytes[135] = 0xff
        _bodyBytes[136] = 0xff
        _bodyBytes[137] = 0xff
        _bodyBytes[138] = 0xff
        _bodyBytes[139] = 0xff
        _bodyBytes[140] = 0xff

	end
	-- 构造消息部分
	return getTotalMsg(_bodyBytes,cmdTable["MSG_TYPE_CONTROL"])
end

-- json转二进制，可传入原状态
function jsonToData(jsonCmd)
    if (#jsonCmd == 0) then
        return nil
    end

    local _infoM = {}
    local _json = decode(jsonCmd)
    local _deviceSubType = _json["deviceinfo"]["deviceSubType"]

    -- 根据设备子类型来处理协议差异
    if (_deviceSubType == 1) then

    end

    local _query = _json[unitTable["str_query"]]
    local _control = _json[unitTable["str_control"]]
    local _status = _json[unitTable["str_status"]]

	if (_query) then
		if (_query[unitTable["str_query_type"]] ~= nil) then
			_infoM = createQueryCmd(string2Int(_query[unitTable["str_query_type"]]), _query)
		else
			_infoM = createQueryCmd(cmdTable["MSG_TYPE_QUERY_BASIC"], _query) -- 默认
		end
	elseif (_control) then
		-- 先将原始状态转为属性
		if (_status) then
			jsonToModel(_status)
		end
		-- 将用户控制jsion转换为属性
		jsonToModel(_control)

		if (_control[unitTable["str_control_type"]] ~= nil) then
			_infoM = createControlCmd(string2Int(_control[unitTable["str_control_type"]]))
		else
			_infoM = createControlCmd(cmdTable["MSG_TYPE_CONTROL_BASIC"]) -- 默认
		end
	end

	local ret = table2string(_infoM)
	ret = string2hexstring(ret)
    return ret
end


-- 二进制转json
function dataToJson(jsonCmd)
    if (not jsonCmd) then
        return nil
    end

    local _json = decode(jsonCmd)
    local _deviceinfo = _json["deviceinfo"]
    local _deviceSubType = _deviceinfo["deviceSubType"]

    -- 根据设备子类型来处理协议差异
    if (_deviceSubType == 1) then

    end

    local _status = _json[unitTable["str_status"]]
    if (_status) then
        jsonToModel(_status)
    end

    local binData = _json["msg"]["data"]
    local info = {}
    local msgBytes = {0}
    local msgLength = 0
    local _bodyBytes = {}
    local bodyLength = 0
	local _msgType = 0
	local _msgBodyType = 0

    info = string2table(binData)

    for i = 1, #info do
        msgBytes[i - 1] = info[i]
    end

    msgLength = msgBytes[1] --length
    bodyLength = msgLength - cmdTable["PROTOCOL_LENGTH"] - 1
	-- 消息体类型
	_msgType = msgBytes[9]
	-- 消息体开头第一位，消息体类型
	_msgBodyType = msgBytes[10]
    -- 获取 body 部分
	for i = 0, bodyLength do
		_bodyBytes[i] = msgBytes[i + cmdTable["PROTOCOL_LENGTH"]]
	end
	--end

    -- 将属性值转换为最终 table
    local streams = {}
 	-- 版本
    streams["version"] = JSON_VERSION
    -- 将二进制状态解析为属性值
	if(((_msgType==cmdTable["MSG_TYPE_CONTROL"]) and (_msgBodyType==cmdTable["MSG_TYPE_CONTROL_BASIC"])) or
		((_msgType==cmdTable["MSG_TYPE_QUERY"])   and (_msgBodyType==cmdTable["MSG_TYPE_QUERY_BASIC"])) or
		(_msgType==cmdTable["MSG_TYPE_UP"])) and (_msgBodyType==cmdTable["MSG_TYPE_UP_BASIC"]) then
		-- 基本状态的控制回复02-01、查询03-01、上报04-01(电控回复数据组包)
        binToModel(streams, "msg_up_type", cmdTable["MSG_TYPE_UP_BASIC"],nil)
		binToModel(streams, "zone1_power_state", _bodyBytes[1], BIT0)
		binToModel(streams, "zone2_power_state", _bodyBytes[1], BIT1)
		binToModel(streams, "dhw_power_state", _bodyBytes[1], BIT2)
		binToModel(streams, "zone1_curve_state",_bodyBytes[1], BIT3)
		binToModel(streams, "zone2_curve_state",_bodyBytes[1], BIT4)
		binToModel(streams, "forcetbh_state", _bodyBytes[1],BIT5)
		binToModel(streams, "fastdhw_state", _bodyBytes[1], BIT6)
		binToModel(streams, "remote_onoff", _bodyBytes[1], BIT7)

		binToModel(streams, "heat_enable", _bodyBytes[2], BIT0)
		binToModel(streams, "cool_enable", _bodyBytes[2], BIT1)
		binToModel(streams, "dhw_enable", _bodyBytes[2], BIT2)
		binToModel(streams, "double_zone_enable", _bodyBytes[2], BIT3)
		binToModel(streams, "zone1_temp_type", _bodyBytes[2], BIT4)
		binToModel(streams, "zone2_temp_type", _bodyBytes[2], BIT5)
		binToModel(streams, "room_thermalen_state", _bodyBytes[2], BIT6)
		binToModel(streams, "room_thermalmode_state", _bodyBytes[2], BIT7)

		binToModel(streams, "time_set_state", _bodyBytes[3], BIT0)
		binToModel(streams, "silence_on_state", _bodyBytes[3], BIT1)
		binToModel(streams, "holiday_on_state", _bodyBytes[3], BIT2)
		binToModel(streams, "eco_on_state", _bodyBytes[3], BIT3)
		binToModel(streams, "zone1_terminal_type", _bodyBytes[3],nil)
		binToModel(streams, "zone2_terminal_type", _bodyBytes[3],nil)

		binToModel(streams, "run_mode_set", _bodyBytes[4], nil)
		binToModel(streams, "runmode_under_auto", _bodyBytes[5], nil)
		binToModel(streams, "zone1_temp_set", _bodyBytes[6], nil)
		binToModel(streams, "zone2_temp_set", _bodyBytes[7], nil)
		binToModel(streams, "dhw_temp_set", _bodyBytes[8], nil)
		binToModel(streams, "room_temp_set", _bodyBytes[9]/2, nil)
        --区域1设定温度范围
		binToModel(streams, "zone1_heat_max_set_temp", _bodyBytes[10], nil)
		binToModel(streams, "zone1_heat_min_set_temp", _bodyBytes[11], nil)
		binToModel(streams, "zone1_cool_max_set_temp", _bodyBytes[12], nil)
		binToModel(streams, "zone1_cool_min_set_temp", _bodyBytes[13], nil)
        --区域2设定温度范围
		binToModel(streams, "zone2_heat_max_set_temp", _bodyBytes[14], nil)
		binToModel(streams, "zone2_heat_min_set_temp", _bodyBytes[15], nil)
		binToModel(streams, "zone2_cool_max_set_temp", _bodyBytes[16], nil)
		binToModel(streams, "zone2_cool_min_set_temp", _bodyBytes[17], nil)

		binToModel(streams, "room_max_set_temp", _bodyBytes[18]/2, nil)
		binToModel(streams, "room_min_set_temp", _bodyBytes[19]/2, nil)
		binToModel(streams, "dhw_max_set_temp", _bodyBytes[20], nil)
		binToModel(streams, "dhw_min_set_temp", _bodyBytes[21], nil)
		binToModel(streams, "tank_actual_temp", _bodyBytes[22], nil)
		binToModel(streams, "error_code", _bodyBytes[23], nil)
        binToModel(streams, "SysEnergyAnaEN", _bodyBytes[24], BIT5)
		binToModel(streams, "HMIEnergyAnaSetEN", _bodyBytes[24], BIT6)
        --binToModel(streams, "protocol_newfunction_en", _bodyBytes[24], BIT7)
        binToModel(streams, "boostertbh_en", _bodyBytes[24], BIT7)
        --回复支持230312V1.2协议
        if(bodyLength > 24)  then  
            binToModel(streams, "protocol_newfunction_en",1,BIT0)
            --新增温度曲线设定
            binToModel(streams, "zone1_curve_type", _bodyBytes[25], nil)
            binToModel(streams, "zone2_curve_type", _bodyBytes[26], nil)
        else
            binToModel(streams, "protocol_newfunction_en",0,BIT0)
            --新增温度曲线设定
        end

	elseif ((_msgType==cmdTable["MSG_TYPE_QUERY"])   and (_msgBodyType==cmdTable["MSG_TYPE_QUERY_DAY_TIME"])) then
		-- 日定时查询
		-- 区域1日定时使能
		binToModel(streams, "daytimer_timer1en", _bodyBytes[1], BIT0)
		binToModel(streams, "daytimer_timer2en", _bodyBytes[1], BIT1)
		binToModel(streams, "daytimer_timer3en", _bodyBytes[1], BIT2)
		binToModel(streams, "daytimer_timer4en", _bodyBytes[1], BIT3)
		binToModel(streams, "daytimer_timer5en", _bodyBytes[1], BIT4)
		binToModel(streams, "daytimer_timer6en", _bodyBytes[1], BIT5)
        --22-12-19 增加protocol_newfunction_en
        --binToModel(streams, "protocol_newfunction_en", _bodyBytes[1], BIT7)
		-- 日定时 1
		binToModel(streams, "daytimer_timer1_mode", _bodyBytes[2], nil)
		binToModel(streams, "daytimer_timer1_temp", _bodyBytes[3], nil)
		binToModel(streams, "daytimer_timer1_openhour", _bodyBytes[4], nil)
		binToModel(streams, "daytimer_timer1_openmin", _bodyBytes[5], nil)
		binToModel(streams, "daytimer_timer1_closehour", _bodyBytes[6], nil)
		binToModel(streams, "daytimer_timer1_closemin", _bodyBytes[7], nil)
		-- 日定时 2
		binToModel(streams, "daytimer_timer2_mode", _bodyBytes[8], nil)
		binToModel(streams, "daytimer_timer2_temp", _bodyBytes[9], nil)
		binToModel(streams, "daytimer_timer2_openhour", _bodyBytes[10], nil)
		binToModel(streams, "daytimer_timer2_openmin", _bodyBytes[11], nil)
		binToModel(streams, "daytimer_timer2_closehour", _bodyBytes[12], nil)
		binToModel(streams, "daytimer_timer2_closemin", _bodyBytes[13], nil)
		-- 日定时 3
		binToModel(streams, "daytimer_timer3_mode", _bodyBytes[14], nil)
		binToModel(streams, "daytimer_timer3_temp", _bodyBytes[15], nil)
		binToModel(streams, "daytimer_timer3_openhour", _bodyBytes[16], nil)
		binToModel(streams, "daytimer_timer3_openmin", _bodyBytes[17], nil)
		binToModel(streams, "daytimer_timer3_closehour", _bodyBytes[18], nil)
		binToModel(streams, "daytimer_timer3_closemin", _bodyBytes[19], nil)
		-- 日定时 4
		binToModel(streams, "daytimer_timer4_mode", _bodyBytes[20], nil)
		binToModel(streams, "daytimer_timer4_temp", _bodyBytes[21], nil)
		binToModel(streams, "daytimer_timer4_openhour", _bodyBytes[22], nil)
		binToModel(streams, "daytimer_timer4_openmin", _bodyBytes[23], nil)
		binToModel(streams, "daytimer_timer4_closehour", _bodyBytes[24], nil)
		binToModel(streams, "daytimer_timer4_closemin", _bodyBytes[25], nil)
		-- 日定时 5
		binToModel(streams, "daytimer_timer5_mode", _bodyBytes[26], nil)
		binToModel(streams, "daytimer_timer5_temp", _bodyBytes[27], nil)
		binToModel(streams, "daytimer_timer5_openhour", _bodyBytes[28], nil)
		binToModel(streams, "daytimer_timer5_openmin", _bodyBytes[29], nil)
		binToModel(streams, "daytimer_timer5_closehour", _bodyBytes[30], nil)
		binToModel(streams, "daytimer_timer5_closemin", _bodyBytes[31], nil)
		-- 日定时 6
		binToModel(streams, "daytimer_timer6_mode", _bodyBytes[32], nil)
		binToModel(streams, "daytimer_timer6_temp", _bodyBytes[33], nil)
		binToModel(streams, "daytimer_timer6_openhour", _bodyBytes[34], nil)
		binToModel(streams, "daytimer_timer6_openmin", _bodyBytes[35], nil)
		binToModel(streams, "daytimer_timer6_closehour", _bodyBytes[36], nil)
		binToModel(streams, "daytimer_timer6_closemin", _bodyBytes[37], nil)
        --支持230312V1.2协议
        if(bodyLength > 37)  then  
            binToModel(streams, "protocol_newfunction_en",1,BIT0)
    
            -- 区域2日定时使能
            binToModel(streams, "zone2daytimer_timer1en", _bodyBytes[38], BIT0)
            binToModel(streams, "zone2daytimer_timer2en", _bodyBytes[38], BIT1)
            binToModel(streams, "zone2daytimer_timer3en", _bodyBytes[38], BIT2)
            binToModel(streams, "zone2daytimer_timer4en", _bodyBytes[38], BIT3)
            binToModel(streams, "zone2daytimer_timer5en", _bodyBytes[38], BIT4)
            binToModel(streams, "zone2daytimer_timer6en", _bodyBytes[38], BIT5)
            -- 区域2日定时 1
            binToModel(streams, "zone2daytimer_timer1_mode", _bodyBytes[39], nil)
            binToModel(streams, "zone2daytimer_timer1_temp", _bodyBytes[40], nil)
            binToModel(streams, "zone2daytimer_timer1_openhour", _bodyBytes[41], nil)
            binToModel(streams, "zone2daytimer_timer1_openmin", _bodyBytes[42], nil)
            binToModel(streams, "zone2daytimer_timer1_closehour", _bodyBytes[43], nil)
            binToModel(streams, "zone2daytimer_timer1_closemin", _bodyBytes[44], nil)
            -- 区域2日定时 2
            binToModel(streams, "zone2daytimer_timer2_mode", _bodyBytes[45], nil)
            binToModel(streams, "zone2daytimer_timer2_temp", _bodyBytes[46], nil)
            binToModel(streams, "zone2daytimer_timer2_openhour", _bodyBytes[47], nil)
            binToModel(streams, "zone2daytimer_timer2_openmin", _bodyBytes[48], nil)
            binToModel(streams, "zone2daytimer_timer2_closehour", _bodyBytes[49], nil)
            binToModel(streams, "zone2daytimer_timer2_closemin", _bodyBytes[50], nil)
            -- 区域2日定时 3
            binToModel(streams, "zone2daytimer_timer3_mode", _bodyBytes[51], nil)
            binToModel(streams, "zone2daytimer_timer3_temp", _bodyBytes[52], nil)
            binToModel(streams, "zone2daytimer_timer3_openhour", _bodyBytes[53], nil)
            binToModel(streams, "zone2daytimer_timer3_openmin", _bodyBytes[54], nil)
            binToModel(streams, "zone2daytimer_timer3_closehour", _bodyBytes[55], nil)
            binToModel(streams, "zone2daytimer_timer3_closemin", _bodyBytes[56], nil)
            -- 区域2日定时 4
            binToModel(streams, "zone2daytimer_timer4_mode", _bodyBytes[57], nil)
            binToModel(streams, "zone2daytimer_timer4_temp", _bodyBytes[58], nil)
            binToModel(streams, "zone2daytimer_timer4_openhour", _bodyBytes[59], nil)
            binToModel(streams, "zone2daytimer_timer4_openmin", _bodyBytes[60], nil)
            binToModel(streams, "zone2daytimer_timer4_closehour", _bodyBytes[61], nil)
            binToModel(streams, "zone2daytimer_timer4_closemin", _bodyBytes[62], nil)
            -- 区域2日定时 5
            binToModel(streams, "zone2daytimer_timer5_mode", _bodyBytes[63], nil)
            binToModel(streams, "zone2daytimer_timer5_temp", _bodyBytes[64], nil)
            binToModel(streams, "zone2daytimer_timer5_openhour", _bodyBytes[65], nil)
            binToModel(streams, "zone2daytimer_timer5_openmin", _bodyBytes[66], nil)
            binToModel(streams, "zone2daytimer_timer5_closehour", _bodyBytes[67], nil)
            binToModel(streams, "zone2daytimer_timer5_closemin", _bodyBytes[68], nil)
            -- 区域2日定时 6
            binToModel(streams, "zone2daytimer_timer6_mode", _bodyBytes[69], nil)
            binToModel(streams, "zone2daytimer_timer6_temp", _bodyBytes[70], nil)
            binToModel(streams, "zone2daytimer_timer6_openhour", _bodyBytes[71], nil)
            binToModel(streams, "zone2daytimer_timer6_openmin", _bodyBytes[72], nil)
            binToModel(streams, "zone2daytimer_timer6_closehour", _bodyBytes[73], nil)
            binToModel(streams, "zone2daytimer_timer6_closemin", _bodyBytes[74], nil)
        end
	elseif ((_msgType==cmdTable["MSG_TYPE_QUERY"])   and (_msgBodyType==cmdTable["MSG_TYPE_QUERY_WEEKS_TIME"])) then
		-- 周定时查询
		-- 周定时使能
		binToModel(streams, "weektimer_weeken", _bodyBytes[1], nil)
		binToModel(streams, "weektimer_timer1en", _bodyBytes[2], BIT0)
		binToModel(streams, "weektimer_timer2en", _bodyBytes[2], BIT1)
		binToModel(streams, "weektimer_timer3en", _bodyBytes[2], BIT2)
		binToModel(streams, "weektimer_timer4en", _bodyBytes[2], BIT3)
		binToModel(streams, "weektimer_timer5en", _bodyBytes[2], BIT4)
		binToModel(streams, "weektimer_timer6en", _bodyBytes[2], BIT5)
        --22-12-19 增加protocol_newfunction_en
        --binToModel(streams, "protocol_newfunction_en", _bodyBytes[2], BIT7)
		-- 周定时 1
		binToModel(streams, "weektimer_timer1_mode", _bodyBytes[3], nil)
		binToModel(streams, "weektimer_timer1_temp", _bodyBytes[4], nil)
		binToModel(streams, "weektimer_timer1_openhour", _bodyBytes[5], nil)
		binToModel(streams, "weektimer_timer1_openmin", _bodyBytes[6], nil)
		binToModel(streams, "weektimer_timer1_closehour", _bodyBytes[7], nil)
		binToModel(streams, "weektimer_timer1_closemin", _bodyBytes[8], nil)
		-- 周定时 2
		binToModel(streams, "weektimer_timer2_mode", _bodyBytes[9], nil)
		binToModel(streams, "weektimer_timer2_temp", _bodyBytes[10], nil)
		binToModel(streams, "weektimer_timer2_openhour", _bodyBytes[11], nil)
		binToModel(streams, "weektimer_timer2_openmin", _bodyBytes[12], nil)
		binToModel(streams, "weektimer_timer2_closehour", _bodyBytes[13], nil)
		binToModel(streams, "weektimer_timer2_closemin", _bodyBytes[14], nil)
		-- 周定时 3
		binToModel(streams, "weektimer_timer3_mode", _bodyBytes[15], nil)
		binToModel(streams, "weektimer_timer3_temp", _bodyBytes[16], nil)
		binToModel(streams, "weektimer_timer3_openhour", _bodyBytes[17], nil)
		binToModel(streams, "weektimer_timer3_openmin", _bodyBytes[18], nil)
		binToModel(streams, "weektimer_timer3_closehour", _bodyBytes[19], nil)
		binToModel(streams, "weektimer_timer3_closemin", _bodyBytes[20], nil)
		-- 周定时 4
		binToModel(streams, "weektimer_timer4_mode", _bodyBytes[21], nil)
		binToModel(streams, "weektimer_timer4_temp", _bodyBytes[22], nil)
		binToModel(streams, "weektimer_timer4_openhour", _bodyBytes[23], nil)
		binToModel(streams, "weektimer_timer4_openmin", _bodyBytes[24], nil)
		binToModel(streams, "weektimer_timer4_closehour", _bodyBytes[25], nil)
		binToModel(streams, "weektimer_timer4_closemin", _bodyBytes[26], nil)
		-- 周定时 5
		binToModel(streams, "weektimer_timer5_mode", _bodyBytes[27], nil)
		binToModel(streams, "weektimer_timer5_temp", _bodyBytes[28], nil)
		binToModel(streams, "weektimer_timer5_openhour", _bodyBytes[29], nil)
		binToModel(streams, "weektimer_timer5_openmin", _bodyBytes[30], nil)
		binToModel(streams, "weektimer_timer5_closehour", _bodyBytes[31], nil)
		binToModel(streams, "weektimer_timer5_closemin", _bodyBytes[32], nil)
		-- 周定时 6
		binToModel(streams, "weektimer_timer6_mode", _bodyBytes[33], nil)
		binToModel(streams, "weektimer_timer6_temp", _bodyBytes[34], nil)
		binToModel(streams, "weektimer_timer6_openhour", _bodyBytes[35], nil)
		binToModel(streams, "weektimer_timer6_openmin", _bodyBytes[36], nil)
		binToModel(streams, "weektimer_timer6_closehour", _bodyBytes[37], nil)
		binToModel(streams, "weektimer_timer6_closemin", _bodyBytes[38], nil)
        --支持230312V1.2协议
        if(bodyLength > 38)  then  
            binToModel(streams, "protocol_newfunction_en",1,BIT0) 
            --周定时区域2查询日期及时段使能
            binToModel(streams, "zone2weektimer_weeken", _bodyBytes[39], nil)
            binToModel(streams, "zone2weektimer_timer1en", _bodyBytes[40], BIT0)
            binToModel(streams, "zone2weektimer_timer2en", _bodyBytes[40], BIT1)
            binToModel(streams, "zone2weektimer_timer3en", _bodyBytes[40], BIT2)
            binToModel(streams, "zone2weektimer_timer4en", _bodyBytes[40], BIT3)
            binToModel(streams, "zone2weektimer_timer5en", _bodyBytes[40], BIT4)
            binToModel(streams, "zone2weektimer_timer6en", _bodyBytes[40], BIT5)
            --周定时区域2 1
            binToModel(streams, "zone2weektimer_timer1_mode", _bodyBytes[41], nil)
            binToModel(streams, "zone2weektimer_timer1_temp", _bodyBytes[42], nil)
            binToModel(streams, "zone2weektimer_timer1_openhour", _bodyBytes[43], nil)
            binToModel(streams, "zone2weektimer_timer1_openmin", _bodyBytes[44], nil)
            binToModel(streams, "zone2weektimer_timer1_closehour", _bodyBytes[45], nil)
            binToModel(streams, "zone2weektimer_timer1_closemin", _bodyBytes[46], nil)
            --周定时区域2 2
            binToModel(streams, "zone2weektimer_timer2_mode", _bodyBytes[47], nil)
            binToModel(streams, "zone2weektimer_timer2_temp", _bodyBytes[48], nil)
            binToModel(streams, "zone2weektimer_timer2_openhour", _bodyBytes[49], nil)
            binToModel(streams, "zone2weektimer_timer2_openmin", _bodyBytes[50], nil)
            binToModel(streams, "zone2weektimer_timer2_closehour", _bodyBytes[51], nil)
            binToModel(streams, "zone2weektimer_timer2_closemin", _bodyBytes[52], nil)
            --周定时区域2 3
            binToModel(streams, "zone2weektimer_timer3_mode", _bodyBytes[53], nil)
            binToModel(streams, "zone2weektimer_timer3_temp", _bodyBytes[54], nil)
            binToModel(streams, "zone2weektimer_timer3_openhour", _bodyBytes[55], nil)
            binToModel(streams, "zone2weektimer_timer3_openmin", _bodyBytes[56], nil)
            binToModel(streams, "zone2weektimer_timer3_closehour", _bodyBytes[57], nil)
            binToModel(streams, "zone2weektimer_timer3_closemin", _bodyBytes[58], nil)
            --周定时区域2 4
            binToModel(streams, "zone2weektimer_timer4_mode", _bodyBytes[59], nil)
            binToModel(streams, "zone2weektimer_timer4_temp", _bodyBytes[60], nil)
            binToModel(streams, "zone2weektimer_timer4_openhour", _bodyBytes[61], nil)
            binToModel(streams, "zone2weektimer_timer4_openmin", _bodyBytes[62], nil)
            binToModel(streams, "zone2weektimer_timer4_closehour", _bodyBytes[63], nil)
            binToModel(streams, "zone2weektimer_timer4_closemin", _bodyBytes[64], nil)
            --周定时区域2 5
            binToModel(streams, "zone2weektimer_timer5_mode", _bodyBytes[65], nil)
            binToModel(streams, "zone2weektimer_timer5_temp", _bodyBytes[66], nil)
            binToModel(streams, "zone2weektimer_timer5_openhour", _bodyBytes[67], nil)
            binToModel(streams, "zone2weektimer_timer5_openmin", _bodyBytes[68], nil)
            binToModel(streams, "zone2weektimer_timer5_closehour", _bodyBytes[69], nil)
            binToModel(streams, "zone2weektimer_timer5_closemin", _bodyBytes[70], nil)
            --周定时区域2 6
            binToModel(streams, "zone2weektimer_timer6_mode", _bodyBytes[71], nil)
            binToModel(streams, "zone2weektimer_timer6_temp", _bodyBytes[72], nil)
            binToModel(streams, "zone2weektimer_timer6_openhour", _bodyBytes[73], nil)
            binToModel(streams, "zone2weektimer_timer6_openmin", _bodyBytes[74], nil)
            binToModel(streams, "zone2weektimer_timer6_closehour", _bodyBytes[75], nil)
            binToModel(streams, "zone2weektimer_timer6_closemin", _bodyBytes[76], nil)
        end
	elseif ((_msgType==cmdTable["MSG_TYPE_QUERY"])   and (_msgBodyType==cmdTable["MSG_TYPE_QUERY_HOLIDAY_AWAY"])) then
		-- 外出休假设置查询
		binToModel(streams, "holidayaway_state", _bodyBytes[1], BIT0)
		--binToModel(streams, "protocol_newfunction_en", _bodyBytes[1], BIT7)
		binToModel(streams, "holidayaway_startyear", _bodyBytes[2], nil)
		binToModel(streams, "holidayaway_startmonth", _bodyBytes[3], nil)
		binToModel(streams, "holidayaway_startdate", _bodyBytes[4], nil)
		binToModel(streams, "holidayaway_endyear", _bodyBytes[5], nil)
		binToModel(streams, "holidayaway_endmonth", _bodyBytes[6], nil)
		binToModel(streams, "holidayaway_enddate", _bodyBytes[7], nil)
        --支持230312V1.2协议
        if(bodyLength > 7)  then  
            binToModel(streams, "protocol_newfunction_en",1,BIT0) 
			binToModel(streams, "holidayaway_heat_state", _bodyBytes[8], BIT0)
			binToModel(streams, "holidayaway_dhw_state", _bodyBytes[8], BIT1)
			binToModel(streams, "holidayaway_disinfect_state", _bodyBytes[8], BIT2)            
        end   
	elseif ((_msgType==cmdTable["MSG_TYPE_QUERY"])   and (_msgBodyType==cmdTable["MSG_TYPE_QUERY_SILENCE"])) then
		-- 静音设置查询
		-- 状态
		binToModel(streams, "silence_function_state", _bodyBytes[1], BIT0)
		binToModel(streams, "silence_timer1_state", _bodyBytes[1], BIT1)
		binToModel(streams, "silence_timer2_state", _bodyBytes[1], BIT2)
		binToModel(streams, "silence_function_level", _bodyBytes[1], BIT3)
		-- 静音定时1
		binToModel(streams, "silence_timer1_starthour", _bodyBytes[2], nil)
		binToModel(streams, "silence_timer1_startmin", _bodyBytes[3], nil)
		binToModel(streams, "silence_timer1_endhour", _bodyBytes[4], nil)
		binToModel(streams, "silence_timer1_endmin", _bodyBytes[5], nil)
		-- 静音定时2
		binToModel(streams, "silence_timer2_starthour", _bodyBytes[6], nil)
		binToModel(streams, "silence_timer2_startmin", _bodyBytes[7], nil)
		binToModel(streams, "silence_timer2_endhour", _bodyBytes[8], nil)
		binToModel(streams, "silence_timer2_endmin", _bodyBytes[9], nil)
	elseif ((_msgType==cmdTable["MSG_TYPE_QUERY"])   and (_msgBodyType==cmdTable["MSG_TYPE_QUERY_HOLIDAY_HOME"])) then
		-- 在家休假设置查询-holidayhome
		binToModel(streams, "holidayhome_state", _bodyBytes[1], BIT0)
		binToModel(streams, "holidayhome_startyear", _bodyBytes[2], nil)
		binToModel(streams, "holidayhome_startmonth", _bodyBytes[3], nil)
		binToModel(streams, "holidayhome_startdate", _bodyBytes[4], nil)
		binToModel(streams, "holidayhome_endyear", _bodyBytes[5], nil)
		binToModel(streams, "holidayhome_endmonth", _bodyBytes[6], nil)
		binToModel(streams, "holidayhome_enddate", _bodyBytes[7], nil)
		-- HOLIDAY_HOME 定时使能
		binToModel(streams, "holhometimer_timer1en", _bodyBytes[8], BIT0)
		binToModel(streams, "holhometimer_timer2en", _bodyBytes[8], BIT1)
		binToModel(streams, "holhometimer_timer3en", _bodyBytes[8], BIT2)
		binToModel(streams, "holhometimer_timer4en", _bodyBytes[8], BIT3)
		binToModel(streams, "holhometimer_timer5en", _bodyBytes[8], BIT4)
		binToModel(streams, "holhometimer_timer6en", _bodyBytes[8], BIT5)
        --binToModel(streams, "protocol_newfunction_en", _bodyBytes[8], BIT7)
		--HOLIDAY_HOME定时 1
		binToModel(streams, "holhometimer_timer1_mode", _bodyBytes[9], nil)
		binToModel(streams, "holhometimer_timer1_temp", _bodyBytes[10], nil)
		binToModel(streams, "holhometimer_timer1_openhour", _bodyBytes[11], nil)
		binToModel(streams, "holhometimer_timer1_openmin", _bodyBytes[12], nil)
		binToModel(streams, "holhometimer_timer1_closehour", _bodyBytes[13], nil)
		binToModel(streams, "holhometimer_timer1_closemin", _bodyBytes[14], nil)
		-- HOLIDAY_HOME 定时 2
		binToModel(streams, "holhometimer_timer2_mode", _bodyBytes[15], nil)
		binToModel(streams, "holhometimer_timer2_temp", _bodyBytes[16], nil)
		binToModel(streams, "holhometimer_timer2_openhour", _bodyBytes[17], nil)
		binToModel(streams, "holhometimer_timer2_openmin", _bodyBytes[18], nil)
		binToModel(streams, "holhometimer_timer2_closehour", _bodyBytes[19], nil)
		binToModel(streams, "holhometimer_timer2_closemin", _bodyBytes[20], nil)
		-- HOLIDAY_HOME定时 3
		binToModel(streams, "holhometimer_timer3_mode", _bodyBytes[21], nil)
		binToModel(streams, "holhometimer_timer3_temp", _bodyBytes[22], nil)
		binToModel(streams, "holhometimer_timer3_openhour", _bodyBytes[23], nil)
		binToModel(streams, "holhometimer_timer3_openmin", _bodyBytes[24], nil)
		binToModel(streams, "holhometimer_timer3_closehour", _bodyBytes[25], nil)
		binToModel(streams, "holhometimer_timer3_closemin", _bodyBytes[26], nil)
		-- HOLIDAY_HOME定时 4
		binToModel(streams, "holhometimer_timer4_mode", _bodyBytes[27], nil)
		binToModel(streams, "holhometimer_timer4_temp", _bodyBytes[28], nil)
		binToModel(streams, "holhometimer_timer4_openhour", _bodyBytes[29], nil)
		binToModel(streams, "holhometimer_timer4_openmin", _bodyBytes[30], nil)
		binToModel(streams, "holhometimer_timer4_closehour", _bodyBytes[31], nil)
		binToModel(streams, "holhometimer_timer4_closemin", _bodyBytes[32], nil)
		-- HOLIDAY_HOME定时 5
		binToModel(streams, "holhometimer_timer5_mode", _bodyBytes[33], nil)
		binToModel(streams, "holhometimer_timer5_temp", _bodyBytes[34], nil)
		binToModel(streams, "holhometimer_timer5_openhour", _bodyBytes[35], nil)
		binToModel(streams, "holhometimer_timer5_openmin", _bodyBytes[36], nil)
		binToModel(streams, "holhometimer_timer5_closehour", _bodyBytes[37], nil)
		binToModel(streams, "holhometimer_timer5_closemin", _bodyBytes[38], nil)
		-- HOLIDAY_HOME定时 6
		binToModel(streams, "holhometimer_timer6_mode", _bodyBytes[39], nil)
		binToModel(streams, "holhometimer_timer6_temp", _bodyBytes[40], nil)
		binToModel(streams, "holhometimer_timer6_openhour", _bodyBytes[41], nil)
		binToModel(streams, "holhometimer_timer6_openmin", _bodyBytes[42], nil)
		binToModel(streams, "holhometimer_timer6_closehour", _bodyBytes[43], nil)
		binToModel(streams, "holhometimer_timer6_closemin", _bodyBytes[44], nil)
        --支持230312V1.2协议
        if(bodyLength > 44)  then  
            binToModel(streams, "protocol_newfunction_en",1,BIT0) 
            -- HOLIDAY_HOME 区域2定时使能
            binToModel(streams, "zone2holhometimer_timer1en", _bodyBytes[45], BIT0)
            binToModel(streams, "zone2holhometimer_timer2en", _bodyBytes[45], BIT1)
            binToModel(streams, "zone2holhometimer_timer3en", _bodyBytes[45], BIT2)
            binToModel(streams, "zone2holhometimer_timer4en", _bodyBytes[45], BIT3)
            binToModel(streams, "zone2holhometimer_timer5en", _bodyBytes[45], BIT4)
            binToModel(streams, "zone2holhometimer_timer6en", _bodyBytes[45], BIT5)
            --HOLIDAY_HOME区域2定时 1
            binToModel(streams, "zone2holhometimer_timer1_mode", _bodyBytes[46], nil)
            binToModel(streams, "zone2holhometimer_timer1_temp", _bodyBytes[47], nil)
            binToModel(streams, "zone2holhometimer_timer1_openhour", _bodyBytes[48], nil)
            binToModel(streams, "zone2holhometimer_timer1_openmin", _bodyBytes[49], nil)
            binToModel(streams, "zone2holhometimer_timer1_closehour", _bodyBytes[50], nil)
            binToModel(streams, "zone2holhometimer_timer1_closemin", _bodyBytes[51], nil)
            -- HOLIDAY_HOME 区域2定时 2
            binToModel(streams, "zone2holhometimer_timer2_mode", _bodyBytes[52], nil)
            binToModel(streams, "zone2holhometimer_timer2_temp", _bodyBytes[53], nil)
            binToModel(streams, "zone2holhometimer_timer2_openhour", _bodyBytes[54], nil)
            binToModel(streams, "zone2holhometimer_timer2_openmin", _bodyBytes[55], nil)
            binToModel(streams, "zone2holhometimer_timer2_closehour", _bodyBytes[56], nil)
            binToModel(streams, "zone2holhometimer_timer2_closemin", _bodyBytes[57], nil)
            -- HOLIDAY_HOME区域2定时 3
            binToModel(streams, "zone2holhometimer_timer3_mode", _bodyBytes[58], nil)
            binToModel(streams, "zone2holhometimer_timer3_temp", _bodyBytes[59], nil)
            binToModel(streams, "zone2holhometimer_timer3_openhour", _bodyBytes[60], nil)
            binToModel(streams, "zone2holhometimer_timer3_openmin", _bodyBytes[61], nil)
            binToModel(streams, "zone2holhometimer_timer3_closehour", _bodyBytes[62], nil)
            binToModel(streams, "zone2holhometimer_timer3_closemin", _bodyBytes[63], nil)
            -- HOLIDAY_HOME区域2定时 4
            binToModel(streams, "zone2holhometimer_timer4_mode", _bodyBytes[64], nil)
            binToModel(streams, "zone2holhometimer_timer4_temp", _bodyBytes[65], nil)
            binToModel(streams, "zone2holhometimer_timer4_openhour", _bodyBytes[66], nil)
            binToModel(streams, "zone2holhometimer_timer4_openmin", _bodyBytes[67], nil)
            binToModel(streams, "zone2holhometimer_timer4_closehour", _bodyBytes[68], nil)
            binToModel(streams, "zone2holhometimer_timer4_closemin", _bodyBytes[69], nil)
            -- HOLIDAY_HOME区域2定时 5
            binToModel(streams, "zone2holhometimer_timer5_mode", _bodyBytes[70], nil)
            binToModel(streams, "zone2holhometimer_timer5_temp", _bodyBytes[71], nil)
            binToModel(streams, "zone2holhometimer_timer5_openhour", _bodyBytes[72], nil)
            binToModel(streams, "zone2holhometimer_timer5_openmin", _bodyBytes[73], nil)
            binToModel(streams, "zone2holhometimer_timer5_closehour", _bodyBytes[74], nil)
            binToModel(streams, "zone2holhometimer_timer5_closemin", _bodyBytes[75], nil)
            -- HOLIDAY_HOME区域2定时 6
            binToModel(streams, "zone2holhometimer_timer6_mode", _bodyBytes[76], nil)
            binToModel(streams, "zone2holhometimer_timer6_temp", _bodyBytes[77], nil)
            binToModel(streams, "zone2holhometimer_timer6_openhour", _bodyBytes[78], nil)
            binToModel(streams, "zone2holhometimer_timer6_openmin", _bodyBytes[79], nil)
            binToModel(streams, "zone2holhometimer_timer6_closehour", _bodyBytes[80], nil)
            binToModel(streams, "zone2holhometimer_timer6_closemin", _bodyBytes[81], nil)
        end
	elseif ((_msgType==cmdTable["MSG_TYPE_QUERY"])   and (_msgBodyType==cmdTable["MSG_TYPE_QUERY_ECO"])) then
		-- ECO设置查询
		binToModel(streams, "eco_function_state", _bodyBytes[1], BIT0)
		binToModel(streams, "eco_timer_state", _bodyBytes[1], BIT1)
		-- 静音定时1
		binToModel(streams, "eco_timer_starthour", _bodyBytes[2], nil)
		binToModel(streams, "eco_timer_startmin", _bodyBytes[3], nil)
		binToModel(streams, "eco_timer_endhour", _bodyBytes[4], nil)
		binToModel(streams, "eco_timer_endmin", _bodyBytes[5], nil)
        --支持230312V1.2协议
        if(bodyLength > 5)  then          
            binToModel(streams, "eco_curve_type", _bodyBytes[6], nil)
        end
    elseif ((_msgType==cmdTable["MSG_TYPE_QUERY"])   and (_msgBodyType==cmdTable["MSG_TYPE_QUERY_DISINFECT"])) then
		-- DISINFECT 设置查询
		binToModel(streams, "disinfect_function_state", _bodyBytes[1], BIT0)
		binToModel(streams, "disinfect_run_state", _bodyBytes[1], BIT1)
		-- DISINFECT定时
		binToModel(streams, "disinfect_setweekday", _bodyBytes[2], nil)
		binToModel(streams, "disinfect_starthour", _bodyBytes[3], nil)
		binToModel(streams, "disinfect_startmin", _bodyBytes[4], nil)

	elseif ((_msgType==cmdTable["MSG_TYPE_UP"])  and ( _msgBodyType==cmdTable["MSG_TYPE_UP_POWER3"])) then
        binToModel(streams, "msg_up_type", cmdTable["MSG_TYPE_UP_POWER3"],nil)
		binToModel(streams, "isheatrun0", _bodyBytes[1], BIT0)
		binToModel(streams, "iscoolrun0", _bodyBytes[1], BIT1)
		binToModel(streams, "isdhwrun0", _bodyBytes[1], BIT2)
		binToModel(streams, "istbhrun0", _bodyBytes[1], BIT3)
		binToModel(streams, "isibhrun0", _bodyBytes[1], BIT4)
		binToModel(streams, "issmartgrid0", _bodyBytes[1], BIT5)
		binToModel(streams, "ishighprices0", _bodyBytes[1], BIT6)
		binToModel(streams, "isbottomprices0", _bodyBytes[1], BIT7)

		binToModel(streams, "totalelectricity0",_bodyBytes[2]*16777216+_bodyBytes[3]*65536+_bodyBytes[4]*256+_bodyBytes[5], nil)
		binToModel(streams, "totalthermal0",  _bodyBytes[6]*16777216+_bodyBytes[7]*65536+_bodyBytes[8]*256+_bodyBytes[9], nil)

		binToModel(streams, "t4", _bodyBytes[10], nil)
		binToModel(streams, "zone1_temp_set", _bodyBytes[11], nil)
		binToModel(streams, "zone2_temp_set", _bodyBytes[12], nil)
		binToModel(streams, "t5s", _bodyBytes[13], nil)
		binToModel(streams, "tas", _bodyBytes[14], nil)        

    elseif ((_msgType==cmdTable["MSG_TYPE_UP"])  and (_msgBodyType==cmdTable["MSG_TYPE_UP_POWER4"]) ) then
		-- 上报04-04(电控主动上报能量数据组包)
        binToModel(streams, "msg_up_type", cmdTable["MSG_TYPE_UP_POWER4"],nil)
		binToModel(streams, "isheatrun0", _bodyBytes[1], BIT0)
		binToModel(streams, "iscoolrun0", _bodyBytes[1], BIT1)
		binToModel(streams, "isdhwrun0", _bodyBytes[1], BIT2)
		binToModel(streams, "istbhrun0", _bodyBytes[1], BIT3)
		binToModel(streams, "isibhrun0", _bodyBytes[1], BIT4)
		binToModel(streams, "issmartgrid0", _bodyBytes[1], BIT5)
		binToModel(streams, "ishighprices0", _bodyBytes[1], BIT6)
		binToModel(streams, "isbottomprices0", _bodyBytes[1], BIT7)
		binToModel(streams, "totalelectricity0",_bodyBytes[2]*16777216+_bodyBytes[3]*65536+_bodyBytes[4]*256+_bodyBytes[5], nil)
		binToModel(streams, "totalthermal0",  _bodyBytes[6]*16777216+_bodyBytes[7]*65536+_bodyBytes[8]*256+_bodyBytes[9], nil)
		binToModel(streams, "t4", _bodyBytes[10], nil)
		binToModel(streams, "zone1_temp_set", _bodyBytes[11], nil)
		binToModel(streams, "zone2_temp_set", _bodyBytes[12], nil)
		binToModel(streams, "t5s", _bodyBytes[13], nil)
		binToModel(streams, "tas", _bodyBytes[14], nil)
		binToModel(streams, "newt1s1", _bodyBytes[15], nil)
		binToModel(streams, "newt1s2", _bodyBytes[16], nil)
		binToModel(streams, "isonline0", _bodyBytes[17], BIT0)
		binToModel(streams, "isonline1", _bodyBytes[17], BIT1)
		binToModel(streams, "isonline2", _bodyBytes[17], BIT2)
		binToModel(streams, "isonline3", _bodyBytes[17], BIT3)
		binToModel(streams, "isonline4", _bodyBytes[17], BIT4)
		binToModel(streams, "isonline5", _bodyBytes[17], BIT5)
		binToModel(streams, "isonline6", _bodyBytes[17], BIT6)
		binToModel(streams, "isonline7", _bodyBytes[17], BIT7)
		binToModel(streams, "isonline8", _bodyBytes[18], BIT0)
		binToModel(streams, "isonline9", _bodyBytes[18], BIT1)
		binToModel(streams, "isonline10", _bodyBytes[18], BIT2)
		binToModel(streams, "isonline11", _bodyBytes[18], BIT3)
		binToModel(streams, "isonline12", _bodyBytes[18], BIT4)
		binToModel(streams, "isonline13", _bodyBytes[18], BIT5)
		binToModel(streams, "isonline14", _bodyBytes[18], BIT6)
		binToModel(streams, "isonline15", _bodyBytes[18], BIT7)

		binToModel(streams, "isheatrun1", _bodyBytes[19], BIT0)
		binToModel(streams, "iscoolrun1", _bodyBytes[19], BIT1)
		binToModel(streams, "isdhwrun1", _bodyBytes[19], BIT2)
		binToModel(streams, "istbhrun1", _bodyBytes[19], BIT3)
		binToModel(streams, "isibhrun1", _bodyBytes[19], BIT4)
		binToModel(streams, "totalelectricity1",_bodyBytes[20]*16777216+_bodyBytes[21]*65536+_bodyBytes[22]*256+_bodyBytes[23], nil)
		binToModel(streams, "totalthermal1",  _bodyBytes[24]*16777216+_bodyBytes[25]*65536+_bodyBytes[26]*256+_bodyBytes[27], nil)

		binToModel(streams, "isheatrun2", _bodyBytes[28], BIT0)
		binToModel(streams, "iscoolrun2", _bodyBytes[28], BIT1)
		binToModel(streams, "isdhwrun2", _bodyBytes[28], BIT2)
		binToModel(streams, "istbhrun2", _bodyBytes[28], BIT3)
		binToModel(streams, "isibhrun2", _bodyBytes[28], BIT4)
		binToModel(streams, "totalelectricity2",_bodyBytes[29]*16777216+_bodyBytes[30]*65536+_bodyBytes[31]*256+_bodyBytes[32], nil)
		binToModel(streams, "totalthermal2",  _bodyBytes[33]*16777216+_bodyBytes[34]*65536+_bodyBytes[35]*256+_bodyBytes[36], nil)

		binToModel(streams, "isheatrun3", _bodyBytes[37], BIT0)
		binToModel(streams, "iscoolrun3", _bodyBytes[37], BIT1)
		binToModel(streams, "isdhwrun3", _bodyBytes[37], BIT2)
		binToModel(streams, "istbhrun3", _bodyBytes[37], BIT3)
		binToModel(streams, "isibhrun3", _bodyBytes[37], BIT4)
		binToModel(streams, "totalelectricity3",_bodyBytes[38]*16777216+_bodyBytes[39]*65536+_bodyBytes[40]*256+_bodyBytes[41], nil)
		binToModel(streams, "totalthermal3",  _bodyBytes[42]*16777216+_bodyBytes[43]*65536+_bodyBytes[44]*256+_bodyBytes[45], nil)

		binToModel(streams, "isheatrun4", _bodyBytes[46], BIT0)
		binToModel(streams, "iscoolrun4", _bodyBytes[46], BIT1)
		binToModel(streams, "isdhwrun4", _bodyBytes[46], BIT2)
		binToModel(streams, "istbhrun4", _bodyBytes[46], BIT3)
		binToModel(streams, "isibhrun4", _bodyBytes[46], BIT4)
		binToModel(streams, "totalelectricity4",_bodyBytes[47]*16777216+_bodyBytes[48]*65536+_bodyBytes[49]*256+_bodyBytes[50], nil)
		binToModel(streams, "totalthermal4",  _bodyBytes[51]*16777216+_bodyBytes[52]*65536+_bodyBytes[53]*256+_bodyBytes[54], nil)

		binToModel(streams, "isheatrun5", _bodyBytes[55], BIT0)
		binToModel(streams, "iscoolrun5", _bodyBytes[55], BIT1)
		binToModel(streams, "isdhwrun5", _bodyBytes[55], BIT2)
		binToModel(streams, "istbhrun5", _bodyBytes[55], BIT3)
		binToModel(streams, "isibhrun5", _bodyBytes[55], BIT4)
		binToModel(streams, "totalelectricity5",_bodyBytes[56]*16777216+_bodyBytes[57]*65536+_bodyBytes[58]*256+_bodyBytes[59], nil)
		binToModel(streams, "totalthermal5",  _bodyBytes[60]*16777216+_bodyBytes[61]*65536+_bodyBytes[62]*256+_bodyBytes[63], nil)

		binToModel(streams, "isheatrun6", _bodyBytes[64], BIT0)
		binToModel(streams, "iscoolrun6", _bodyBytes[64], BIT1)
		binToModel(streams, "isdhwrun6", _bodyBytes[64], BIT2)
		binToModel(streams, "istbhrun6", _bodyBytes[64], BIT3)
		binToModel(streams, "isibhrun6", _bodyBytes[64], BIT4)
		binToModel(streams, "totalelectricity6",_bodyBytes[65]*16777216+_bodyBytes[66]*65536+_bodyBytes[67]*256+_bodyBytes[68], nil)
		binToModel(streams, "totalthermal6",  _bodyBytes[69]*16777216+_bodyBytes[70]*65536+_bodyBytes[71]*256+_bodyBytes[72], nil)

		binToModel(streams, "isheatrun7", _bodyBytes[73], BIT0)
		binToModel(streams, "iscoolrun7", _bodyBytes[73], BIT1)
		binToModel(streams, "isdhwrun7", _bodyBytes[73], BIT2)
		binToModel(streams, "istbhrun7", _bodyBytes[73], BIT3)
		binToModel(streams, "isibhrun7", _bodyBytes[73], BIT4)
		binToModel(streams, "totalelectricity7",_bodyBytes[74]*16777216+_bodyBytes[75]*65536+_bodyBytes[76]*256+_bodyBytes[77], nil)
		binToModel(streams, "totalthermal7",  _bodyBytes[78]*16777216+_bodyBytes[79]*65536+_bodyBytes[80]*256+_bodyBytes[81], nil)

		binToModel(streams, "isheatrun8", _bodyBytes[82], BIT0)
		binToModel(streams, "iscoolrun8", _bodyBytes[82], BIT1)
		binToModel(streams, "isdhwrun8", _bodyBytes[82], BIT2)
		binToModel(streams, "istbhrun8", _bodyBytes[82], BIT3)
		binToModel(streams, "isibhrun8", _bodyBytes[82], BIT4)
		binToModel(streams, "totalelectricity8",_bodyBytes[83]*16777216+_bodyBytes[84]*65536+_bodyBytes[85]*256+_bodyBytes[86], nil)
		binToModel(streams, "totalthermal8",  _bodyBytes[87]*16777216+_bodyBytes[88]*65536+_bodyBytes[89]*256+_bodyBytes[90], nil)

		binToModel(streams, "isheatrun9", _bodyBytes[91], BIT0)
		binToModel(streams, "iscoolrun9", _bodyBytes[91], BIT1)
		binToModel(streams, "isdhwrun9", _bodyBytes[91], BIT2)
		binToModel(streams, "istbhrun9", _bodyBytes[91], BIT3)
		binToModel(streams, "isibhrun9", _bodyBytes[91], BIT4)
		binToModel(streams, "totalelectricity9",_bodyBytes[92]*16777216+_bodyBytes[93]*65536+_bodyBytes[94]*256+_bodyBytes[95], nil)
		binToModel(streams, "totalthermal9",  _bodyBytes[96]*16777216+_bodyBytes[97]*65536+_bodyBytes[98]*256+_bodyBytes[99], nil)

		binToModel(streams, "isheatrun10", _bodyBytes[100], BIT0)
		binToModel(streams, "iscoolrun10", _bodyBytes[100], BIT1)
		binToModel(streams, "isdhwrun10", _bodyBytes[100], BIT2)
		binToModel(streams, "istbhrun10", _bodyBytes[100], BIT3)
		binToModel(streams, "isibhrun10", _bodyBytes[100], BIT4)
		binToModel(streams, "totalelectricity10",_bodyBytes[101]*16777216+_bodyBytes[102]*65536+_bodyBytes[103]*256+_bodyBytes[104], nil)
		binToModel(streams, "totalthermal10",  _bodyBytes[105]*16777216+_bodyBytes[106]*65536+_bodyBytes[107]*256+_bodyBytes[108], nil)

		binToModel(streams, "isheatrun11", _bodyBytes[109], BIT0)
		binToModel(streams, "iscoolrun11", _bodyBytes[109], BIT1)
		binToModel(streams, "isdhwrun11", _bodyBytes[109], BIT2)
		binToModel(streams, "istbhrun11", _bodyBytes[109], BIT3)
		binToModel(streams, "isibhrun11", _bodyBytes[109], BIT4)
		binToModel(streams, "totalelectricity11",_bodyBytes[110]*16777216+_bodyBytes[111]*65536+_bodyBytes[112]*256+_bodyBytes[113], nil)
		binToModel(streams, "totalthermal11",  _bodyBytes[114]*16777216+_bodyBytes[115]*65536+_bodyBytes[116]*256+_bodyBytes[117], nil)

		binToModel(streams, "isheatrun12", _bodyBytes[118], BIT0)
		binToModel(streams, "iscoolrun12", _bodyBytes[118], BIT1)
		binToModel(streams, "isdhwrun12", _bodyBytes[118], BIT2)
		binToModel(streams, "istbhrun12", _bodyBytes[118], BIT3)
		binToModel(streams, "isibhrun12", _bodyBytes[118], BIT4)
		binToModel(streams, "totalelectricity12", _bodyBytes[119]*16777216+_bodyBytes[120]*65536+_bodyBytes[121]*256+_bodyBytes[122], nil)
		binToModel(streams, "totalthermal12", _bodyBytes[123]*16777216+_bodyBytes[124]*65536+_bodyBytes[125]*256+_bodyBytes[126], nil)

		binToModel(streams, "isheatrun13", _bodyBytes[127], BIT0)
		binToModel(streams, "iscoolrun13", _bodyBytes[127], BIT1)
		binToModel(streams, "isdhwrun13", _bodyBytes[127], BIT2)
		binToModel(streams, "istbhrun13", _bodyBytes[127], BIT3)
		binToModel(streams, "isibhrun13", _bodyBytes[127], BIT4)
		binToModel(streams, "totalelectricity13", _bodyBytes[128]*16777216+_bodyBytes[129]*65536+_bodyBytes[130]*256+_bodyBytes[131], nil)
		binToModel(streams, "totalthermal13", _bodyBytes[132]*16777216+_bodyBytes[133]*65536+_bodyBytes[134]*256+_bodyBytes[135], nil)

		binToModel(streams, "isheatrun14", _bodyBytes[136], BIT0)
		binToModel(streams, "iscoolrun14", _bodyBytes[136], BIT1)
		binToModel(streams, "isdhwrun14", _bodyBytes[136], BIT2)
		binToModel(streams, "istbhrun14", _bodyBytes[136], BIT3)
		binToModel(streams, "isibhrun14", _bodyBytes[136], BIT4)
		binToModel(streams, "totalelectricity14", _bodyBytes[137]*16777216+_bodyBytes[138]*65536+_bodyBytes[139]*256+_bodyBytes[140], nil)
		binToModel(streams, "totalthermal14", _bodyBytes[141]*16777216+_bodyBytes[142]*65536+_bodyBytes[143]*256+_bodyBytes[144], nil)

		binToModel(streams, "isheatrun15", _bodyBytes[145], BIT0)
		binToModel(streams, "iscoolrun15", _bodyBytes[145], BIT1)
		binToModel(streams, "isdhwrun15", _bodyBytes[145], BIT2)
		binToModel(streams, "istbhrun15", _bodyBytes[145], BIT3)
		binToModel(streams, "isibhrun15", _bodyBytes[145], BIT4)
		binToModel(streams, "totalelectricity15", _bodyBytes[146]*16777216+_bodyBytes[147]*65536+_bodyBytes[148]*256+_bodyBytes[149], nil)
		binToModel(streams, "totalthermal15", _bodyBytes[150]*16777216+_bodyBytes[151]*65536+_bodyBytes[152]*256+_bodyBytes[153], nil)

		binToModel(streams, "isibh2run0", _bodyBytes[154], BIT0)
		binToModel(streams, "isibh2run1 ", _bodyBytes[154], BIT1)
		binToModel(streams, "isibh2run2 ", _bodyBytes[154], BIT2)
		binToModel(streams, "isibh2run3 ", _bodyBytes[154], BIT3)
		binToModel(streams, "isibh2run4 ", _bodyBytes[154], BIT4)
		binToModel(streams, "isibh2run5 ", _bodyBytes[154], BIT5)
		binToModel(streams, "isibh2run6 ", _bodyBytes[154], BIT6)
		binToModel(streams, "isibh2run7 ", _bodyBytes[154], BIT7)
		binToModel(streams, "isibh2run8 ", _bodyBytes[155], BIT0)
		binToModel(streams, "isibh2run9 ", _bodyBytes[155], BIT1)
		binToModel(streams, "isibh2run10 ", _bodyBytes[155], BIT2)
		binToModel(streams, "isibh2run11 ", _bodyBytes[155], BIT3)
		binToModel(streams, "isibh2run12 ", _bodyBytes[155], BIT4)
		binToModel(streams, "isibh2run13 ", _bodyBytes[155], BIT5)
		binToModel(streams, "isibh2run14 ", _bodyBytes[155], BIT6)
		binToModel(streams, "isibh2run15 ", _bodyBytes[155], BIT7)

		binToModel(streams, "voltage0", _bodyBytes[156], nil)
		binToModel(streams, "voltage1", _bodyBytes[157], nil)
		binToModel(streams, "voltage2", _bodyBytes[158], nil)
		binToModel(streams, "voltage3", _bodyBytes[159], nil)
		binToModel(streams, "voltage4", _bodyBytes[160], nil)
		binToModel(streams, "voltage5", _bodyBytes[161], nil)
		binToModel(streams, "voltage6", _bodyBytes[162], nil)
		binToModel(streams, "voltage7", _bodyBytes[163], nil)
		binToModel(streams, "voltage8", _bodyBytes[164], nil)
		binToModel(streams, "voltage9", _bodyBytes[165], nil)
		binToModel(streams, "voltage10", _bodyBytes[166], nil)
		binToModel(streams, "voltage11", _bodyBytes[167], nil)
		binToModel(streams, "voltage12", _bodyBytes[168], nil)
		binToModel(streams, "voltage13", _bodyBytes[169], nil)
		binToModel(streams, "voltage14", _bodyBytes[170], nil)
		binToModel(streams, "voltage15", _bodyBytes[171], nil)

		binToModel(streams, "power_ibh1", _bodyBytes[172], nil)
		binToModel(streams, "power_ibh2", _bodyBytes[173], nil)
		binToModel(streams, "power_tbh", _bodyBytes[174], nil)
	elseif ((_msgType==cmdTable["MSG_TYPE_QUERY"])   and (_msgBodyType==cmdTable["MSG_TYPE_QUERY_INSTALL"])) then
        -- 安装设定参数0x08查询
        binToModel(streams, "dhwEnable", _bodyBytes[1],BIT7)
        binToModel(streams, "boostertbhEn", _bodyBytes[1],BIT6)
        binToModel(streams, "disinfectEnable", _bodyBytes[1],BIT5)
        binToModel(streams, "dhwPumpEnable", _bodyBytes[1],BIT4)
        binToModel(streams, "dhwPriorityTime", _bodyBytes[1],BIT3)
        binToModel(streams, "dhwPumpDIEnable", _bodyBytes[1],BIT2)
        binToModel(streams, "coolEnable", _bodyBytes[1],BIT1)
        binToModel(streams, "fgZone1CoolTempHigh", _bodyBytes[1],BIT0)
        binToModel(streams, "heatEnable", _bodyBytes[2],BIT7)
        binToModel(streams, "fgZone1HeatTempHigh", _bodyBytes[2],BIT6)
        binToModel(streams, "pumpiSliModeEn", _bodyBytes[2],BIT5)
        binToModel(streams, "roomSensorEn", _bodyBytes[2],BIT4)
        binToModel(streams, "roomTherEn", _bodyBytes[2],BIT3)
        binToModel(streams, "roomTherSetModeEn", _bodyBytes[2],BIT2)
        binToModel(streams, "dualroomThermostatEn", _bodyBytes[2],BIT1)
        binToModel(streams, "fgdhwPriorEn", _bodyBytes[2],BIT0)
        binToModel(streams, "acsEnable", _bodyBytes[3],BIT7)
        binToModel(streams, "dhwHeaterAhsEn", _bodyBytes[3],BIT6)
        binToModel(streams, "tempPcbEn", _bodyBytes[3],BIT5)
        binToModel(streams, "tbt2ProbeEn", _bodyBytes[3],BIT4)
        binToModel(streams, "pipeExceed10m", _bodyBytes[3],BIT3)
        binToModel(streams, "solarCn18En", _bodyBytes[3],BIT2)
        binToModel(streams, "fgOwnSolarEn", _bodyBytes[3],BIT1)
        binToModel(streams, "fgInputDhwHeater", _bodyBytes[3],BIT0)
        binToModel(streams, "smartgridEn", _bodyBytes[4],BIT7)
        binToModel(streams, "t1bProbeEn", _bodyBytes[4],BIT6)
        binToModel(streams, "fgZone2CoolTempHigh", _bodyBytes[4],BIT5)
        binToModel(streams, "fgZone2HeatTempHigh", _bodyBytes[4],BIT4)
        binToModel(streams, "doubleZoneEn", _bodyBytes[4],BIT3)
        binToModel(streams, "fgTaProbeIdu", _bodyBytes[4],BIT2)
        binToModel(streams, "tbt1ProbeEn", _bodyBytes[4],BIT1)
        binToModel(streams, "fgIbhInTank", _bodyBytes[4],BIT0)
		binToModel(streams, "dT5On", _bodyBytes[6], nil)
        binToModel(streams, "dT5On", _bodyBytes[6], nil)
        binToModel(streams, "dT1S5", _bodyBytes[8], nil)
        binToModel(streams, "tIntervaDhw", _bodyBytes[10], nil)
        binToModel(streams, "t4Dhwmax", _bodyBytes[12], nil)
        binToModel(streams, "t4Dhwmin", _bodyBytes[13]* 256+_bodyBytes[14], nil)
        binToModel(streams, "tTBHdelay", _bodyBytes[15]* 256+_bodyBytes[16], nil)
        binToModel(streams, "dT5STBHoff", _bodyBytes[17]* 256+_bodyBytes[18], nil)
        binToModel(streams, "t4TBHon", _bodyBytes[19]* 256+_bodyBytes[20], nil)
        binToModel(streams, "t5sDI", _bodyBytes[21]* 256+_bodyBytes[22], nil)
        binToModel(streams, "tDImax", _bodyBytes[23]* 256+_bodyBytes[24], nil)
        binToModel(streams, "tDIhightemp", _bodyBytes[25]* 256+_bodyBytes[26], nil)
        binToModel(streams, "tIntervalC", _bodyBytes[27]* 256+_bodyBytes[28], nil)
        binToModel(streams, "dT1SC", _bodyBytes[29]* 256+_bodyBytes[30], nil)
        binToModel(streams, "dTSC", _bodyBytes[31]* 256+_bodyBytes[32], nil)
        binToModel(streams, "t4Cmax", _bodyBytes[33]* 256+_bodyBytes[34], nil)
        binToModel(streams, "t4Cmin", _bodyBytes[35]* 256+_bodyBytes[36], nil)
        binToModel(streams, "tIntervalH", _bodyBytes[37]* 256+_bodyBytes[38], nil)
        binToModel(streams, "dT1SH", _bodyBytes[39]* 256+_bodyBytes[40], nil)
        binToModel(streams, "dTSH", _bodyBytes[41]* 256+_bodyBytes[42], nil)
        binToModel(streams, "t4Hmax", _bodyBytes[43]* 256+_bodyBytes[44], nil)
        binToModel(streams, "t4Hmin", _bodyBytes[45]* 256+_bodyBytes[46], nil)
        binToModel(streams, "t4IBHon", _bodyBytes[47]* 256+_bodyBytes[48], nil)
        binToModel(streams, "dT1IBHon", _bodyBytes[49]* 256+_bodyBytes[50], nil)
        binToModel(streams, "tIBHdelay", _bodyBytes[51]* 256+_bodyBytes[52], nil)
        binToModel(streams, "tIBH12delay", _bodyBytes[53]* 256+_bodyBytes[54], nil)
        binToModel(streams, "t4AHSon", _bodyBytes[55]* 256+_bodyBytes[56], nil)
        binToModel(streams, "dT1AHSon", _bodyBytes[57]* 256+_bodyBytes[58], nil)
        binToModel(streams, "dT1AHSoff", _bodyBytes[59]* 256+_bodyBytes[60], nil)
        binToModel(streams, "tAHSdelay", _bodyBytes[61]* 256+_bodyBytes[62], nil)
        binToModel(streams, "tDHWHPmax", _bodyBytes[63]* 256+_bodyBytes[64], nil)
        binToModel(streams, "tDHWHPrestrict", _bodyBytes[65]* 256+_bodyBytes[66], nil)
        binToModel(streams, "t4autocmin", _bodyBytes[67]* 256+_bodyBytes[68], nil)
        binToModel(streams, "t4autohmax", _bodyBytes[69]* 256+_bodyBytes[70], nil)
        binToModel(streams, "t1sHolHeat", _bodyBytes[71]* 256+_bodyBytes[72], nil)
        binToModel(streams, "t5SHolDhw", _bodyBytes[73]* 256+_bodyBytes[74], nil)
        binToModel(streams, "perStart", _bodyBytes[75]* 256+_bodyBytes[76], nil)
        binToModel(streams, "timeAdjust", _bodyBytes[77]* 256+_bodyBytes[78], nil)
        binToModel(streams, "dTbt2", _bodyBytes[79]* 256+_bodyBytes[80], nil)
        binToModel(streams, "powerIbh1", (_bodyBytes[81]* 256+_bodyBytes[82])/10, nil)
        binToModel(streams, "powerIbh2", (_bodyBytes[83]* 256+_bodyBytes[84])/10, nil)
        binToModel(streams, "powerTbh", (_bodyBytes[85]* 256+_bodyBytes[86])/10, nil)
        binToModel(streams, "ecoHeatT1s", _bodyBytes[87]* 256+_bodyBytes[88], nil)
        binToModel(streams, "ecoHeatTs", _bodyBytes[89]* 256+_bodyBytes[90], nil)
        binToModel(streams, "tDryup", _bodyBytes[91]* 256+_bodyBytes[92], nil)
        binToModel(streams, "tDrypeak", _bodyBytes[93]* 256+_bodyBytes[94], nil)
        binToModel(streams, "tdrydown", _bodyBytes[95]* 256+_bodyBytes[96], nil)
        binToModel(streams, "tempDrypeak", _bodyBytes[97]* 256+_bodyBytes[98], nil)
        binToModel(streams, "timePreheatFloor", _bodyBytes[99]* 256+_bodyBytes[100], nil)
        binToModel(streams, "t1SPreheatFloor", _bodyBytes[101]* 256+_bodyBytes[102], nil)
        --103~112为空
        binToModel(streams, "t1SetC1", _bodyBytes[113]* 256+_bodyBytes[114], nil)
        binToModel(streams, "t1SetC2", _bodyBytes[115]* 256+_bodyBytes[116], nil)
        binToModel(streams, "t4C1", _bodyBytes[117]* 256+_bodyBytes[118], nil)
        binToModel(streams, "t4C2", _bodyBytes[119]* 256+_bodyBytes[120], nil)
        binToModel(streams, "t1SetH1", _bodyBytes[121]* 256+_bodyBytes[122], nil)
        binToModel(streams, "t1SetH2", _bodyBytes[123]* 256+_bodyBytes[124], nil)
        binToModel(streams, "t4H1", _bodyBytes[125]* 256+_bodyBytes[126], nil)
        binToModel(streams, "t4H2", _bodyBytes[127]* 256+_bodyBytes[128], nil)
        binToModel(streams, "typeVolLmt", _bodyBytes[129]* 256+_bodyBytes[130], nil)
        binToModel(streams, "timeT4FreshC", _bodyBytes[131]/2, nil)
        binToModel(streams, "timeT4FreshH", _bodyBytes[132]/2, nil)
        binToModel(streams, "tPumpiDelay", (_bodyBytes[133]* 256+_bodyBytes[134])/2, nil)
        binToModel(streams, "deltaTsloar", _bodyBytes[135], nil)
        binToModel(streams, "solarFunction", _bodyBytes[136], nil)
        binToModel(streams, "enSwitchPDC", _bodyBytes[138],BIT0)
        binToModel(streams, "gasCost", (_bodyBytes[139]* 256+_bodyBytes[140])/100, nil)
        binToModel(streams, "eleCost", (_bodyBytes[141]* 256+_bodyBytes[142])/100, nil)
        binToModel(streams, "ahsSetTempMax", _bodyBytes[143], nil)
        binToModel(streams, "ahsSetTempMin", _bodyBytes[144], nil)
        binToModel(streams, "ahsSetTempMaxVolt", _bodyBytes[145], nil)
        binToModel(streams, "ahsSetTempMinVolt", _bodyBytes[146], nil)
        binToModel(streams, "t2AntiSVRun", _bodyBytes[147]* 256+_bodyBytes[148], nil)
        binToModel(streams, "dftPortFuncEn", _bodyBytes[150],BIT0)
		--_bodyBytes[150]~_bodyBytes[180]预留
		binToModel(streams, "t1AntiPump", _bodyBytes[181]* 256+_bodyBytes[182], nil)
		binToModel(streams, "t2AntiPumpRun", _bodyBytes[183]* 256+_bodyBytes[184], nil)
		binToModel(streams, "t1AntiLockSV", _bodyBytes[185]* 256+_bodyBytes[186], nil)
		binToModel(streams, "tbhEnFunc", _bodyBytes[187]* 256+_bodyBytes[188], nil)
		binToModel(streams, "ibhEnFunc", _bodyBytes[189]* 256+_bodyBytes[190], nil)
		--binToModel(streams, "", _bodyBytes[191]* 256+_bodyBytes[192], nil)
		binToModel(streams, "ahsEnFunc", _bodyBytes[193]* 256+_bodyBytes[194], nil)
		binToModel(streams, "ahsPumpiControl", _bodyBytes[195]* 256+_bodyBytes[196], nil)
		binToModel(streams, "modeSetPri", _bodyBytes[197]* 256+_bodyBytes[198], nil)
		binToModel(streams, "pumpType", _bodyBytes[199]* 256+_bodyBytes[200], nil)
		binToModel(streams, "pumpiSilentOutput", _bodyBytes[201]* 256+_bodyBytes[202], nil)
    elseif ((_msgType==cmdTable["MSG_TYPE_QUERY"])   and (_msgBodyType==cmdTable["MSG_TYPE_QUERY_HMIPARA"])) then
        binToModel(streams, "hmiVersionNum", _bodyBytes[1], nil)
        binToModel(streams, "compRunCurTime0", _bodyBytes[2]* 256+_bodyBytes[3], nil)
        binToModel(streams, "compRunTotalTime0", _bodyBytes[4]* 256+_bodyBytes[5], nil)
        binToModel(streams, "fanRunTotalTime0", _bodyBytes[6]* 256+_bodyBytes[7], nil)
        binToModel(streams, "pumpiRunTotalTime0", _bodyBytes[8]* 256+_bodyBytes[9], nil)
        binToModel(streams, "ibh1RunTotalTime0", _bodyBytes[10]* 256+_bodyBytes[11], nil)
        binToModel(streams, "ibh2RunTotalTime0", _bodyBytes[12]* 256+_bodyBytes[13], nil)
        binToModel(streams, "tbhRunTotalTime0", _bodyBytes[14]* 256+_bodyBytes[15], nil)
        binToModel(streams, "ahsRunTotalTime0", _bodyBytes[16]* 256+_bodyBytes[17], nil)
        binToModel(streams, "arrayServiceTel0", _bodyBytes[18], nil)
        binToModel(streams, "arrayServiceTel1", _bodyBytes[19], nil)
        binToModel(streams, "arrayServiceTel2", _bodyBytes[20], nil)
        binToModel(streams, "arrayServiceTel3", _bodyBytes[21], nil)
        binToModel(streams, "arrayServiceTel4", _bodyBytes[22], nil)
        binToModel(streams, "arrayServiceTel5", _bodyBytes[23], nil)
        binToModel(streams, "arrayServiceTel6", _bodyBytes[24], nil)
        binToModel(streams, "arrayServiceTel7", _bodyBytes[25], nil)
        binToModel(streams, "arrayServiceTel8", _bodyBytes[26], nil)
        binToModel(streams, "arrayServiceTel9", _bodyBytes[27], nil)
        binToModel(streams, "arrayServiceTel10", _bodyBytes[28], nil)
        binToModel(streams, "arrayServiceTel11", _bodyBytes[29], nil)
        binToModel(streams, "arrayServiceTel12", _bodyBytes[30], nil)
        binToModel(streams, "ArrayServiceCel0", _bodyBytes[31], nil)
        binToModel(streams, "ArrayServiceCel1", _bodyBytes[32], nil)
        binToModel(streams, "ArrayServiceCel2", _bodyBytes[33], nil)
        binToModel(streams, "ArrayServiceCel3", _bodyBytes[34], nil)
        binToModel(streams, "ArrayServiceCel4", _bodyBytes[35], nil)
        binToModel(streams, "ArrayServiceCel5", _bodyBytes[36], nil)
        binToModel(streams, "ArrayServiceCel6", _bodyBytes[37], nil)
        binToModel(streams, "ArrayServiceCel7", _bodyBytes[38], nil)
        binToModel(streams, "ArrayServiceCel8", _bodyBytes[39], nil)
        binToModel(streams, "ArrayServiceCel9", _bodyBytes[40], nil)
        binToModel(streams, "ArrayServiceCel10", _bodyBytes[41], nil)
        binToModel(streams, "ArrayServiceCel11", _bodyBytes[42], nil)
        binToModel(streams, "ArrayServiceCel12", _bodyBytes[43], nil)
        binToModel(streams, "u8warnTotal", _bodyBytes[44], nil)
        binToModel(streams, "codeErrProt1", _bodyBytes[45], nil)
        binToModel(streams, "warnAddress1", _bodyBytes[46], nil)
        binToModel(streams, "warnHour1", _bodyBytes[47], nil)
        binToModel(streams, "warnMin1", _bodyBytes[48], nil)
        binToModel(streams, "warnYear1", _bodyBytes[49], nil)
        binToModel(streams, "warnMonth1", _bodyBytes[50], nil)
        binToModel(streams, "warnDate1", _bodyBytes[51], nil)
        binToModel(streams, "codeErrProt2", _bodyBytes[52], nil)
        binToModel(streams, "warnAddress2", _bodyBytes[53], nil)
        binToModel(streams, "warnHour2", _bodyBytes[54], nil)
        binToModel(streams, "warnMin2", _bodyBytes[55], nil)
        binToModel(streams, "warnYear2", _bodyBytes[56], nil)
        binToModel(streams, "warnMonth2", _bodyBytes[57], nil)
        binToModel(streams, "warnDate2", _bodyBytes[58], nil)
        binToModel(streams, "codeErrProt3", _bodyBytes[59], nil)
        binToModel(streams, "warnAddress3", _bodyBytes[60], nil)
        binToModel(streams, "warnHour3", _bodyBytes[61], nil)
        binToModel(streams, "warnMin3", _bodyBytes[62], nil)
        binToModel(streams, "warnYear3", _bodyBytes[63], nil)
        binToModel(streams, "warnMonth3", _bodyBytes[64], nil)
        binToModel(streams, "warnDate3", _bodyBytes[65], nil)
        binToModel(streams, "codeErrProt4", _bodyBytes[66], nil)
        binToModel(streams, "warnAddress4", _bodyBytes[67], nil)
        binToModel(streams, "warnHour4", _bodyBytes[68], nil)
        binToModel(streams, "warnMin4", _bodyBytes[69], nil)
        binToModel(streams, "warnYear4", _bodyBytes[70], nil)
        binToModel(streams, "warnMonth4", _bodyBytes[71], nil)
        binToModel(streams, "warnDate4", _bodyBytes[72], nil)
        binToModel(streams, "codeErrProt5", _bodyBytes[73], nil)
        binToModel(streams, "warnAddress5", _bodyBytes[74], nil)
        binToModel(streams, "warnHour5", _bodyBytes[75], nil)
        binToModel(streams, "warnMin5", _bodyBytes[76], nil)
        binToModel(streams, "warnYear5", _bodyBytes[77], nil)
        binToModel(streams, "warnMonth5", _bodyBytes[78], nil)
        binToModel(streams, "warnDate5", _bodyBytes[79], nil)
        binToModel(streams, "codeErrProt6", _bodyBytes[80], nil)
        binToModel(streams, "warnAddress6", _bodyBytes[81], nil)
        binToModel(streams, "warnHour6", _bodyBytes[82], nil)
        binToModel(streams, "warnMin6", _bodyBytes[83], nil)
        binToModel(streams, "warnYear6", _bodyBytes[84], nil)
        binToModel(streams, "warnMonth6", _bodyBytes[85], nil)
        binToModel(streams, "warnDate6", _bodyBytes[86], nil)
        binToModel(streams, "codeErrProt7", _bodyBytes[87], nil)
        binToModel(streams, "warnAddress7", _bodyBytes[88], nil)
        binToModel(streams, "warnHour7", _bodyBytes[89], nil)
        binToModel(streams, "warnMin7", _bodyBytes[90], nil)
        binToModel(streams, "warnYear7", _bodyBytes[91], nil)
        binToModel(streams, "warnMonth7", _bodyBytes[92], nil)
        binToModel(streams, "warnDate7", _bodyBytes[93], nil)
        binToModel(streams, "codeErrProt8", _bodyBytes[94], nil)
        binToModel(streams, "warnAddress8", _bodyBytes[95], nil)
        binToModel(streams, "warnHour8", _bodyBytes[96], nil)
        binToModel(streams, "warnMin8", _bodyBytes[97], nil)
        binToModel(streams, "warnYear8", _bodyBytes[98], nil)
        binToModel(streams, "warnMonth8", _bodyBytes[99], nil)
        binToModel(streams, "warnDate8", _bodyBytes[100], nil)

	elseif ((_msgType==cmdTable["MSG_TYPE_QUERY"])   and (_msgBodyType==cmdTable["MSG_TYPE_QUERY_UNITPARA"])) then
        -- 主机运行参数0x10查询
		binToModel(streams, "compRunFreq", _bodyBytes[1], nil)
		binToModel(streams, "unitModeRun", _bodyBytes[2], nil)
		binToModel(streams, "fanSpeed", _bodyBytes[3]*10, nil)
        binToModel(streams, "machVersion", _bodyBytes[4], nil)
		binToModel(streams, "fgCapacityNeed", _bodyBytes[5], nil)
		--binToModel(streams, "tempset", _bodyBytes[6], nil)
		binToModel(streams, "tempT3", _bodyBytes[7], nil)
		binToModel(streams, "tempT4", _bodyBytes[8], nil)
		binToModel(streams, "tempTp", _bodyBytes[9], nil)
		binToModel(streams, "tempTwin", _bodyBytes[10], nil)
		binToModel(streams, "tempTwout", _bodyBytes[11], nil)
		binToModel(streams, "tempTsolar", _bodyBytes[12], nil)
		binToModel(streams, "hydboxSubtype", _bodyBytes[13], nil)
		binToModel(streams, "fgUSBInfoConnect", _bodyBytes[14], nil)
		binToModel(streams, "usbIndexMax", _bodyBytes[15], nil)
		binToModel(streams, "p6ErrCode", _bodyBytes[16], nil)
		binToModel(streams, "oduCompCurrent", _bodyBytes[17], nil)
		binToModel(streams, "oduVoltage", _bodyBytes[18] * 256 +  _bodyBytes[19], nil)
		binToModel(streams, "exvCurrent", _bodyBytes[20] * 256 +  _bodyBytes[21], nil)
		binToModel(streams, "oduModel", _bodyBytes[22], nil)
		binToModel(streams, "unitonlineNum", _bodyBytes[23], nil)
		binToModel(streams, "currentCode", _bodyBytes[24], nil)
		binToModel(streams, "u8Code1", _bodyBytes[25], nil)
		binToModel(streams, "u8Code2", _bodyBytes[26], nil)
		binToModel(streams, "u8Code3", _bodyBytes[27], nil)
		binToModel(streams, "fgReqParaSet", _bodyBytes[28],BIT7)
		binToModel(streams, "fgReqVerAsk", _bodyBytes[28],BIT6)
		binToModel(streams, "fgReqSNAsk", _bodyBytes[28],BIT5)
		binToModel(streams, "fgUnitLockSignal", _bodyBytes[28],BIT4)
		binToModel(streams, "fgEVUSignal", _bodyBytes[28],BIT3)
		binToModel(streams, "fgSGSignal", _bodyBytes[28],BIT2)
		binToModel(streams, "fgTankAntiFreeze", _bodyBytes[28],BIT1)
		binToModel(streams, "fgSolarInput", _bodyBytes[28],BIT0)
		binToModel(streams, "fgRoomTherCoolRun", _bodyBytes[29],BIT7)
		binToModel(streams, "fgRoomTherHeatRun", _bodyBytes[29],BIT6)
		binToModel(streams, "fgOutDoorTestMode", _bodyBytes[29],BIT5)
		binToModel(streams, "fgRemoteOnOff", _bodyBytes[29],BIT4)
		binToModel(streams, "fgBackOil", _bodyBytes[29],BIT3)
		binToModel(streams, "fgAntiFreezeRun", _bodyBytes[29],BIT2)
		binToModel(streams, "fgDefrost", _bodyBytes[29],BIT1)
		binToModel(streams, "fgIsSlaveUnit", _bodyBytes[29],BIT0)
		binToModel(streams, "fgTBHEnable", _bodyBytes[30],BIT7)
		binToModel(streams, "fgAHSIsOwn", _bodyBytes[30],BIT6)
		binToModel(streams, "fgCapTestEnable", _bodyBytes[30],BIT5)
		binToModel(streams, "fgT1BSensorEnable", _bodyBytes[30],BIT4)
		binToModel(streams, "fgAHSDHWMode", _bodyBytes[30],BIT3)
		binToModel(streams, "fgIBH1Enable", _bodyBytes[30],BIT2)
		binToModel(streams, "fgT1SensorEnable", _bodyBytes[30],BIT1)
		--binToModel(streams, "", _bodyBytes[30],BIT0)
		binToModel(streams, "fgEdgeVersionType", _bodyBytes[31],BIT7)
		binToModel(streams, "fgFactReqTherHeatOn", _bodyBytes[31],BIT6)
		binToModel(streams, "fgDHWRun", _bodyBytes[31],BIT5)
		binToModel(streams, "fgHeatRun", _bodyBytes[31],BIT4)
		binToModel(streams, "fgCoolRun", _bodyBytes[31],BIT3)
		binToModel(streams, "fgFactReqTherCoolOn", _bodyBytes[31],BIT2)
		binToModel(streams, "fgFactReqSolarOn", _bodyBytes[31],BIT1)
		binToModel(streams, "fgFactoryRun", _bodyBytes[30],BIT0)
		binToModel(streams, "fgDefValveOn", _bodyBytes[32],BIT7)
		binToModel(streams, "fgAHSValveOn", _bodyBytes[32],BIT6)
		binToModel(streams, "fgRunValveOn", _bodyBytes[32],BIT5)
		binToModel(streams, "fgAlmValveOn", _bodyBytes[32],BIT4)
		binToModel(streams, "fgPumpSolarOn", _bodyBytes[32],BIT3)
		binToModel(streams, "fgHeat4ValveOn", _bodyBytes[32],BIT2)
		binToModel(streams, "fgSV3Output", _bodyBytes[32],BIT1)
		binToModel(streams, "fgMixedPumpValveOn", _bodyBytes[32],BIT0)
		binToModel(streams, "fgPumpDHWOn", _bodyBytes[33],BIT7)
		binToModel(streams, "fgPumpOOn", _bodyBytes[33],BIT6)
		binToModel(streams, "fgSV2On", _bodyBytes[33],BIT5)
		binToModel(streams, "fgSV1On", _bodyBytes[33],BIT4)
		binToModel(streams, "fgPumpIOutput", _bodyBytes[33],BIT3)
		binToModel(streams, "fgTBHOutput", _bodyBytes[33],BIT2)
		binToModel(streams, "fgIBH2Output", _bodyBytes[33],BIT1)
		binToModel(streams, "fgIBH1Output", _bodyBytes[33],BIT0)
		binToModel(streams, "tempT1", _bodyBytes[34], nil)
		binToModel(streams, "tempTw2", _bodyBytes[35], nil)
		binToModel(streams, "tempT2", _bodyBytes[36], nil)
		binToModel(streams, "tempT2b", _bodyBytes[37], nil)
		binToModel(streams, "tempT5", _bodyBytes[38], nil)
		binToModel(streams, "tempTa", _bodyBytes[39], nil)
		binToModel(streams, "tempTbt1", _bodyBytes[40], nil)
		binToModel(streams, "tempTbt2", _bodyBytes[41], nil)
		binToModel(streams, "hydroboxCapacity", _bodyBytes[42], nil)
		binToModel(streams, "pressureHigh", _bodyBytes[43] * 256 +  _bodyBytes[44], nil)

		binToModel(streams, "pressureLow", _bodyBytes[45] * 256 +  _bodyBytes[46], nil)

		binToModel(streams, "tempTh", _bodyBytes[47], nil)
		binToModel(streams, "machineType", _bodyBytes[48], nil)
		binToModel(streams, "oduTargetFre", _bodyBytes[49], nil)
		binToModel(streams, "dcCurrent", _bodyBytes[50], nil)
		binToModel(streams, "dcVoltage", _bodyBytes[51], nil)
		binToModel(streams, "tempTf", _bodyBytes[52], nil)
		binToModel(streams, "iduT1s1", _bodyBytes[53], nil)
		binToModel(streams, "iduT1s2", _bodyBytes[54], nil)
		binToModel(streams, "waterFlow", _bodyBytes[55] * 256 +  _bodyBytes[56], nil)

		binToModel(streams, "oduPlanVolLmt", _bodyBytes[57], nil)
		binToModel(streams, "currentUnitCapacity", _bodyBytes[58] * 256 +  _bodyBytes[59], nil)

		binToModel(streams, "spheraAHSVoltage", _bodyBytes[60], nil)
		binToModel(streams, "tempT4Aver", _bodyBytes[61], nil)
		binToModel(streams, "waterPressure", _bodyBytes[62] * 256 +  _bodyBytes[63], nil)

		binToModel(streams, "roomRelHum", _bodyBytes[64], nil)
		binToModel(streams, "pwmPumpOut", _bodyBytes[65], nil)
		--66预留
		binToModel(streams, "totalelectricity0", _bodyBytes[67]* 16777216 +_bodyBytes[68]* 65536 +_bodyBytes[69]*256 +_bodyBytes[70], nil)

		binToModel(streams, "totalthermal0", _bodyBytes[71]* 16777216 +_bodyBytes[72]* 65536 +_bodyBytes[73]*256 +_bodyBytes[74], nil)

		binToModel(streams, "heatElecTotConsum0", _bodyBytes[75]* 16777216 +_bodyBytes[76]* 65536 +_bodyBytes[77]*256 +_bodyBytes[78], nil)

		binToModel(streams, "heatTotCapacity0", _bodyBytes[79]* 16777216 +_bodyBytes[80]* 65536 +_bodyBytes[81]*256 +_bodyBytes[82], nil)

		binToModel(streams, "instantPower0", _bodyBytes[83] * 256 +  _bodyBytes[84], nil)

		binToModel(streams, "instantRenewPower0", _bodyBytes[85] * 256 +  _bodyBytes[86], nil)

		binToModel(streams, "totalRenewPower0", _bodyBytes[87]* 16777216 +_bodyBytes[88]* 65536 +_bodyBytes[89]*256 +_bodyBytes[90], nil)
		--91-93预留
		binToModel(streams, "iduVersionNum", _bodyBytes[94], nil)
		binToModel(streams, "oduVersionNum", _bodyBytes[95], nil)
		--iduSNCode0
		binToModel(streams, "iduSNCode0", _bodyBytes[96], nil)
		binToModel(streams, "iduSNCode1", _bodyBytes[97], nil)
		binToModel(streams, "iduSNCode2", _bodyBytes[98], nil)
		binToModel(streams, "iduSNCode3", _bodyBytes[99], nil)
		binToModel(streams, "iduSNCode4", _bodyBytes[100], nil)
		binToModel(streams, "iduSNCode5", _bodyBytes[101], nil)
		binToModel(streams, "iduSNCode6", _bodyBytes[102], nil)
		binToModel(streams, "iduSNCode7", _bodyBytes[103], nil)
		binToModel(streams, "iduSNCode8", _bodyBytes[104], nil)
		binToModel(streams, "iduSNCode9", _bodyBytes[105], nil)
		binToModel(streams, "iduSNCode10", _bodyBytes[106], nil)
		binToModel(streams, "iduSNCode11", _bodyBytes[107], nil)
		binToModel(streams, "iduSNCode12", _bodyBytes[108], nil)
		binToModel(streams, "iduSNCode13", _bodyBytes[109], nil)
		binToModel(streams, "iduSNCode14", _bodyBytes[110], nil)
		binToModel(streams, "iduSNCode15", _bodyBytes[111], nil)
		binToModel(streams, "iduSNCode16", _bodyBytes[112], nil)
		binToModel(streams, "iduSNCode17", _bodyBytes[113], nil)
		binToModel(streams, "iduSNCode18", _bodyBytes[114], nil)
		binToModel(streams, "iduSNCode19", _bodyBytes[115], nil)
		binToModel(streams, "iduSNCode20", _bodyBytes[116], nil)
		binToModel(streams, "iduSNCode21", _bodyBytes[117], nil)
		binToModel(streams, "iduSNCode22", _bodyBytes[118], nil)
		binToModel(streams, "iduSNCode23", _bodyBytes[119], nil)
		binToModel(streams, "iduSNCode24", _bodyBytes[120], nil)
		binToModel(streams, "iduSNCode25", _bodyBytes[121], nil)
		binToModel(streams, "iduSNCode26", _bodyBytes[122], nil)
		binToModel(streams, "iduSNCode27", _bodyBytes[123], nil)
		binToModel(streams, "iduSNCode28", _bodyBytes[124], nil)
		binToModel(streams, "iduSNCode29", _bodyBytes[125], nil)
		binToModel(streams, "iduSNCode30", _bodyBytes[126], nil)
		binToModel(streams, "iduSNCode31", _bodyBytes[127], nil)
		--oduSNCode0
		binToModel(streams, "oduSNCode0", _bodyBytes[128], nil)
		binToModel(streams, "oduSNCode1", _bodyBytes[129], nil)
		binToModel(streams, "oduSNCode2", _bodyBytes[130], nil)
		binToModel(streams, "oduSNCode3", _bodyBytes[131], nil)
		binToModel(streams, "oduSNCode4", _bodyBytes[132], nil)
		binToModel(streams, "oduSNCode5", _bodyBytes[133], nil)
		binToModel(streams, "oduSNCode6", _bodyBytes[134], nil)
		binToModel(streams, "oduSNCode7", _bodyBytes[135], nil)
		binToModel(streams, "oduSNCode8", _bodyBytes[136], nil)
		binToModel(streams, "oduSNCode9", _bodyBytes[137], nil)
		binToModel(streams, "oduSNCode10", _bodyBytes[138], nil)
		binToModel(streams, "oduSNCode11", _bodyBytes[139], nil)
		binToModel(streams, "oduSNCode12", _bodyBytes[140], nil)
		binToModel(streams, "oduSNCode13", _bodyBytes[141], nil)
		binToModel(streams, "oduSNCode14", _bodyBytes[142], nil)
		binToModel(streams, "oduSNCode15", _bodyBytes[143], nil)
		binToModel(streams, "oduSNCode16", _bodyBytes[144], nil)
		binToModel(streams, "oduSNCode17", _bodyBytes[145], nil)
		binToModel(streams, "oduSNCode18", _bodyBytes[146], nil)
		binToModel(streams, "oduSNCode19", _bodyBytes[147], nil)
		binToModel(streams, "oduSNCode20", _bodyBytes[148], nil)
		binToModel(streams, "oduSNCode21", _bodyBytes[149], nil)
		binToModel(streams, "oduSNCode22", _bodyBytes[150], nil)
		binToModel(streams, "oduSNCode23", _bodyBytes[151], nil)
		binToModel(streams, "oduSNCode24", _bodyBytes[152], nil)
		binToModel(streams, "oduSNCode25", _bodyBytes[153], nil)
		binToModel(streams, "oduSNCode26", _bodyBytes[154], nil)
		binToModel(streams, "oduSNCode27", _bodyBytes[155], nil)
		binToModel(streams, "oduSNCode28", _bodyBytes[156], nil)
		binToModel(streams, "oduSNCode29", _bodyBytes[157], nil)
		binToModel(streams, "oduSNCode30", _bodyBytes[158], nil)
		binToModel(streams, "oduSNCode31", _bodyBytes[159], nil)
		--hmiSNCode0
		binToModel(streams, "hmiSNCode0", _bodyBytes[160], nil)
		binToModel(streams, "hmiSNCode1", _bodyBytes[161], nil)
		binToModel(streams, "hmiSNCode2", _bodyBytes[162], nil)
		binToModel(streams, "hmiSNCode3", _bodyBytes[163], nil)
		binToModel(streams, "hmiSNCode4", _bodyBytes[164], nil)
		binToModel(streams, "hmiSNCode5", _bodyBytes[165], nil)
		binToModel(streams, "hmiSNCode6", _bodyBytes[166], nil)
		binToModel(streams, "hmiSNCode7", _bodyBytes[167], nil)
		binToModel(streams, "hmiSNCode8", _bodyBytes[168], nil)
		binToModel(streams, "hmiSNCode9", _bodyBytes[169], nil)
		binToModel(streams, "hmiSNCode10", _bodyBytes[170], nil)
		binToModel(streams, "hmiSNCode11", _bodyBytes[171], nil)
		binToModel(streams, "hmiSNCode12", _bodyBytes[172], nil)
		binToModel(streams, "hmiSNCode13", _bodyBytes[173], nil)
		binToModel(streams, "hmiSNCode14", _bodyBytes[174], nil)
		binToModel(streams, "hmiSNCode15", _bodyBytes[175], nil)
		binToModel(streams, "hmiSNCode16", _bodyBytes[176], nil)
		binToModel(streams, "hmiSNCode17", _bodyBytes[177], nil)
		binToModel(streams, "hmiSNCode18", _bodyBytes[178], nil)
		binToModel(streams, "hmiSNCode19", _bodyBytes[179], nil)
		binToModel(streams, "hmiSNCode20", _bodyBytes[180], nil)
		binToModel(streams, "hmiSNCode21", _bodyBytes[181], nil)
		binToModel(streams, "hmiSNCode22", _bodyBytes[182], nil)
		binToModel(streams, "hmiSNCode23", _bodyBytes[183], nil)
		binToModel(streams, "hmiSNCode24", _bodyBytes[184], nil)
		binToModel(streams, "hmiSNCode25", _bodyBytes[185], nil)
		binToModel(streams, "hmiSNCode26", _bodyBytes[186], nil)
		binToModel(streams, "hmiSNCode27", _bodyBytes[187], nil)
		binToModel(streams, "hmiSNCode28", _bodyBytes[188], nil)
		binToModel(streams, "hmiSNCode29", _bodyBytes[189], nil)
		binToModel(streams, "hmiSNCode30", _bodyBytes[190], nil)
		binToModel(streams, "hmiSNCode31", _bodyBytes[191], nil)

    elseif ((_msgType==cmdTable["MSG_TYPE_UP"])  and (_msgBodyType==cmdTable["MSG_TYPE_UP_UNITPARA"]) ) then
        binToModel(streams, "msg_up_type", cmdTable["MSG_TYPE_UP_UNITPARA"],nil)
		binToModel(streams, "compRunFreq", _bodyBytes[1], nil)
		binToModel(streams, "fanSpeed", _bodyBytes[2]*10, nil)
		binToModel(streams, "tempT3", _bodyBytes[3], nil)
		binToModel(streams, "tempT4", _bodyBytes[4], nil)
		binToModel(streams, "tempTp", _bodyBytes[5], nil)
		binToModel(streams, "tempTwin", _bodyBytes[6], nil)
		binToModel(streams, "tempTwout", _bodyBytes[7], nil)
		binToModel(streams, "oduCompCurrent", _bodyBytes[8], nil)
		binToModel(streams, "oduVoltage", _bodyBytes[9] * 256 +  _bodyBytes[10], nil)
		binToModel(streams, "tempT1", _bodyBytes[11], nil)
		binToModel(streams, "tempTw2", _bodyBytes[12], nil)
		binToModel(streams, "tempT2", _bodyBytes[13], nil)
		binToModel(streams, "tempT2b", _bodyBytes[14], nil)
		binToModel(streams, "tempT5", _bodyBytes[15], nil)
		binToModel(streams, "tempTa", _bodyBytes[16], nil)
		binToModel(streams, "pressureHigh", _bodyBytes[17] * 256 +  _bodyBytes[18], nil)
		binToModel(streams, "pressureLow", _bodyBytes[19] * 256 +  _bodyBytes[20], nil)		
		binToModel(streams, "tempTh", _bodyBytes[21], nil)
		binToModel(streams, "oduTargetFre", _bodyBytes[22], nil)
		binToModel(streams, "tempTf", _bodyBytes[23], nil)
		binToModel(streams, "iduT1s1", _bodyBytes[24], nil)
		binToModel(streams, "iduT1s2", _bodyBytes[25], nil)
		binToModel(streams, "waterFlow", _bodyBytes[26] * 256 +  _bodyBytes[27], nil)		
		binToModel(streams, "currentUnitCapacity", _bodyBytes[28] * 256 +  _bodyBytes[29], nil)		
		binToModel(streams, "waterPressure", _bodyBytes[30] * 256 +  _bodyBytes[31], nil)		
		binToModel(streams, "roomRelHum", _bodyBytes[32], nil)
		binToModel(streams, "totalelectricity0", _bodyBytes[33] * 16777216 +  _bodyBytes[34]  *  65536 +  _bodyBytes[35] * 256 +  _bodyBytes[36], nil)						
		binToModel(streams, "totalthermal0", _bodyBytes[37] * 16777216 +  _bodyBytes[38]  *  65536 +  _bodyBytes[39] * 256 +  _bodyBytes[40], nil)
		--binToModel(streams, "heatElecTotConsum0", _bodyBytes[41] * 16777216 +  _bodyBytes[42]  *  65536 +  _bodyBytes[43] * 256 +  _bodyBytes[44], nil)
		--binToModel(streams, "heatTotCapacity0", _bodyBytes[45] * 16777216 +  _bodyBytes[46]  *  65536 +  _bodyBytes[47] * 256 +  _bodyBytes[48], nil)
        binToModel(streams, "SysHeatDayCapacity", _bodyBytes[41] * 256 +  _bodyBytes[42], nil)

        binToModel(streams, "SysHeatDayRenewPower", _bodyBytes[43] * 256 +  _bodyBytes[44], nil)
        
        binToModel(streams, "SysHeatDayElecConsum", _bodyBytes[45] * 256 +  _bodyBytes[46], nil)
        
        binToModel(streams, "SysHeatDayCOPEER", _bodyBytes[47] * 256 +  _bodyBytes[48], nil)
                
        binToModel(streams, "instantPower0", _bodyBytes[49] * 256 +  _bodyBytes[50], nil)
		binToModel(streams, "instantRenewPower0", _bodyBytes[51] * 256 +  _bodyBytes[52], nil)
		binToModel(streams, "totalRenewPower0", _bodyBytes[53] * 16777216 +  _bodyBytes[54]  *  65536 +  _bodyBytes[55] * 256 +  _bodyBytes[56], nil)
		binToModel(streams, "compRunTotalTime0", _bodyBytes[57] * 256 +  _bodyBytes[58], nil)
        binToModel(streams, "pwmPumpOut", _bodyBytes[59], nil)
        binToModel(streams, "unitModeRun", _bodyBytes[60], nil)
        binToModel(streams, "SysInstantHPCapacity", _bodyBytes[61] * 256 +  _bodyBytes[62], nil)
        
        binToModel(streams, "SysInstantRenewPower", _bodyBytes[63] * 256 +  _bodyBytes[64], nil)
        
        binToModel(streams, "SysInstantPower", _bodyBytes[65] * 256 +  _bodyBytes[66], nil)
        
        binToModel(streams, "SysInstantCopEER", _bodyBytes[67] * 256 +  _bodyBytes[68], nil)
        
        binToModel(streams, "SysTotalHPCapacity", _bodyBytes[69] * 16777216 +  _bodyBytes[70]  *  65536 +  _bodyBytes[71] * 256 +  _bodyBytes[72], nil)

        --binToModel(streams, "SysTotalHeatCapacity", _bodyBytes[73] * 16777216 +  _bodyBytes[74]  *  65536 +  _bodyBytes[75] * 256 +  _bodyBytes[76], nil)

        binToModel(streams, "SysTotalRenewPower", _bodyBytes[73] * 16777216 +  _bodyBytes[74]  *  65536 +  _bodyBytes[75] * 256 +  _bodyBytes[76], nil)
    
        binToModel(streams, "SysTotalPowerConsum", _bodyBytes[77] * 16777216 +  _bodyBytes[78]  *  65536 +  _bodyBytes[79] * 256 +  _bodyBytes[80], nil)
        --binToModel(streams, "SysTotalHeatElecConsum", _bodyBytes[81] * 16777216 +  _bodyBytes[82]  *  65536 +  _bodyBytes[83] * 256 +  _bodyBytes[84], nil)
        binToModel(streams, "SysTotalCOPEER", _bodyBytes[81] * 256 +  _bodyBytes[82], nil)  
        binToModel(streams, "SysHeatInsHPCapacity", _bodyBytes[83] * 256 +  _bodyBytes[84], nil)

        binToModel(streams, "SysHeatInsRenewPower", _bodyBytes[85] * 256 +  _bodyBytes[86], nil)
        
        binToModel(streams, "SysHeatInsPower", _bodyBytes[87] * 256 +  _bodyBytes[88], nil)
        
        binToModel(streams, "SysHeatInsCopEER", _bodyBytes[89] * 256 +  _bodyBytes[90], nil)
        
        binToModel(streams, "SysHeatCapacity", _bodyBytes[91] * 16777216 +  _bodyBytes[92]  *  65536 +_bodyBytes[93] * 256 +  _bodyBytes[94], nil)

        binToModel(streams, "SysHeatRenewPower", _bodyBytes[95] * 16777216 +  _bodyBytes[96]  *  65536 +_bodyBytes[97] * 256 +  _bodyBytes[98], nil)

        binToModel(streams, "SysHeatElecConsum", _bodyBytes[99] * 16777216 +  _bodyBytes[100]  *  65536 +_bodyBytes[101] * 256 +  _bodyBytes[102], nil)
  
        binToModel(streams, "SysHeatCOPEER", _bodyBytes[103] * 256 +  _bodyBytes[104], nil)
        
        binToModel(streams, "SysCoolInsHPCapacity", _bodyBytes[105] * 256 +  _bodyBytes[106], nil)
        
        binToModel(streams, "SysCoolInsRenewPower", _bodyBytes[107] * 256 +  _bodyBytes[108], nil)
        
        binToModel(streams, "SysCoolInsPower", _bodyBytes[109] * 256 +  _bodyBytes[110], nil)
        
        binToModel(streams, "SysCoolInsCopEER", _bodyBytes[111] * 256 +  _bodyBytes[112], nil)
        
        binToModel(streams, "SysCoolCapacity", _bodyBytes[113] * 16777216 +  _bodyBytes[114]  *  65536 +_bodyBytes[115] * 256 +  _bodyBytes[116], nil)

        binToModel(streams, "SysCoolRenewPower", _bodyBytes[117] * 16777216 +  _bodyBytes[118]  *  65536 +_bodyBytes[119] * 256 +  _bodyBytes[120], nil)

        binToModel(streams, "SysCoolElecConsum", _bodyBytes[121] * 16777216 +  _bodyBytes[122]  *  65536 +_bodyBytes[123] * 256 +  _bodyBytes[124], nil)
        
        binToModel(streams, "SysCoolCOPEER", _bodyBytes[125] * 256 +  _bodyBytes[126], nil)
        
        binToModel(streams, "SysDhwInsHPCapacity", _bodyBytes[127] * 256 +  _bodyBytes[128], nil)
        
        binToModel(streams, "SysDhwInsRenewPower", _bodyBytes[129] * 256 +  _bodyBytes[130], nil)
        
        binToModel(streams, "SysDhwInsPower", _bodyBytes[131] * 256 +  _bodyBytes[132], nil)

        binToModel(streams, "SysDhwInsCopEER", _bodyBytes[133] * 256 +  _bodyBytes[134], nil)
        
        binToModel(streams, "SysDhwCapacity", _bodyBytes[135] * 16777216 +  _bodyBytes[136]  *  65536 +_bodyBytes[137] * 256 +  _bodyBytes[138], nil)

        binToModel(streams, "SysDhwRenewPower", _bodyBytes[139] * 16777216 +  _bodyBytes[140]  *  65536 +_bodyBytes[141] * 256 +  _bodyBytes[142], nil)

        binToModel(streams, "SysDhwElecConsum", _bodyBytes[143] * 16777216 +  _bodyBytes[144]  *  65536 +_bodyBytes[145] * 256 +  _bodyBytes[146], nil)
        

        binToModel(streams, "SysDhwCOPEER", _bodyBytes[147] * 256 +  _bodyBytes[148], nil)
        
        binToModel(streams, "SysEnergyAnaEN", _bodyBytes[149], BIT0)
        binToModel(streams, "HMIEnergyAnaSetEN", _bodyBytes[149], BIT1)

        binToModel(streams, "SysHeatWeekCapacity", _bodyBytes[150] * 256 +  _bodyBytes[151], nil)

        binToModel(streams, "SysHeatWeekRenewPower", _bodyBytes[152] * 256 +  _bodyBytes[153], nil)
        
        binToModel(streams, "SysHeatWeekElecConsum", _bodyBytes[154] * 256 +  _bodyBytes[155], nil)
        
        binToModel(streams, "SysHeatWeekCOPEER", _bodyBytes[156] * 256 +  _bodyBytes[157], nil)
        
        binToModel(streams, "SysHeatMonthCapacity", _bodyBytes[158] * 256 +  _bodyBytes[159], nil)
        
        binToModel(streams, "SysHeatMonthRenewPower", _bodyBytes[160] * 256 +  _bodyBytes[161], nil)
        
        binToModel(streams, "SysHeatMonthElecConsum", _bodyBytes[162] * 256 +  _bodyBytes[163], nil)
        
        binToModel(streams, "SysHeatMonthCOPEER", _bodyBytes[164] * 256 +  _bodyBytes[165], nil)
        
        binToModel(streams, "SysHeatYearCapacity", _bodyBytes[166] * 256 +  _bodyBytes[167], nil)
        
        binToModel(streams, "SysHeatYearRenewPower", _bodyBytes[168] * 256 +  _bodyBytes[169], nil)
        
        binToModel(streams, "SysHeatYearElecConsum", _bodyBytes[170] * 256 +  _bodyBytes[171], nil)
        
        binToModel(streams, "SysHeatYearCOPEER", _bodyBytes[172] * 256 +  _bodyBytes[173], nil)
        
        binToModel(streams, "SysCoolDayCapacity", _bodyBytes[174] * 256 +  _bodyBytes[175], nil)
        
        binToModel(streams, "SysCoolDayRenewPower", _bodyBytes[176] * 256 +  _bodyBytes[177], nil)
        
        binToModel(streams, "SysCoolDayElecConsum", _bodyBytes[178] * 256 +  _bodyBytes[179], nil)
        
        binToModel(streams, "SysCoolDayCOPEER", _bodyBytes[180] * 256 +  _bodyBytes[181], nil)
        
        binToModel(streams, "SysCoolWeekCapacity", _bodyBytes[182] * 256 +  _bodyBytes[183], nil)
        
        binToModel(streams, "SysCoolWeekRenewPower", _bodyBytes[184] * 256 +  _bodyBytes[185], nil)
        
        binToModel(streams, "SysCoolWeekElecConsum", _bodyBytes[186] * 256 +  _bodyBytes[187], nil)
        
        binToModel(streams, "SysCoolWeekCOPEER", _bodyBytes[188] * 256 +  _bodyBytes[189], nil)
        
        binToModel(streams, "SysCoolMonthCapacity", _bodyBytes[190] * 256 +  _bodyBytes[191], nil)
        
        binToModel(streams, "SysCoolMonthRenewPower", _bodyBytes[192] * 256 +  _bodyBytes[193], nil)
        
        binToModel(streams, "SysCoolMonthElecConsum", _bodyBytes[194] * 256 +  _bodyBytes[195], nil)
        
        binToModel(streams, "SysCoolMonthCOPEER", _bodyBytes[196] * 256 +  _bodyBytes[197], nil)
        
        binToModel(streams, "SysCoolYearCapacity", _bodyBytes[198] * 256 +  _bodyBytes[199], nil)
        
        binToModel(streams, "SysCoolYearRenewPower", _bodyBytes[200] * 256 +  _bodyBytes[201], nil)
        
        binToModel(streams, "SysCoolYearElecConsum", _bodyBytes[202] * 256 +  _bodyBytes[203], nil)
        
        binToModel(streams, "SysCoolYearCOPEER", _bodyBytes[204] * 256 +  _bodyBytes[205], nil)
        
        binToModel(streams, "SysDhwDayCapacity", _bodyBytes[206] * 256 +  _bodyBytes[207], nil)
        
        binToModel(streams, "SysDhwDayRenewPower", _bodyBytes[208] * 256 +  _bodyBytes[209], nil)
        
        binToModel(streams, "SysDhwDayElecConsum", _bodyBytes[210] * 256 +  _bodyBytes[211], nil)
        
        binToModel(streams, "SysDhwDayCOPEER", _bodyBytes[212] * 256 +  _bodyBytes[213], nil)
        
        binToModel(streams, "SysDhwWeekCapacity", _bodyBytes[214] * 256 +  _bodyBytes[215], nil)
        
        binToModel(streams, "SysDhwWeekRenewPower", _bodyBytes[216] * 256 +  _bodyBytes[217], nil)
        
        binToModel(streams, "SysDhwWeekElecConsum", _bodyBytes[218] * 256 +  _bodyBytes[219], nil)
        
        binToModel(streams, "SysDhwWeekCOPEER", _bodyBytes[220] * 256 +  _bodyBytes[221], nil)
        
        binToModel(streams, "SysDhwMonthCapacity", _bodyBytes[222] * 256 +  _bodyBytes[223], nil)
        
        binToModel(streams, "SysDhwMonthRenewPower", _bodyBytes[224] * 256 +  _bodyBytes[225], nil)
        
        binToModel(streams, "SysDhwMonthElecConsum", _bodyBytes[226] * 256 +  _bodyBytes[227], nil)
        
        binToModel(streams, "SysDhwMonthCOPEER", _bodyBytes[228] * 256 +  _bodyBytes[229], nil)
        
        binToModel(streams, "SysDhwYearCapacity", _bodyBytes[230] * 256 +  _bodyBytes[231], nil)
        
        binToModel(streams, "SysDhwYearRenewPower", _bodyBytes[232] * 256 +  _bodyBytes[233], nil)
        
        binToModel(streams, "SysDhwYearElecConsum", _bodyBytes[234] * 256 +  _bodyBytes[235], nil)
        
        binToModel(streams, "SysDhwYearCOPEER", _bodyBytes[236] * 256 +  _bodyBytes[237], nil)
        
        
	end

    local retTable = {}
    retTable[unitTable["str_status"]] = streams
    local ret = encode(retTable)
    return ret
end

