"""Module for minimal Midea cloud access."""
import hashlib
import hmac
import json
import logging
import os
from asyncio import Lock
from datetime import datetime, timezone
from secrets import token_hex, token_urlsafe
from typing import Any, Callable, Optional
from urllib.parse import unquote_plus, urlencode, urlparse

import httpx
from Crypto.Cipher import AES
from Crypto.Util import Padding

from msmart.const import DEFAULT_CLOUD_REGION, DeviceType

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


class BaseCloud:
    """Base class for minimal Midea cloud access."""

    # Misc constants for the API
    APP_ID = ""
    CLIENT_TYPE = 1  # Android
    FORMAT = 2  # JSON
    LANGUAGE = "en_US"
    DEVICE_ID = token_hex(8)  # Random device ID

    # Default number of request retries
    RETRIES = 3

    CLOUD_CREDENTIALS = {}

    def __init__(self,
                 base_url: str,
                 region: Optional[str],
                 account: Optional[str],
                 password: Optional[str],
                 *,
                 get_async_client: Optional[
                     Callable[..., httpx.AsyncClient]] = None,
                 ) -> None:

        # Validate incoming credentials and region
        if account and password:
            self._account = account
            self._password = password
        elif account or password:
            raise ValueError("Account and password must be specified.")
        else:
            try:
                self._account, self._password = self.CLOUD_CREDENTIALS[region]
            except KeyError:
                raise ValueError(f"Unknown cloud region '{region}'.")

        self._api_lock = Lock()
        self._base_url = base_url
        self._login_id = None
        self._session = {}

        # Setup method for getting a client
        self._get_async_client = get_async_client if get_async_client else httpx.AsyncClient

    def _timestamp(self) -> str:
        """Format a timestamp for the API."""
        return datetime.now(timezone.utc).strftime("%Y%m%d%H%M%S")

    def _parse_response(self, response) -> Any:
        """Parse a response from the cloud."""
        raise NotImplementedError

    async def _post_request(self,
                            url: str,
                            headers: Optional[dict[str, Any]] = None,
                            raw_data: Optional[str] = None,
                            form_data: Optional[dict[str, Any]] = None,
                            retries: int = RETRIES
                            ) -> Optional[dict]:
        """Post a request to the cloud."""

        async with self._get_async_client() as client:
            while retries > 0:
                try:
                    # Post request and handle bad status code
                    r = await client.post(url, headers=headers, content=raw_data, data=form_data, timeout=10.0)
                    r.raise_for_status()

                    # Parse the response
                    return self._parse_response(r)
                except httpx.TimeoutException as e:
                    if retries > 1:
                        _LOGGER.warning("Request to %s timed out.", url)
                        retries -= 1
                    else:
                        raise CloudError("No response from server.") from e
                except httpx.HTTPError as e:
                    raise CloudError(f"HTTP request failed: {e}") from e

    async def _api_request(self, endpoint: str, body: dict[str, Any]) -> Optional[dict]:
        """Make a request to the cloud and return the results."""
        raise NotImplementedError

    def _build_request_body(self, data: dict[str, Any]) -> dict[str, Any]:
        """Build a request body."""

        # Set up the initial body
        body = {
            "appId": self.APP_ID,
            "src": self.APP_ID,
            "format": BaseCloud.FORMAT,
            "clientType": BaseCloud.CLIENT_TYPE,
            "language": BaseCloud.LANGUAGE,
            "deviceId": BaseCloud.DEVICE_ID,
            "stamp": self._timestamp(),
        }

        # Add additional fields to the body
        body.update(data)

        return body

    async def _get_login_id(self) -> str:
        """Get a login ID for the cloud account."""

        response = await self._api_request(
            "/v1/user/login/id/get",
            self._build_request_body(
                {
                    "loginAccount": self._account
                }
            )
        )

        # Assert response is not None since we should throw on errors
        assert response is not None

        login_id = response["loginId"]
        _LOGGER.debug("Received loginId: %s", login_id)

        return login_id

    async def get_token(self, udpid: str) -> tuple[str, str]:
        """Get token and key for the provided udpid."""

        response = await self._api_request(
            "/v1/iot/secure/getToken",
            self._build_request_body(
                {
                    "udpid": udpid
                }
            )
        )

        # Assert response is not None since we should throw on errors
        assert response is not None

        for token in response["tokenlist"]:
            if token["udpId"] == udpid:
                return token["token"], token["key"]

        # No matching udpId in the tokenlist
        raise CloudError(f"No token/key found for udpid {udpid}.")


