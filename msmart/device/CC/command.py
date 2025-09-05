"""Command and repsonse messages for 0xCC devices."""
from __future__ import annotations

import logging
import math
import struct
from collections import namedtuple
from enum import IntEnum
from typing import Any, Callable, Collection, Mapping, Optional, Union

import msmart.crc8 as crc8
from msmart.const import DeviceType, FrameType
from msmart.frame import Frame

_LOGGER = logging.getLogger(__name__)


class CommandType(IntEnum):
    """Command message types."""
    COMMAND_CONTROL = 0xC3
    COMMAND_QUERY = 0x01
    COMMAND_LOCK = 0xB0
    COMMAND_SMART = 0xE0
    COMMAND_NOT_SUPPORTED = 0x0D  # ?


class Command(Frame):
    """Base class for CC commands."""

    _message_id = 0

    def __init__(self, frame_type: FrameType) -> None:
        super().__init__(DeviceType.COMMERCIAL_AC, frame_type)

    def tobytes(self, data: Union[bytes, bytearray] = bytes()) -> bytes:
        # Append message ID to payload
        # TODO Message ID in reference is just a random value
        payload = data + bytes([self._next_message_id()])

        # Append CRC
        return super().tobytes(payload + bytes([crc8.calculate(payload)]))

    def _next_message_id(self) -> int:
        Command._message_id += 1
        return Command._message_id & 0xFF


class QueryCommand(Command):
    """Command to query state of the device."""

    def __init__(self) -> None:
        super().__init__(frame_type=FrameType.QUERY)

    def tobytes(self) -> bytes:  # pyright: ignore[reportIncompatibleMethodOverride] # nopep8
        payload = bytearray(22)

        payload[0] = CommandType.COMMAND_QUERY

        return super().tobytes(payload)


class ControlCommand(Command):
    """Command to control state of the device."""

    def __init__(self) -> None:
        super().__init__(frame_type=FrameType.CONTROL)

        self.power_on = False
        self.target_temperature = 25.0
        self.operational_mode = 0
        self.fan_speed = 0
        self.eco = True
        self.sleep = False
        self.swing_ud = False
        self.swing_ud_angle = 0
        self.swing_lr = False
        self.swing_lr_angle = 0
        self.exhaust = False
        self.ptc_setting = 0
        self.digit_display = False

    def tobytes(self) -> bytes:  # pyright: ignore[reportIncompatibleMethodOverride] # nopep8
        payload = bytearray(22)

        payload[0] = CommandType.COMMAND_CONTROL

        payload[1] |= 1 << 8 if self.power_on else 0
        payload[1] |= (self.operational_mode & 0x1F)

        payload[2] = self.fan_speed

        # Get integer and fraction components of target temp
        fractional_temp, integral_temp = math.modf(self.target_temperature)
        integral_temp = int(integral_temp)

        payload[3] = max(17, min(integral_temp, 30))

        payload[6] |= 1 << 0 if self.eco else 0
        payload[6] |= 1 << 2 if self.swing_ud else 0
        payload[6] |= 1 << 3 if self.exhaust else 0
        payload[6] |= self.ptc_setting << 4

        payload[7] = 0xFF

        payload[8] |= 1 << 0 if self.swing_lr else 0
        payload[8] |= 1 << 3 if self.digit_display else 0
        payload[8] |= 1 << 4 if self.sleep else 0

        payload[9] = self.swing_lr_angle
        payload[10] = self.swing_ud_angle

        payload[11] = int(fractional_temp * 10)

        return super().tobytes(payload)


