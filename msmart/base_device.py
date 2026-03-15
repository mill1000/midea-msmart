from __future__ import annotations

import logging
import time
from enum import Enum, Flag
from typing import TYPE_CHECKING, Any, NoReturn, Optional, Union, cast

from msmart.const import DeviceType
from msmart.frame import Frame
from msmart.lan import LAN, AuthenticationError, Key, ProtocolError, Token
from msmart.utils import CapabilityManager

_LOGGER = logging.getLogger(__name__)

if TYPE_CHECKING:
    # Conditionally import device classes for type hints
    from msmart.device import AirConditioner, CommercialAirConditioner


class Device():

    _SUPPORTED_CAPABILITY_OVERRIDES: dict[str, tuple[str, type]] = {}

    def __init__(self, *, ip: str, port: int, device_id: int, device_type: DeviceType, **kwargs) -> None:
        self._ip = ip
        self._port = port

        self._id = device_id
        self._type = device_type
        self._sn = kwargs.get("sn", None)
        self._name = kwargs.get("name", None)
        self._version = kwargs.get("version", None)

        self._lan = LAN(ip, port, device_id)
        self._supported = False
        self._online = False

    async def _send_command(self, command: Frame) -> list[bytes]:
        """Send a command to the device and return any responses."""

        data = command.tobytes()
        _LOGGER.debug("Sending command to %s:%d: %s",
                      self.ip, self.port, data.hex())

        start = time.time()
        responses = []
        try:
            responses = await self._lan.send(data)
        except ProtocolError as e:
            _LOGGER.error("Network error %s:%d: %s", self.ip, self.port, e)
            return []
        except TimeoutError as e:
            _LOGGER.warning("Network timeout %s:%d: %s", self.ip, self.port, e)
        finally:
            response_time = round(time.time() - start, 2)

        if len(responses) == 0:
            _LOGGER.warning("No response from %s:%d in %f seconds.",
                            self.ip, self.port, response_time)
        else:
            _LOGGER.debug("Response from %s:%d in %f seconds.",
                          self.ip, self.port, response_time)

        return responses

    async def refresh(self) -> NoReturn:
        raise NotImplementedError()

    async def apply(self) -> NoReturn:
        raise NotImplementedError()

    async def authenticate(self, token: Token, key: Key) -> None:
        """Authenticate with a V3 device."""
        try:
            await self._lan.authenticate(token, key)
        except (ProtocolError, TimeoutError) as e:
            raise AuthenticationError(e) from e

    def set_max_connection_lifetime(self, seconds: Optional[int]) -> None:
        """Set the maximum connection lifetime of the LAN protocol."""
        self._lan.max_connection_lifetime = seconds

    @property
    def ip(self) -> str:
        return self._ip

    @property
    def port(self) -> int:
        return self._port

    @property
    def id(self) -> int:
        return self._id

    @property
    def token(self) -> Optional[str]:
        if self._lan.token is None:
            return None

        return self._lan.token.hex()

    @property
    def key(self) -> Optional[str]:
        if self._lan.key is None:
            return None

        return self._lan.key.hex()

    @property
    def type(self) -> DeviceType:
        return self._type

    @property
    def name(self) -> Optional[str]:
        return self._name

    @property
    def sn(self) -> Optional[str]:
        return self._sn

    @property
    def version(self) -> Optional[int]:
        return self._version

    @property
    def online(self) -> bool:
        return self._online

    @property
    def supported(self) -> bool:
        return self._supported

    def to_dict(self) -> dict:
        return {
            "ip": self.ip,
            "port": self.port,
            "id": self.id,
            "online": self.online,
            "supported": self.supported,
            "type": self.type,
            "name": self.name,
            "sn": self.sn,
            "key": self.key,
            "token": self.token
        }

    async def capabilities_dict(self) -> dict:
        raise NotImplementedError()

    def __str__(self) -> str:
        return str(self.to_dict())

    def serialize_capabilities(self) -> dict[str, Any]:
        """Dump device capabilities as an easily serializable dict."""
        def _serialize(value) -> Any:
            """Recursively convert values into serializable primitives."""

            if isinstance(value, Enum):
                return value.name

            if isinstance(value, dict):
                return {k: _serialize(v) for k, v in value.items()}

            if isinstance(value, (list, tuple)):
                return [_serialize(v) for v in value]

            if isinstance(value, set):
                return [_serialize(v) for v in value]

            return value

        # Serialize capabilities into basic types
        return _serialize(self.capabilities_dict())

    def override_capabilities(self, overrides: dict[str, Any], *, merge=False) -> None:
        """Override device capabilities via serialized dict."""

        # Get supported overrides
        supported_overrides = self._SUPPORTED_CAPABILITY_OVERRIDES

        # Convert and apply each override
        for key, value in overrides.items():
            # Check if override is allowed
            if key not in supported_overrides:
                raise ValueError(f"Unsupported capabilities override '{key}'.")

            # Get target attribute and value type
            attr_name, value_type = supported_overrides[key]

            # Handle numeric overrides
            if value_type is float:
                # Check if value is numeric
                if not isinstance(value, (float, int)):
                    raise ValueError(f"'{key}' must be a number.")

                # Coerce to float and apply
                setattr(self, attr_name, float(value))
                continue

            # Handle enum overrides
            if issubclass(value_type, Enum):
                # Value should be a list of enum names
                if not isinstance(value, list):
                    raise ValueError(f"'{key}' must be a list.")

                # Attempt to convert from names
                try:
                    members = [value_type[v] for v in value]
                except KeyError as e:
                    raise ValueError(
                        f"Invalid value '{e.args[0]!r}' for '{key}'.")

                # Handle regular enums
                if not issubclass(value_type, Flag):
                    members = list(members)
                    if merge:
                        existing = getattr(self, attr_name)
                        merged_members = set(existing) | set(members)
                        members = list(merged_members)

                    setattr(self, attr_name, members)
                    continue

                # Merge Flag enums into a single value
                flags = value_type(0)
                for m in members:
                    flags |= cast(Flag, m)

                # Handle special case for capability manager
                attr = getattr(self, attr_name)
                if isinstance(attr, CapabilityManager):
                    if merge:
                        attr.set(flags)
                    else:
                        attr.flags = flags
                else:
                    if merge:
                        flags = flags | attr
                    setattr(self, attr_name, flags)

    @classmethod
    def construct(cls, *, type: DeviceType, **kwargs) -> Union[AirConditioner, CommercialAirConditioner, Device]:
        """Construct a device object based on the provided device type."""

        if type == DeviceType.AIR_CONDITIONER:
            from msmart.device import AirConditioner
            return AirConditioner(**kwargs)

        if type == DeviceType.COMMERCIAL_AC:
            from msmart.device import CommercialAirConditioner
            return CommercialAirConditioner(**kwargs)

        # Unknown type return generic device
        return Device(device_type=type, **kwargs)