class SmartHomeCloud(BaseCloud):
    """Class for minimal Midea SmartHome cloud access."""

    # Misc constants for the SmartHome cloud
    APP_ID = "1010"

    # Base URLs
    BASE_URL = "https://mp-prod.appsmb.com"
    BASE_URL_CHINA = "https://mp-prod.smartmidea.net"

    CLOUD_CREDENTIALS = {
        "DE": ("midea_eu@mailinator.com", "das_ist_passwort1"),
        "KR": ("midea_sea@mailinator.com", "password_for_sea1"),
        "US": ("midea@mailinator.com", "this_is_a_password1")
    }

    def __init__(self,
                 region: str = DEFAULT_CLOUD_REGION,
                 *,
                 account: Optional[str] = None,
                 password: Optional[str] = None,
                 use_china_server: bool = False,
                 **kwargs
                 ) -> None:
        # Allow override Chia server from environment
        if os.getenv("MIDEA_CHINA_SERVER", "0") == "1":
            use_china_server = True

        base_url = SmartHomeCloud.BASE_URL_CHINA if use_china_server else SmartHomeCloud.BASE_URL
        super().__init__(base_url, region, account, password, **kwargs)

        self._access_token = ""
        self._security = SmartHomeCloud._Security(use_china_server)

    def _parse_response(self, response) -> Any:
        """Parse a response from the cloud."""

        _LOGGER.debug("Cloud response: %s", response.text)
        body = json.loads(response.text)

        response_code = int(body["code"])
        if response_code == 0:
            return body["data"]

        raise ApiError(body["msg"], code=response_code)

    async def _api_request(self, endpoint: str, body: dict[str, Any]) -> Optional[dict]:
        """Make a request to the cloud and return the results."""

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
            return await self._post_request(url, headers=headers, raw_data=contents)

    def _build_request_body(self, data: dict[str, Any]) -> dict[str, Any]:
        """Build a request body."""

        # Set up the initial body
        body = super()._build_request_body({
            "reqId": token_hex(16),
        })

        # Add additional fields to the body
        body.update(data)

        return body

    async def login(self, force: bool = False) -> None:
        """Login to the cloud."""

        # Don't login if session already exists
        if self._session and not force:
            return

        # Get a login ID if we don't have one
        if self._login_id is None:
            self._login_id = await self._get_login_id()

        # Build the login data
        body = {
            "data": {
                "platform": BaseCloud.FORMAT,
                "deviceId": BaseCloud.DEVICE_ID,
            },
            "iotData": {
                "appId": SmartHomeCloud.APP_ID,
                "src": SmartHomeCloud.APP_ID,
                "clientType": BaseCloud.CLIENT_TYPE,
                "loginAccount": self._account,
                "iampwd": self._security.encrypt_iam_password(self._login_id, self._password),
                "password": self._security.encrypt_password(self._login_id, self._password),
                "pushToken": token_urlsafe(120),
                "stamp": self._timestamp(),
                "reqId": token_hex(16),
            },
        }

        # Login and store the session
        response = await self._api_request("/mj/user/login", body)

        # Assert response is not None since we should throw on errors
        assert response is not None

        self._session = response
        self._access_token = response["mdata"]["accessToken"]
        _LOGGER.debug("Received accessToken: %s", self._access_token)

    async def get_protocol_lua(self, device_type: DeviceType, sn: str) -> tuple[str, str]:
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
        async with self._get_async_client() as client:
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

    async def get_plugin(self, device_type: DeviceType, sn: str) -> tuple[str, bytes]:
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
        async with self._get_async_client() as client:
            try:
                # Get file from server
                r = await client.get(url, timeout=10.0)
                r.raise_for_status()
            except httpx.TimeoutException as e:
                raise CloudError("No response from server.") from e

        file_data = r.content
        return (file_name, file_data)

    class _Security:
        """"Class for SmartHome cloud specific security."""

        HMAC_KEY = "PROD_VnoClJI9aikS8dyy"

        IOT_KEY = "meicloud"
        LOGIN_KEY = "ac21b9f9cbfe4ca5a88562ef25e2b768"

        IOT_KEY_CHINA = "prod_secret123@muc"
        LOGIN_KEY_CHINA = "ad0ee21d48a64bf49f4fb583ab76e799"

        # MSmartHome
        APP_KEY = "ac21b9f9cbfe4ca5a88562ef25e2b768"

        def __init__(self, use_china_server=False):
            self._use_china_server = use_china_server

        @property
        def _iot_key(self) -> str:
            """Get the IOT key for the appropriate server."""
            return self.IOT_KEY_CHINA if self._use_china_server else self.IOT_KEY

        @property
        def _login_key(self) -> str:
            """Get the login key for the appropriate server."""
            return self.LOGIN_KEY_CHINA if self._use_china_server else self.LOGIN_KEY

        def sign(self, data: str, random: str) -> str:
            """Generate a HMAC signature for the provided data and random data."""
            msg = self._iot_key + data + random

            sign = hmac.new(self.HMAC_KEY.encode("ASCII"),
                            msg.encode("ASCII"), hashlib.sha256)
            return sign.hexdigest()

        def encrypt_password(self, login_id: str, password: str) -> str:
            """Encrypt the password for cloud password."""
            # Hash the password
            m1 = hashlib.sha256(password.encode("ASCII"))

            # Create the login hash with the login ID + password hash + login key, then hash it all AGAIN
            login_hash = login_id + m1.hexdigest() + self._login_key
            m2 = hashlib.sha256(login_hash.encode("ASCII"))

            return m2.hexdigest()

        def encrypt_iam_password(self, login_id: str, password: str) -> str:
            """Encrypts password for cloud iampwd field."""

            # Hash the password
            m1 = hashlib.md5(password.encode("ASCII"))

            # Hash the password hash
            m2 = hashlib.md5(m1.hexdigest().encode("ASCII"))

            if self._use_china_server:
                return m2.hexdigest()

            login_hash = login_id + m2.hexdigest() + self._login_key
            sha = hashlib.sha256(login_hash.encode("ASCII"))

            return sha.hexdigest()

        def _get_app_key_and_iv(self) -> tuple[bytes, bytes]:
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


