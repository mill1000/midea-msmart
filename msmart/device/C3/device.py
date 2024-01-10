from __future__ import annotations

import logging
from enum import IntEnum
from typing import Any, List, Optional, cast

from msmart.base_device import Device
from msmart.const import DeviceType

_LOGGER = logging.getLogger(__name__)

class HeatPump(Device):

    def __init__(self, ip: str, device_id: int,  port: int, **kwargs) -> None:
        # Remove possible duplicate device_type kwarg
        kwargs.pop("device_type", None)

        super().__init__(ip=ip, port=port, device_id=device_id,
                         device_type=DeviceType.HEAT_PUMP, **kwargs)

