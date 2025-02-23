from __future__ import annotations

import logging
from typing import Any, Optional, Union, cast

from msmart.base_device import Device
from msmart.const import DeviceType
from msmart.frame import InvalidFrameException
from msmart.utils import MideaIntEnum, deprecated

from .command import (CapabilitiesResponse, EnergyUsageResponse,
                      GetCapabilitiesCommand, GetEnergyUsageCommand,
                      GetHumidityCommand, GetPropertiesCommand,
                      GetStateCommand, HumidityResponse,
                      InvalidResponseException, PropertiesResponse, PropertyId,
                      Response, ResponseId, SetPropertiesCommand,
                      SetStateCommand, StateResponse, ToggleDisplayCommand)

_LOGGER = logging.getLogger(__name__)


class AirConditioner(Device):

    class FanSpeed(MideaIntEnum):
        AUTO = 102
        MAX = 100
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
        SMART_DRY = 6

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

    class RateSelect(MideaIntEnum):
        OFF = 100

        # 2 levels
        GEAR_50 = 50
        GEAR_75 = 75

        # 5 levels
        LEVEL_1 = 1
        LEVEL_2 = 20
        LEVEL_3 = 40
        LEVEL_4 = 60
        LEVEL_5 = 80

        DEFAULT = OFF

    class BreezeMode(MideaIntEnum):
        OFF = 1
        BREEZE_AWAY = 2
        BREEZE_MILD = 3
        BREEZELESS = 4

        DEFAULT = OFF

    class AuxHeatMode(MideaIntEnum):
        OFF = 0
        AUX_HEAT = 1
        AUX_ONLY = 2

        DEFAULT = OFF

    # Create a dict to map attributes to property values
    _PROPERTY_MAP = {
        PropertyId.BREEZE_AWAY: lambda s: s._breeze_mode == AirConditioner.BreezeMode.BREEZE_AWAY,
        PropertyId.BREEZE_CONTROL: lambda s: s._breeze_mode,
        PropertyId.BREEZELESS: lambda s: s._breeze_mode == AirConditioner.BreezeMode.BREEZELESS,
        PropertyId.IECO: lambda s: s._ieco,
        PropertyId.RATE_SELECT: lambda s: s._rate_select,
        PropertyId.SWING_LR_ANGLE: lambda s: s._horizontal_swing_angle,
        PropertyId.SWING_UD_ANGLE: lambda s: s._vertical_swing_angle
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
        self._eco = False
        self._turbo = False
        self._freeze_protection = False
        self._sleep = False
        self._fahrenheit_unit = False  # Display temperature in Fahrenheit
        self._display_on = False
        self._filter_alert = False
        self._follow_me = False
        self._purifier = False
        self._target_humidity = 40

        # Support all known modes initially
        self._supported_op_modes = cast(
            list[AirConditioner.OperationalMode], AirConditioner.OperationalMode.list())
        self._supported_swing_modes = cast(
            list[AirConditioner.SwingMode], AirConditioner.SwingMode.list())
        self._supported_fan_speeds = cast(
            list[AirConditioner.FanSpeed], AirConditioner.FanSpeed.list())
        self._supports_custom_fan_speed = True
        self._supports_eco = True
        self._supports_turbo = True
        self._supports_freeze_protection = True
        self._supports_display_control = True
        self._supports_filter_reminder = True
        self._supports_purifier = True
        self._supports_humidity = False
        self._supports_target_humidity = False
        self._min_target_temperature = 16
        self._max_target_temperature = 30

        self._indoor_temperature = None
        self._indoor_humidity = None
        self._outdoor_temperature = None

        self._request_energy_usage = False
        self._total_energy_usage = None
        self._current_energy_usage = None
        self._real_time_power_usage = None
        self._use_binary_energy = False

        # Default to assuming device can't handle any properties
        self._supported_properties = set()
        self._updated_properties = set()

        self._horizontal_swing_angle = AirConditioner.SwingAngle.OFF
        self._vertical_swing_angle = AirConditioner.SwingAngle.OFF

        self._self_clean_active = False

        self._rate_select = AirConditioner.RateSelect.OFF
        self._supported_rate_selects = [AirConditioner.RateSelect.OFF]

        self._breeze_mode = AirConditioner.BreezeMode.OFF

        self._ieco = False

        self._aux_mode = AirConditioner.AuxHeatMode.OFF
        self._supported_aux_modes = [AirConditioner.AuxHeatMode.OFF]

    def _update_state(self, res: Response) -> None:
        """Update the local state from a device state response."""

        if isinstance(res, StateResponse):
            _LOGGER.debug("State response payload from device %s: %s",
                          self.id, res)

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

            self._eco = res.eco
            self._turbo = res.turbo
            self._freeze_protection = res.freeze_protection
            self._sleep = res.sleep

            self._indoor_temperature = res.indoor_temperature
            self._outdoor_temperature = res.outdoor_temperature

            self._display_on = res.display_on
            self._fahrenheit_unit = res.fahrenheit

            self._filter_alert = res.filter_alert

            self._follow_me = res.follow_me
            self._purifier = res.purifier

            self._target_humidity = res.target_humidity

            if res.independent_aux_heat:
                self._aux_mode = AirConditioner.AuxHeatMode.AUX_ONLY
            elif res.aux_heat:
                self._aux_mode = AirConditioner.AuxHeatMode.AUX_HEAT
            else:
                self._aux_mode = AirConditioner.AuxHeatMode.OFF

        elif isinstance(res, PropertiesResponse):
            _LOGGER.debug(
                "Properties response payload from device %s: %s", self.id, res)

            if (angle := res.get_property(PropertyId.SWING_LR_ANGLE)) is not None:
                self._horizontal_swing_angle = cast(
                    AirConditioner.SwingAngle,
                    AirConditioner.SwingAngle.get_from_value(angle))

            if (angle := res.get_property(PropertyId.SWING_UD_ANGLE)) is not None:
                self._vertical_swing_angle = cast(
                    AirConditioner.SwingAngle,
                    AirConditioner.SwingAngle.get_from_value(angle))

            if (value := res.get_property(PropertyId.SELF_CLEAN)) is not None:
                self._self_clean_active = value

            if (rate := res.get_property(PropertyId.RATE_SELECT)) is not None:
                self._rate_select = cast(
                    AirConditioner.RateSelect,
                    AirConditioner.RateSelect.get_from_value(rate))

            # Breeze control supersedes breeze away and breezeless
            if (value := res.get_property(PropertyId.BREEZE_CONTROL)) is not None:
                self._breeze_mode = (AirConditioner.BreezeMode(value) if value in AirConditioner.BreezeMode.list()
                                     else AirConditioner.BreezeMode.OFF)
            else:
                if (value := res.get_property(PropertyId.BREEZE_AWAY)) is not None:
                    self._breeze_mode = (AirConditioner.BreezeMode.BREEZE_AWAY if value
                                         else AirConditioner.BreezeMode.OFF)

                if (value := res.get_property(PropertyId.BREEZELESS)) is not None:
                    self._breeze_mode = (AirConditioner.BreezeMode.BREEZELESS if value
                                         else AirConditioner.BreezeMode.OFF)

            if (value := res.get_property(PropertyId.IECO)) is not None:
                self._ieco = value

        elif isinstance(res, EnergyUsageResponse):
            _LOGGER.debug("Energy response payload from device %s: %s",
                          self.id, res)

            self._total_energy_usage = res.total_energy_binary if self._use_binary_energy else res.total_energy
            self._current_energy_usage = res.current_energy_binary if self._use_binary_energy else res.current_energy
            self._real_time_power_usage = res.real_time_power_binary if self._use_binary_energy else res.real_time_power

        elif isinstance(res, HumidityResponse):
            _LOGGER.debug(
                "Humidity response payload from device %s: %s", self.id, res)

            self._indoor_humidity = res.humidity

        else:
            _LOGGER.debug("Ignored unknown response from device %s: %s",
                          self.id, res)

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
        if res.target_humidity:
            # Add SMART_DRY support if target humidity is supported
            op_modes.append(AirConditioner.OperationalMode.SMART_DRY)

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
        if res.fan_custom:
            # Include additional MAX speed if custom speeds are supported
            fan_speeds.append(AirConditioner.FanSpeed.MAX)

        self._supported_fan_speeds = fan_speeds
        self._supports_custom_fan_speed = res.fan_custom

        self._supports_eco = res.eco
        self._supports_turbo = res.turbo
        self._supports_freeze_protection = res.freeze_protection

        self._supports_display_control = res.display_control
        self._supports_filter_reminder = res.filter_reminder
        self._supports_purifier = res.anion

        # Build list of supported aux heating modes
        aux_modes = [AirConditioner.AuxHeatMode.OFF]
        if res.aux_electric_heat or res.aux_heat_mode:
            aux_modes.append(AirConditioner.AuxHeatMode.AUX_HEAT)
        if res.aux_mode:
            aux_modes.append(AirConditioner.AuxHeatMode.AUX_ONLY)

        self._supported_aux_modes = aux_modes

        self._min_target_temperature = res.min_temperature
        self._max_target_temperature = res.max_temperature

        # Allow capabilities to enable energy usage requests, but not disable them
        # We've seen devices that claim no capability but return energy data
        self._request_energy_usage |= res.energy_stats

        self._supports_humidity = res.humidity
        self._supports_target_humidity = res.target_humidity

        # Add supported properties based on capabilities
        self._supported_properties.clear()

        if res.swing_vertical_angle:
            self._supported_properties.add(PropertyId.SWING_UD_ANGLE)

        if res.swing_horizontal_angle:
            self._supported_properties.add(PropertyId.SWING_LR_ANGLE)

        if res.self_clean:
            self._supported_properties.add(PropertyId.SELF_CLEAN)

        # Add supported rate select levels
        if (rates := res.rate_select_levels) is not None:
            self._supported_properties.add(PropertyId.RATE_SELECT)

            if rates > 2:
                self._supported_rate_selects = [
                    AirConditioner.RateSelect.OFF,
                    AirConditioner.RateSelect.LEVEL_5,
                    AirConditioner.RateSelect.LEVEL_4,
                    AirConditioner.RateSelect.LEVEL_3,
                    AirConditioner.RateSelect.LEVEL_2,
                    AirConditioner.RateSelect.LEVEL_1,
                ]
            else:
                self._supported_rate_selects = [
                    AirConditioner.RateSelect.OFF,
                    AirConditioner.RateSelect.GEAR_75,
                    AirConditioner.RateSelect.GEAR_50,
                ]

        # Breeze control supersedes breeze away and breezeless
        if res.breeze_control:
            self._supported_properties.add(PropertyId.BREEZE_CONTROL)
        else:
            if res.breeze_away:
                self._supported_properties.add(PropertyId.BREEZE_AWAY)

            if res.breezeless:
                self._supported_properties.add(PropertyId.BREEZELESS)

        if res.ieco:
            self._supported_properties.add(PropertyId.IECO)

    async def _send_command_get_responses(self, command) -> list[Response]:
        """Send a command and return all valid responses."""

        responses = await super()._send_command(command)

        valid_responses = []
        for data in responses:
            try:
                # Construct response from data
                response = Response.construct(data)
            except (InvalidFrameException, InvalidResponseException) as e:
                _LOGGER.error(e)
                continue

            valid_responses.append(response)

        # Device is supported if we can process any response
        self._supported = len(valid_responses) > 0

        return valid_responses

    async def _send_command_get_response_with_id(self, command, response_id: ResponseId) -> Optional[Response]:
        """Send a command and return the first response with a matching ID."""
        for response in await self._send_command_get_responses(command):
            if response.id == response_id:
                return response

            _LOGGER.debug("Ignored response with ID %d from device %s: %s",
                          response.id, self.id, response)

        return None

    async def get_capabilities(self) -> None:
        """Fetch the device capabilities."""

        # Send capabilities request and get a response
        cmd = GetCapabilitiesCommand()
        response = await self._send_command_get_response_with_id(cmd, ResponseId.CAPABILITIES)
        response = cast(CapabilitiesResponse, response)

        if response is None:
            _LOGGER.error(
                "Failed to query capabilities from device %s.", self.id)
            return

        _LOGGER.debug("Capabilities response payload from device %s: %s",
                      self.id, response)
        _LOGGER.debug("Raw capabilities: %s", response.raw_capabilities)

        # Send 2nd capabilities request if needed
        if response.additional_capabilities:
            cmd = GetCapabilitiesCommand(True)
            additional_response = await self._send_command_get_response_with_id(cmd, ResponseId.CAPABILITIES)
            additional_response = cast(
                CapabilitiesResponse, additional_response)

            if additional_response:
                _LOGGER.debug(
                    "Additional capabilities response payload from device %s: %s", self.id, response)

                # Merge additional capabilities
                response.merge(additional_response)

                _LOGGER.debug("Merged raw capabilities: %s",
                              response.raw_capabilities)

            else:
                _LOGGER.warning(
                    "Failed to query additional capabilities from device %s.", self.id)

        # Update device capabilities
        self._update_capabilities(response)

    async def toggle_display(self) -> None:
        """Toggle the device display if the device supports it."""

        if not self._supports_display_control:
            _LOGGER.warning(
                "Device %s is not capable of display control.", self.id)

        cmd = ToggleDisplayCommand()
        cmd.beep_on = self._beep_on
        # Send the command and ignore all responses
        await self._send_command_get_responses(cmd)

        # Force a refresh to get the updated display state
        await self.refresh()

    async def start_self_clean(self) -> None:
        """Start a self cleaning if the device supports it."""

        # Start self clean via properties command
        await self._apply_properties({
            PropertyId.SELF_CLEAN: True,
        })

    async def refresh(self) -> None:
        """Refresh the local copy of the device state by sending a GetState command."""

        commands = []

        # Always request state updates
        commands.append(GetStateCommand())

        # Fetch power stats if supported
        if self._request_energy_usage:
            commands.append(GetEnergyUsageCommand())

        # Fetch humidity if supported
        if self._supports_humidity:
            commands.append(GetHumidityCommand())

        # Update supported properties
        if len(self._supported_properties):
            commands.append(GetPropertiesCommand(self._supported_properties))

        # Send all commands and collect responses
        responses = [
            resp
            for cmd in commands
            for resp in await self._send_command_get_responses(cmd)
        ]

        # Device is online if any response received
        self._online = len(responses) > 0

        # Update state from responses
        for response in responses:
            self._update_state(response)

    async def _apply_properties(self, properties: dict[PropertyId, Union[int, bool]]) -> None:
        """Apply the provided properties to the device."""

        # Warn if attempting to update a property that isn't supported
        for prop in (properties.keys() - self._supported_properties):
            _LOGGER.warning(
                "Device %s is not capable of property %r.", self.id, prop)

        # Always add buzzer property
        properties[PropertyId.BUZZER] = self._beep_on

        # Build command with properties
        cmd = SetPropertiesCommand(properties)
        for response in await self._send_command_get_responses(cmd):
            self._update_state(response)

    async def apply(self) -> None:
        """Apply the local state to the device."""

        # Warn if trying to apply unsupported modes
        if self._operational_mode not in self._supported_op_modes:
            _LOGGER.warning(
                "Device %s is not capable of operational mode %r.",  self.id, self._operational_mode)

        if (self._fan_speed not in self._supported_fan_speeds
                and not self._supports_custom_fan_speed):
            _LOGGER.warning(
                "Device %s is not capable of fan speed %r.",  self.id, self._fan_speed)

        if self._swing_mode not in self._supported_swing_modes:
            _LOGGER.warning(
                "Device %s is not capable of swing mode %r.",  self.id, self._swing_mode)

        if self._turbo and not self._supports_turbo:
            _LOGGER.warning("Device %s is not capable of turbo mode.", self.id)

        if self._eco and not self._supports_eco:
            _LOGGER.warning("Device %s is not capable of eco mode.",  self.id)

        if self._freeze_protection and not self._supports_freeze_protection:
            _LOGGER.warning(
                "Device %s is not capable of freeze protection.", self.id)

        if self._rate_select != AirConditioner.RateSelect.OFF and self._rate_select not in self._supported_rate_selects:
            _LOGGER.warning(
                "Device %s is not capable of rate select %r.",  self.id, self._rate_select)

        if self._aux_mode != AirConditioner.AuxHeatMode.OFF and self._aux_mode not in self._supported_aux_modes:
            _LOGGER.warning(
                "Device is not capable of aux mode %r.", self._aux_mode)

        # Define function to return value or a default if value is None
        def or_default(v, d) -> Any: return v if v is not None else d

        cmd = SetStateCommand()
        cmd.beep_on = self._beep_on
        cmd.power_on = or_default(self._power_state, False)
        cmd.target_temperature = or_default(self._target_temperature, 25)
        cmd.operational_mode = self._operational_mode
        cmd.fan_speed = self._fan_speed
        cmd.swing_mode = self._swing_mode
        cmd.eco = or_default(self._eco, False)
        cmd.turbo = or_default(self._turbo, False)
        cmd.freeze_protection = or_default(
            self._freeze_protection, False)
        cmd.sleep = or_default(self._sleep, False)
        cmd.fahrenheit = or_default(self._fahrenheit_unit, False)
        cmd.follow_me = or_default(self._follow_me, False)
        cmd.purifier = or_default(self._purifier, False)
        cmd.target_humidity = or_default(self._target_humidity, 40)
        cmd.aux_heat = self._aux_mode == AirConditioner.AuxHeatMode.AUX_HEAT
        cmd.independent_aux_heat = self._aux_mode == AirConditioner.AuxHeatMode.AUX_ONLY

        # Process any state responses from the device
        for response in await self._send_command_get_responses(cmd):
            self._update_state(response)

        # Done if no properties need updating
        if not len(self._updated_properties):
            return

        # Get current state of updated properties
        props = {
            k: self._PROPERTY_MAP[k](self)
            for k in self._updated_properties & self._PROPERTY_MAP.keys()
        }

        # Apply new properties
        await self._apply_properties(props)

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
    def fahrenheit(self) -> Optional[bool]:
        return self._fahrenheit_unit

    @fahrenheit.setter
    def fahrenheit(self, enabled: bool) -> None:
        self._fahrenheit_unit = enabled

    @property
    def min_target_temperature(self) -> int:
        return self._min_target_temperature

    @property
    def max_target_temperature(self) -> int:
        return self._max_target_temperature

    @property
    def target_temperature(self) -> Optional[float]:
        return self._target_temperature

    @target_temperature.setter
    def target_temperature(self, temperature_celsius: float) -> None:
        self._target_temperature = temperature_celsius

    @property
    def indoor_temperature(self) -> Optional[float]:
        return self._indoor_temperature

    @property
    def outdoor_temperature(self) -> Optional[float]:
        return self._outdoor_temperature

    @property
    def supported_operation_modes(self) -> list[OperationalMode]:
        return self._supported_op_modes

    @property
    def operational_mode(self) -> OperationalMode:
        return self._operational_mode

    @operational_mode.setter
    def operational_mode(self, mode: OperationalMode) -> None:
        self._operational_mode = mode

    @property
    def supported_fan_speeds(self) -> list[FanSpeed]:
        return self._supported_fan_speeds

    @property
    def supports_custom_fan_speed(self) -> bool:
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
    def supports_breeze_away(self) -> bool:
        return (PropertyId.BREEZE_AWAY in self._supported_properties
                or PropertyId.BREEZE_CONTROL in self._supported_properties)

    @property
    def breeze_away(self) -> Optional[bool]:
        return self._breeze_mode == AirConditioner.BreezeMode.BREEZE_AWAY

    @breeze_away.setter
    def breeze_away(self, enable: bool) -> None:
        self._breeze_mode = (AirConditioner.BreezeMode.BREEZE_AWAY if enable
                             else AirConditioner.BreezeMode.OFF)

        self._updated_properties.add(
            PropertyId.BREEZE_CONTROL if PropertyId.BREEZE_CONTROL in self._supported_properties
            else PropertyId.BREEZE_AWAY)

    @property
    def supports_breeze_mild(self) -> bool:
        return PropertyId.BREEZE_CONTROL in self._supported_properties

    @property
    def breeze_mild(self) -> Optional[bool]:
        return self._breeze_mode == AirConditioner.BreezeMode.BREEZE_MILD

    @breeze_mild.setter
    def breeze_mild(self, enable: bool) -> None:
        self._breeze_mode = (AirConditioner.BreezeMode.BREEZE_MILD if enable
                             else AirConditioner.BreezeMode.OFF)

        self._updated_properties.add(PropertyId.BREEZE_CONTROL)

    @property
    def supports_breezeless(self) -> bool:
        return (PropertyId.BREEZELESS in self._supported_properties
                or PropertyId.BREEZE_CONTROL in self._supported_properties)

    @property
    def breezeless(self) -> Optional[bool]:
        return self._breeze_mode == AirConditioner.BreezeMode.BREEZELESS

    @breezeless.setter
    def breezeless(self, enable: bool) -> None:
        self._breeze_mode = (AirConditioner.BreezeMode.BREEZELESS if enable
                             else AirConditioner.BreezeMode.OFF)

        self._updated_properties.add(
            PropertyId.BREEZE_CONTROL if PropertyId.BREEZE_CONTROL in self._supported_properties
            else PropertyId.BREEZELESS)

    @property
    def supported_swing_modes(self) -> list[SwingMode]:
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
    def supports_eco(self) -> bool:
        return self._supports_eco

    @property
    def eco(self) -> Optional[bool]:
        return self._eco

    @eco.setter
    def eco(self, enabled: bool) -> None:
        self._eco = enabled

    @property
    def supports_ieco(self) -> bool:
        return PropertyId.IECO in self._supported_properties

    @property
    def ieco(self) -> Optional[bool]:
        return self._ieco

    @ieco.setter
    def ieco(self, enabled: bool) -> None:
        self._ieco = enabled
        self._updated_properties.add(PropertyId.IECO)

    @property
    def supports_turbo(self) -> bool:
        return self._supports_turbo

    @property
    def turbo(self) -> Optional[bool]:
        return self._turbo

    @turbo.setter
    def turbo(self, enabled: bool) -> None:
        self._turbo = enabled

    @property
    def supports_freeze_protection(self) -> bool:
        return self._supports_freeze_protection

    @property
    def freeze_protection(self) -> Optional[bool]:
        return self._freeze_protection

    @freeze_protection.setter
    def freeze_protection(self, enabled: bool) -> None:
        self._freeze_protection = enabled

    @property
    def sleep(self) -> Optional[bool]:
        return self._sleep

    @sleep.setter
    def sleep(self, enabled: bool) -> None:
        self._sleep = enabled

    @property
    def follow_me(self) -> Optional[bool]:
        return self._follow_me

    @follow_me.setter
    def follow_me(self, enabled: bool) -> None:
        self._follow_me = enabled

    @property
    def supports_purifier(self) -> bool:
        return self._supports_purifier

    @property
    def purifier(self) -> Optional[bool]:
        return self._purifier

    @purifier.setter
    def purifier(self, enabled: bool) -> None:
        self._purifier = enabled

    @property
    def supports_display_control(self) -> bool:
        return self._supports_display_control

    @property
    def display_on(self) -> Optional[bool]:
        return self._display_on

    @property
    def supports_filter_reminder(self) -> bool:
        return self._supports_filter_reminder

    @property
    def filter_alert(self) -> Optional[bool]:
        return self._filter_alert

    @property
    def use_alternate_energy_format(self) -> bool:
        return self._use_binary_energy

    @use_alternate_energy_format.setter
    def use_alternate_energy_format(self, enable: bool) -> None:
        self._use_binary_energy = enable

    @property
    def enable_energy_usage_requests(self) -> bool:
        return self._request_energy_usage

    @enable_energy_usage_requests.setter
    def enable_energy_usage_requests(self, enable: bool) -> None:
        self._request_energy_usage = enable

    @property
    def total_energy_usage(self) -> Optional[float]:
        return self._total_energy_usage

    @property
    def current_energy_usage(self) -> Optional[float]:
        return self._current_energy_usage

    @property
    def real_time_power_usage(self) -> Optional[float]:
        return self._real_time_power_usage

    @property
    def supports_humidity(self) -> bool:
        return self._supports_humidity

    @property
    def indoor_humidity(self) -> Optional[int]:
        return self._indoor_humidity

    @property
    def supports_target_humidity(self) -> bool:
        return self._supports_target_humidity

    @property
    def target_humidity(self) -> Optional[int]:
        return self._target_humidity

    @target_humidity.setter
    def target_humidity(self, humidity: int) -> None:
        self._target_humidity = humidity

    @property
    def supports_self_clean(self) -> bool:
        return PropertyId.SELF_CLEAN in self._supported_properties

    @property
    def self_clean_active(self) -> bool:
        return self._self_clean_active

    @property
    def supported_rate_selects(self) -> list[RateSelect]:
        return self._supported_rate_selects

    @property
    def rate_select(self) -> RateSelect:
        return self._rate_select

    @rate_select.setter
    def rate_select(self, rate: RateSelect) -> None:
        self._rate_select = rate
        self._updated_properties.add(PropertyId.RATE_SELECT)

    @property
    def supported_aux_modes(self) -> list[AuxHeatMode]:
        return self._supported_aux_modes

    @property
    def aux_mode(self) -> AuxHeatMode:
        return self._aux_mode

    @aux_mode.setter
    def aux_mode(self, mode: AuxHeatMode) -> None:
        self._aux_mode = mode

    def to_dict(self) -> dict:
        return {**super().to_dict(), **{
            "power": self.power_state,
            "mode": self.operational_mode,
            "fan_speed": self.fan_speed,
            "swing_mode": self.swing_mode,
            "horizontal_swing_angle": self.horizontal_swing_angle,
            "vertical_swing_angle": self.vertical_swing_angle,
            "target_temperature": self.target_temperature,
            "indoor_temperature": self.indoor_temperature,
            "outdoor_temperature": self.outdoor_temperature,
            "target_humidity": self.target_humidity,
            "indoor_humidity": self.indoor_humidity,
            "eco": self.eco,
            "turbo": self.turbo,
            "freeze_protection": self.freeze_protection,
            "sleep": self.sleep,
            "display_on": self.display_on,
            "beep": self.beep,
            "fahrenheit": self.fahrenheit,
            "filter_alert": self.filter_alert,
            "follow_me": self.follow_me,
            "purifier": self.purifier,
            "self_clean": self.self_clean_active,
            "total_energy_usage": self.total_energy_usage,
            "current_energy_usage": self.current_energy_usage,
            "real_time_power_usage": self.real_time_power_usage,
            "rate_select": self.rate_select,
            "aux_mode": self.aux_mode,
        }}

    # Deprecated methods and properties
    @property
    @deprecated("supports_eco")
    def supports_eco_mode(self) -> bool:
        return self.supports_eco

    @property
    @deprecated("eco")
    def eco_mode(self) -> Optional[bool]:
        return self.eco

    @eco_mode.setter
    @deprecated("eco")
    def eco_mode(self, enabled: bool) -> None:
        self.eco = enabled

    @property
    @deprecated("supports_freeze_protection")
    def supports_freeze_protection_mode(self) -> bool:
        return self.supports_freeze_protection

    @property
    @deprecated("freeze_protection")
    def freeze_protection_mode(self) -> Optional[bool]:
        return self.freeze_protection

    @freeze_protection_mode.setter
    @deprecated("freeze_protection")
    def freeze_protection_mode(self, enabled: bool) -> None:
        self.freeze_protection = enabled

    @property
    @deprecated("sleep")
    def sleep_mode(self) -> Optional[bool]:
        return self.sleep

    @sleep_mode.setter
    @deprecated("sleep")
    def sleep_mode(self, enabled: bool) -> None:
        self.sleep = enabled

    @property
    @deprecated("supports_turbo")
    def supports_turbo_mode(self) -> bool:
        return self.supports_turbo

    @property
    @deprecated("turbo")
    def turbo_mode(self) -> Optional[bool]:
        return self.turbo

    @turbo_mode.setter
    @deprecated("turbo")
    def turbo_mode(self, enabled: bool) -> None:
        self.turbo = enabled