class Response():
    """Base class for CC responses."""

    def __init__(self, payload: memoryview) -> None:
        self._type = payload[0]
        self._payload = bytes(payload)

    def __str__(self) -> str:
        return self.payload.hex()

    @property
    def type(self) -> int:
        return self._type

    @property
    def payload(self) -> bytes:
        return self._payload

    @classmethod
    def validate(cls, frame: memoryview) -> None:
        """Validate the response."""
        # TODO
        pass

    @classmethod
    def construct(cls, frame: bytes) -> Union[StateResponse, Response]:
        """Construct a response object from raw data."""

        # Build a memoryview of the frame for zero-copy slicing
        with memoryview(frame) as frame_mv:
            # Validate the frame
            Frame.validate(frame_mv)

            # Default to base class
            response_class = Response

            # Fetch the appropriate response class from the ID
            response_type = frame_mv[10]
            if response_type == CommandType.COMMAND_QUERY or response_type == CommandType.COMMAND_CONTROL:
                response_class = StateResponse

            # Validate the payload
            Response.validate(frame_mv[10:-1])

            # Build the response
            return response_class(frame_mv[10:-2])


class StateResponse(Response):
    """Response to query or control command."""

    def __init__(self, payload: memoryview) -> None:
        super().__init__(payload)

        self.power_on = False
        self.target_temperature = 25.0
        self.operational_mode = 0
        self.fan_speed = 0
        self.indoor_temperature = None
        self.evaporator_entrance_temperature = None
        self.evaporator_exit_temperature = None
        self.eco = True
        self.sleep = False
        self.swing_ud = False
        self.swing_ud_angle = 0
        self.swing_lr = False
        self.swing_lr_angle = 0
        self.exhaust = False
        self.ptc_on = False # Indicates if PTC is active?
        self.ptc_setting = 0
        self.digit_display = False
        
        self._parse(payload)

    def _parse(self, payload: memoryview) -> None:
        """Parse the state response payload."""

        self.power_on = bool(payload[1] & 0x80)
        self.operational_mode = payload[1] & 0x1F

        self.fan_speed = payload[2]

        self.target_temperature = payload[3]
        self.indoor_temperature = payload[4]

        self.evaporator_entrance_temperature = payload[5]
        self.evaporator_exit_temperature = payload[6]

        self.swing_ud_angle = payload[9]

        # TODO temperature parsing
        # streams[KEY_TEMPERATURE] = int2String(temperatureValue)
        # streams[KEY_INDOOR_TEMPERATURE] = int2String((indoorTemperature - 40) / 2)
        # streams[KEY_EVAPORATOR_ENTRANCE_TEMPERATURE] = int2String((evaporatorEntranceTemp - 40) / 2)
        # streams[KEY_EVAPORATOR_EXIT_TEMPERATURE] = int2String((evaporatorExitTemp - 40) / 2)

        # Timers
        # openTime payload[10]
        # closeTime payload[11]

        self.eco = bool(payload[13] & 0x01)
        self.ptc_on = bool(payload[13] & 0x02)  # Emergency heat PTC?
        self.swing_ud = bool(payload[13] & 0x04)
        self.exhaust = bool (payload[13] & 0x08)

        # isCanDecimals (payload[14] & 80) # Decimals?
        # streams[KEY_SMALL_TEMPERATURE] = int2String(temperatureDecimals / 10)
        # if (isCanDecimals == 0x00) then
        #     streams['support_decimals'] = 'on'
        # elseif (isCanDecimals == 0x01) then
        #     streams['support_decimals'] = 'off'
        # end


        self.swing_lr = payload[14] & 0x01
        self.digit_display = payload[14] & 0x08  # Display on/off?
        self.sleep = payload[14] & 0x10
        self.ptc_setting = (payload[14] & 0x60) >> 5
        # if (PTCValue == 0x02) then
        #     streams[KEY_PTC_POWER] = VALUE_ON
        # elseif (PTCValue == 0x00) then
        #     streams[KEY_PTC_POWER] = VALUE_OFF
        # end

        self.swing_lr_value = payload[17]
        
        self.target_temperature += (payload[19] / 10.0)

        # errorCodeMachineStyle payload[18] & 0x80
        # errorHigh payload[18] & 0x7F
        # errorLow payload[19]
