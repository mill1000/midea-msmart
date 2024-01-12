import logging
import time
from typing import List, Optional

from msmart.const import DeviceType
from msmart.frame import Frame
from msmart.lan import LAN, AuthenticationError, Key, ProtocolError, Token

_LOGGER = logging.getLogger(__name__)


class Device():

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

    async def _send_command(self, command: Frame) -> Optional[List[bytes]]:
        """Send a command to the device and return any responses."""

        data = command.tobytes()
        _LOGGER.debug("Sending command to %s:%d: %s",
                      self.ip, self.port, data.hex())

        start = time.time()
        responses = None
        try:
            responses = await self._lan.send(data)
        except ProtocolError as e:
            _LOGGER.error("Network error %s:%d: %s", self.ip, self.port, e)
            return None
        except TimeoutError as e:
            _LOGGER.warning("Network timeout %s:%d: %s", self.ip, self.port, e)
        finally:
            response_time = round(time.time() - start, 2)

        if responses is None:
            _LOGGER.warning("No response from %s:%d in %f seconds. ",
                            self.ip, self.port, response_time)
            return None

        _LOGGER.debug("Response from %s:%d in %f seconds.",
                      self.ip, self.port, response_time)

        return responses

    async def refresh(self) -> None:
        raise NotImplementedError()

    async def apply(self) -> None:
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

    def __str__(self) -> str:
        return str(self.to_dict())
