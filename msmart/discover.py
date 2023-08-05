"""Discovery module for Midea AC devices."""
import asyncio
import logging
import socket
import ipaddress
import xml.etree.ElementTree as ET
from typing import Optional, cast

from msmart.const import (
    DISCOVERY_MSG,
    DEVICE_INFO_MSG,
    OPEN_MIDEA_APP_ACCOUNT,
    OPEN_MIDEA_APP_PASSWORD,
    DeviceId
)
from msmart.security import Security
from msmart.cloud import cloud
from msmart.device import device, air_conditioning

_LOGGER = logging.getLogger(__name__)

_IPV4_BROADCAST = "255.255.255.255"


class _V1DeviceInfoProtocol(asyncio.Protocol):
    """V1 device info protocol."""

    def __init__(self):
        self._transport = None

    def connection_made(self, transport) -> None:
        """Send device info request on connection."""

        self._transport = transport
        transport.write(DEVICE_INFO_MSG)

    def data_received(self, data) -> None:
        """Handle device info responses."""

        _LOGGER.debug("Device info response: %s", data.decode())

        self.response = data

    def error_received(self, ex):
        """Handle asyncio.Protocol errors."""
        _LOGGER.error("Got error: %s", ex)

    def connection_lost(self, ex):
        """NOP implementation of connection lost."""


class _DiscoverProtocol(asyncio.DatagramProtocol):
    """Midea broadcast discovery protocol"""

    def __init__(
        self,
        *,
        target: str = _IPV4_BROADCAST,
        discovery_packets: int = 3,
        interface: Optional[str] = None,
    ):
        self._transport = None
        self._discovery_packets = discovery_packets
        self._interface = interface
        self._target = target
        self._discovered_ips = set()

        self.tasks = set()

    def connection_made(self, transport) -> None:
        """Set socket options for broadcasting."""

        self._transport = transport

        # Set broadcast if broadcasting
        if self._target == _IPV4_BROADCAST:
            sock = transport.get_extra_info("socket")
            sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)

        if self._interface is not None:
            sock.setsockopt(
                socket.SOL_SOCKET, socket.SO_BINDTODEVICE, self._interface.encode()
            )

        self._send_discovery()

    def _send_discovery(self) -> None:
        """Send discovery messages to the target."""

        for port in [6445, 20086]:
            _LOGGER.debug("Discovery sent to %s:%d.", self._target, port)
            for i in range(self._discovery_packets):
                self._transport.sendto(DISCOVERY_MSG, (self._target, port))

    def datagram_received(self, data, addr) -> None:
        """Handle discovery responses."""

        ip, _port = addr

        # Ignore already discovered devices
        if ip in self._discovered_ips:
            return

        self._discovered_ips.add(ip)

        _LOGGER.debug("Discovery response from %s: %s", ip, data.hex())

        try:
            version = Discover._get_device_version(data)
        except Discover.UnknownDeviceVersion:
            _LOGGER.error("Unknown device version for %s.", ip)
            return

        # Construct a task
        task = asyncio.create_task(Discover._get_device(ip, version, data))
        self.tasks.add(task)

    def error_received(self, ex):
        """Handle asyncio.Protocol errors."""
        _LOGGER.error("Got error: %s", ex)

    def connection_lost(self, ex):
        """NOP implementation of connection lost."""


