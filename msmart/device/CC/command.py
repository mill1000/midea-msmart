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
    COMMAND_COMMON = 0xC3
    COMMAND_QUERY_COMMON = 0x01
    COMMAND_LOCK = 0xB0
    COMMAND_SMART = 0xE0
    COMMAND_NOT_SUPPORTED = 0x0D


class Command(Frame):
    """Base class for 0xCC commands."""

    def __init__(self, type: CommandType) -> None:
        super().__init__(DeviceType.COMMERCIAL_AC, frame_type=FrameType.CONTROL)  # TODO

        self._type = type


class QueryCommand(Command):
    """Command to query state of the device."""

    def __init__(self) -> None:
        super().__init__(CommandType.COMMAND_QUERY_COMMON)

    def tobytes(self) -> bytes:  # pyright: ignore[reportIncompatibleMethodOverride] # nopep8
        payload = bytearray(24)  # TODO include random ID and crc8?

        payload[0] = self._type

        return super().tobytes(payload)


class SetStateCommand(Command):
    """Command to set basic state of the device."""

    def __init__(self) -> None:
        super().__init__(CommandType.COMMAND_COMMON)

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
        payload = bytearray(24)  # TODO include random ID and crc8?

        payload[0] = self._type

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
    """Base class for AC responses."""

    def __init__(self, frame: memoryview) -> None:
        self._type = frame[10]
        self._payload = bytes(frame[10:-1])

    @property
    def type(self) -> int:
        """Type of the response."""
        return self._type

    @property
    def payload(self) -> bytes:
        """Payload portion of the response."""
        return self._payload

    @classmethod
    def validate(cls, frame: memoryview) -> None:
        """Validate the response."""
        # Responses only have frame checksum
        Frame.validate(frame)

    @classmethod
    def construct(cls, frame: bytes) -> Union[Response]:
        """Build a response object from the frame and response type."""
        pass


class StateResponse(Response):
    """Response to state query."""

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

    def _parse_temperature(self, data: int, decimals: float, fahrenheit: bool) -> Optional[float]:
        """Parse a temperature value from the payload using additional precision bits as needed."""
        if data == 0xFF:
            return None

        # Temperature parsing lifted from https://github.com/dudanov/MideaUART
        temperature = (data - 50) / 2

        # In Celcius, use additional precision from decimals if present
        if not fahrenheit and decimals:
            return int(temperature) + (decimals if temperature >= 0 else -decimals)

        if decimals >= 0.5:
            return int(temperature) + (0.5 if temperature >= 0 else -0.5)

        return temperature

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
