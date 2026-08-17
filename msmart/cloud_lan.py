"""Cloud transport for Midea AC devices.

Relays device command frames through the Midea cloud's
``/v1/appliance/transparent/send/new`` endpoint, so an ordinary msmart device
(e.g. ``AirConditioner``) can be controlled from anywhere with only account
credentials, without local network access to the unit. Useful when the device
is on an isolated network.

The command frame is wrapped in the cloud's transport packet, AES-CBC encrypted
with a per-session key and IV, and posted to the cloud. Replies are decrypted
and returned as raw device frames, matching the local ``LAN`` transport, so the
same device objects and commands work over either path.

Only one login session is allowed per account at a time, so running cloud
commands may sign out the phone app (and vice versa).
"""
from __future__ import annotations

import hashlib
import logging
import struct
from datetime import datetime
from secrets import token_hex
from typing import Optional
from urllib.parse import unquote_plus, urlencode

import httpx
from Crypto.Cipher import AES
from Crypto.Util import Padding

_LOGGER = logging.getLogger(__name__)

# Cooper & Hunter ("C&H Remote") app identity. Override via app_id/app_key
# for other Midea OEM apps.
CH_APP_ID = "1121"
CH_APP_KEY = "08822d2f357aa76712189c00fcc0fc4d"
DEFAULT_BASE_URL = "https://mapp-us.appsmb.com"

_LOGIN_ID_PATH = "/v1/user/login/id/get"
_LOGIN_PATH = "/v1/user/login"
_SEND_PATH = "/v1/appliance/transparent/send/new"
_FUN_ID = "0008"


class CloudLANError(RuntimeError):
    pass


