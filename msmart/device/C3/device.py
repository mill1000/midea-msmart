"""Module for Midea 0xC3 devices."""
from __future__ import annotations

import logging
from enum import IntEnum
from typing import Optional, Union

from msmart.base_device import Device
from msmart.const import DeviceType
from msmart.frame import InvalidFrameException
from msmart.utils import MideaIntEnum

from .command import (ControlBasicCommand, QueryBasicCommand,
                      QueryBasicResponse, ReportPower4Response, Response)

_LOGGER = logging.getLogger(__name__)


class HeatPump(Device):
    """Device class for heat pump (0xC3) devices."""

    class RunMode(MideaIntEnum):
        """Heat pump run/operation modes."""
        # TODO is 0 off?
        AUTO = 1
        COOL = 2
        HEAT = 3
        DHW = 5

        DEFAULT = AUTO

    class TerminalType(IntEnum):
        """Zone "terminal" type."""
        FAN_COIL = 0
        FLOOR_HEAT = 1
        RADIATOR = 2

    class TemperatureType(IntEnum):
        """Zone temperature type."""
        AIR = 0
        WATER = 1

    class Zone:
        """A zone within the heat pump system."""

        def __init__(self) -> None:
            self._power_state = False
            self._curve_state = False
            self._temperature_type = HeatPump.TemperatureType.AIR
            self._terminal_type = HeatPump.TerminalType.FAN_COIL

            self._target_temperature = 25

            self._min_heat_temperature = 25
            self._max_heat_temperature = 55

            self._min_cool_temperature = 5
            self._max_cool_temperature = 25

        @property
        def power_state(self) -> bool:
            """Power state of the zone."""
            return self._power_state

        @power_state.setter
        def power_state(self, state: bool) -> None:
            self._power_state = state

        @property
        def curve_state(self) -> bool:
            """Curve state of the zone."""
            return self._curve_state

        @curve_state.setter
        def curve_state(self, state: bool) -> None:
            self._curve_state = state

        @property
        def target_temperature(self) -> int:
            """Target temperature of the zone."""
            return self._target_temperature

        @target_temperature.setter
        def target_temperature(self, temperature_celsius: int) -> None:
            self._target_temperature = temperature_celsius

        @property
        def temperature_type(self) -> HeatPump.TemperatureType:
            """Temperature type of the zone."""
            return self._temperature_type

        @property
        def terminal_type(self) -> HeatPump.TerminalType:
            """Terminal type of the zone."""
            return self._terminal_type

    def __init__(self, ip: str, device_id: int,  port: int, **kwargs) -> None:
        # Remove possible duplicate device_type kwarg
        kwargs.pop("device_type", None)

        super().__init__(ip=ip, port=port, device_id=device_id,
                         device_type=DeviceType.HEAT_PUMP, **kwargs)

        self._run_mode = HeatPump.RunMode.DEFAULT
        self._heat_enable = False
        self._cool_enable = False

        self._zone_1 = HeatPump.Zone()
        self._zone_2 = None

        # Domestic hot water
        self._dhw_enable = False
        self._dhw_power_state = False
        self._dhw_target_temperature = 25
        self._dhw_min_temperature = 20
        self._dhw_max_temperature = 60

        # Room thermostat
        self._room_thermostat_enable = False
        self._room_thermostat_power_state = False
        self._room_target_temperature = 25.0
        self._room_min_temperature = 17.0
        self._room_max_temperature = 30.0

        # Misc
        self._tbh_state = False
        self._fastdhw_state = False

        self._tank_temperature = None
        self._outdoor_temperature = None

        self._electric_power = None
        self._thermal_power = None
        self._voltage = None

    def _update_state(self, res: Union[QueryBasicResponse, ReportPower4Response]) -> None:
        """Update local device state from device responses."""

        if isinstance(res, QueryBasicResponse):
            self._run_mode = HeatPump.RunMode.get_from_value(res.run_mode)
            # TODO Run mode in auto?
            self._heat_enable = res.heat_enable
            self._cool_enable = res.cool_enable

            # Create zone 2 if supported
            if res.zone2_enable and self._zone_2 is None:
                self._zone_2 = HeatPump.Zone()

            for i, zone in enumerate([self._zone_1, self._zone_2], start=1):

                # Skip nonexistent zones
                if zone is None:
                    continue

                zone._power_state = getattr(res, f"zone{i}_power_state")
                zone._curve_state = getattr(res, f"zone{i}_curve_state")
                zone._temperature_type = HeatPump.TemperatureType(
                    getattr(res, f"zone{i}_temp_type"))
                zone._terminal_type = HeatPump.TerminalType(getattr(
                    res, f"zone{i}_terminal_type"))

                zone._target_temperature = getattr(
                    res, f"zone{i}_target_temperature")

                zone._min_heat_temperature = getattr(
                    res, f"zone{i}_heat_min_temperature")
                zone._max_heat_temperature = getattr(
                    res, f"zone{i}_heat_max_temperature")

                zone._min_cool_temperature = getattr(
                    res, f"zone{i}_cool_min_temperature")
                zone._max_cool_temperature = getattr(
                    res, f"zone{i}_cool_max_temperature")

            self._dhw_enable = res.dhw_enable
            self._dhw_power_state = res.dhw_power_state
            self._dhw_target_temperature = res.dhw_target_temperature
            self._dhw_min_temperature = res.dhw_min_temperature
            self._dhw_max_temperature = res.dhw_max_temperature

            self._room_thermostat_enable = res.room_thermostat_enable
            self._room_thermostat_power_state = res.room_thermostat_power_state
            self._room_target_temperature = res.room_target_temperature
            self._room_min_temperature = res.room_min_temperature
            self._room_max_temperature = res.room_max_temperature

            self._tbh_state = res.tbh_state
            self._fastdhw_state = res.fastdhw_state

            # TODO time set state, silence state, holiday state, eco state
            # TODO error code

            self._tank_temperature = res.tank_temperature

        elif isinstance(res, ReportPower4Response):

            self._electric_power = res.electric_power
            self._thermal_power = res.thermal_power
            self._outdoor_temperature = res.outdoor_air_temperature
            self._voltage = res.voltage

            # TODO Duplicate water tank temperature reading
            # self._water_temperature_2 = res.water_tank_temperature

    async def _send_command_parse_responses(self, command) -> None:
        """Send a command and parse any responses."""

        responses = await super()._send_command(command)

        # No response from device
        if responses is None:
            self._online = False
            return

        # Device is online if we received any response
        self._online = True

        for data in responses:
            try:
                # Construct response from data
                response = Response.construct(data)
            except InvalidFrameException as e:
                _LOGGER.error(e)
                continue

            # Device is supported if we can process a response
            self._supported = True

            # Parse responses as needed
            if isinstance(response, (QueryBasicResponse, ReportPower4Response)):
                self._update_state(response)
            else:
                _LOGGER.debug("Ignored unknown response from %s:%d: %s",
                              self.ip, self.port, response.payload.hex())

    async def refresh(self) -> None:
        """Refresh the local copy of the device state."""

        # Query basic state
        cmd = QueryBasicCommand()
        await self._send_command_parse_responses(cmd)

    async def apply(self) -> None:
        """Apply the local state to the device."""

        cmd = ControlBasicCommand()
        cmd.run_mode = self._run_mode

        cmd.zone1_power_state = self._zone_1.power_state
        cmd.zone1_target_temperature = self._zone_1.target_temperature
        cmd.zone1_curve_state = self._zone_1.curve_state

        if self._zone_2:
            cmd.zone2_power_state = self._zone_2.power_state
            cmd.zone2_target_temperature = self._zone_2.target_temperature
            cmd.zone2_curve_state = self._zone_2.curve_state

        cmd.dhw_power_state = self._dhw_power_state
        cmd.dhw_target_temperature = self._dhw_target_temperature
        cmd.fastdhw_state = self._fastdhw_state

        cmd.room_target_temperature = self._room_target_temperature

        cmd.tbh_state = self._tbh_state

        await self._send_command_parse_responses(cmd)

    @property
    def zone1(self) -> HeatPump.Zone:
        """Zone 1"""
        return self._zone_1

    @property
    def zone2(self) -> Optional[HeatPump.Zone]:
        """Zone 2 if supported"""
        return self._zone_2

    @property
    def dhw_min_temperature(self) -> int:
        """Minimum target domestic hot water temperature."""
        return self._dhw_min_temperature

    @property
    def dhw_max_temperature(self) -> int:
        """Maximum target domestic hot water temperature."""
        return self._dhw_max_temperature

    @property
    def dhw_target_temperature(self) -> int:
        """Target domestic hot water temperature."""
        return self._dhw_target_temperature

    @dhw_target_temperature.setter
    def dhw_target_temperature(self, temperature_celsius: int) -> None:
        self._dhw_target_temperature = temperature_celsius

    @property
    def water_temperature(self) -> Optional[int]:
        """Current water tank temperature."""
        return self._tank_temperature

    @property
    def outdoor_temperature(self) -> Optional[int]:
        """Current outdoor temperature."""
        return self._outdoor_temperature

    @property
    def electric_power(self) -> Optional[int]:
        """Consumed electric power."""
        return self._electric_power

    @property
    def thermal_power(self) -> Optional[int]:
        """Generated thermal power."""
        return self._thermal_power

    @property
    def voltage(self) -> Optional[int]:
        """Current voltage of the mains."""
        return self._voltage
