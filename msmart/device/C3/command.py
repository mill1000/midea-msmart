from __future__ import annotations

import logging
import math
import struct
from collections import namedtuple
from enum import IntEnum
from typing import Callable, Optional, Union

import msmart.crc8 as crc8
from msmart.const import DeviceType, FrameType
from msmart.frame import Frame

_LOGGER = logging.getLogger(__name__)

# Useful acronyms
# DHW - Domestic hot water
# TBH - Tank booster heater
# IBH - Internal backup heater


class ControlType(IntEnum):
    CONTROL_BASIC = 0x1
    CONTROL_DAY_TIMER = 0x2
    CONTROL_WEEKS_TIMER = 0x3
    CONTROL_HOLIDAY_AWAY = 0x4
    CONTROL_SILENCE = 0x05
    CONTROL_HOLIDAY_HOME = 0x6
    CONTROL_ECO = 0x7
    CONTROL_INSTALL = 0x8
    CONTROL_DISINFECT = 0x9


class QueryType(IntEnum):
    QUERY_BASIC = 0x1
    QUERY_DAY_TIMER = 0x2
    QUERY_WEEKS_TIMER = 0x3
    QUERY_HOLIDAY_AWAY = 0x4
    QUERY_SILENCE = 0x05
    QUERY_HOLIDAY_HOME = 0x6
    QUERY_ECO = 0x7
    QUERY_INSTALL = 0x8
    QUERY_DISINFECT = 0x9
    QUERY_HMI_PARAMETERS = 0x0A
    QUERY_UNIT_PARAMETERS = 0x10


class ReportType(IntEnum):  # Ref: MSG_TYPE_UP
    REPORT_BASIC = 0x1
    REPORT_POWER3 = 0x3
    REPORT_POWER4 = 0x4
    REPORT_UNIT_PARAMETERS = 0x5


class QueryCommand(Frame):
    """Base class for query commands."""

    def __init__(self, type: QueryType) -> None:
        super().__init__(DeviceType.HEAT_PUMP, frame_type=FrameType.QUERY)

        self._type = type

    def tobytes(self) -> bytes:
        return super().tobytes(bytes([
            self._type
        ]))


class QueryBasicCommand(QueryCommand):
    """Command to query basic device state."""

    def __init__(self) -> None:
        super().__init__(QueryType.QUERY_BASIC)


class QueryEcoCommand(QueryCommand):
    """Command to query ECO state."""

    def __init__(self) -> None:
        super().__init__(QueryType.QUERY_ECO)


class QueryUnitParametersCommand(QueryCommand):
    """Command to query unit parameters."""

    def __init__(self) -> None:
        super().__init__(QueryType.QUERY_UNIT_PARAMETERS)


class ControlCommand(Frame):
    """Base class for control commands."""

    def __init__(self, type: ControlType) -> None:
        super().__init__(DeviceType.HEAT_PUMP, frame_type=FrameType.QUERY)

        self._type = type


class ControlBasicCommand(ControlCommand):
    """Command to control basic device state."""

    def __init__(self) -> None:
        super().__init__(ControlType.CONTROL_BASIC)

        self.zone1_power_state = False
        self.zone2_power_state = False
        self.dhw_power_state = False

        self.run_mode = 0  # TODO??

        # TODO default values?
        self.zone1_target_temperature = 0
        self.zone2_target_temperature = 0
        self.dhw_target_temperature = 0
        self.room_target_temperature = 0

        self.zone1_curve_state = False
        self.zone2_curve_state = False

        self.tbh_state = False
        self.fastdhw_state = False

        # TODO "newfunction_en"
        self.zone1_curve_type = 0  # TODO??
        self.zone2_curve_type = 0

    def tobytes(self) -> bytes:
        payload = bytearray(10)

        payload[0] = self._type

        payload[1] |= 1 << 0 if self.zone1_power_state else 0
        payload[1] |= 1 << 1 if self.zone2_power_state else 0
        payload[1] |= 1 << 2 if self.dhw_power_state else 0

        payload[2] = self.run_mode
        payload[3] = self.zone1_target_temperature
        payload[4] = self.zone2_target_temperature
        payload[5] = self.dhw_target_temperature
        payload[6] = self.room_target_temperature * 2  # Convert ℃ to .5 ℃

        payload[7] |= 1 << 0 if self.zone1_curve_state else 0
        payload[7] |= 1 << 1 if self.zone2_curve_state else 0
        payload[7] |= 1 << 2 if self.tbh_state else 0
        payload[7] |= 1 << 3 if self.fastdhw_state else 0

        # TODO newfunction_en
        # payload[8] = self.zone1_curve_type
        # payload[9] = self.zone2_curve_type

        return super().tobytes(payload)


