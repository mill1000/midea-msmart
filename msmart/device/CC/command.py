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
        self.swing_ud_angle = 0
        self.swing_lr_angle = 0
        self.soft = False
        self.eco = False
        self.silent = False
        self.sleep = False
        self.purifier = False
        self.aux_mode = 0

    def tobytes(self) -> bytes:  # pyright: ignore[reportIncompatibleMethodOverride] # nopep8
        payload = bytearray(22)

        payload[0] = CommandType.COMMAND_CONTROL

        payload[1] |= 1 << 7 if self.power_on else 0
        payload[1] |= (self.operational_mode & 0x1F)

        payload[2] = self.fan_speed

        # Get integer and fraction components of target temp
        temperature = max(17, min(self.target_temperature, 30))
        fractional_temp, integral_temp = math.modf(temperature)
        integral_temp = int(integral_temp)

        payload[3] = max(17, min(integral_temp, 30))

        payload[6] |= 1 << 0 if self.eco else 0
        payload[6] |= self.aux_mode << 4

        payload[7] = 0xFF

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
    def validate(cls, payload: memoryview) -> None:
        """Validate the response."""
        # TODO
        pass

    @classmethod
    def construct(cls, frame: bytes) -> Union[StateResponse, Response]:
        """Construct a response object from raw data."""

        # Build a memoryview of the frame for zero-copy slicing
        with memoryview(frame) as frame_mv:
            # Validate the frame
            Frame.validate(frame_mv, DeviceType.COMMERCIAL_AC)

            # Default to base class
            response_class = Response

            # Fetch the appropriate response class from the ID
            response_type = frame_mv[10]
            if response_type == CommandType.COMMAND_QUERY or response_type == CommandType.COMMAND_CONTROL:
                response_class = StateResponse

            # Validate the payload
            Response.validate(frame_mv[10:-1])

            # Build the response
            return response_class(frame_mv[10:-1])


class StateResponse(Response):
    """Response to query or control command."""

    def __init__(self, payload: memoryview) -> None:
        super().__init__(payload)

        self.power_on = False
        self.target_temperature = None
        self.indoor_temperature = None
        self.operational_mode = 0
        self.fan_speed = 0
        self.swing_ud_angle = 0
        self.swing_lr_angle = 0
        self.soft = False
        self.eco = False
        self.silent = False
        self.sleep = False
        self.purifier = False
        self.aux_mode = 0

        self._parse(payload)

    def _parse(self, payload: memoryview) -> None:
        """Parse the state response payload."""

        self.power_on = bool(payload[8])

        # min/max temperature possibly encoded in payload[9] & payload[10]
        # Based on sample data
        # 0x72 -> 17C
        # 0x8C -> 30C
        # 0x79 -> 20.5C
        self.target_temperature = (payload[11] / 2.0) - 40

        # Based on samples
        # 0x00CF -> 207 -> 20.7
        # 0x00EF -> 239 -> 23.9
        # 0x0107 -> 263 -> 26.3
        self.indoor_temperature = (payload[12] << 8 | payload[13]) / 10.0

        # 0x728C -> 17C/30C is repeated 3 times in user payload
        # Possible multi zones? Or multiple temp limits for different modes?

        self.operational_mode = payload[31]
        self.fan_speed = payload[34]

        self.swing_ud_angle = payload[36]  # Also at payload[41]
        self.swing_lr_angle = payload[43]

        self.soft = bool(payload[45])  # Cool mode only, breezeless?
        self.eco = bool(payload[56])
        self.silent = bool(payload[58])
        self.sleep = bool(payload[60])
        self.purifier = bool(payload[75] & 0x01)  # 0x01 - On, 0x02 - Off

        # 0x02 - Force off, 0x01 - Force on, 0x00 - Auto
        self.aux_mode = payload[87]