class NetHomePlusCloud(BaseCloud):
    """Class for minimal NetHome Plus cloud access."""

    # Misc constants for the NetHome Plus cloud
    APP_ID = "1017"

    BASE_URL = "https://mapp.appsmb.com"

    CLOUD_CREDENTIALS = {
        "DE": ("nethome+de@mailinator.com", "password1"),
        "KR": ("nethome+sea@mailinator.com", "password1"),
        "US": ("nethome+us@mailinator.com", "password1")
    }

    def __init__(self,
                 region: str = DEFAULT_CLOUD_REGION,
                 *,
                 account: Optional[str] = None,
                 password: Optional[str] = None,
                 **kwargs
                 ) -> None:

        super().__init__(NetHomePlusCloud.BASE_URL, region, account, password, **kwargs)

        self._session_id = ""
        self._security = NetHomePlusCloud._Security()

    def _parse_response(self, response) -> Any:
        """Parse a response from the cloud."""

        _LOGGER.debug("Cloud response: %s", response.text)
        body = json.loads(response.text)

        response_code = int(body["errorCode"])
        if response_code == 0:
            return body["result"]

        raise ApiError(body["msg"], code=response_code)

    async def _api_request(self, endpoint: str, body: dict[str, Any]) -> Optional[dict]:
        """Make a request to the cloud and return the results."""

        # Sign the contents and add it to the body
        body["sign"] = self._security.sign(endpoint, body)

        # Build complete request URL
        url = f"{self._base_url}{endpoint}"

        # Lock the API and post the request
        async with self._api_lock:
            return await self._post_request(url, form_data=body)

    def _build_request_body(self, data: dict[str, Any]) -> dict[str, Any]:
        """Build a request body."""

        # Set up the initial body
        body = super()._build_request_body({
            "sessionId": self._session_id
        })

        # Add additional fields to the body
        body.update(data)

        return body

    async def login(self, force: bool = False) -> None:
        """Login to the cloud."""

        # Don't login if session already exists
        if self._session and not force:
            return

        # Get a login ID if we don't have one
        if self._login_id is None:
            self._login_id = await self._get_login_id()

        # Login and store the session
        response = await self._api_request(
            "/v1/user/login",
            self._build_request_body(
                {
                    "loginAccount": self._account,
                    "password": self._security.encrypt_password(self._login_id, self._password),
                }
            ))

        # Assert response is not None since we should throw on errors
        assert response is not None

        self._session = response
        self._session_id = response["sessionId"]
        _LOGGER.debug("Received sessionId: %s", self._session_id)

    async def get_protocol_lua(self, device_type: DeviceType, sn: str) -> tuple[str, str]:
        """Fetch and decode the protocol Lua file."""
        raise NotImplementedError

    async def get_plugin(self, device_type: DeviceType, sn: str) -> tuple[str, bytes]:
        """Request and download the device plugin."""
        raise NotImplementedError

    class _Security:
        """"Class for NetHome Plus cloud specific security."""

        # NetHome PLus
        APP_KEY = "3742e9e5842d4ad59c2db887e12449f9"

        def sign(self, url: str, data: dict[str, Any]) -> str:
            """Generate a signature for the provided data and URL."""
            # Get path portion of request
            path = urlparse(url).path

            # Sort request and create a query string
            query = unquote_plus(urlencode(sorted(data.items())))

            msg = path + query + self.APP_KEY

            sign = hashlib.sha256(msg.encode("ASCII"))
            return sign.hexdigest()

        def encrypt_password(self, login_id: str, password: str) -> str:
            """Encrypt the login password."""
            # Hash the password
            m1 = hashlib.sha256(password.encode("ASCII"))

            # Create the login hash with the login ID + password hash + app key, then hash it all AGAIN
            login_hash = login_id + m1.hexdigest() + self.APP_KEY
            m2 = hashlib.sha256(login_hash.encode("ASCII"))

            return m2.hexdigest()
