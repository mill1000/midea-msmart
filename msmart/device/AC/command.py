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


class ResponseId(IntEnum):
    STATE = 0xC0
    CAPABILITIES = 0xB5
    PROPERTIES_ACK = 0xB0  # In response to property commands
    PROPERTIES = 0xB1


class CapabilityId(IntEnum):
    SWING_UD_ANGLE = 0x0009
    SWING_LR_ANGLE = 0x000A
    SILKY_COOL = 0x0018
    SMART_EYE = 0x0030
    WIND_ON_ME = 0x0032
    WIND_OFF_ME = 0x0033
    SELF_CLEAN = 0x0039  # AKA Active Clean
    ONE_KEY_NO_WIND_ON_ME = 0x0042
    BREEZE_CONTROL = 0x0043  # AKA "FA No Wind Sense"
    RATE_SELECT = 0x0048
    FRESH_AIR = 0x004B
    PARENT_CONTROL = 0x0051  # ??
    PREVENT_STRAIGHT_WIND_SELECT = 0x0058  # ??
    WIND_AROUND = 0x0059  # ??
    JET_COOL = 0x0067  # ??
    IECO_SWITCH = 0x00E3  # ??
    ICHECK = 0x0091  # ??
    EMERGENT_HEAT_WIND = 0x0093  # ??
    HEAT_PTC_WIND = 0x0094  # ??
    CVP = 0x0098  # ??
    FAN_SPEED_CONTROL = 0x0210
    PRESET_ECO = 0x0212
    PRESET_FREEZE_PROTECTION = 0x0213
    MODES = 0x0214
    SWING_MODES = 0x0215
    POWER = 0x0216
    FILTER_REMIND = 0x0217
    AUX_ELECTRIC_HEAT = 0x0219  # AKA PTC
    PRESET_TURBO = 0x021A
    FILTER_CHECK = 0x0221
    ANION = 0x021E
    HUMIDITY = 0x021F
    FAHRENHEIT = 0x0222
    DISPLAY_CONTROL = 0x0224
    TEMPERATURES = 0x0225
    BUZZER = 0x022C  # TODO Reference refers to this as "sound". Is this different then buzzer?
    MAIN_HORIZONTAL_GUIDE_STRIP = 0x0230  # ??
    SUP_HORIZONTAL_GUIDE_STRIP = 0x0231  # ??
    TWINS_MACHINE = 0x0232  # ??
    GUIDE_STRIP_TYPE = 0x0233  # ??
    BODY_CHECK = 0x0234  # ??


class PropertyId(IntEnum):
    SWING_UD_ANGLE = 0x0009
    SWING_LR_ANGLE = 0x000A
    BUZZER = 0x001A
    INDOOR_HUMIDITY = 0x0015  # TODO Reference refers to a potential bug with this
    SELF_CLEAN = 0x0039
    RATE_SELECT = 0x0048
    FRESH_AIR = 0x004B
    ANION = 0x021E


class TemperatureType(IntEnum):
    UNKNOWN = 0
    INDOOR = 0x2
    OUTDOOR = 0x3


class Command(Frame):
    """Base class for AC commands."""

    CONTROL_SOURCE = 0x2  # App control

    _message_id = 0

    def __init__(self, frame_type: FrameType) -> None:
        super().__init__(DeviceType.AIR_CONDITIONER, frame_type)

    def tobytes(self, data: Union[bytes, bytearray] = bytes()) -> bytes:
        # Append message ID to payload
        # TODO Message ID in reference is just a random value
        payload = data + bytes([self._next_message_id()])

        # Append CRC
        return super().tobytes(payload + bytes([crc8.calculate(payload)]))

    def _next_message_id(self) -> int:
        Command._message_id += 1
        return Command._message_id & 0xFF


class GetCapabilitiesCommand(Command):
    """Command to query capabilities of the device."""

    def __init__(self, additional: bool = False) -> None:
        super().__init__(frame_type=FrameType.QUERY)

        self._additional = additional

    def tobytes(self) -> bytes:  # pyright: ignore[reportIncompatibleMethodOverride] # nopep8
        if not self._additional:
            # Get capabilities
            payload = bytes([0xB5, 0x01, 0x00])
        else:
            # Get more capabilities
            payload = bytes([0xB5, 0x01, 0x01, 0x1])
        return super().tobytes(payload)