class Response():
    """Base class for responses."""

    def __init__(self, frame: memoryview) -> None:

        self._type = frame[10]
        self._payload = bytes(frame[10:-1])

    @property
    def type(self) -> int:
        return self._type

    @property
    def payload(self) -> bytes:
        return self._payload

    @classmethod
    def validate(cls, frame: memoryview) -> None:
        # Responses only have frame checksum
        Frame.validate(frame)

    @classmethod
    def construct(cls, frame: bytes) -> Union[QueryBasicResponse, QueryUnitParametersResponse, ReportPower4Response, Response]:
        # Build a memoryview of the frame for zero-copy slicing
        with memoryview(frame) as frame_mv:
            # Ensure frame is valid before parsing
            Response.validate(frame_mv)

            # Parse frame depending on id
            frame_type = frame_mv[9]
            type = frame_mv[10]
            if frame_type == FrameType.QUERY and type == QueryType.QUERY_BASIC:
                return QueryBasicResponse(frame_mv)
            elif frame_type == FrameType.QUERY and type == QueryType.QUERY_UNIT_PARAMETERS:
                return QueryUnitParametersResponse(frame_mv)
            elif frame_type == FrameType.REPORT and type == ReportType.REPORT_POWER4:
                return ReportPower4Response(frame_mv)
            else:
                return Response(frame_mv)


class QueryBasicResponse(Response):
    """Response to basic query."""

    def __init__(self, frame: memoryview) -> None:
        super().__init__(frame)

        _LOGGER.debug("Query basic response payload: %s", self.payload.hex())

        with memoryview(self.payload) as payload:
            self._parse(payload)

    def _parse(self, payload: memoryview) -> None:

        self.zone1_power_state = bool(payload[1] & 0x01)
        self.zone2_power_state = bool(payload[1] & 0x02)
        self.dhw_power_state = bool(payload[1] & 0x04)
        self.zone1_curve_state = bool(payload[1] & 0x08)
        self.zone2_curve_state = bool(payload[1] & 0x10)
        self.tbh_state = bool(payload[1] & 0x40)  # Ref: forcetbh_state
        self.fastdhw_state = bool(payload[1] & 0x40)
        # self.remote_onoff = bool(payload[1] & 0x80) # TODO never referenced in ref

        self.heat_enable = bool(payload[2] & 0x01)
        self.cool_enable = bool(payload[2] & 0x02)
        self.dhw_enable = bool(payload[2] & 0x04)
        self.zone2_enable = bool(payload[2] & 0x08)  # Ref: double_zone_enable

        # 0 - Air, 1 - Water
        self.zone1_temperature_type = int(bool(payload[2] & 0x10))
        self.zone2_temperature_type = int(bool(payload[2] & 0x20))

        # Ref: room_thermalen_state, room_thermalmode_state
        self.room_thermostat_power_state = bool(payload[2] & 0x40)
        self.room_thermostat_enable = bool(payload[2] & 0x80)

        self.time_set_state = bool(payload[3] & 0x01)
        self.silence_on_state = bool(payload[3] & 0x02)
        self.holiday_on_state = bool(payload[3] & 0x04)
        self.eco_on_state = bool(payload[3] & 0x08)

        self.zone1_terminal_type = (payload[3] & 0x30) >> 4
        self.zone2_terminal_type = (payload[3] & 0xC0) >> 4

        self.run_mode = payload[4]  # Ref: run_mode_set
        self.run_mode_under_auto = payload[5]  # Ref: runmode_under_auto

        self.zone1_target_temperature = payload[6]  # Ref: zone1_temp_set
        self.zone2_target_temperature = payload[7]  # Ref: zone2_temp_set
        self.dhw_target_temperature = payload[8]  # Ref: dhw_temp_set
        self.room_target_temperature = payload[9]/2  # .5 ℃ Ref: room_temp_set

        self.zone1_heat_max_temperature = payload[10]
        self.zone1_heat_min_temperature = payload[11]
        self.zone1_cool_max_temperature = payload[12]
        self.zone1_cool_min_temperature = payload[13]

        self.zone2_heat_max_temperature = payload[14]
        self.zone2_heat_min_temperature = payload[15]
        self.zone2_cool_max_temperature = payload[16]
        self.zone2_cool_min_temperature = payload[17]

        self.room_max_temperature = payload[18]/2  # .5 ℃
        self.room_min_temperature = payload[19]/2  # .5 ℃

        self.dhw_max_temperature = payload[20]
        self.dhw_min_temperature = payload[21]

        # Actual tank temperature in ℃
        # Ref: tank_actual_temp
        self.tank_temperature = payload[22] if payload[22] != 0xFF else None

        self.error_code = payload[23]

        # Ref: boostertbh_en
        self.tbh_enable = bool(payload[24] & 0x80)

        if len(payload) > 25:
            # TODO newfunction_en = True
            self.zone1_curve_type = payload[25]
            self.zone2_curve_type = payload[26]


