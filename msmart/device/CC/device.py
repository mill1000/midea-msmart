from __future__ import annotations

import logging
from typing import Any, Optional, Union, cast

from msmart.base_device import Device
from msmart.const import DeviceType
from msmart.frame import InvalidFrameException
from msmart.utils import MideaIntEnum

from .command import (Command, ControlCommand, ControlId,
                      InvalidResponseException, QueryCommand, QueryResponse,
                      Response)

_LOGGER = logging.getLogger(__name__)


class CommercialAirConditioner(Device):

    class FanSpeed(MideaIntEnum):
        L1 = 0x01
        L2 = 0x02
        L3 = 0x03
        L4 = 0x04
        L5 = 0x05
        L6 = 0x06
        L7 = 0x07
        AUTO = 0x08

        DEFAULT = AUTO

    class OperationalMode(MideaIntEnum):
        FAN = 0x01
        COOL = 0x02
        HEAT = 0x03
        AUTO = 0x05
        DRY = 0x06

        DEFAULT = FAN

    class SwingMode(MideaIntEnum):
        OFF = 0x0
        VERTICAL = 0x1
        HORIZONTAL = 0x2
        BOTH = 0x3

        DEFAULT = OFF

    class SwingAngle(MideaIntEnum):
        CLOSE = 0x00  # TODO unverified
        POS_1 = 0x01
        POS_2 = 0x02
        POS_3 = 0x03
        POS_4 = 0x04
        POS_5 = 0x05
        AUTO = 0x06

        DEFAULT = POS_3

    class PurifierMode(MideaIntEnum):
        AUTO = 0x00
        ON = 0x01
        OFF = 0x02

        DEFAULT = OFF

    class AuxHeatMode(MideaIntEnum):
        AUTO = 0x00
        ON = 0x01
        OFF = 0x02

        DEFAULT = OFF

    # Map control IDs to device properties
    _CONTROL_MAP = {
        ControlId.POWER: lambda s: s._power_state,
        ControlId.TARGET_TEMPERATURE: lambda s: s._target_temperature,
        ControlId.TEMPERATURE_UNIT: lambda s: s._fahrenheit,
        ControlId.TARGET_HUMIDITY: lambda s: s._target_humidity,
        ControlId.MODE: lambda s: s._operational_mode,
        ControlId.FAN_SPEED: lambda s: s._fan_speed,
        ControlId.HORZ_SWING_ANGLE: lambda s: s._horizontal_swing_angle,
        ControlId.VERT_SWING_ANGLE: lambda s: s._vertical_swing_angle,
        ControlId.ECO: lambda s: s._eco,
        ControlId.SILENT: lambda s: False,
        ControlId.SLEEP: lambda s: False,
        ControlId.PURIFIER: lambda s: s._purifier,
        ControlId.AUX_MODE: lambda s: s._aux_mode,
    }

    def __init__(self, ip: str, device_id: int,  port: int, **kwargs) -> None:
        # Remove possible duplicate device_type kwarg
        kwargs.pop("device_type", None)

        super().__init__(ip=ip, port=port, device_id=device_id,
                         device_type=DeviceType.COMMERCIAL_AC, **kwargs)

        self._power_state = False
        self._target_temperature = 17.0
        self._indoor_temperature = None
        self._outdoor_temperature = None
        self._fahrenheit = False
        self._target_humidity = 40
        self._indoor_humidity = None
        self._operational_mode = self.OperationalMode.DEFAULT
        self._fan_speed = self.FanSpeed.DEFAULT
        self._horizontal_swing_angle = self.SwingAngle.DEFAULT
        self._vertical_swing_angle = self.SwingAngle.DEFAULT

        self._eco = False
        self._silent = False
        self._sleep = False
        self._purifier = self.PurifierMode.DEFAULT
        self._aux_mode = self.AuxHeatMode.DEFAULT

        # self._display_on = True # TODO

        self._updated_controls: set[ControlId] = set()

        # Setup default capabilities
        self._min_target_temperature = 17
        self._max_target_temperature = 30

        self._supports_humidity = True

        self._supported_op_modes = cast(
            list[self.OperationalMode], self.OperationalMode.list())
        self._supported_swing_modes = cast(
            list[self.SwingMode], self.SwingMode.list())
        self._supported_fan_speeds = cast(
            list[self.FanSpeed], self.FanSpeed.list())

        self._supports_eco = True
        self._supports_silent = True
        self._supports_sleep = True

        self._supported_purifier_modes = cast(
            list[self.PurifierMode], self.PurifierMode.list())
        self._supported_aux_modes = cast(
            list[self.AuxHeatMode], self.AuxHeatMode.list())

    def _update_state(self, res: Response) -> None:
        """Update the local state from a device state response."""
        if isinstance(res, QueryResponse):
            _LOGGER.debug("Query response payload from device %s: %s",
                          self.id, res)

            self._power_state = res.power_on

            self._target_temperature = res.target_temperature
            self._indoor_temperature = res.indoor_temperature
            self._outdoor_temperature = res.outdoor_temperature
            self._fahrenheit = res.fahrenheit
            self._target_humidity = res.target_humidity
            self._indoor_humidity = res.indoor_humidity

            self._operational_mode = cast(
                self.OperationalMode, self.OperationalMode.get_from_value(res.operational_mode))

            self._fan_speed = cast(
                self.FanSpeed, self.FanSpeed.get_from_value(res.fan_speed))

            self._vertical_swing_angle = cast(
                self.SwingAngle,
                self.SwingAngle.get_from_value(res.vert_swing_angle))

            self._horizontal_swing_angle = cast(
                self.SwingAngle,
                self.SwingAngle.get_from_value(res.horz_swing_angle))

            # TODO wind sense
            # self._soft = res.soft

            self._eco = res.eco
            self._silent = res.silent
            self._sleep = res.sleep

            # self._display_on = res.display  # TODO?

            self._purifier = cast(self.PurifierMode,
                                  self.PurifierMode.get_from_value(res.purifier))

            self._aux_mode = cast(self.AuxHeatMode,
                                  self.AuxHeatMode.get_from_value(res.aux_mode))

        else:
            _LOGGER.debug("Ignored unknown response from device %s: %s",
                          self.id, res)

    def _update_capabilities(self, res: QueryResponse) -> None:
        """Update device capabiltiies."""
        self._min_target_temperature = res.target_temperature_min
        self._max_target_temperature = res.target_temperature_max

        self._supports_humidity = res.supports_humidity

        # Build list of supported operation modes
        assert res.supported_op_modes
        self._supported_op_modes = cast(
            list[self.OperationalMode], [
                self.OperationalMode.get_from_value(mode)
                for mode in res.supported_op_modes
                if mode in {m.value for m in self.OperationalMode}
            ])

        # Build list of supported fan speeds
        if res.supports_fan_speed:
            self._supported_fan_speeds = cast(
                list[self.FanSpeed], self.FanSpeed.list())
        else:
            self._supported_fan_speeds = [self.FanSpeed.AUTO]  # TODO??

        # Build list of supported swing modes
        swing_modes = [self.SwingMode.OFF]
        if res.supports_horz_swing_angle:
            swing_modes.append(self.SwingMode.HORIZONTAL)
        if res.supports_vert_swing_angle:
            swing_modes.append(self.SwingMode.VERTICAL)
        if res.supports_horz_swing_angle and res.supports_vert_swing_angle:
            swing_modes.append(self.SwingMode.BOTH)

        self._supported_swing_modes = swing_modes

        self._supports_eco = res.supports_eco
        self._supports_silent = res.supports_silent
        self._supports_sleep = res.supports_sleep

        # Build list of supported purifier modes
        purifier_modes = [self.PurifierMode.OFF]
        if res.supports_purifier:
            purifier_modes.append(self.PurifierMode.ON)
        if res.supports_purifier_auto:
            purifier_modes.append(self.PurifierMode.AUTO)

        self._supported_purifier_modes = purifier_modes

        # Build list of supported aux heating modes
        assert res.supported_aux_modes
        self._supported_aux_modes = cast(
            list[self.AuxHeatMode], [
                self.AuxHeatMode.get_from_value(mode)
                for mode in res.supported_aux_modes
                if mode in {m.value for m in self.AuxHeatMode}
            ])

    async def _send_commands_get_responses(self, commands: Union[Command, list[Command]]) -> list[Response]:
        """Send a list of commands and return all valid responses."""
        responses: list[bytes] = []
        for cmd in commands if isinstance(commands, list) else [commands]:
            responses.extend(await super()._send_command(cmd))

        # Device is online if any response received
        self._online = len(responses) > 0

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
        self._supported |= self._online and len(valid_responses) > 0

        return valid_responses

    async def get_capabilities(self) -> None:
        """Fetch the device capabilities."""
        # Capabilties are part of query response
        cmd = QueryCommand()
        responses = await self._send_commands_get_responses(cmd)
        if len(responses) == 0:
            _LOGGER.error(
                "Failed to query capabilities from device %s.", self.id)
            return

        response = responses[0]
        if not isinstance(response, QueryResponse):
            _LOGGER.error(
                "Unexpected response from device %s.", self.id)
            return

        # Get capabilities from query response
        _LOGGER.debug("Parsing capabiltiies from query response payload from device %s: %s",
                      self.id, response)
        response.parse_capabilities()

        # Update device capabilities
        self._update_capabilities(response)

    async def refresh(self) -> None:
        """Refresh the local copy of the device state by sending a GetState command."""
        commands = []

        # Always request state updates
        commands.append(QueryCommand())

        # Send all commands and collect responses
        responses = await self._send_commands_get_responses(commands)

        # Update state from responses
        for response in responses:
            self._update_state(response)

    async def apply(self) -> None:
        """Apply the local state to the device."""
        # Check if nothing to apply
        if not len(self._updated_controls):
            return

        # Warn if trying to apply unsupported modes
        if (ControlId.MODE in self._updated_controls and
                self._operational_mode not in self._supported_op_modes):
            _LOGGER.warning(
                "Device %s is not capable of operational mode %r.",  self.id, self._operational_mode)

        if (ControlId.FAN_SPEED in self._updated_controls and
                self._fan_speed not in self._supported_fan_speeds):
            _LOGGER.warning("Device %s is not capable of fan speed %r.",
                            self.id, self._fan_speed)

        if (ControlId.ECO in self._updated_controls and
                self._eco and not self._supports_eco):
            _LOGGER.warning("Device %s is not capable of eco preset.",
                            self.id)

        if (ControlId.SILENT in self._updated_controls and
                self._silent and not self._supports_silent):
            _LOGGER.warning("Device %s is not capable of silent preset.",
                            self.id)

        if (ControlId.SLEEP in self._updated_controls and
                self._sleep and not self._supports_sleep):
            _LOGGER.warning("Device %s is not capable of sleep preset.",
                            self.id)

        if (ControlId.PURIFIER in self._updated_controls and
            self._purifier != self.PurifierMode.OFF and
                self._purifier not in self._supported_purifier_modes):
            _LOGGER.warning("Device %s is not capable of purifier mode %r.",
                            self.id, self._purifier)

        if (ControlId.AUX_MODE in self._updated_controls and
            self._aux_mode != self.AuxHeatMode.OFF and
                self._aux_mode not in self._supported_aux_modes):
            _LOGGER.warning("Device %s is not capable of aux mode %r.",
                            self.id, self._aux_mode)

        # Get current state of updated controls
        controls = {
            k: self._CONTROL_MAP[k](self)
            for k in self._updated_controls & self._CONTROL_MAP.keys()
        }

        # If powering off device, only send the power control
        cmds: list[Command] = []
        if controls.get(ControlId.POWER, None) is False:
            if len(controls) > 1:
                _LOGGER.warning("Device %s powering off. Dropped additional control updates: %s",
                                self.id,
                                {k: v for k, v in controls.items() if k != ControlId.POWER})
            cmds.append(ControlCommand({ControlId.POWER: False}))
        else:
            cmds.append(ControlCommand(controls))

        # Process any state responses from the device
        for response in await self._send_commands_get_responses(cmds):
            self._update_state(response)

        # Clear control
        self._updated_controls.clear()

    @property
    def power_state(self) -> Optional[bool]:
        return self._power_state

    @power_state.setter
    def power_state(self, state: bool) -> None:
        self._power_state = state
        self._updated_controls.add(ControlId.POWER)

    @property
    def min_target_temperature(self) -> int:
        return int(self._min_target_temperature)

    @property
    def max_target_temperature(self) -> int:
        return int(self._max_target_temperature)

    @property
    def target_temperature(self) -> Optional[float]:
        return self._target_temperature

    @target_temperature.setter
    def target_temperature(self, temperature_celsius: float) -> None:
        self._target_temperature = temperature_celsius
        self._updated_controls.add(ControlId.TARGET_TEMPERATURE)

    @property
    def indoor_temperature(self) -> Optional[float]:
        return self._indoor_temperature

    @property
    def outdoor_temperature(self) -> Optional[float]:
        return self._outdoor_temperature

    @property
    def fahrenheit(self) -> Optional[bool]:
        return self._fahrenheit

    @fahrenheit.setter
    def fahrenheit(self, enabled: bool) -> None:
        self._fahrenheit = enabled
        self._updated_controls.add(ControlId.TEMPERATURE_UNIT)

    @property
    def supports_humidity(self) -> bool:
        return self._supports_humidity or False

    @property
    def target_humidity(self) -> Optional[int]:
        return self._target_humidity

    @target_humidity.setter
    def target_humidity(self, humidity: int) -> None:
        self._target_humidity = humidity
        self._updated_controls.add(ControlId.TARGET_HUMIDITY)

    @property
    def indoor_humidity(self) -> Optional[int]:
        return self._indoor_humidity

    @property
    def supported_operation_modes(self) -> list[OperationalMode]:
        return self._supported_op_modes

    @property
    def operational_mode(self) -> OperationalMode:
        return self._operational_mode

    @operational_mode.setter
    def operational_mode(self, mode: OperationalMode) -> None:
        self._operational_mode = mode
        self._updated_controls.add(ControlId.MODE)

    @property
    def supported_fan_speeds(self) -> list[FanSpeed]:
        return self._supported_fan_speeds

    @property
    def fan_speed(self) -> FanSpeed | int:
        return self._fan_speed

    @fan_speed.setter
    def fan_speed(self, speed: FanSpeed | int | float) -> None:
        # Convert float as needed
        if isinstance(speed, float):
            speed = int(speed)

        self._fan_speed = speed
        self._updated_controls.add(ControlId.FAN_SPEED)

    @property
    def supported_swing_modes(self) -> list[SwingMode]:
        return self._supported_swing_modes

    @property
    def swing_mode(self) -> SwingMode:
        swing_mode = self.SwingMode.OFF

        if self._horizontal_swing_angle == self.SwingAngle.AUTO:
            swing_mode |= self.SwingMode.HORIZONTAL

        if self._vertical_swing_angle == self.SwingAngle.AUTO:
            swing_mode |= self.SwingMode.VERTICAL

        return self.SwingMode(swing_mode)

    @swing_mode.setter
    def swing_mode(self, mode: SwingMode) -> None:

        def get_angle(swing, enum, state) -> Optional[self.SwingAngle]:
            if swing & enum:
                return self.SwingAngle.AUTO
            elif state == self.SwingAngle.AUTO:
                return self.SwingAngle.DEFAULT
            return None

        # Enable swing on correct axises
        if horz_angle := get_angle(mode, self.SwingMode.HORIZONTAL, self._horizontal_swing_angle):
            self._horizontal_swing_angle = horz_angle
            self._updated_controls.add(ControlId.HORZ_SWING_ANGLE)

        if vert_angle := get_angle(mode, self.SwingMode.VERTICAL, self._vertical_swing_angle):
            self._vertical_swing_angle = vert_angle
            self._updated_controls.add(ControlId.VERT_SWING_ANGLE)

    @property
    def supports_horizontal_swing_angle(self) -> bool:
        # If device can swing it can control the angle
        return self.SwingMode.HORIZONTAL in self._supported_swing_modes

    @property
    def horizontal_swing_angle(self) -> SwingAngle:
        return self._horizontal_swing_angle

    @horizontal_swing_angle.setter
    def horizontal_swing_angle(self, angle: SwingAngle) -> None:
        self._horizontal_swing_angle = angle
        self._updated_controls.add(ControlId.HORZ_SWING_ANGLE)

    @property
    def supports_vertical_swing_angle(self) -> bool:
        # If device can swing it can control the angle
        return self.SwingMode.VERTICAL in self._supported_swing_modes

    @property
    def vertical_swing_angle(self) -> SwingAngle:
        return self._vertical_swing_angle

    @vertical_swing_angle.setter
    def vertical_swing_angle(self, angle: SwingAngle) -> None:
        self._vertical_swing_angle = angle
        self._updated_controls.add(ControlId.VERT_SWING_ANGLE)

    @property
    def supports_eco(self) -> bool:
        return self._supports_eco or False

    @property
    def eco(self) -> Optional[bool]:
        return self._eco

    @eco.setter
    def eco(self, enabled: bool) -> None:
        self._eco = enabled
        self._updated_controls.add(ControlId.ECO)

    @property
    def supports_silent(self) -> bool:
        return self._supports_silent or False

    @property
    def silent(self) -> Optional[bool]:
        return self._silent

    @silent.setter
    def silent(self, enabled: bool) -> None:
        self._silent = enabled
        self._updated_controls.add(ControlId.SILENT)

    @property
    def supports_sleep(self) -> bool:
        return self._supports_sleep or False

    @property
    def sleep(self) -> Optional[bool]:
        return self._sleep

    @sleep.setter
    def sleep(self, enabled: bool) -> None:
        self._sleep = enabled
        self._updated_controls.add(ControlId.SLEEP)

    @property
    def supported_purifier_modes(self) -> list[PurifierMode]:
        return self._supported_purifier_modes

    @property
    def purifier(self) -> PurifierMode:
        return self._purifier

    @purifier.setter
    def purifier(self, mode: PurifierMode) -> None:
        self._purifier = mode
        self._updated_controls.add(ControlId.PURIFIER)

    @property
    def supported_aux_modes(self) -> list[AuxHeatMode]:
        return self._supported_aux_modes

    @property
    def aux_mode(self) -> AuxHeatMode:
        return self._aux_mode

    @aux_mode.setter
    def aux_mode(self, mode: AuxHeatMode) -> None:
        self._aux_mode = mode
        self._updated_controls.add(ControlId.AUX_MODE)

    # TODO
    # @property
    # def display(self) -> Optional[bool]:
    #     return self._display_on

    # @display.setter
    # def display(self, enabled: bool) -> None:
    #     self._display_on = enabled

    def to_dict(self) -> dict:
        return {**super().to_dict(), **{
            "power": self.power_state,
            "target_temperature": self.target_temperature,
            "indoor_temperature": self.indoor_temperature,
            "outdoor_temperature": self.outdoor_temperature,
            "fahrenheit": self.fahrenheit,
            "target_humidity": self.target_humidity,
            "indoor_humidity": self.indoor_humidity,
            "mode": self.operational_mode,
            "fan_speed": self.fan_speed,
            "swing_mode": self.swing_mode,
            "horizontal_swing_angle": self.horizontal_swing_angle,
            "vertical_swing_angle": self.vertical_swing_angle,
            "eco": self.eco,
            "silent": self.silent,
            "sleep": self.sleep,
            "purifier": self.purifier,
            "aux_mode": self.aux_mode,
            # "display": self.display,
        }}

    def capabilities_dict(self) -> dict:
        return {
            "supported_modes": self.supported_operation_modes,
            "supported_swing_modes": self.supported_swing_modes,
            "supports_horizontal_swing_angle": self.supports_horizontal_swing_angle,
            "supports_vertical_swing_angle": self.supports_vertical_swing_angle,
            "supported_fan_speeds": self.supported_fan_speeds,
            "min_target_temperature": self.min_target_temperature,
            "max_target_temperature": self.max_target_temperature,
            "supports_humidity": self.supports_humidity,
            "supports_eco": self.supports_eco,
            "supports_silent": self.supports_silent,
            "supports_sleep": self.supports_sleep,
            "supported_purifier_modes": self.supported_purifier_modes,
            "supported_aux_modes": self.supported_aux_modes,
        }