class GetStateCommand(Command):
    """Command to query basic state of the device."""

    def __init__(self) -> None:
        super().__init__(frame_type=FrameType.QUERY)

        self.temperature_type = TemperatureType.INDOOR

    def tobytes(self) -> bytes:  # pyright: ignore[reportIncompatibleMethodOverride] # nopep8
        return super().tobytes(bytes([
            # Get state
            0x41,
            # Unknown
            0x81, 0x00, 0xFF, 0x03, 0xFF, 0x00,
            # Temperature request
            self.temperature_type,
            # Unknown
            0x00, 0x00, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00,
            # Unknown
            0x03,
        ]))


class SetStateCommand(Command):
    """Command to set basic state of the device."""

    def __init__(self) -> None:
        super().__init__(frame_type=FrameType.CONTROL)

        self.beep_on = True
        self.power_on = False
        self.target_temperature = 25.0
        self.operational_mode = 0
        self.fan_speed = 0
        self.eco_mode = True
        self.swing_mode = 0
        self.turbo_mode = False
        self.fahrenheit = True
        self.sleep_mode = False
        self.freeze_protection_mode = False
        self.follow_me = False

    def tobytes(self) -> bytes:  # pyright: ignore[reportIncompatibleMethodOverride] # nopep8
        # Build beep and power status bytes
        beep = 0x40 if self.beep_on else 0
        power = 0x1 if self.power_on else 0

        # Get integer and fraction components of target temp
        fractional_temp, integral_temp = math.modf(self.target_temperature)
        integral_temp = int(integral_temp)

        if 17 <= integral_temp <= 30:
            # Use primary method
            temperature = (integral_temp - 16) & 0xF
            temperature_alt = 0
        else:
            # Out of range, use alternate method
            # TODO additional range possible according to Lua code
            temperature = 0
            temperature_alt = (integral_temp - 12) & 0x1F

        # Set half degree bit
        temperature |= 0x10 if (fractional_temp > 0) else 0

        mode = (self.operational_mode & 0x7) << 5

        # Build swing mode byte
        swing_mode = 0x30 | (self.swing_mode & 0x3F)

        # Build eco mode byte
        eco_mode = 0x80 if self.eco_mode else 0

        # Build sleep, turbo and fahrenheit byte
        sleep = 0x01 if self.sleep_mode else 0
        turbo = 0x02 if self.turbo_mode else 0
        fahrenheit = 0x04 if self.fahrenheit else 0

        # Build alternate turbo byte
        turbo_alt = 0x20 if self.turbo_mode else 0
        follow_me = 0x80 if self.follow_me else 0

        # Build alternate turbo byte
        freeze_protect = 0x80 if self.freeze_protection_mode else 0

        return super().tobytes(bytes([
            # Set state
            0x40,
            # Beep and power state
            self.CONTROL_SOURCE | beep | power,
            # Temperature and operational mode
            temperature | mode,
            # Fan speed
            self.fan_speed,
            # Unknown
            0x7F, 0x7F, 0x00,
            # Swing mode
            swing_mode,
            # Follow me amd alternate turbo mode
            follow_me | turbo_alt,
            # ECO mode
            eco_mode,
            # Sleep mode, turbo mode and fahrenheit
            sleep | turbo | fahrenheit,
            # Unknown
            0x00, 0x00, 0x00, 0x00,
            0x00, 0x00, 0x00,
            # Alternate temperature
            temperature_alt,
            # Unknown
            0x00, 0x00,
            # Frost/freeze protection
            freeze_protect,
            # Unknown
            0x00, 0x00,
        ]))