class Discover:
    """Discover Midea smart devices on the local network."""

    class UnknownDeviceVersion(Exception):
        """Exception for unknown device version."""
        pass

    _account = OPEN_MIDEA_APP_ACCOUNT
    _password = OPEN_MIDEA_APP_PASSWORD
    _lock = asyncio.Lock()
    _cloud = None

    @classmethod
    async def discover(
        cls,
        *,
        target=_IPV4_BROADCAST,
        timeout=5,
        discovery_packets=3,
        interface=None,
        account=None,
        password=None,
    ) -> [device]:
        """Discover devices via broadcast."""

        Discover._set_cloud_credentials(account, password)

        # Start discover protocol
        loop = asyncio.get_event_loop()
        transport, protocol = await loop.create_datagram_endpoint(
            lambda: _DiscoverProtocol(
                target=target,
                discovery_packets=discovery_packets,
                interface=interface,
            ),
            local_addr=("0.0.0.0", 0),
        )
        protocol = cast(_DiscoverProtocol, protocol)

        try:
            _LOGGER.debug("Waiting %s seconds for responses...", timeout)
            await asyncio.sleep(timeout)
        finally:
            transport.close()

        _LOGGER.debug("Discovered %s devices.", len(protocol.tasks))

        # Wait for remaining tasks
        devices = await asyncio.gather(*protocol.tasks)

        return devices

    @classmethod
    async def discover_single(
        cls,
        host,
        **kwargs
    ) -> device:
        """Discover a single device by hostname or IP."""

        devices = await Discover.discover(target=host, **kwargs)

        # Return first discovered device
        if len(devices) > 0:
            return devices[0]

        return None

    @classmethod
    def _set_cloud_credentials(cls, account, password):
        """Set credentials for cloud access."""

        if account and password:
            cls._account = account
            cls._password = password
        elif account or password:
            raise ValueError("Both account and password must be specified.")

    @classmethod
    async def _get_cloud(cls):
        """Return a cloud connection, creating it if necessary."""

        async with cls._lock:
            # Create cloud connection if nonexistent
            if cls._cloud is None:
                cls._cloud = cloud(cls._account, cls._password)
                cls._cloud.login()

        return cls._cloud

    @classmethod
    def _get_device_version(cls, data: bytes) -> int:
        """Get the device version from the provided discovery response data."""

        # Attempt to parse XML from V1 device
        with memoryview(data) as data_mv:
            try:
                ET.fromstring(data_mv)
                return 1
            except ET.ParseError:
                pass

            # Use start of packet data to differentiate between V2 and V3
            start_of_packet = data_mv[:2]
            if start_of_packet == b'\x5a\x5a':
                return 2
            elif start_of_packet == b'\x83\x70':
                return 3

        raise Discover.UnknownDeviceVersion()

    @classmethod
    async def _get_device_info(cls, ip: str, version: int, data: bytes):
        """Get device information. 

        V2/V3 devices return sufficient information in their discovery response.
        V1 devices must be querried.
        """

        # Version 1 devices
        if version == 1:
            with memoryview(data) as data_mv:
                root = ET.fromstring(data_mv)

            port = root.find("body/device").attrib["port"]

            loop = asyncio.get_event_loop()
            transport, protocol = await loop.create_connection(
                lambda: _V1DeviceInfoProtocol(), ip, port)
            protocol = cast(_V1DeviceInfoProtocol, protocol)

            try:
                _LOGGER.debug(
                    "Waiting %s seconds for device info response.", 8)
                await asyncio.sleep(8)
            finally:
                transport.close()

            # Parse response
            root = ET.fromstring(protocol.response)
            _LOGGER.debug("Device info response:\n%s", ET.indent(root))

            raise NotImplementedError("V1 device not supported yet.")

        # Version 2 & 3 devices
        else:
            with memoryview(data) as data_mv:
                # Strip V3 header and hash
                if version == 3:
                    data_mv = data_mv[8:-16]

                # Extract encrypted payload
                encrypted_data = data_mv[40:-16]

                # Extract ID
                id = int.from_bytes(data_mv[20:26], 'little')

                # Attempt to decrypt the packet
                try:
                    decrypted_data = Security.decrypt_aes(encrypted_data)
                except ValueError:
                    _LOGGER.error("Discovery packet decrypt failed.")
                    return

            with memoryview(decrypted_data) as decrypted_mv:
                _LOGGER.debug("Decrypted data from %s: %s",
                              ip, decrypted_mv.hex())

                # Extract IP and port
                ip_address = str(ipaddress.IPv4Address(
                    decrypted_mv[3::-1].tobytes()))
                port = int.from_bytes(decrypted_mv[4:6], 'little')

                if ip_address != ip:
                    _LOGGER.warning(
                        "Reported device IP %s does not match received IP %s.", ip_address, ip)

                # Extract serial number
                sn = decrypted_mv[8:40].tobytes().decode()

                # Extract name/SSID
                name_length = decrypted_mv[40]
                name = decrypted_mv[41:41+name_length].tobytes().decode()

                type = int(name.split('_')[1], 16)

            # Return dictionary of device info
            return {"ip": ip_address, "port": port, "id": id, "name": name, "sn": sn, "type": type}

    @classmethod
    def _get_device_class(cls, type: int):
        """Get the device class from the device type."""

        if type == DeviceId.AIR_CONDITIONER:
            return air_conditioning

        # Unknown type return generic device
        return device

    @classmethod
    async def _authenticate_device(cls, dev: device):
        """Attempt to authenticate a V3 device."""

        # Get cloud connection
        cloud = await Discover._get_cloud()

        # Try authenticating with udpids generated from both endians
        for endian in ["little", "big"]:
            udpid = Security.udpid(dev.id.to_bytes(6, endian)).hex()

            _LOGGER.debug(
                "Fetching token and key for udpid '%s' (%s).", udpid, endian)
            token, key = cloud.gettoken(udpid)

            if dev.authenticate(token, key):
                return token, key

    @classmethod
    async def _get_device(cls, ip: str, version: int, data: bytes):
        """Get device information and construct a device instance from the discovery response data."""

        # Fetch device information
        info = await Discover._get_device_info(ip, version, data)

        # Get device class corresponding to type
        device_class = Discover._get_device_class(info["type"])

        # Build device, authenticate as needed and refresh
        dev = device_class(**info)

        if version == 3:
            await Discover._authenticate_device(dev)

        dev.refresh()

        return dev


async def main():
    logging.basicConfig(level=logging.DEBUG)
    # result = await Discover.discover_single("net_ac_63BA")
    result = await Discover.discover()
    for dev in result:
        print(dev)

if __name__ == '__main__':
    asyncio.run(main())