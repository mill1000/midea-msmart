from __future__ import annotations

import logging
from typing import Any, Optional, cast

from msmart.base_device import Device
from msmart.const import DeviceType
from msmart.frame import InvalidFrameException
from msmart.utils import MideaIntEnum

from .command import ControlCommand, QueryCommand, Response, StateResponse

_LOGGER = logging.getLogger(__name__)


_MIN_TEMPERATURE = 17
_MAX_TEMPERATURE = 30


class CommercialCooler(Device):

    class FanSpeed(MideaIntEnum):
        OFF = 0x00  # TODO OFF doesn't make sense right?
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
        DRY = 0x06
        # AUTO = 0x10 TODO remote only? No obvious bit

        DEFAULT = FAN

    # TODO Is swing mode the right way to represent this device?
    class SwingMode(MideaIntEnum):
        OFF = 0x0
        VERTICAL = 0x1
        HORIZONTAL = 0x2
        BOTH = 0x3

        DEFAULT = OFF

    class SwingAngle(MideaIntEnum):
        # OFF = 0x00 TODO would off just mean...middle?
        POS_1 = 0x01
        POS_2 = 0x02
        POS_3 = 0x03
        POS_4 = 0x04
        POS_5 = 0x05
        AUTO = 0x06  # TODO 0 might be valid too?

        DEFAULT = POS_3

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
        self._operational_mode = CommercialCooler.OperationalMode.DEFAULT
        self._fan_speed = CommercialCooler.FanSpeed.AUTO
        # self._swing_mode = CommercialCooler.SwingMode.OFF # TODO generate on the fly?
        self._soft = False
        self._eco = False
        self._silent = False
        self._sleep = False
        self._purifier = False
        # self._display_on = False # TODO

        self._horizontal_swing_angle = CommercialCooler.SwingAngle.DEFAULT
        self._vertical_swing_angle = CommercialCooler.SwingAngle.DEFAULT

        self._aux_mode = CommercialCooler.AuxHeatMode.OFF
        # self._aux_heat_on = False # TODO

        # Support all known modes initially
        self._supported_op_modes = cast(
            list[CommercialCooler.OperationalMode], CommercialCooler.OperationalMode.list())
        self._supported_swing_modes = cast(
            list[CommercialCooler.SwingMode], CommercialCooler.SwingMode.list())
        self._supported_fan_speeds = cast(
            list[CommercialCooler.FanSpeed], CommercialCooler.FanSpeed.list())

    def _update_state(self, res: Response) -> None:
        """Update the local state from a device state response."""

        if isinstance(res, StateResponse):
            _LOGGER.debug("State response payload from device %s: %s",
                          self.id, res)

            self._power_state = res.power_on

            self._target_temperature = res.target_temperature
            self._operational_mode = cast(
                CommercialCooler.OperationalMode, CommercialCooler.OperationalMode.get_from_value(res.operational_mode))

            self._fan_speed = cast(
                CommercialCooler.FanSpeed, CommercialCooler.FanSpeed.get_from_value(res.fan_speed))

            self._horizontal_swing_angle = cast(CommercialCooler.SwingAngle,
                                                CommercialCooler.SwingAngle.get_from_value(res.swing_lr_angle))

            self._vertical_swing_angle = cast(CommercialCooler.SwingAngle,
                                              CommercialCooler.SwingAngle.get_from_value(res.swing_ud_angle))

            self._soft = res.soft
            self._eco = res.eco
            self._silent = res.silent
            self._sleep = res.sleep
            self._purifier = res.purifier

            # self._display_on = res.digit_display  # TODO?

            self._aux_mode = cast(CommercialCooler.AuxHeatMode,
                                  CommercialCooler.AuxHeatMode.get_from_value(res.aux_mode))
            # self._aux_heat_on = res.ptc_on # TODO

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

        if self._fan_speed not in self._supported_fan_speeds:
            _LOGGER.warning(
                "Device %s is not capable of fan speed %r.",  self.id, self._fan_speed)

        # Define function to return value or a default if value is None
        def or_default(v, d) -> Any: return v if v is not None else d

        # TODO control command is completely unknown
        cmd = ControlCommand()
        cmd.power_on = or_default(self._power_state, False)
        cmd.target_temperature = or_default(self._target_temperature, 25)
        cmd.operational_mode = self._operational_mode
        cmd.fan_speed = self._fan_speed
        # cmd.swing_lr = bool(self._swing_mode &
        #                     CommercialCooler.SwingMode.HORIZONTAL)
        # cmd.swing_ud = bool(self._swing_mode &
        #                     CommercialCooler.SwingMode.VERTICAL)
        cmd.swing_lr_angle = self._horizontal_swing_angle
        cmd.swing_ud_angle = self._vertical_swing_angle
        cmd.eco = or_default(self._eco, False)
        cmd.sleep = or_default(self._sleep, False)
        cmd.ptc_setting = self._aux_mode
        # cmd.digit_display = self._display_on

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
    def min_target_temperature(self) -> int:
        return _MIN_TEMPERATURE

    @property
    def max_target_temperature(self) -> int:
        return _MAX_TEMPERATURE

    @property
    def target_temperature(self) -> Optional[float]:
        return self._target_temperature

    @target_temperature.setter
    def target_temperature(self, temperature_celsius: float) -> None:
        self._target_temperature = temperature_celsius

    # TODO sensor must exist!
    # @property
    # def indoor_temperature(self) -> Optional[float]:
    #     return self._indoor_temperature

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
    def fan_speed(self) -> FanSpeed | int:
        return self._fan_speed

    @fan_speed.setter
    def fan_speed(self, speed: FanSpeed | int | float) -> None:
        # Convert float as needed
        if isinstance(speed, float):
            speed = int(speed)

        self._fan_speed = speed

    @property
    def swing_mode(self) -> SwingMode:
        swing_mode = CommercialCooler.SwingMode.OFF

        # TODO better to keep a swing_mode attr?
        if self._horizontal_swing_angle == CommercialCooler.SwingAngle.AUTO:
            swing_mode |= CommercialCooler.SwingMode.HORIZONTAL

        if self._vertical_swing_angle == CommercialCooler.SwingAngle.AUTO:
            swing_mode |= CommercialCooler.SwingMode.VERTICAL

        return cast(CommercialCooler.SwingMode, swing_mode)

    @swing_mode.setter
    def swing_mode(self, mode: SwingMode) -> None:
        # Enable swing on correct axises
        if mode & CommercialCooler.SwingMode.HORIZONTAL:
            self._horizontal_swing_angle = CommercialCooler.SwingAngle.AUT
        else:
            self._horizontal_swing_angle = CommercialCooler.SwingAngle.DEFAULT

        if mode & CommercialCooler.SwingMode.VERTICAL:
            self._vertical_swing_angle = CommercialCooler.SwingAngle.AUTO
        else:
            self._horizontal_swing_angle = CommercialCooler.SwingAngle.DEFAULT

    @property
    def horizontal_swing_angle(self) -> SwingAngle:
        return self._horizontal_swing_angle

    @horizontal_swing_angle.setter
    def horizontal_swing_angle(self, angle: SwingAngle) -> None:
        self._horizontal_swing_angle = angle

    @property
    def vertical_swing_angle(self) -> SwingAngle:
        return self._vertical_swing_angle

    @vertical_swing_angle.setter
    def vertical_swing_angle(self, angle: SwingAngle) -> None:
        self._vertical_swing_angle = angle

    @property
    def soft(self) -> Optional[bool]:
        return self._soft

    @soft.setter
    def soft(self, enabled: bool) -> None:
        self._soft = enabled

    @property
    def eco(self) -> Optional[bool]:
        return self._eco

    @eco.setter
    def eco(self, enabled: bool) -> None:
        self._eco = enabled

    @property
    def silent(self) -> Optional[bool]:
        return self._silent

    @silent.setter
    def silent(self, enabled: bool) -> None:
        self._silent = enabled

    @property
    def sleep(self) -> Optional[bool]:
        return self._sleep

    @sleep.setter
    def sleep(self, enabled: bool) -> None:
        self._sleep = enabled

    @property
    def purifier(self) -> Optional[bool]:
        return self._purifier

    @purifier.setter
    def purifier(self, enabled: bool) -> None:
        self._purifier = enabled

    # TODO
    # @property
    # def display(self) -> Optional[bool]:
    #     return self._display_on

    # @display.setter
    # def display(self, enabled: bool) -> None:
    #     self._display_on = enabled

    # TODO
    # @property
    # def aux_heat_on(self) -> Optional[bool]:
    #     return self._aux_heat_on

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
            "eco": self.eco,
            "sleep": self.silent,
            "sleep": self.sleep,
            "purifier": self.purifier,
            # "display": self.display,
            # "aux_heat_on": self.aux_heat_on,
            "aux_mode": self.aux_mode,
        }}