class ReportPower4Response(Response):
    """Unsolicited report of POWER4."""

    def __init__(self, frame: memoryview) -> None:
        super().__init__(frame)

        _LOGGER.debug("Power4 report payload: %s", self.payload.hex())

        with memoryview(self.payload) as payload:
            self._parse(payload)

    def _parse(self, payload: memoryview) -> None:

        # Local function to convert byte to signed int
        def signed_int(data) -> int:
            return struct.unpack("b", data)[0]

        # TODO do these indicate current activity, or power state
        self.heat_active = bool(payload[1] & 0x01)  # Ref: isheatrun0
        self.cool_active = bool(payload[1] & 0x02)  # Ref: iscoolrun0
        self.dhw_active = bool(payload[1] & 0x04)  # Ref: isdhwrun0
        self.tbh_active = bool(payload[1] & 0x08)  # Ref: istbhrun0

        # TODO isibhrun0, issmartgrid0m, ishighprices0, isbottomprices0

        # Ref: totalelectricity0
        self.electric_power = struct.unpack(">I", payload[2:6])[0]
        # Ref: totalthermal0
        self.thermal_power = struct.unpack(">I", payload[6:10])[0]

        # TODO water and air temperatures may need to be checked for validity
        self.outdoor_air_temperature = signed_int(payload[10:11])  # Ref: t4

        self.zone1_target_temperature = payload[11]
        self.zone2_target_temperature = payload[12]

        self.water_tank_temperature = payload[13]  # Ref: t5s
        # TODO payload[14] Ref: tas

        # TODO What does online mean?
        self.online = bool(payload[17] & 0x01)  # Ref: isonline0

        # Bytes 19 - 153 contain run status and energy 1 - 15

        # Bytes 154, 155 contain run status of ibh2 0-15

        self.voltage = payload[156]  # Ref: voltage0
        # voltage0-15 bytes 157-171

        # TODO
        # self.ibh1_power = payload[172] # Ref: power_ibh1
        # self.ibh2_power = payload[173] # Ref: power_ibh1
        # self.tbh_power = payload[174] # Ref: power_ibh1


class QueryUnitParametersResponse(Response):
    """Response to unit parameters query."""

    def __init__(self, frame: memoryview) -> None:
        super().__init__(frame)

        _LOGGER.debug("Query unit parameters response payload: %s",
                      self.payload.hex())

        with memoryview(self.payload) as payload:
            self._parse(payload)

    def _parse(self, payload: memoryview) -> None:

        # There are many fields of this response that are unused and thus not parsed

        # Local function to convert byte to signed int
        def signed_int(data) -> int:
            return struct.unpack("b", data)[0]

        self.outdoor_temperature = signed_int(payload[8:9])  # Ref: tempT4
        self.water_temperature_2 = signed_int(payload[11:12])  # Ref: tempTwout
        # Referenced in JS w/o friendly name
        self.tempT5 = signed_int(payload[38:39])
        self.room_temperature = signed_int(payload[39:40])  # Ref: tempTa
