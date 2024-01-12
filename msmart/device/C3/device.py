from __future__ import annotations

import logging
from enum import IntEnum
from typing import Any, List, Optional, cast

from msmart.base_command import InvalidFrameException
from msmart.base_device import Device
from msmart.const import DeviceType

from .command import Response

_LOGGER = logging.getLogger(__name__)


class HeatPump(Device):

    def __init__(self, ip: str, device_id: int,  port: int, **kwargs) -> None:
        # Remove possible duplicate device_type kwarg
        kwargs.pop("device_type", None)

        super().__init__(ip=ip, port=port, device_id=device_id,
                         device_type=DeviceType.HEAT_PUMP, **kwargs)

    async def _send_command_get_responses(self, command) -> List[Response]:
        """Send a command and yield an iterator of valid response."""

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
            except InvalidFrameException as e:
                _LOGGER.error(e)
                continue

            # Device is supported if we can process a response
            self._supported = True

            valid_responses.append(response)

        return valid_responses
