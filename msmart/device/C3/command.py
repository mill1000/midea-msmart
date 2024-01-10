from __future__ import annotations

import logging
import math
import struct
from abc import ABC
from collections import namedtuple
from enum import IntEnum
from typing import Callable, Optional, Union

import msmart.crc8 as crc8
from msmart.base_command import Command
from msmart.const import DeviceType, FrameType

_LOGGER = logging.getLogger(__name__)


class ControlType(IntEnum):
    CONTROL_BASIC = 0x1
    CONTROL_DAY_TIMER = 0x2
    CONTROL_WEEKS_TIMER = 0x3
    CONTROL_HOLIDAY_AWAY = 0x4
    CONTROL_SILENCE = 0x05
    CONTROL_HOLIDAY_HOME = 0x6
    CONTROL_ECO = 0x7
    CONTROL_INSTALL = 0x8
    CONTROL_DISINFECT = 0x9


class QueryType(IntEnum):
    QUERY_BASIC = 0x1
    QUERY_DAY_TIMER = 0x2
    QUERY_WEEKS_TIMER = 0x3
    QUERY_HOLIDAY_AWAY = 0x4
    QUERY_SILENCE = 0x05
    QUERY_HOLIDAY_HOME = 0x6
    QUERY_ECO = 0x7
    QUERY_INSTALL = 0x8
    QUERY_DISINFECT = 0x9


class QueryCommand(Command, ABC):
    """Base class for query commands."""

    def __init__(self, type: QueryType) -> None:
        super().__init__(DeviceType.HEAT_PUMP, frame_type=FrameType.REQUEST)

        self._type = type

    @property
    def payload(self) -> bytes:
        return bytes([
            self._type
        ])


class QueryBasicCommand(QueryCommand):
    """Command to query basic device state."""

    def __init__(self) -> None:
        super().__init__(QueryType.QUERY_BASIC)


class QueryEcoCommand(QueryCommand):
    """Command to query ECO state."""

    def __init__(self) -> None:
        super().__init__(QueryType.QUERY_ECO)


class ControlCommand(Command, ABC):
    """Base class for control commands."""

    def __init__(self, type: ControlType) -> None:
        super().__init__(DeviceType.HEAT_PUMP, frame_type=FrameType.REQUEST)

        self._type = type


class ControlBasicCommand(ControlCommand):
    """Command to control basic device state."""

    def __init__(self) -> None:
        super().__init__(ControlType.CONTROL_BASIC)

        self.zone1_power_state = False
        self.zone2_power_state = False
        self.dhw_power_state = False

        self.run_mode_set = 0  # TODO??

        # TODO default values?
        self.zone1_target_temperature = 0
        self.zone2_target_temperature = 0
        self.dhw_target_temperature = 0
        self.room_target_temperature = 0

        self.zone1_curve_state = False
        self.zone2_curve_state = False

        # TODO forcetbh_state
        self.fastdhw_state = False

        # TODO "newfunction_en"
        self.zone1_curve_type = 0  # TODO??
        self.zone2_curve_type = 0

    @property
    def payload(self) -> bytes:

        payload = [0] * 10

        payload[0] = self._type

        payload[1] |= 1 << 0 if self.zone1_power_state else 0
        payload[1] |= 1 << 1 if self.zone2_power_state else 0
        payload[1] |= 1 << 2 if self.dhw_power_state else 0

        payload[2] = self.run_mode_set
        payload[3] = self.zone1_target_temperature
        payload[4] = self.zone2_target_temperature
        payload[5] = self.dhw_target_temperature
        payload[6] = self.room_target_temperature * 2  # TODO ??

        payload[7] |= 1 << 0 if self.zone1_curve_state else 0
        payload[7] |= 1 << 1 if self.zone2_curve_state else 0
        # payload[7] |= 1 << 2 if self.forcetbh_state else 0
        payload[7] |= 1 << 3 if self.fastdhw_state else 0

        # TODO newfunction_en
        payload[8] = self.zone1_curve_type
        payload[9] = self.zone2_curve_type

        return bytes(payload)
