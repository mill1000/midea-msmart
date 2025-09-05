from __future__ import annotations

import logging
from typing import Any, Optional, cast

from msmart.base_device import Device
from msmart.const import DeviceType
from msmart.frame import InvalidFrameException
from msmart.utils import MideaIntEnum

from .command import (ControlCommand, QueryCommand, Response,
                      StateResponse)

_LOGGER = logging.getLogger(__name__)


class CommercialCooler(Device):

    class FanSpeed(MideaIntEnum):
        AUTO = 0x80
        POWER = 0x40  # ?
        SUPER_HIGH = 0x20
        HIGH = 0x10
        MEDIUM = 0x08
        LOW = 0x04
        MICRON = 0x02  # ?
        SLEEP = 0x01

        DEFAULT = AUTO

    class OperationalMode(MideaIntEnum):
        AUTO = 0x10
        COOL = 0x08
        HEAT = 0x04
        DRY = 0x02
        FAN = 0x01

        DEFAULT = FAN

    class SwingMode(MideaIntEnum):
        OFF = 0x0
        VERTICAL = 0xC
        HORIZONTAL = 0x3
        BOTH = 0xF

        DEFAULT = OFF

    class SwingAngle(MideaIntEnum):
        OFF = 0
        POS_1 = 1
        POS_2 = 2
        POS_3 = 3
        POS_4 = 4
        POS_5 = 5
        POS_6 = 6

        DEFAULT = OFF

    # PTC Setting?
    class AuxHeatMode(MideaIntEnum):
        AUTO = 0x00
        ON = 0x10
        OFF = 0x20

        DEFAULT = OFF

    def __init__(self, ip: str, device_id: int,  port: int, **kwargs) -> None:
        # Remove possible duplicate device_type kwarg
        kwargs.pop("device_type", None)

        super().__init__(ip=ip, port=port, device_id=device_id,
                         device_type=DeviceType.COMMERCIAL_AC, **kwargs)

        self._power_state = False
        self._target_temperature = 17.0
        self._operational_mode = CommercialCooler.OperationalMode.AUTO
        self._fan_speed = CommercialCooler.FanSpeed.AUTO
        self._swing_mode = CommercialCooler.SwingMode.OFF
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
            list[CommercialCooler.OperationalMode], CommercialCooler.OperationalMode.list())
        self._supported_swing_modes = cast(
            list[CommercialCooler.SwingMode], CommercialCooler.SwingMode.list())
        self._supported_fan_speeds = cast(
            list[CommercialCooler.FanSpeed], CommercialCooler.FanSpeed.list())
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

        self._horizontal_swing_angle = CommercialCooler.SwingAngle.OFF
        self._vertical_swing_angle = CommercialCooler.SwingAngle.OFF

        self._aux_mode = CommercialCooler.AuxHeatMode.OFF
        self._supported_aux_modes = [CommercialCooler.AuxHeatMode.OFF]  # TODO

    def _update_state(self, res: Response) -> None:
        """Update the local state from a device state response."""

        if isinstance(res, StateResponse):
            _LOGGER.debug("State response payload from device %s: %s",
                          self.id, res)

            self._power_state = res.power_on

            self._target_temperature = res.target_temperature
            self._operational_mode = cast(
                CommercialCooler.OperationalMode,
                CommercialCooler.OperationalMode.get_from_value(res.operational_mode))

            if self._supports_custom_fan_speed:
                # Attempt to fetch enum of fan speed, but fallback to raw int if custom
                try:
                    self._fan_speed = CommercialCooler.FanSpeed(
                        cast(int, res.fan_speed))
                except ValueError:
                    self._fan_speed = cast(int, res.fan_speed)
            else:
                self._fan_speed = CommercialCooler.FanSpeed.get_from_value(
                    res.fan_speed)

            self._swing_mode = cast(
                CommercialCooler.SwingMode,
                CommercialCooler.SwingMode.get_from_value(res.swing_mode))

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
                pass
                #  TODO self._aux_mode = CommercialCooler.AuxHeatMode.AUX_ONLY
            elif res.aux_heat:
                pass
                # TODO
                # self._aux_mode = CommercialCooler.AuxHeatMode.AUX_HEAT
            else:
                self._aux_mode = CommercialCooler.AuxHeatMode.OFF
        else:
            _LOGGER.debug("Ignored unknown response from device %s: %s",
                          self.id, res)

    async def _send_command_get_responses(self, command) -> list[Response]:
        """Send a command and return all valid responses."""

        responses = await super()._send_command(command)

        valid_responses = []
        for data in responses:
            try:
                # Construct response from data
                response = Response.construct(data)
            # TODO, InvalidResponseException) as e:
            except (InvalidFrameException) as e:
                _LOGGER.error(e)
                continue

            valid_responses.append(response)

        # Device is supported if we can process any response
        self._supported = len(valid_responses) > 0

        return valid_responses

    async def refresh(self) -> None:
        """Refresh the local copy of the device state by sending a GetState command."""

        commands = []

        # Always request state updates
        commands.append(QueryCommand())

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

        # TODO
        # if self._aux_mode != AirConditioner.AuxHeatMode.OFF and self._aux_mode not in self._supported_aux_modes:
        #     _LOGGER.warning(
        #         "Device is not capable of aux mode %r.", self._aux_mode)

        # Define function to return value or a default if value is None

        def or_default(v, d) -> Any: return v if v is not None else d

        cmd = ControlCommand()
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
        # TODO
        # cmd.aux_heat = self._aux_mode == CommercialCooler.AuxHeatMode.AUX_HEAT
        # cmd.independent_aux_heat = self._aux_mode == CommercialCooler.AuxHeatMode.AUX_ONLY

        # Process any state responses from the device
        for response in await self._send_command_get_responses(cmd):
            self._update_state(response)

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
    def supported_swing_modes(self) -> list[SwingMode]:
        return self._supported_swing_modes

    @property
    def swing_mode(self) -> SwingMode:
        return self._swing_mode

    @swing_mode.setter
    def swing_mode(self, mode: SwingMode) -> None:
        self._swing_mode = mode

    # TODO
    # @property
    # def supports_horizontal_swing_angle(self) -> bool:
    #     return PropertyId.SWING_LR_ANGLE in self._supported_properties

    # @property
    # def horizontal_swing_angle(self) -> SwingAngle:
    #     return self._horizontal_swing_angle

    # @horizontal_swing_angle.setter
    # def horizontal_swing_angle(self, angle: SwingAngle) -> None:
    #     self._horizontal_swing_angle = angle
    #     self._updated_properties.add(PropertyId.SWING_LR_ANGLE)

    # @property
    # def supports_vertical_swing_angle(self) -> bool:
    #     return PropertyId.SWING_UD_ANGLE in self._supported_properties

    # @property
    # def vertical_swing_angle(self) -> SwingAngle:
    #     return self._vertical_swing_angle

    # @vertical_swing_angle.setter
    # def vertical_swing_angle(self, angle: SwingAngle) -> None:
    #     self._vertical_swing_angle = angle
    #     self._updated_properties.add(PropertyId.SWING_UD_ANGLE)

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
            "fahrenheit": self.fahrenheit,
            "filter_alert": self.filter_alert,
            "follow_me": self.follow_me,
            "purifier": self.purifier,
            "aux_mode": self.aux_mode,
        }}
