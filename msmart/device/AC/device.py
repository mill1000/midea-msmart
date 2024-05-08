from __future__ import annotations

import logging
from typing import Any, List, Optional, Union, cast

from msmart.base_device import Device
from msmart.const import DeviceType
from msmart.frame import InvalidFrameException
from msmart.utils import MideaIntEnum

from .command import (CapabilitiesResponse, GetCapabilitiesCommand,
                      GetPropertiesCommand, GetStateCommand,
                      InvalidResponseException, PropertiesResponse, PropertyId,
                      Response, ResponseId, SetPropertiesCommand,
                      SetStateCommand, StateResponse, ToggleDisplayCommand)

_LOGGER = logging.getLogger(__name__)


class AirConditioner(Device):

    class FanSpeed(MideaIntEnum):
        AUTO = 102
        HIGH = 80
        MEDIUM = 60
        LOW = 40
        SILENT = 20

        DEFAULT = AUTO

    class OperationalMode(MideaIntEnum):
        AUTO = 1
        COOL = 2
        DRY = 3
        HEAT = 4
        FAN_ONLY = 5

        DEFAULT = FAN_ONLY

    class SwingMode(MideaIntEnum):
        OFF = 0x0
        VERTICAL = 0xC
        HORIZONTAL = 0x3
        BOTH = 0xF

        DEFAULT = OFF

    class SwingAngle(MideaIntEnum):
        OFF = 0
        POS_1 = 1
        POS_2 = 25
        POS_3 = 50
        POS_4 = 75
        POS_5 = 100

        DEFAULT = OFF

    # Create a dict to map properties to attribute names
    _PROPERTY_MAP = {
        PropertyId.SWING_LR_ANGLE: "_horizontal_swing_angle",
        PropertyId.SWING_UD_ANGLE: "_vertical_swing_angle"
    }

    def __init__(self, ip: str, device_id: int,  port: int, **kwargs) -> None:
        # Remove possible duplicate device_type kwarg
        kwargs.pop("device_type", None)

        super().__init__(ip=ip, port=port, device_id=device_id,
                         device_type=DeviceType.AIR_CONDITIONER, **kwargs)

        self._beep_on = False
        self._power_state = False
        self._target_temperature = 17.0
        self._operational_mode = AirConditioner.OperationalMode.AUTO
        self._fan_speed = AirConditioner.FanSpeed.AUTO
        self._swing_mode = AirConditioner.SwingMode.OFF
        self._eco_mode = False
        self._turbo_mode = False
        self._freeze_protection_mode = False
        self._sleep_mode = False
        self._fahrenheit_unit = False  # Display temperature in Fahrenheit
        self._display_on = False
        self._filter_alert = False
        self._follow_me = False

        # Support all known modes initially
        self._supported_op_modes = cast(
            List[AirConditioner.OperationalMode], AirConditioner.OperationalMode.list())
        self._supported_swing_modes = cast(
            List[AirConditioner.SwingMode], AirConditioner.SwingMode.list())
        self._supported_fan_speeds = cast(
            List[AirConditioner.FanSpeed], AirConditioner.FanSpeed.list())
        self._supports_custom_fan_speed = True
        self._supports_eco_mode = True
        self._supports_turbo_mode = True
        self._supports_freeze_protection_mode = True
        self._supports_display_control = True
        self._supports_filter_reminder = True
        self._min_target_temperature = 16
        self._max_target_temperature = 30

        self._indoor_temperature = None
        self._outdoor_temperature = None

        # Default to assuming device can't handle any properties
        self._supported_properties = set()
        self._updated_properties = set()

        self._horizontal_swing_angle = AirConditioner.SwingAngle.OFF
        self._vertical_swing_angle = AirConditioner.SwingAngle.OFF

    def _update_state(self, res: Union[StateResponse, PropertiesResponse]) -> None:
        if isinstance(res, StateResponse):

            self._power_state = res.power_on

            self._target_temperature = res.target_temperature
            self._operational_mode = cast(
                AirConditioner.OperationalMode,
                AirConditioner.OperationalMode.get_from_value(res.operational_mode))

            if self._supports_custom_fan_speed:
                # Attempt to fetch enum of fan speed, but fallback to raw int if custom
                try:
                    self._fan_speed = AirConditioner.FanSpeed(
                        cast(int, res.fan_speed))
                except ValueError:
                    self._fan_speed = cast(int, res.fan_speed)
            else:
                self._fan_speed = AirConditioner.FanSpeed.get_from_value(
                    res.fan_speed)

            self._swing_mode = cast(
                AirConditioner.SwingMode,
                AirConditioner.SwingMode.get_from_value(res.swing_mode))

            self._eco_mode = res.eco_mode
            self._turbo_mode = res.turbo_mode
            self._freeze_protection_mode = res.freeze_protection_mode
            self._sleep_mode = res.sleep_mode

            self._indoor_temperature = res.indoor_temperature
            self._outdoor_temperature = res.outdoor_temperature

            self._display_on = res.display_on
            self._fahrenheit_unit = res.fahrenheit

            self._filter_alert = res.filter_alert

            self._follow_me = res.follow_me

        elif isinstance(res, PropertiesResponse):

            if angle := res.get_property(PropertyId.SWING_LR_ANGLE):
                self._horizontal_swing_angle = cast(
                    AirConditioner.SwingAngle,
                    AirConditioner.SwingAngle.get_from_value(angle))

            if angle := res.get_property(PropertyId.SWING_UD_ANGLE):
                self._vertical_swing_angle = cast(
                    AirConditioner.SwingAngle,
                    AirConditioner.SwingAngle.get_from_value(angle))

    def _update_capabilities(self, res: CapabilitiesResponse) -> None:
        # Build list of supported operation modes
        op_modes = [AirConditioner.OperationalMode.FAN_ONLY]
        if res.dry_mode:
            op_modes.append(AirConditioner.OperationalMode.DRY)
        if res.cool_mode:
            op_modes.append(AirConditioner.OperationalMode.COOL)
        if res.heat_mode:
            op_modes.append(AirConditioner.OperationalMode.HEAT)
        if res.auto_mode:
            op_modes.append(AirConditioner.OperationalMode.AUTO)

        self._supported_op_modes = op_modes

        # Build list of supported swing modes
        swing_modes = [AirConditioner.SwingMode.OFF]
        if res.swing_horizontal:
            swing_modes.append(AirConditioner.SwingMode.HORIZONTAL)
        if res.swing_vertical:
            swing_modes.append(AirConditioner.SwingMode.VERTICAL)
        if res.swing_both:
            swing_modes.append(AirConditioner.SwingMode.BOTH)

        self._supported_swing_modes = swing_modes

       # Build list of supported fan speeds
        fan_speeds = []
        if res.fan_silent:
            fan_speeds.append(AirConditioner.FanSpeed.SILENT)
        if res.fan_low:
            fan_speeds.append(AirConditioner.FanSpeed.LOW)
        if res.fan_medium:
            fan_speeds.append(AirConditioner.FanSpeed.MEDIUM)
        if res.fan_high:
            fan_speeds.append(AirConditioner.FanSpeed.HIGH)
        if res.fan_auto:
            fan_speeds.append(AirConditioner.FanSpeed.AUTO)

        self._supported_fan_speeds = fan_speeds
        self._supports_custom_fan_speed = res.fan_custom

        self._supports_eco_mode = res.eco_mode
        self._supports_turbo_mode = res.turbo_mode
        self._supports_freeze_protection_mode = res.freeze_protection_mode

        self._supports_display_control = res.display_control
        self._supports_filter_reminder = res.filter_reminder

        self._min_target_temperature = res.min_temperature
        self._max_target_temperature = res.max_temperature

        self._supported_properties.clear()
        # Add supported properties based on capabilities
        if res.swing_vertical_angle:
            self._supported_properties.add(PropertyId.SWING_UD_ANGLE)

        if res.swing_horizontal_angle:
            self._supported_properties.add(PropertyId.SWING_LR_ANGLE)

    def _process_state_response(self, response: Response) -> None:
        """Update the local state from a device state response."""

        if isinstance(response, (StateResponse, PropertiesResponse)):
            self._update_state(response)
        else:
            _LOGGER.debug("Ignored unknown response from %s:%d: %s",
                          self.ip, self.port, response.payload.hex())

    async def _send_command_get_responses(self, command) -> List[Response]:
        """Send a command and return all valid responses."""

        responses = await super()._send_command(command)

        # No response from device
        if responses is None:
            self._online = False
            return []

        # Device is online if we received any response
        self._online = True

        valid_responses = []
        for data in responses:
            try:
                # Construct response from data
                response = Response.construct(data)
            except (InvalidFrameException, InvalidResponseException) as e:
                _LOGGER.error(e)
                continue

            # Device is supported if we can process a response
            self._supported = True

            valid_responses.append(response)

        return valid_responses

    async def _send_command_get_response_with_id(self, command, response_id: ResponseId) -> Optional[Response]:
        """Send a command and return the first response with a matching ID."""
        for response in await self._send_command_get_responses(command):
            if response.id == response_id:
                return response

            _LOGGER.debug("Ignored response with ID %d from %s:%d: %s",
                          response.id, self.ip, self.port, response.payload.hex())

        return None

    async def get_capabilities(self) -> None:
        """Fetch the device capabilities."""

        # Send capabilities request and get a response
        cmd = GetCapabilitiesCommand()
        response = await self._send_command_get_response_with_id(cmd, ResponseId.CAPABILITIES)
        response = cast(CapabilitiesResponse, response)

        if response is None:
            _LOGGER.error("Failed to query device capabilities.")
            return

        # Send 2nd capabilities request if needed
        if response.additional_capabilities:
            cmd = GetCapabilitiesCommand(True)
            additional_response = await self._send_command_get_response_with_id(cmd, ResponseId.CAPABILITIES)
            additional_response = cast(
                CapabilitiesResponse, additional_response)

            if additional_response:
                # Merge additional capabilities
                response.merge(additional_response)
            else:
                _LOGGER.warning(
                    "Failed to query additional device capabilities.")

        # Update device capabilities
        self._update_capabilities(response)

    async def toggle_display(self) -> None:
        """Toggle the device display if the device supports it."""

        if not self._supports_display_control:
            _LOGGER.warning("Device is not capable of display control.")

        cmd = ToggleDisplayCommand()
        cmd.beep_on = self._beep_on
        # Send the command and ignore all responses
        await self._send_command_get_responses(cmd)

        # Force a refresh to get the updated display state
        await self.refresh()

    async def refresh(self) -> None:
        """Refresh the local copy of the device state by sending a GetState command."""

        cmd = GetStateCommand()
        # Process any state responses from the device
        for response in await self._send_command_get_responses(cmd):
            self._process_state_response(response)

        # Update supported properties
        if len(self._supported_properties):
            cmd = GetPropertiesCommand(self._supported_properties)
            for response in await self._send_command_get_responses(cmd):
                self._process_state_response(response)

    async def apply(self) -> None:
        """Apply the local state to the device."""

        # Warn if trying to apply unsupported modes
        if self._operational_mode not in self._supported_op_modes:
            _LOGGER.warning(
                "Device is not capable of operational mode %s.", self._operational_mode)

        if (self._fan_speed not in self._supported_fan_speeds
                and not self._supports_custom_fan_speed):
            _LOGGER.warning(
                "Device is not capable of fan speed %s.", self._fan_speed)

        if self._swing_mode not in self._supported_swing_modes:
            _LOGGER.warning(
                "Device is not capable of swing mode %s.", self._swing_mode)

        if self._turbo_mode and not self._supports_turbo_mode:
            _LOGGER.warning("Device is not capable of turbo mode.")

        if self._eco_mode and not self._supports_eco_mode:
            _LOGGER.warning("Device is not capable of eco mode.")

        if self._freeze_protection_mode and not self._supports_freeze_protection_mode:
            _LOGGER.warning("Device is not capable of freeze protection.")

        # Define function to return value or a default if value is None
        def or_default(v, d) -> Any: return v if v is not None else d

        cmd = SetStateCommand()
        cmd.beep_on = self._beep_on
        cmd.power_on = or_default(self._power_state, False)
        cmd.target_temperature = or_default(
            self._target_temperature, 25)  # TODO?
        cmd.operational_mode = self._operational_mode
        cmd.fan_speed = self._fan_speed
        cmd.swing_mode = self._swing_mode
        cmd.eco_mode = or_default(self._eco_mode, False)
        cmd.turbo_mode = or_default(self._turbo_mode, False)
        cmd.freeze_protection_mode = or_default(
            self._freeze_protection_mode, False)
        cmd.sleep_mode = or_default(self._sleep_mode, False)
        cmd.fahrenheit = or_default(self._fahrenheit_unit, False)
        cmd.follow_me = or_default(self._follow_me, False)

        # Process any state responses from the device
        for response in await self._send_command_get_responses(cmd):
            self._process_state_response(response)

        # Done if no properties need updating
        if not len(self._updated_properties):
            return

        # Warn if attempting to update a property that isn't supported
        for prop in (self._updated_properties - self._supported_properties):
            _LOGGER.warning("Device is not capable of property %s.", prop)

        # Get current state of updated properties
        props = {
            k: getattr(self, self._PROPERTY_MAP[k])
            for k in self._updated_properties & self._PROPERTY_MAP.keys()
        }

        # Always add buzzer property
        props[PropertyId.BUZZER] = self._beep_on

        # Build command with properties
        cmd = SetPropertiesCommand(props)
        for response in await self._send_command_get_responses(cmd):
            self._process_state_response(response)

        # Reset updated properties set
        self._updated_properties.clear()

    @property
    def beep(self) -> bool:
        return self._beep_on

    @beep.setter
    def beep(self, tone: bool) -> None:
        self._beep_on = tone

    @property
    def power_state(self) -> Optional[bool]:
        return self._power_state

    @power_state.setter
    def power_state(self, state: bool) -> None:
        self._power_state = state

    @property
    def min_target_temperature(self) -> Optional[int]:
        return self._min_target_temperature

    @property
    def max_target_temperature(self) -> Optional[int]:
        return self._max_target_temperature

    @property
    def target_temperature(self) -> Optional[float]:
        return self._target_temperature

    @target_temperature.setter
    def target_temperature(self, temperature_celsius: float) -> None:
        self._target_temperature = temperature_celsius

    @property
    def supported_operation_modes(self) -> List[OperationalMode]:
        return self._supported_op_modes

    @property
    def operational_mode(self) -> OperationalMode:
        return self._operational_mode

    @operational_mode.setter
    def operational_mode(self, mode: OperationalMode) -> None:
        self._operational_mode = mode

    @property
    def supported_fan_speeds(self) -> List[FanSpeed]:
        return self._supported_fan_speeds

    @property
    def supports_custom_fan_speed(self) -> Optional[bool]:
        return self._supports_custom_fan_speed

    @property
    def fan_speed(self) -> FanSpeed | int:
        return self._fan_speed

    @fan_speed.setter
    def fan_speed(self, speed: FanSpeed | int | float) -> None:
        # Convert float as needed
        if isinstance(speed, float):
            speed = int(speed)

        self._fan_speed = speed

    @property
    def supported_swing_modes(self) -> List[SwingMode]:
        return self._supported_swing_modes

    @property
    def swing_mode(self) -> SwingMode:
        return self._swing_mode

    @swing_mode.setter
    def swing_mode(self, mode: SwingMode) -> None:
        self._swing_mode = mode

    @property
    def supports_horizontal_swing_angle(self) -> bool:
        return PropertyId.SWING_LR_ANGLE in self._supported_properties

    @property
    def horizontal_swing_angle(self) -> SwingAngle:
        return self._horizontal_swing_angle

    @horizontal_swing_angle.setter
    def horizontal_swing_angle(self, angle: SwingAngle) -> None:
        self._horizontal_swing_angle = angle
        self._updated_properties.add(PropertyId.SWING_LR_ANGLE)

    @property
    def supports_vertical_swing_angle(self) -> bool:
        return PropertyId.SWING_UD_ANGLE in self._supported_properties

    @property
    def vertical_swing_angle(self) -> SwingAngle:
        return self._vertical_swing_angle

    @vertical_swing_angle.setter
    def vertical_swing_angle(self, angle: SwingAngle) -> None:
        self._vertical_swing_angle = angle
        self._updated_properties.add(PropertyId.SWING_UD_ANGLE)

    @property
    def supports_eco_mode(self) -> Optional[bool]:
        return self._supports_eco_mode

    @property
    def eco_mode(self) -> Optional[bool]:
        return self._eco_mode

    @eco_mode.setter
    def eco_mode(self, enabled: bool) -> None:
        self._eco_mode = enabled

    @property
    def supports_turbo_mode(self) -> Optional[bool]:
        return self._supports_turbo_mode

    @property
    def turbo_mode(self) -> Optional[bool]:
        return self._turbo_mode

    @turbo_mode.setter
    def turbo_mode(self, enabled: bool) -> None:
        self._turbo_mode = enabled

    @property
    def supports_freeze_protection_mode(self) -> Optional[bool]:
        return self._supports_freeze_protection_mode

    @property
    def freeze_protection_mode(self) -> Optional[bool]:
        return self._freeze_protection_mode

    @freeze_protection_mode.setter
    def freeze_protection_mode(self, enabled: bool) -> None:
        self._freeze_protection_mode = enabled

    @property
    def sleep_mode(self) -> Optional[bool]:
        return self._sleep_mode

    @sleep_mode.setter
    def sleep_mode(self, enabled: bool) -> None:
        self._sleep_mode = enabled

    @property
    def fahrenheit(self) -> Optional[bool]:
        return self._fahrenheit_unit

    @fahrenheit.setter
    def fahrenheit(self, enabled: bool) -> None:
        self._fahrenheit_unit = enabled

    @property
    def follow_me(self) -> Optional[bool]:
        return self._follow_me

    @follow_me.setter
    def follow_me(self, enabled: bool) -> None:
        self._follow_me = enabled

    @property
    def display_on(self) -> Optional[bool]:
        return self._display_on

    @property
    def filter_alert(self) -> Optional[bool]:
        return self._filter_alert

    @property
    def indoor_temperature(self) -> Optional[float]:
        return self._indoor_temperature

    @property
    def outdoor_temperature(self) -> Optional[float]:
        return self._outdoor_temperature

    @property
    def supports_display_control(self) -> Optional[bool]:
        return self._supports_display_control

    @property
    def supports_filter_reminder(self) -> Optional[bool]:
        return self._supports_filter_reminder

    def to_dict(self) -> dict:
        return {**super().to_dict(), **{
            "power": self.power_state,
            "mode": self.operational_mode,
            "fan_speed": self.fan_speed,
            "swing_mode": self.swing_mode,
            "target_temperature": self.target_temperature,
            "indoor_temperature": self.indoor_temperature,
            "outdoor_temperature": self.outdoor_temperature,
            "eco": self.eco_mode,
            "turbo": self.turbo_mode,
            "freeze_protection": self.freeze_protection_mode,
            "sleep": self.sleep_mode,
            "follow_me": self.follow_me,
            "display_on": self.display_on,
            "beep": self.beep,
            "fahrenheit": self.fahrenheit,
        }}