class ToggleDisplayCommand(Command):
    """Command to toggle the LED display of the device."""

    def __init__(self) -> None:
        # For whatever reason, toggle display uses a request type...
        super().__init__(frame_type=FrameType.QUERY)

        self.beep_on = True

    def tobytes(self) -> bytes:  # pyright: ignore[reportIncompatibleMethodOverride] # nopep8
        # Set beep bit
        beep = 0x40 if self.beep_on else 0

        return super().tobytes(bytes([
            # Get state
            0x41,
            # Beep and other flags
            self.CONTROL_SOURCE | beep,
            # Unknown
            0x00, 0xFF, 0x02,
            0x00, 0x02, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00,
        ]))


class GetPropertiesCommand(Command):
    """Command to query specific properties from the device."""

    def __init__(self, props: Collection[PropertyId]) -> None:
        super().__init__(frame_type=FrameType.QUERY)

        self._properties = props

    def tobytes(self) -> bytes:  # pyright: ignore[reportIncompatibleMethodOverride] # nopep8
        payload = bytearray([
            0xB1,  # Property request
            len(self._properties),
        ])

        for prop in self._properties:
            payload += struct.pack("<H", prop)

        return super().tobytes(payload)


class SetPropertiesCommand(Command):
    """Command to set specific properties of the device."""

    def __init__(self, props: Mapping[PropertyId, Union[bytes, int]]) -> None:
        super().__init__(frame_type=FrameType.CONTROL)

        self._properties = props

    def tobytes(self) -> bytes:  # pyright: ignore[reportIncompatibleMethodOverride] # nopep8
        payload = bytearray([
            0xB0,  # Property request
            len(self._properties),
        ])

        for prop, value in self._properties.items():
            payload += struct.pack("<H", prop)

            if isinstance(value, int):
                value = bytes([value])

            payload += bytes([len(value)])
            payload += value

        return super().tobytes(payload)


class Response():
    """Base class for AC responses."""

    def __init__(self, payload: memoryview) -> None:
        # Set ID and copy the payload
        self._id = payload[0]
        self._payload = bytes(payload)

    @property
    def id(self) -> int:
        return self._id

    @property
    def payload(self) -> bytes:
        return self._payload

    @classmethod
    def validate(cls, payload: memoryview) -> None:
        """Validate a response by checking the frame checksum and payload CRC."""

        # Some devices use a CRC others seem to use a 2nd checksum
        payload_crc = crc8.calculate(payload[0:-1])
        payload_checksum = Frame.checksum(payload[0:-1])
        if payload_crc != payload[-1] and payload_checksum != payload[-1]:
            raise InvalidResponseException(
                f"Payload '{payload.hex()}' failed CRC and checksum. Received: 0x{payload[-1]:X}, Expected: 0x{payload_crc:X} or 0x{payload_checksum:X}.")

    @classmethod
    def construct(cls, frame: bytes) -> Response:
        """Construct a response object from raw data."""

        # Build a memoryview of the frame for zero-copy slicing
        with memoryview(frame) as frame_mv:
            # Validate the frame
            Frame.validate(frame_mv)

            # Fetch the appropriate response class from the ID
            frame_type = frame_mv[9]
            response_id = frame_mv[10]
            if response_id == ResponseId.STATE:
                response_class = StateResponse
            elif response_id == ResponseId.CAPABILITIES and frame_type == FrameType.QUERY:
                # Some devices have unsolicited "capabilities" responses with a frame type of 0x5
                response_class = CapabilitiesResponse
            elif response_id in [ResponseId.PROPERTIES, ResponseId.PROPERTIES_ACK]:
                response_class = PropertiesResponse
            else:
                response_class = Response

            # Validate the payload CRC
            # ...except for properties which certain devices send invalid CRCs
            if response_class != PropertiesResponse:
                Response.validate(frame_mv[10:-1])

            # Build the response
            return response_class(frame_mv[10:-2])


