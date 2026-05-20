"""Module for minimal Midea cloud API access."""
import hashlib
import hmac
import json
import logging
import os
from asyncio import Lock
from binascii import hexlify, unhexlify
from datetime import datetime
from secrets import token_hex, token_urlsafe
from typing import Any, Dict, Optional, Tuple

import httpx
from Crypto.Cipher import AES
from Crypto.Util import Padding

from msmart.const import DeviceType

_LOGGER = logging.getLogger(__name__)


class CloudError(Exception):
    """Generic exception for Midea cloud errors."""
    pass


class ApiError(CloudError):
    """Exception class for Midea cloud API errors."""

    def __init__(self, message, code=None) -> None:
        super().__init__(message, code)

        self.message = message
        self.code = code

    def __str__(self) -> str:
        return f"Code: {self.code}, Message: {self.message}"


class Cloud:
    """Class for minimal Midea cloud API access."""

    # Misc constants for the API
    CLIENT_TYPE = 1  # Android
    FORMAT = 2  # JSON
    LANGUAGE = "en_US"
    APP_ID = "1010"
    SRC = "1010"
    DEVICE_ID = token_hex(8)  # Random device ID

    # Base URLs
    BASE_URL = "https://mp-prod.appsmb.com"
    BASE_URL_CHINA = "https://mp-prod.smartmidea.net"

    # Default number of request retries
    RETRIES = 3

    def __init__(self, account: str, password: str,
                 use_china_server: bool = False) -> None:
        # Allow override Chia server from environment
        if os.getenv("MIDEA_CHINA_SERVER", "0") == "1":
            use_china_server = True

        self._account = account
        self._password = password

        # Attributes that holds the login information of the current user
        self._login_id = None
        self._access_token = ""
        self._session = {}

        self._api_lock = Lock()
        self._security = _Security(use_china_server)

        self._base_url = Cloud.BASE_URL_CHINA if use_china_server else Cloud.BASE_URL

        _LOGGER.info("Using Midea cloud server: %s (China: %s).",
                     self._base_url, use_china_server)

    def _timestamp(self) -> str:
        """Format a timestamp for the API."""
        return datetime.utcnow().strftime("%Y%m%d%H%M%S")

    def _parse_response(self, response) -> Any:
        """Parse a response from the API."""

        _LOGGER.debug("API response: %s", response.text)
        body = json.loads(response.text)

        response_code = int(body["code"])
        if response_code == 0:
            return body["data"]

        raise ApiError(body["msg"], code=response_code)

    async def _post_request(self, url: str, headers: Dict[str, Any],
                            contents: str, retries: int = RETRIES) -> Optional[dict]:
        """Post a request to the API."""

        async with httpx.AsyncClient() as client:
            while retries > 0:
                try:
                    # Post request and handle bad status code
                    r = await client.post(url, headers=headers, content=contents, timeout=10.0)
                    r.raise_for_status()

                    # Parse the response
                    return self._parse_response(r)
                except httpx.TimeoutException as e:
                    if retries > 1:
                        _LOGGER.warning("Request to %s timed out.", url)
                        retries -= 1
                    else:
                        raise CloudError("No response from server.") from e

    async def _api_request(self, endpoint: str, body: Dict[str, Any]) -> Optional[dict]:
        """Make a request to the Midea cloud return the results."""

        # Encode body as JSON
        contents = json.dumps(body)
        random = token_hex(16)

        # Sign the contents and add it to the header
        sign = self._security.sign(contents, random)
        headers = {
            "Content-Type": "application/json",
            "secretVersion": "1",
            "sign": sign,
            "random": random,
            "accessToken": self._access_token
        }

        # Build complete request URL
        url = f"{self._base_url}/mas/v5/app/proxy?alias={endpoint}"

        # Lock the API and post the request
        async with self._api_lock:
            return await self._post_request(url, headers, contents)

    def _build_request_body(self, data: Dict[str, Any]) -> Dict[str, Any]:
        """Build a request body."""

        # Set up the initial body
        body = {
            "appId": Cloud.APP_ID,
            "format": Cloud.FORMAT,
            "clientType": Cloud.CLIENT_TYPE,
            "language": Cloud.LANGUAGE,
            "src": Cloud.SRC,
            "stamp": self._timestamp(),
            "deviceId": Cloud.DEVICE_ID,
            "reqId": token_hex(16),
        }

        # Add additional fields to the body
        body.update(data)

        return body

    async def _get_login_id(self) -> str:
        """Get a login ID for the cloud account."""

        response = await self._api_request(
            "/v1/user/login/id/get",
            self._build_request_body(
                {"loginAccount": self._account}
            )
        )

        # Assert response is not None since we should throw on errors
        assert response is not None

        return response["loginId"]

    async def login(self, force: bool = False) -> None:
        """Login to the cloud API."""

        # Don't login if session already exists
        if self._session and not force:
            return

        # Get a login ID if we don't have one
        if self._login_id is None:
            self._login_id = await self._get_login_id()
            _LOGGER.debug("Received loginId: %s", self._login_id)

        # Build the login data
        body = {
            "data": {
                "platform": Cloud.FORMAT,
                "deviceId": Cloud.DEVICE_ID,
            },
            "iotData": {
                "appId": Cloud.APP_ID,
                "clientType": Cloud.CLIENT_TYPE,
                "iampwd": self._security.encrypt_iam_password(self._login_id, self._password),
                "loginAccount": self._account,
                "password": self._security.encrypt_password(self._login_id, self._password),
                "pushToken": token_urlsafe(120),
                "reqId": token_hex(16),
                "src": Cloud.SRC,
                "stamp": self._timestamp(),
            },
        }

        # Login and store the session
        response = await self._api_request("/mj/user/login", body)

        # Assert response is not None since we should throw on errors
        assert response is not None

        self._session = response
        self._access_token = response["mdata"]["accessToken"]
        _LOGGER.debug("Received accessToken: %s", self._access_token)

        # Derive relay encryption keys from root-level session fields
        self._security.set_relay_keys(
            str(response.get("accessToken", "")),
            str(response.get("randomData", "")),
        )

    async def get_token(self, udpid: str) -> Tuple[str, str]:
        """Get token and key for the provided udpid."""

        response = await self._api_request(
            "/v1/iot/secure/getToken",
            self._build_request_body({"udpid": udpid})
        )

        # Assert response is not None since we should throw on errors
        assert response is not None

        for token in response["tokenlist"]:
            if token["udpId"] == udpid:
                return token["token"], token["key"]

        # No matching udpId in the tokenlist
        raise CloudError(f"No token/key found for udpid {udpid}.")

    async def get_protocol_lua(self, device_type: DeviceType, sn: str) -> Tuple[str, str]:
        """Fetch and decode the protocol Lua file."""

        response = await self._api_request(
            "/v2/luaEncryption/luaGet",
            self._build_request_body({
                "applianceMFCode": "0000",
                "applianceSn": self._security.encrypt_aes_app_key(sn.encode("UTF-8")).hex(),
                "applianceType": hex(device_type),
                "encryptedType ": 2,
                "version": "0"
            })
        )

        # Assert response is not None since we should throw on errors
        assert response is not None

        file_name = response["fileName"]
        url = response["url"]
        async with httpx.AsyncClient() as client:
            try:
                # Get file from server
                r = await client.get(url, timeout=10.0)
                r.raise_for_status()
            except httpx.TimeoutException as e:
                raise CloudError("No response from server.") from e

        encrypted_data = bytes.fromhex(r.text)
        file_data = self._security.decrypt_aes_app_key(
            encrypted_data).decode("UTF-8")
        return (file_name, file_data)

    def _build_relay_packet(self, device_id: int, cmd_bytes: bytes) -> bytes:
        """Wrap a device command in the 0x5A5A LAN packet format for cloud relay.

        Cloud relay uses the same packet format as direct LAN communication, but
        without the local AES encryption layer.
        """
        id_bytes = device_id.to_bytes(8, "little")
        now = datetime.now()
        pkt = bytearray([
            0x5A, 0x5A,
            0x01, 0x11,
            0x00, 0x00,          # length, filled below
            0x20, 0x00,
            0x00, 0x00, 0x00, 0x00,  # message id
            int(now.microsecond / 10000), now.second, now.minute, now.hour,
            now.day, now.month, now.year % 100, int(now.year / 100),
            id_bytes[0], id_bytes[1], id_bytes[2], id_bytes[3],
            id_bytes[4], id_bytes[5], id_bytes[6], id_bytes[7],
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00,
        ])
        pkt.extend(cmd_bytes)
        pkt[4:6] = (len(pkt) + 16).to_bytes(2, "little")
        pkt.extend(self._security.md5_fingerprint(bytes(pkt)))
        return bytes(pkt)

    async def appliance_transparent_send(self, device_id: int, cmd_bytes: bytes) -> Optional[bytes]:
        """Send a device command via the cloud relay.

        This bypasses LAN authentication entirely — the cloud server forwards
        the command over its own authenticated connection to the device.

        Args:
            device_id: Numeric appliance ID.
            cmd_bytes: Raw device command frame (0xAA … format).

        Returns:
            Device response frame (0xAA … format) or None on failure.
        """
        if not self._security.has_relay_keys:
            _LOGGER.error("Cloud relay keys not available; call login() first.")
            return None

        packet = self._build_relay_packet(device_id, cmd_bytes)
        order = self._security.encrypt_relay(_Security.encode_as_csv(packet))

        body = self._build_request_body({
            "order": order,
            "funId": "0000",
            "applianceCode": str(device_id),
        })

        try:
            response = await self._api_request("/v1/appliance/transparent/send", body)
        except CloudError as e:
            _LOGGER.error("Cloud relay request failed: %s", e)
            return None

        if not response or "reply" not in response:
            _LOGGER.error("Cloud relay response missing 'reply' field: %s", response)
            return None

        csv_reply = self._security.decrypt_relay(response["reply"])
        reply_bytes = _Security.decode_from_csv(csv_reply)

        # Response is a full 0x5A5A packet; strip the 40-byte header
        if len(reply_bytes) < 40:
            _LOGGER.error("Cloud relay reply too short (%d bytes).", len(reply_bytes))
            return None

        return reply_bytes[40:]

    async def get_plugin(self, device_type: DeviceType, sn: str) -> Tuple[str, bytes]:
        """Request and download the device plugin."""

        response = await self._api_request(
            "/v1/plugin/update/overseas/get",
            self._build_request_body({
                "clientVersion": "0",
                "uid": token_hex(16),
                "applianceList": [
                    {
                        "appModel": sn[9:17],
                        "appType": hex(device_type),
                        "modelNumber": "0"
                    }
                ]
            })
        )

        # Assert response is not None since we should throw on errors
        assert response is not None

        result = response["result"][0]

        file_name = result["title"]
        url = result["url"]
        async with httpx.AsyncClient(verify=False) as client:
            try:
                # Get file from server
                r = await client.get(url, timeout=10.0)
                r.raise_for_status()
            except httpx.TimeoutException as e:
                raise CloudError("No response from server.") from e

        file_data = r.content
        return (file_name, file_data)


