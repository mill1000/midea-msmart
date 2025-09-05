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

        self.beep_on = True
        self.power_on = False
        self.target_temperature = 25.0
        self.operational_mode = 0
        self.fan_speed = 0
        self.eco = True
        self.swing_mode = 0
        self.turbo = False
        self.fahrenheit = True
        self.sleep = False
        self.freeze_protection = False
        self.follow_me = False
        self.purifier = False
        self.target_humidity = 40
        self.aux_heat = False
        self.force_aux_heat = False
        self.independent_aux_heat = False

    def tobytes(self) -> bytes:  # pyright: ignore[reportIncompatibleMethodOverride] # nopep8
        payload = bytearray(22)

        payload[0] = CommandType.COMMAND_CONTROL

        payload[1] |= 1 << 8 if self.power_on else 0
        payload[1] |= (self.operational_mode & 0x1F)

        payload[2] = self.fan_speed

        payload[3] = int(self.target_temperature)

        payload[6] |= 1 << 0 if self.eco else 0
        # swingUDValue, exhaustValue, PTCSettingValue in payload[6]

        payload[7] = 0xFF

        payload[8] |= 1 << 4 if self.sleep else 0
        # digitDisplay, swingLRValue in payload[8]

        # payload[9] = swingLRSiteValue
        # payload[10] = swingUDSiteValue
        # payload[11] temperatureDecimals * 10

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
    def construct(cls, frame: bytes) -> Union[Response]:
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

        self.power_on = None
        self.target_temperature = None
        self.operational_mode = None
        self.fan_speed = None
        self.swing_mode = None
        self.turbo = None
        self.eco = None
        self.sleep = None
        self.fahrenheit = None
        self.indoor_temperature = None
        self.outdoor_temperature = None
        self.filter_alert = None
        self.display_on = None
        self.freeze_protection = None
        self.follow_me = None
        self.purifier = None
        self.target_humidity = None
        self.aux_heat = None
        self.independent_aux_heat = None

        self._parse(payload)

    def _parse(self, payload: memoryview) -> None:
        """Parse the state response payload."""

        self.power_on = bool(payload[1] & 0x80)
        self.operational_mode = payload[1] & 0x1F

        self.fan_speed = payload[2]

        temperature_value = payload[3]  # Target temp?
        self.indoor_temperature = payload[4]

        evaporator_entrance_temperature = payload[5]
        evaporator_exit_temperature = payload[6]

        swing_ud_value = payload[9]

        # Timers?
        # openTime payload[10]
        # closeTime payload[11]

        # exhaustValue payload[13] & 0x08
        swing_up = payload[13] & 0x04
        ptc_value = payload[13] & 0x02  # Emergency heat PTC?
        self.eco = payload[13] & 0x01

        # isCanDecimals (payload[14] & 80) # Decimals?
        ptc_setting_value = payload[14] & 0x60
        self.sleep = payload[14] & 0x10
        digit_display = payload[14] & 0x08  # Unit?
        swing_lr = payload[14] & 0x01

        swing_lr_value = payload[17]
        temperature_decimals = payload[19]

        # errorCodeMachineStyle payload[18] & 0x80
        # errorHigh payload[18] & 0x7F
        # errorLow payload[19]
