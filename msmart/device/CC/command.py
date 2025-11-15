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


class InvalidResponseException(Exception):
    pass


class CommandType(IntEnum):
    """Command message types."""
    COMMAND_CONTROL = 0xC3
    COMMAND_QUERY = 0x01
    COMMAND_LOCK = 0xB0
    COMMAND_SMART = 0xE0
    COMMAND_NOT_SUPPORTED = 0x0D  # ?


class ControlId(IntEnum):
    POWER = 0x0000
    TARGET_TEMPERATURE = 0x0003
    TEMPERATURE_UNIT = 0x000C
    MODE = 0x0012
    FAN_SPEED = 0x0015
    VERT_SWING_ANGLE = 0x001C
    HORZ_SWING_ANGLE = 0x001E
    WIND_SENSE = 0x0020
    ECO = 0x0028
    SILENT = 0x002A
    SLEEP = 0x002C
    SELF_CLEAN = 0x002E
    PURIFIER = 0x003A
    BEEP = 0x003F
    DISPLAY = 0x0040
    AUX_MODE = 0x0043

    def decode(self, data: bytes) -> Any:
        """Decode raw control data into a convenient form."""

        if self == ControlId.TARGET_TEMPERATURE:
            return (data[0] / 2.0) - 40
        elif self == ControlId.PURIFIER:
            return data[0] == 0x01
        else:
            return data[0]

    def encode(self, *args, **kwargs) -> bytes:
        """Encode controls into raw form."""

        if self == ControlId.TARGET_TEMPERATURE:
            return bytes([(2 * int(args[0])) + 80])
        elif self == ControlId.PURIFIER:
            return bytes([0x01 if args[0] else 0x02]) # TODO Auto = 0 if supported
        else:
            return bytes(args[0:1])


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

    def __init__(self, controls: Mapping[ControlId, Union[int, float, bool]]) -> None:
        super().__init__(frame_type=FrameType.CONTROL)

        self._controls = controls

    def tobytes(self) -> bytes:  # pyright: ignore[reportIncompatibleMethodOverride] # nopep8
        payload = bytearray()

        for control, value in self._controls.items():
            payload += struct.pack(">H", control)

            # Encode property value to bytes
            value = control.encode(value)

            payload += bytes([len(value)])
            payload += value
            payload += bytes([0xFF])

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
    def construct(cls, frame: bytes) -> Union[QueryResponse, Response]:
        """Construct a response object from raw data."""

        # Build a memoryview of the frame for zero-copy slicing
        with memoryview(frame) as frame_mv:
            # Validate the frame
            Frame.validate(frame_mv, DeviceType.COMMERCIAL_AC)

            # Default to base class
            response_class = Response

            # Fetch the appropriate response class from the frame type
            frame_type = frame_mv[9]
            if frame_type in [FrameType.QUERY, FrameType.REPORT]:
                response_class = QueryResponse
            elif frame_type == FrameType.CONTROL:
                response_class = ControlResponse

            # Validate the payload
            Response.validate(frame_mv[10:-1])

            # Build the response
            return response_class(frame_mv[10:-1])


class QueryResponse(Response):
    """Response to query command."""

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

        self.supported_modes = []

        self._parse(payload)

    def _parse(self, payload: memoryview) -> None:
        """Parse the query response payload."""

        # Query response starts with an 8 byte header
        # 0x01 - Basic data set
        # 0xFE - Indicates formt of data
        # 2 bytes - Start index in protocol's "key_maps"
        # 2 bytes - End index in "key_maps"
        # 2 bytes - Length of section in bytes
        # Our ControlIds are translated indeces in "key_maps"

        # Validate header
        if payload[0:2] != b"\x01\xfe":
            raise InvalidResponseException(
                f"Query response payload '{payload.hex()}' lacks expected header 0x01FE.")

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

        self.supported_modes = list(payload[26:31])
        self.operational_mode = payload[31]
        self.fan_speed = payload[34]

        self.swing_ud_angle = payload[41]  # Replicated at payload[36]?
        self.swing_lr_angle = payload[43]  # Not replicated?

        self.soft = bool(payload[45])  # Cool mode only, breezeless?
        self.eco = bool(payload[56])
        self.silent = bool(payload[58])
        self.sleep = bool(payload[60])
        self.purifier = bool(payload[75] & 0x01)  # 0x01 - On, 0x02 - Off

        # 0x02 - Force off, 0x01 - Force on, 0x00 - Auto
        self.aux_mode = payload[87]


class ControlResponse(Response):
    """Response to control command."""

    def __init__(self, payload: memoryview) -> None:
        super().__init__(payload)

        self._states = {}

        self._parse(payload)

    def _parse(self, payload: memoryview) -> None:
        """Parse the control response payload."""
        # Clear existing states
        self._states.clear()

        if len(payload) < 6:
            raise InvalidResponseException(
                f"Control response payload '{payload.hex()}' is too short.")

        # Loop through each entry
        # Each entry is 2 byte ID, 1 byte length, N byte value, 1 byte terminator 0xFF
        while len(payload) >= 5:
            # Skip empty states
            size = payload[2]
            if size == 0:
                # Zero length values still are at least 1 byte
                payload = payload[5:]
                continue

            # Unpack 16 bit ID
            (raw_id, ) = struct.unpack(">H", payload[0:2])

            # Covert ID to enumerate type
            try:
                control = ControlId(raw_id)
            except ValueError:
                _LOGGER.warning(
                    "Unknown control ID 0x%04X, Size: %d.", raw_id, size)
                # Advance to next entry
                payload = payload[4+size:]
                continue

            # Parse the property
            try:
                if (value := control.decode(payload[3:])) is not None:
                    self._states.update({control: value})
            except NotImplementedError:
                _LOGGER.warning(
                    "Unsupported control %r, Size: %d.", control, size)

            # Advance to next entry
            payload = payload[4+size:]

    def get_control_state(self, id: ControlId) -> Optional[Any]:
        return self._states.get(id, None)