class CapabilitiesResponse(Response):
    """Response to capabilities query."""

    def __init__(self, payload: memoryview) -> None:
        super().__init__(payload)

        self._capabilities = {}
        self._additional_capabilities = False

        _LOGGER.debug("Capabilities response payload: %s", payload.hex())

        self._parse_capabilities(payload)

        _LOGGER.debug("Raw capabilities: %s", self._capabilities)

    def _parse_capabilities(self, payload: memoryview) -> None:
        # Clear existing capabilities
        self._capabilities.clear()

        # Define some local functions to parse capability values
        def get_value(w) -> Callable[[int], bool]: return lambda v: v == w

        # Define a named tuple that represents a decoder
        reader = namedtuple("decoder", "name read")

        # Create a map of capability ID to decoders
        capability_readers = {
            CapabilityId.ANION: reader("anion", get_value(1)),
            CapabilityId.AUX_ELECTRIC_HEAT: reader("aux_electric_heat", get_value(1)),
            CapabilityId.BREEZE_CONTROL: reader("breeze_control", get_value(1)),
            CapabilityId.BUZZER:  reader("buzzer", get_value(1)),
            CapabilityId.DISPLAY_CONTROL: reader("display_control", lambda v: v in [1, 2, 100]),
            CapabilityId.FAHRENHEIT: reader("fahrenheit", get_value(0)),
            CapabilityId.FAN_SPEED_CONTROL: [
                reader("fan_silent", get_value(6)),
                reader("fan_low", lambda v: v in [3, 4, 5, 6, 7]),
                reader("fan_medium", lambda v: v in [5, 6, 7]),
                reader("fan_high", lambda v: v in [3, 4, 5, 6, 7]),
                reader("fan_auto", lambda v: v in [4, 5, 6]),
                reader("fan_custom", get_value(1)),
            ],
            CapabilityId.FILTER_REMIND: [
                reader("filter_notice", lambda v: v == 1 or v == 2 or v == 4),
                reader("filter_clean", lambda v: v == 3 or v == 4),
            ],
            CapabilityId.HUMIDITY:
            [
                reader("humidity_auto_set", lambda v: v == 1 or v == 2),
                reader("humidity_manual_set", lambda v: v == 2 or v == 3),
            ],
            CapabilityId.MODES: [
                reader("heat_mode", lambda v: v in [1, 2, 4, 6, 7, 9]),
                reader("cool_mode", lambda v: v != 2),
                reader("dry_mode", lambda v: v in [0, 1, 5, 6, 9]),
                reader("auto_mode", lambda v: v in [0, 1, 2, 7, 8, 9]),
            ],
            CapabilityId.ONE_KEY_NO_WIND_ON_ME: reader("one_key_no_wind_on_me", get_value(1)),
            CapabilityId.POWER: [
                reader("power_stats", lambda v: v in [2, 3, 4, 5]),
                reader("power_setting", lambda v: v in [3, 5]),
                reader("power_bcd", lambda v: v in [4, 5]),
            ],
            CapabilityId.PRESET_ECO: [
                reader("eco_mode", get_value(1)),
                reader("eco_mode_2", get_value(2)),
            ],
            CapabilityId.PRESET_FREEZE_PROTECTION: reader("freeze_protection", get_value(1)),
            CapabilityId.PRESET_TURBO:  [
                reader("turbo_heat", lambda v: v == 1 or v == 3),
                reader("turbo_cool", lambda v: v < 2),
            ],
            CapabilityId.SELF_CLEAN:  reader("self_clean", get_value(1)),
            CapabilityId.SILKY_COOL: reader("silky_cool", get_value(1)),
            CapabilityId.SMART_EYE:  reader("smart_eye", get_value(1)),
            CapabilityId.SWING_LR_ANGLE: reader("swing_horizontal_angle", get_value(1)),
            CapabilityId.SWING_UD_ANGLE: reader("swing_vertical_angle", get_value(1)),
            CapabilityId.SWING_MODES: [
                reader("swing_horizontal", lambda v: v == 1 or v == 3),
                reader("swing_vertical", lambda v: v < 2),
            ],
            # CapabilityId.TEMPERATURES too complex to be handled here
            CapabilityId.WIND_OFF_ME:  reader("wind_off_me", get_value(1)),
            CapabilityId.WIND_ON_ME:  reader("wind_on_me", get_value(1)),
        }

        count = payload[1]
        caps = payload[2:]

        # Loop through each capability
        for _ in range(0, count):
            # Stop if out of data
            if len(caps) < 3:
                break

            # Skip empty capabilities
            size = caps[2]
            if size == 0:
                caps = caps[3:]
                continue

            # Unpack 16 bit ID
            (raw_id, ) = struct.unpack("<H", caps[0:2])

            # Covert ID to enumerate type
            try:
                capability_id = CapabilityId(raw_id)
            except ValueError:
                _LOGGER.warning(
                    "Unknown capability. ID: 0x%04X, Size: %d.", raw_id, size)
                # Advanced to next capability
                caps = caps[3+size:]
                continue

            # Fetch first cap value
            value = caps[3]

            # Apply predefined capability reader if it exists
            if capability_id in capability_readers:
                # Local function to apply a reader
                def apply(d, v): return {d.name: d.read(v)}

                reader = capability_readers[capability_id]
                if isinstance(reader, list):
                    # Apply each reader in the list
                    for r in reader:
                        self._capabilities.update(apply(r, value))
                else:
                    # Apply the single reader
                    self._capabilities.update(apply(reader, value))

            elif capability_id == CapabilityId.TEMPERATURES:
                # Skip if capability size is too small
                if size < 6:
                    continue

                self._capabilities["cool_min_temperature"] = caps[3] * 0.5
                self._capabilities["cool_max_temperature"] = caps[4] * 0.5
                self._capabilities["auto_min_temperature"] = caps[5] * 0.5
                self._capabilities["auto_max_temperature"] = caps[6] * 0.5
                self._capabilities["heat_min_temperature"] = caps[7] * 0.5
                self._capabilities["heat_max_temperature"] = caps[8] * 0.5

                # TODO The else of this condition is commented out in reference code
                self._capabilities["decimals"] = (
                    caps[9] if size > 6 else caps[2]) != 0

            else:
                _LOGGER.warning(
                    "Unsupported capability. ID: 0x%04X, Size: %d.", capability_id, size)

            # Advanced to next capability
            caps = caps[3+size:]

        # Check if there are additional capabilities
        if len(caps) > 1:
            self._additional_capabilities = bool(caps[-2])

    def _get_fan_speed(self, speed) -> bool:
        # If any fan_ capability was received, check against them
        if any(k.startswith("fan_") for k in self._capabilities):
            # Assume that a fan capable of custom speeds is capable of any speed
            return self._capabilities.get(f"fan_{speed}", False) or self._capabilities.get("fan_custom", False)

        # Otherwise return a default set for devices that don't send the capability
        return speed in ["low", "medium", "high", "auto"]

    def merge(self, other: CapabilitiesResponse) -> None:
        # Add other's capabilities to ours
        self._capabilities.update(other._capabilities)

        _LOGGER.debug("Merged raw capabilities: %s", self._capabilities)

    @property
    def additional_capabilities(self) -> bool:
        return self._additional_capabilities

    # TODO rethink these properties for fan speed, operation mode and swing mode
    # Surely there's a better way than define props for each possible cap
    @property
    def fan_silent(self) -> bool:
        return self._get_fan_speed("silent")

    @property
    def fan_low(self) -> bool:
        return self._get_fan_speed("low")

    @property
    def fan_medium(self) -> bool:
        return self._get_fan_speed("medium")

    @property
    def fan_high(self) -> bool:
        return self._get_fan_speed("high")

    @property
    def fan_auto(self) -> bool:
        return self._get_fan_speed("auto")

    @property
    def fan_custom(self) -> bool:
        return self._capabilities.get("fan_custom", False)

    @property
    def swing_horizontal_angle(self) -> bool:
        return self._capabilities.get("swing_horizontal_angle", False)

    @property
    def swing_vertical_angle(self) -> bool:
        return self._capabilities.get("swing_vertical_angle", False)

    @property
    def swing_horizontal(self) -> bool:
        return self._capabilities.get("swing_horizontal", False)

    @property
    def swing_vertical(self) -> bool:
        return self._capabilities.get("swing_vertical", False)

    @property
    def swing_both(self) -> bool:
        return self.swing_vertical and self.swing_horizontal

    @property
    def dry_mode(self) -> bool:
        return self._capabilities.get("dry_mode", False)

    @property
    def cool_mode(self) -> bool:
        return self._capabilities.get("cool_mode", False)

    @property
    def heat_mode(self) -> bool:
        return self._capabilities.get("heat_mode", False)

    @property
    def auto_mode(self) -> bool:
        return self._capabilities.get("auto_mode", False)

    @property
    def eco_mode(self) -> bool:
        return self._capabilities.get("eco_mode", False) or self._capabilities.get("eco_mode_2", False)

    @property
    def turbo_mode(self) -> bool:
        return self._capabilities.get("turbo_heat", False) or self._capabilities.get("turbo_cool", False)

    @property
    def freeze_protection_mode(self) -> bool:
        return self._capabilities.get("freeze_protection", False)

    @property
    def display_control(self) -> bool:
        return self._capabilities.get("display_control", False)

    @property
    def filter_reminder(self) -> bool:
        # TODO unsure of difference between filter_notice and filter_clean
        return self._capabilities.get("filter_notice", False)

    @property
    def min_temperature(self) -> int:
        mode = ["cool", "auto", "heat"]
        return min([self._capabilities.get(f"{m}_min_temperature", 16) for m in mode])

    @property
    def max_temperature(self) -> int:
        mode = ["cool", "auto", "heat"]
        return max([self._capabilities.get(f"{m}_max_temperature", 30) for m in mode])


