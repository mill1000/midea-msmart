from typing import Type

from msmart.base_device import Device
from msmart.const import DeviceType

from .AC.device import AirConditioner
from .CC.device import CommercialAirConditioner


def get_device_class(device_type: DeviceType) -> Type[Device]:
    """Get the device class from the device type."""

    if device_type == DeviceType.AIR_CONDITIONER:
        return AirConditioner

    if device_type == DeviceType.COMMERCIAL_AC:
        return CommercialAirConditioner

    # Unknown type return generic device
    return Device
