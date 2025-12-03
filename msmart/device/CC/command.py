"""Command and repsonse messages for 0xCC devices."""
from __future__ import annotations

import logging
import struct
from enum import IntEnum
from typing import Any, Mapping, Optional, Union

import msmart.crc8 as crc8
from msmart.const import DeviceType, FrameType
from msmart.frame import Frame

_LOGGER = logging.getLogger(__name__)


class InvalidResponseException(Exception):
    pass


class ControlId(IntEnum):
    POWER = 0x0000
    TARGET_TEMPERATURE = 0x0003
    TEMPERATURE_UNIT = 0x000C
    TARGET_HUMIDITY = 0x000F
    MODE = 0x0012
    FAN_SPEED = 0x0015
    VERT_SWING_ANGLE = 0x001C
    HORZ_SWING_ANGLE = 0x001E
    WIND_SENSE = 0x0020  # Untested
    ECO = 0x0028
    SILENT = 0x002A
    SLEEP = 0x002C
    SELF_CLEAN = 0x002E  # Untested
    PURIFIER = 0x003A
    BEEP = 0x003F
    DISPLAY = 0x0040
    AUX_MODE = 0x0043  # Untested

    def decode(self, data: bytes) -> Any:
        """Decode raw control data into a convenient form."""

        if self == ControlId.TARGET_TEMPERATURE:
            return (data[0] / 2.0) - 40
        else:
            return data[0]

    def encode(self, *args, **kwargs) -> bytes:
        """Encode controls into raw form."""

        if self == ControlId.TARGET_TEMPERATURE:
            return bytes([int((2 * args[0]) + 80)])
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
        # TODO Query format doesn't match plugin but seems to work
        payload = bytearray(22)
        payload[0] = 0x01

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
    def construct(cls, frame: bytes) -> Union[ControlResponse, QueryResponse, Response]:
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
        self.target_temperature = 24
        self.indoor_temperature = None
        self.outdoor_temperature = None
        self.fahrenheit = False
        self.target_humidity = 40
        self.indoor_humidity = None
        self.operational_mode = 0
        self.fan_speed = 0
        self.vert_swing_angle = 0
        self.horz_swing_angle = 0
        self.wind_sense = 0
        # self.co2_level = None
        self.eco = False
        self.silent = False
        self.sleep = False
        # self.self_clean = False
        # self.self_clean_time_remaining = None
        self.purifier = 0
        # self.filter_level = None
        self.beep = False
        self.display = False
        self.aux_mode = 0

        # Capablities
        self.target_temperature_min = 17
        self.target_temperature_max = 30
        self.supports_humidity = None
        self.supported_op_modes = None
        self.supports_fan_speed = False
        self.supports_vert_swing_angle = False
        self.supports_horz_swing_angle = False
        self.supports_wind_sense = False
        self.supports_co2_level = False
        self.supports_eco = False
        self.supports_silent = False
        self.supports_sleep = False
        self.supports_self_clean = False
        self.supports_purifier = False
        self.supports_purifier_auto = False
        self.supports_filter_level = False
        self.supported_aux_modes = None

        self._parse(payload)

    def _parse_temperature(self, data: int) -> float:
        return (data / 2.0) - 40

    def _parse(self, payload: memoryview) -> None:
        """Parse the query response payload."""

        # Query response starts with an 8 byte header
        # 0x01 - Basic data set
        # 0xFE - Indicates format of data
        # 2 bytes - Start index in protocol's "key_maps"
        # 2 bytes - End index in "key_maps"
        # 2 bytes - Length of section in bytes
        # Our ControlIds are translated indices in "key_maps"

        # Validate header
        if payload[0:2] != b"\x01\xfe":
            raise InvalidResponseException(
                f"Query response payload '{payload.hex()}' lacks expected header 0x01FE.")

        self.power_on = bool(payload[8])

        self.target_temperature = self._parse_temperature(payload[11])

        self.indoor_temperature = (payload[12] << 8 | payload[13]) / 10.0

        # TODO unverified, sample device returned 0
        if outdoor_temperature := payload[14]:
            self.outdoor_temperature = self._parse_temperature(
                outdoor_temperature)
        else:
            self.outdoor_temperature = None

        # TODO Unsure if these temperatures are setpoints or limits
        # self.target_temperature_auto_min = self._parse_temperature(payload[19])
        # self.target_temperature_auto_max = self._parse_temperature(payload[20])

        self.fahrenheit = bool(payload[21])
        # TODO temperature accuracy at payload[22] # 0 = 1 deg, 1 = 0.5 deg

        # TODO unverified
        self.target_humidity = payload[24]
        if (indoor_humidity := payload[25]) != 0xFF:
            self.indoor_humidity = indoor_humidity
        else:
            self.indoor_humidity = None

        self.operational_mode = payload[31]
        self.fan_speed = payload[34]

        self.vert_swing_angle = payload[41]  # Replicated at payload[36]?
        self.horz_swing_angle = payload[43]  # Not replicated?

        # 0 - "Close", 1 - Follow, 2 - Avoid, 3 - Soft, 4 - Stong
        self.wind_sense = payload[45]

        # TODO fault codes at payload[47:50]

        # TODO unverified, unsupported by sample device
        # self.co2_level = payload[53:55]

        self.eco = bool(payload[56])
        self.silent = bool(payload[58])
        self.sleep = bool(payload[60])

        # TODO unverified, unsupported by sample device
        # self.self_clean = bool(payload[62])
        # self.self_clean_time_remaining = payload[63:65]

        # TODO "leave home" setting could be away/freeze protection?

        self.purifier = payload[75]  # 0 - Auto, 1 - On, 2 - Off

        # TODO unverified, unsupported by sample device
        # self.filter_level = payload[79]

        # TODO unverified, sample device did not respond as expected
        self.beep = bool(payload[80])
        self.display = bool(payload[81])

        # 0 - Auto, 1 - On, 2 - Off, 4 - "Seperate"
        self.aux_mode = payload[87]

    def parse_capabilities(self) -> None:
        """Parse capabilities from the query response payload."""
        payload = self.payload

        # Additional cool/heat min/max temperatures available, but plugin only uses these
        self.target_temperature_min = self._parse_temperature(payload[9])
        self.target_temperature_max = self._parse_temperature(payload[10])

        self.supports_humidity = bool(payload[23])  # TODO unverified

        self.supported_op_modes = list(payload[26:31])

        self.supports_fan_speed = bool(payload[32])

        self.supports_vert_swing_angle = bool(payload[40])
        self.supports_horz_swing_angle = bool(payload[42])

        self.supports_wind_sense = bool(payload[44])

        self.supports_co2_level = bool(payload[52])

        self.supports_eco = bool(payload[55])
        self.supports_silent = bool(payload[57])
        self.supports_sleep = bool(payload[59])

        self.supports_self_clean = bool(payload[61])  # TODO unverified

        self.supports_purifier = bool(payload[73])
        self.supports_purifier_auto = bool(payload[74])  # TODO unverified

        self.supports_filter_level = bool(payload[78])  # TODO unverified

        supports_aux_heat = bool(payload[82])
        if supports_aux_heat:
            self.supported_aux_modes = list(payload[83:87])


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