class StateResponse(Response):
    """Response to state query."""

    def __init__(self, payload: memoryview) -> None:
        super().__init__(payload)

        self.power_on = None
        self.target_temperature = None
        self.operational_mode = None
        self.fan_speed = None
        self.swing_mode = None
        self.turbo_mode = None
        self.eco_mode = None
        self.sleep_mode = None
        self.fahrenheit = None
        self.indoor_temperature = None
        self.outdoor_temperature = None
        self.filter_alert = None
        self.display_on = None
        self.freeze_protection_mode = None
        self.follow_me = None

        _LOGGER.debug("State response payload: %s", payload.hex())

        self._parse(payload)

    def _parse(self, payload: memoryview) -> None:

        self.power_on = bool(payload[1] & 0x1)
        # self.imode_resume = payload[1] & 0x4
        # self.timer_mode = (payload[1] & 0x10) > 0
        # self.appliance_error = (payload[1] & 0x80) > 0

        # Unpack target temp and mode byte
        self.target_temperature = (payload[2] & 0xF) + 16.0
        self.target_temperature += 0.5 if payload[2] & 0x10 else 0.0
        self.operational_mode = (payload[2] >> 5) & 0x7

        # Fan speed
        # TODO Fan speed can be auto = 102, or value from 0 - 100
        # On my unit, Low == 40 (LED < 40), Med == 60 (LED < 60), High == 100 (LED < 100)
        self.fan_speed = payload[3]

        # on_timer_value = payload[4]
        # on_timer_minutes = payload[6]
        # self.on_timer = {
        #     'status': ((on_timer_value & 0x80) >> 7) > 0,
        #     'hour': (on_timer_value & 0x7c) >> 2,
        #     'minutes': (on_timer_value & 0x3) | ((on_timer_minutes & 0xf0) >> 4)
        # }

        # off_timer_value = payload[5]
        # off_timer_minutes = payload[6]
        # self.off_timer = {
        #     'status': ((off_timer_value & 0x80) >> 7) > 0,
        #     'hour': (off_timer_value & 0x7c) >> 2,
        #     'minutes': (off_timer_value & 0x3) | (off_timer_minutes & 0xf)
        # }

        # Swing mode
        self.swing_mode = payload[7] & 0xF

        # self.cozy_sleep = payload[8] & 0x03
        # self.save = (payload[8] & 0x08) > 0
        # self.low_frequency_fan = (payload[8] & 0x10) > 0
        self.turbo_mode = bool(payload[8] & 0x20)
        self.follow_me = bool(payload[8] & 0x80)

        self.eco_mode = bool(payload[9] & 0x10)
        # self.child_sleep_mode = (payload[9] & 0x01) > 0
        # self.exchange_air = (payload[9] & 0x02) > 0
        # self.dry_clean = (payload[9] & 0x04) > 0
        # self.aux_heat = (payload[9] & 0x08) > 0
        # self.clean_up = (payload[9] & 0x20) > 0
        # self.temp_unit = (payload[9] & 0x80) > 0

        self.sleep_mode = bool(payload[10] & 0x1)
        self.turbo_mode |= bool(payload[10] & 0x2)
        self.fahrenheit = bool(payload[10] & 0x4)
        # self.catch_cold = (payload[10] & 0x08) > 0
        # self.night_light = (payload[10] & 0x10) > 0
        # self.peak_elec = (payload[10] & 0x20) > 0
        # self.natural_fan = (payload[10] & 0x40) > 0

        # Define a local function to decode temperature values
        def decode_temp(d: int) -> Optional[float]:
            return ((d - 50)/2 if d != 0xFF else None)

        self.indoor_temperature = decode_temp(payload[11])
        self.outdoor_temperature = decode_temp(payload[12])

        # Decode alternate target temperature
        target_temperature_alt = payload[13] & 0x1F
        if target_temperature_alt != 0:
            # TODO additional range possible according to Lua code
            self.target_temperature = target_temperature_alt + 12
            self.target_temperature += 0.5 if payload[2] & 0x10 else 0.0

        self.filter_alert = bool(payload[13] & 0x20)

        self.display_on = (payload[14] != 0x70)

        # Decode additional temperature resolution
        if self.indoor_temperature:
            self.indoor_temperature += (payload[15] & 0xF) / 10

        if self.outdoor_temperature:
            self.outdoor_temperature += (payload[15] >> 4) / 10

        # TODO dudanov/MideaUART humidity set point in byte 19, mask 0x7F

        # TODO Some payloads are shorter than expected. Unsure what, when or why
        # This length was picked arbitrarily from one user's shorter payload
        if len(payload) < 22:
            return

        self.freeze_protection_mode = bool(payload[21] & 0x80)