# --------------------------------------------------------------- 5A5A packet
def _timestamp() -> bytes:
    """8-byte timestamp field for the transport packet header."""
    n = datetime.now()
    return bytes([
        (n.microsecond // 1000) & 0xFF,
        n.second, n.minute, n.hour % 12,
        n.day, n.month - 1, n.year % 100, n.year // 100,
    ])


def build_5a5a_packet(frame: bytes, appliance_id: int, seq: int) -> bytes:
    """Wrap a device frame in the cloud transport packet.

    The frame is placed plaintext at offset 40; the header carries a live
    timestamp and the appliance id (little-endian) as the device tag.
    """
    length = len(frame) + 56
    p = bytearray(length)
    p[0:2] = b"\x5A\x5A"
    p[2] = 0x01
    # p[3] flags stay 0 (no trailing hash for a cloud send)
    p[4:6] = struct.pack("<H", length)
    p[6:8] = struct.pack("<H", 32)
    p[8:12] = struct.pack("<I", seq & 0xFFFFFFFF)
    p[12:20] = _timestamp()
    p[20:26] = (appliance_id & ((1 << 48) - 1)).to_bytes(6, "little")
    # p[26:40] stay zero
    p[40:40 + len(frame)] = frame
    return bytes(p)


def _extract_aa(packet: bytes) -> Optional[bytes]:
    """Pull the AA-frame back out of a decoded 5A5A packet."""
    i = packet.find(0xAA)
    if i < 0:
        return None
    # Length byte gives the frame size (header + data), +1 for checksum.
    if i + 1 >= len(packet):
        return None
    frame_len = packet[i + 1] + 1
    return packet[i:i + frame_len]


# ------------------------------------------------------------------- session
class CloudLAN:
    """A cloud session that relays frames to one appliance, duck-typing `LAN`.

    Construct, `await login()`, then hand to a Device via its `_lan` attribute
    (see `attach`). `send()` mirrors `LAN.send`: bytes in, list[bytes] out.
    """

    def __init__(
        self,
        appliance_id: int,
        account: str,
        password: str,
        *,
        app_id: str = CH_APP_ID,
        app_key: str = CH_APP_KEY,
        base_url: str = DEFAULT_BASE_URL,
    ) -> None:
        self.appliance_id = int(appliance_id)
        self._account = account
        self._password = password
        self._app_id = app_id
        self._app_key = app_key
        self._base = base_url.rstrip("/")

        self._session_id: Optional[str] = None
        self._key: Optional[bytes] = None
        self._iv: Optional[bytes] = None
        self._seq = 1000
        self._device_id = token_hex(8)  # random per-client id for login
        # duck-typed LAN surface
        self._max_connection_lifetime: Optional[int] = None

    # -- crypto helpers ----------------------------------------------------
    def _sign(self, path: str, body: dict) -> str:
        query = unquote_plus(urlencode(sorted(body.items())))
        return hashlib.sha256((path + query + self._app_key).encode()).hexdigest()

    def _login_body(self, extra: dict) -> dict:
        """Full body used for login endpoints (src = appId)."""
        body = {
            "appId": self._app_id,
            "src": self._app_id,
            "format": "2",
            "clientType": "1",
            "language": "en_US",
            "deviceId": self._device_id,
            "stamp": datetime.now().strftime("%Y%m%d%H%M%S"),
        }
        body.update(extra)
        return body

    def _base_body(self) -> dict:
        """Minimal body used for transparent/send (src = 17, no appId)."""
        body = {
            "src": "17",
            "format": "2",
            "stamp": datetime.now().strftime("%Y%m%d%H%M%S"),
            "language": "en_US",
        }
        if self._session_id:
            body["sessionId"] = self._session_id
        return body

    async def _post(self, client: httpx.AsyncClient, path: str, body: dict) -> dict:
        body = dict(body)
        body["sign"] = self._sign(path, body)
        r = await client.post(self._base + path, data=body, timeout=25)
        r.raise_for_status()
        return r.json()

    def _password_hash(self, login_id: str) -> str:
        m1 = hashlib.sha256(self._password.encode("ASCII")).hexdigest()
        return hashlib.sha256((login_id + m1 + self._app_key).encode("ASCII")).hexdigest()

    def _derive_key(self, access_token: str) -> bytes:
        k = hashlib.md5(self._app_key.encode()).hexdigest()[:16].encode()
        return Padding.unpad(AES.new(k, AES.MODE_ECB).decrypt(bytes.fromhex(access_token)), 16)

    @staticmethod
    def _to_text(packet: bytes) -> bytes:
        return ",".join(str(b - 256 if b > 127 else b) for b in packet).encode("ASCII")

    @staticmethod
    def _from_text(text: str) -> bytes:
        return bytes((int(x) + 256) % 256 for x in text.strip().split(",") if x != "")

    def _encrypt_order(self, packet: bytes) -> str:
        assert self._key and self._iv
        ct = AES.new(self._key, AES.MODE_CBC, iv=self._iv).encrypt(
            Padding.pad(self._to_text(packet), 16))
        return ct.hex()

    def _decrypt_reply(self, order_hex: str) -> bytes:
        assert self._key and self._iv
        pt = Padding.unpad(
            AES.new(self._key, AES.MODE_CBC, iv=self._iv).decrypt(bytes.fromhex(order_hex)), 16)
        return self._from_text(pt.decode("ASCII"))

    # -- login + iv recovery ----------------------------------------------
    async def login(self) -> None:
        async with httpx.AsyncClient() as client:
            # login id
            r = await self._post(client, _LOGIN_ID_PATH,
                                 self._login_body({"loginAccount": self._account}))
            if "result" not in r:
                raise CloudLANError(f"login/id failed: {r}")
            login_id = r["result"]["loginId"]

            # login
            r = await self._post(client, _LOGIN_PATH, self._login_body({
                "loginAccount": self._account,
                "password": self._password_hash(login_id),
            }))
            if "result" not in r:
                raise CloudLANError(f"login failed: {r}")
            res = r["result"]
            self._session_id = res["sessionId"]
            self._key = self._derive_key(res["accessToken"])
            _LOGGER.debug("Cloud login ok; key derived.")

        await self._recover_iv()

    async def _recover_iv(self) -> None:
        """Recover the session IV from the server's decryption echo (CBC leak)."""
        assert self._key
        # A harmless query frame (0x41 status poll).
        query = bytes.fromhex(
            "aa21ac00000000000303418100ff03ff00020000000000000000000000000304560b")
        packet = build_5a5a_packet(query, self.appliance_id, self._next_seq())
        text = self._to_text(packet)

        zero = b"\x00" * 16
        order = AES.new(self._key, AES.MODE_CBC, iv=zero).encrypt(Padding.pad(text, 16)).hex()

        async with httpx.AsyncClient() as client:
            body = {**self._base_body(), "applianceId": str(self.appliance_id),
                    "funId": _FUN_ID, "order": order}
            r = await self._post(client, _SEND_PATH, body)

        msg = str(r.get("msg", ""))
        marker = "order:"
        if marker not in msg:
            # Either already correct (unlikely with zero iv) or a real error.
            raise CloudLANError(f"IV recovery failed: {r}")
        echoed = msg.split(marker, 1)[1].encode("utf-8", "surrogateescape")
        self._iv = bytes(text[i] ^ zero[i] ^ echoed[i] for i in range(16))
        _LOGGER.debug("Recovered session IV: %s", self._iv)

    def _next_seq(self) -> int:
        self._seq += 1
        return self._seq

    # -- LAN-compatible transport -----------------------------------------
    async def send(self, data: bytes, retries: int = 3) -> list[bytes]:
        """Relay a device frame via the cloud; return raw AA responses."""
        if not (self._key and self._iv and self._session_id):
            raise CloudLANError("Not logged in; call login() first.")

        packet = build_5a5a_packet(data, self.appliance_id, self._next_seq())
        order = self._encrypt_order(packet)

        last = None
        for _ in range(max(1, retries)):
            try:
                async with httpx.AsyncClient() as client:
                    body = {**self._base_body(), "applianceId": str(self.appliance_id),
                            "funId": _FUN_ID, "order": order}
                    r = await self._post(client, _SEND_PATH, body)
            except httpx.HTTPError as e:
                last = e
                continue

            code = str(r.get("errorCode"))
            if code == "0":
                reply = r.get("result", {}).get("reply")
                if not reply:
                    return []
                aa = _extract_aa(self._decrypt_reply(reply))
                return [aa] if aa else []
            # Set commands are accepted without a synchronous reply frame.
            if code == "3176":
                _LOGGER.debug("Cloud accepted async (3176); no reply frame.")
                return []
            last = CloudLANError(f"Cloud error {code}: {r.get('msg')}")
            break

        _LOGGER.error("Cloud send failed for %s: %s", self.appliance_id, last)
        return []

    async def authenticate(self, token=None, key=None) -> None:
        return None

    @property
    def token(self):
        return None

    @property
    def key(self):
        return None

    @property
    def max_connection_lifetime(self) -> Optional[int]:
        return self._max_connection_lifetime

    @max_connection_lifetime.setter
    def max_connection_lifetime(self, seconds: Optional[int]) -> None:
        self._max_connection_lifetime = seconds

    def _disconnect(self) -> None:
        return None

    def disconnect(self) -> None:
        return None


def attach(device, cloud: CloudLAN):
    """Swap a Device's LAN transport for a cloud one. Returns the device."""
    device._lan = cloud  # type: ignore[assignment]
    return device