class _Security:
    """"Class for Midea cloud specific security."""

    HMAC_KEY = "PROD_VnoClJI9aikS8dyy"

    IOT_KEY = "meicloud"
    LOGIN_KEY = "ac21b9f9cbfe4ca5a88562ef25e2b768"

    IOT_KEY_CHINA = "prod_secret123@muc"
    LOGIN_KEY_CHINA = "ad0ee21d48a64bf49f4fb583ab76e799"

    # MSmartHome
    APP_KEY = "ac21b9f9cbfe4ca5a88562ef25e2b768"

    # Key used to compute MD5 fingerprint on LAN / relay packets
    RELAY_SIGN_KEY = "xhdiwjnchekd4d512chdjx5d8e4c394D2D7S"

    def __init__(self, use_china_server=False):
        self._use_china_server = use_china_server
        self._relay_data_key: Optional[str] = None
        self._relay_data_iv: Optional[str] = None

    @property
    def _iot_key(self) -> str:
        """Get the IOT key for the appropriate server."""
        return _Security.IOT_KEY_CHINA if self._use_china_server else _Security.IOT_KEY

    @property
    def _login_key(self) -> str:
        """Get the login key for the appropriate server."""
        return _Security.LOGIN_KEY_CHINA if self._use_china_server else _Security.LOGIN_KEY

    def sign(self, data: str, random: str) -> str:
        """Generate a HMAC signature for the provided data and random data."""
        msg = self._iot_key + data + random

        sign = hmac.new(self.HMAC_KEY.encode("ASCII"),
                        msg.encode("ASCII"), hashlib.sha256)
        return sign.hexdigest()

    def encrypt_password(self, login_id: str, password: str) -> str:
        """Encrypt the password for cloud API password."""
        # Hash the password
        m1 = hashlib.sha256(password.encode("ASCII"))

        # Create the login hash with the loginID + password hash + loginKey, then hash it all AGAIN
        login_hash = login_id + m1.hexdigest() + self._login_key
        m2 = hashlib.sha256(login_hash.encode("ASCII"))

        return m2.hexdigest()

    def encrypt_iam_password(self, login_id: str, password: str) -> str:
        """Encrypts password for cloud API iampwd field."""

        # Hash the password
        m1 = hashlib.md5(password.encode("ASCII"))

        # Hash the password hash
        m2 = hashlib.md5(m1.hexdigest().encode("ASCII"))

        if self._use_china_server:
            return m2.hexdigest()

        login_hash = login_id + m2.hexdigest() + self._login_key
        sha = hashlib.sha256(login_hash.encode("ASCII"))

        return sha.hexdigest()

    def _get_app_key_and_iv(self) -> Tuple[bytes, bytes]:
        hash = hashlib.sha256(self.APP_KEY.encode()).hexdigest()
        return (hash[:16].encode(), hash[16:32].encode())

    def encrypt_aes_app_key(self, data: bytes) -> bytes:
        key, iv = self._get_app_key_and_iv()
        cipher = AES.new(key, AES.MODE_CBC, iv=iv)
        return cipher.encrypt(Padding.pad(data, 16))

    def decrypt_aes_app_key(self, data: bytes) -> bytes:
        key, iv = self._get_app_key_and_iv()
        cipher = AES.new(key, AES.MODE_CBC, iv=iv)
        return Padding.unpad(cipher.decrypt(data), 16)

    def set_relay_keys(self, access_token: str, random_data: str) -> None:
        """Derive relay encryption keys from the session's root-level accessToken and randomData."""
        if not access_token or not random_data:
            return
        key, iv = self._get_app_key_and_iv()
        try:
            cipher1 = AES.new(key, AES.MODE_CBC, iv=iv)
            self._relay_data_key = Padding.unpad(
                cipher1.decrypt(unhexlify(access_token)), 16).decode("utf-8")
            cipher2 = AES.new(key, AES.MODE_CBC, iv=iv)
            self._relay_data_iv = Padding.unpad(
                cipher2.decrypt(unhexlify(random_data)), 16).decode("utf-8")
        except Exception as e:
            _LOGGER.error("Failed to derive relay keys: %s", e)

    @property
    def has_relay_keys(self) -> bool:
        """Return True if relay encryption keys have been derived."""
        return self._relay_data_key is not None and self._relay_data_iv is not None

    def encrypt_relay(self, data: str) -> str:
        """AES-CBC encrypt a string with the relay data key, return hex."""
        assert self._relay_data_key and self._relay_data_iv
        key = self._relay_data_key.encode("utf-8")
        iv = self._relay_data_iv.encode("utf-8")
        cipher = AES.new(key, AES.MODE_CBC, iv=iv)
        return hexlify(cipher.encrypt(Padding.pad(data.encode("utf-8"), 16))).decode()

    def decrypt_relay(self, hex_data: str) -> str:
        """AES-CBC decrypt a hex string with the relay data key, return UTF-8 string."""
        assert self._relay_data_key and self._relay_data_iv
        key = self._relay_data_key.encode("utf-8")
        iv = self._relay_data_iv.encode("utf-8")
        cipher = AES.new(key, AES.MODE_CBC, iv=iv)
        return Padding.unpad(cipher.decrypt(unhexlify(hex_data)), 16).decode("utf-8")

    def md5_fingerprint(self, data: bytes) -> bytes:
        """Compute the MD5 packet fingerprint appended to LAN/relay packets."""
        return hashlib.md5(data + self.RELAY_SIGN_KEY.encode()).digest()

    @staticmethod
    def encode_as_csv(data: bytes) -> str:
        """Encode bytes as comma-separated signed integers (relay wire format)."""
        return ",".join(str(b if b < 128 else b - 256) for b in data)

    @staticmethod
    def decode_from_csv(data: str) -> bytes:
        """Decode comma-separated signed integers to bytes."""
        return bytes(int(x) & 0xFF for x in data.split(","))