class PropertiesResponse(Response):
    """Response to properties query."""

    def __init__(self, payload: memoryview) -> None:
        super().__init__(payload)

        self._properties = {}

        _LOGGER.debug("Properties response payload: %s", payload.hex())

        self._parse(payload)

    def _parse(self, payload: memoryview) -> None:
        # Clear existing properties
        self._properties.clear()

        # Define parsing functions for supported properties
        # TODO when a properties has multiple field .e.g fresh air
        # should they be stored all under the fresh_air key or create different
        # keys for each. e.g. capabilities
        parsers = {
            PropertyId.ANION: lambda v: v[0],
            PropertyId.BUZZER: lambda v: None,  # Don't bother parsing buzzer state
            PropertyId.FRESH_AIR: lambda v: (v[0], v[1], v[2]),
            PropertyId.INDOOR_HUMIDITY: lambda v: v[0],
            PropertyId.RATE_SELECT: lambda v: v[0],
            PropertyId.SELF_CLEAN: lambda v: v[0],
            PropertyId.SWING_UD_ANGLE: lambda v: v[0],
            PropertyId.SWING_LR_ANGLE: lambda v: v[0],
        }

        count = payload[1]
        props = payload[2:]

        # Loop through each property
        for _ in range(0, count):
            # Stop if out of data
            if len(props) < 4:
                break

            # Skip empty properties
            size = props[3]
            if size == 0:
                props = props[4:]
                continue

            # Unpack 16 bit ID
            (raw_id, ) = struct.unpack("<H", props[0:2])

            # Covert ID to enumerate type
            try:
                property = PropertyId(raw_id)
            except ValueError:
                _LOGGER.warning(
                    "Unknown property. ID: 0x%04X, Size: %d.", raw_id, size)
                # Advanced to next property
                props = props[4+size:]
                continue

            # Fetch parser for this property
            parser = parsers.get(property, None)

            # Apply parser if it exists
            if parser is not None:
                # Parse the property
                if (value := parser(props[4:])) is not None:
                    self._properties.update({property: value})

            else:
                _LOGGER.warning(
                    "Unsupported property. ID: 0x%04X, Size: %d.", property, size)

            # Advanced to next property
            props = props[4+size:]

    def get_property(self, id: PropertyId) -> Optional[Any]:
        return self._properties.get(id, None)
