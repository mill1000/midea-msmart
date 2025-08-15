import asyncio
import logging
import unittest
from contextlib import contextmanager
from typing import Generator, cast
from unittest.mock import AsyncMock, MagicMock, PropertyMock, patch

from msmart.lan import (LAN, AuthenticationError, ProtocolError, _LanProtocol,
                        _LanProtocolV3, _Packet)


class TestEncodeDecode(unittest.IsolatedAsyncioTestCase):
    # pylint: disable=protected-access

    def test_encode_packet_roundtrip(self) -> None:
        """Test that we can encode and decode a frame."""
        FRAME = bytes.fromhex(
            "aa21ac8d000000000003418100ff03ff000200000000000000000000000003016971")

        packet = _Packet.encode(123456, FRAME)
        self.assertIsNotNone(packet)

        rx_frame = _Packet.decode(packet)
        self.assertEqual(rx_frame, FRAME)

    def test_decode_packet(self) -> None:
        """Test that we can decode a packet to a frame."""
        PACKET = bytes.fromhex(
            "5a5a01116800208000000000000000000000000060ca0000000e0000000000000000000001000000c6a90377a364cb55af337259514c6f96bf084e8c7a899b50b68920cdea36cecf11c882a88861d1f46cd87912f201218c66151f0c9fbe5941c5384e707c36ff76")
        EXPECTED_FRAME = bytes.fromhex(
            "aa22ac00000000000303c0014566000000300010045cff2070000000000000008bed19")

        frame = _Packet.decode(PACKET)
        self.assertIsNotNone(frame)
        self.assertEqual(frame, EXPECTED_FRAME)

    def test_decode_v3_packet(self) -> None:
        """Test that we can decode a V3 packet to payload to a frame."""
        PACKET = bytes.fromhex("8370008e2063ec2b8aeb17d4e3aff77094dde7fa65cf22671adf807f490a97b927347943626e9b4f58362cf34b97a0d641f8bf0c8fcbf69ad8cca131d2d7baa70ef048c5e3f3dc78da8af4598ff47aee762a0345c18815d91b50a24dedcacde0663c4ec5e73a963dc8bbbea9a593859996eb79dcfcc6a29b96262fcaa8ea6346366efea214e4a2e48caf83489475246b6fef90192b00")
        LOCAL_KEY = bytes.fromhex(
            "55a0a178746a424bf1fc6bb74b9fb9e4515965048d24ce8dc72aca91597d05ab")

        EXPECTED_PAYLOAD = bytes.fromhex(
            "5a5a01116800208000000000eaa908020c0817143daa0000008600000000000000000180000000003e99f93bb0cf9ffa100cb24dbae7838641d6e63ccbcd366130cd74a372932526d98479ff1725dce7df687d32e1776bf68a3fa6fd6259d7eb25f32769fcffef78")
        EXPECTED_FRAME = bytes.fromhex(
            "aa23ac00000000000303c00145660000003c0010045c6800000000000000000000018426")

        # Setup the protocol
        protocol = _LanProtocolV3()
        protocol._local_key = LOCAL_KEY

        with memoryview(PACKET) as mv_packet:
            payload = protocol._process_packet(mv_packet)
        self.assertIsNotNone(payload)
        self.assertEqual(payload, EXPECTED_PAYLOAD)

        frame = _Packet.decode(payload)
        self.assertIsNotNone(frame)
        self.assertEqual(frame, EXPECTED_FRAME)

    def test_encode_packet_v3_roundtrip(self) -> None:
        """Test that we can encode a frame to V3 packet and back to the same frame."""
        FRAME = bytes.fromhex(
            "aa23ac00000000000303c00145660000003c0010045c6800000000000000000000018426")
        LOCAL_KEY = bytes.fromhex(
            "55a0a178746a424bf1fc6bb74b9fb9e4515965048d24ce8dc72aca91597d05ab")

        # Setup the protocol
        protocol = _LanProtocolV3()
        protocol._local_key = LOCAL_KEY

        # Encode frame into V2 payload
        payload = _Packet.encode(123456, FRAME)
        self.assertIsNotNone(payload)

        # Encode V2 payload into V3 packet
        with memoryview(payload) as mv_payload:
            packet = protocol._encode_encrypted_request(5555, mv_payload)

        self.assertIsNotNone(packet)

        # Decode packet into V2 payload
        with memoryview(packet) as mv_packet:
            # Can't call _process_packet since our test packet doesn't have the right type byte
            rx_payload = protocol._decode_encrypted_response(mv_packet)

        self.assertIsNotNone(rx_payload)

        # Decode V2 payload to frame
        rx_frame = _Packet.decode(rx_payload)
        self.assertIsNotNone(rx_frame)
        self.assertEqual(rx_frame, FRAME)


class TestLan(unittest.IsolatedAsyncioTestCase):
    # pylint: disable=protected-access

    class MockLAN(LAN):
        """Dummy class to suppress type errors"""
        _protocol: MagicMock
        _connect: AsyncMock  # type: ignore
        _disconnect: MagicMock  # type: ignore

    @contextmanager
    def _mock_lan(self, alive: bool = True, spec_protocol=_LanProtocol) -> Generator[MockLAN, None, None]:
        """Yield a LAN instance with a mock protocol for testing."""
        lan = LAN("0.0.0.0", 0, 0)
        lan._protocol = MagicMock(spec=spec_protocol)
        lan._connect = AsyncMock()
        lan._disconnect = MagicMock()

        # Mock the read_available method so calls to send() will be reached
        lan._read_available = MagicMock()
        lan._read_available.__aiter__.return_value = None

        # Patch _alive property to fake connection
        with patch.object(LAN, '_alive', new_callable=PropertyMock(return_value=alive)):
            yield cast(TestLan.MockLAN, lan)

    async def test_send_connect_flow_v2(self) -> None:
        """Test the connect flow in the send method for V2 protocol."""
        with self._mock_lan(alive=False) as lan:
            # Mock additional methods
            lan.authenticate = AsyncMock()
            lan._protocol.write = MagicMock()
            lan._read = AsyncMock()

            # Send a packet
            await lan.send(bytes(0))

            # Assert a disconnect->connect cycle occurred
            lan._disconnect.assert_called_once()
            lan._connect.assert_awaited_once()

            # Assert we didn't try to authenticate on a V2 protocol
            lan.authenticate.assert_not_awaited()

    async def test_send_connect_flow_v3(self) -> None:
        """Test the connect & authenticate flow in the send method for V3 protocol."""
        with self._mock_lan(alive=False, spec_protocol=_LanProtocolV3) as lan:
            # Mock authentication
            type(lan._protocol).authenticated = PropertyMock(return_value=False)

            async def _authenticate(*args, **kwargs) -> None:
                type(lan._protocol).authenticated = PropertyMock(
                    return_value=True)

            lan.authenticate = AsyncMock(side_effect=_authenticate)
            lan._protocol.write = MagicMock()
            lan._read = AsyncMock()

            # Send a packet
            await lan.send(bytes(0))

           # Assert a disconnect->connect cycle occurred
            lan._disconnect.assert_called_once()
            lan._connect.assert_awaited_once()

            # Assert that authenticate was called
            lan.authenticate.assert_awaited_once()

    async def test_send_read_timeouts(self) -> None:
        """Test that both types of read timeouts are handled."""
        with self._mock_lan() as lan:
            # Test TimeoutError
            lan._protocol.read = AsyncMock(side_effect=TimeoutError)
            with self.assertRaisesRegex(TimeoutError, "No response from host."):
                await lan.send(bytes(0))

            # Assert disconnect was called
            lan._disconnect.assert_called_once()

            # Test asyncio.TimeoutError
            lan._protocol.read.side_effect = asyncio.TimeoutError
            lan._disconnect.reset_mock()
            with self.assertRaisesRegex(TimeoutError, "No response from host."):
                await lan.send(bytes(0))

            # Assert disconnect was called
            lan._disconnect.assert_called_once()

    async def test_send_read_exception(self) -> None:
        """Test that read exceptions are logged and handled."""
        with self._mock_lan() as lan:
            lan._protocol.read = AsyncMock(side_effect=ProtocolError)

            # Test ProtocolErrors bubble up and disconnect
            with (
                self.assertLogs("msmart.lan", logging.WARNING),
                self.assertRaises(ProtocolError)
            ):
                await lan.send(bytes(0))

            # Assert disconnect was called
            lan._disconnect.assert_called_once()

    async def test_send_read_canceled_exception(self) -> None:
        """Test that read cancelled exceptions are logged and propagate as a timeout."""
        with self._mock_lan() as lan:
            lan._protocol.read = AsyncMock(side_effect=asyncio.CancelledError)

            # Test cancelled exceptions log a warning, bubble up as TimeoutError and disconnect
            with (
                self.assertLogs("msmart", logging.WARNING) as log,
                self.assertRaisesRegex(TimeoutError, "Read cancelled.")
            ):
                await lan.send(bytes(0))

                # Assert timeouts were logged
                self.assertRegex(" ".join(log.output),
                                 ".*Read cancelled. Disconnecting.*")

            # Assert disconnect was called
            lan._disconnect.assert_called_once()

    async def test_authenticate_connect_flow(self) -> None:
        """Test the connect flow in the authenticate method."""
        with self._mock_lan(alive=False, spec_protocol=_LanProtocolV3) as lan:
            await lan.authenticate()

            # Assert a disconnect->connect cycle occurred
            lan._disconnect.assert_called_once()
            lan._connect.assert_awaited_once()

            # Assert that the expected protocol version is set
            self.assertEqual(lan._protocol_version, 3)

            # Assert protocol tried to authenticate
            lan._protocol.authenticate.assert_awaited_once()

    async def test_authenticate_timeouts(self) -> None:
        """Test that both types of timeouts are handled in authentication."""
        with self._mock_lan(spec_protocol=_LanProtocolV3) as lan:
            # Test TimeoutError
            lan._protocol.authenticate = AsyncMock(side_effect=TimeoutError)
            with (
                self.assertRaisesRegex(TimeoutError, "No response from host."),
                self.assertLogs("msmart.lan", logging.DEBUG) as log
            ):

                await lan.authenticate(key=bytes(10), token=bytes(10))

                # Assert timeouts were logged
                self.assertRegex(" ".join(log.output),
                                 "Authentication timeout. Resending to .*")

            # Assert disconnect was called
            lan._disconnect.assert_called_once()

            # Test asyncio.TimeoutError
            lan._protocol.read.side_effect = asyncio.TimeoutError
            lan._disconnect.reset_mock()
            with (
                self.assertRaisesRegex(TimeoutError, "No response from host."),
                self.assertLogs("msmart.lan", logging.DEBUG) as log
            ):
                await lan.authenticate(key=bytes(10), token=bytes(10))

            # Assert disconnect was called
            lan._disconnect.assert_called_once()

    async def test_authenticate_exception(self) -> None:
        """Test that authentication exceptions are logged and handled."""
        with self._mock_lan(spec_protocol=_LanProtocolV3) as lan:
            lan._protocol.authenticate = AsyncMock(
                side_effect=AuthenticationError)

            # Test AuthenticationError bubble up and disconnect
            with self.assertRaises(AuthenticationError):
                await lan.authenticate(key=bytes(10), token=bytes(10))

            # Assert disconnect was called
            lan._disconnect.assert_called_once()


class TestProtocol(unittest.IsolatedAsyncioTestCase):
    # pylint: disable=protected-access

    class MockProtocol(_LanProtocol):
        """Dummy class to suppress type errors"""
        authenticate: AsyncMock
        write: MagicMock  # type: ignore

    @contextmanager
    def _mock_protocol(self) -> Generator[MockProtocol, None, None]:
        """Yield a Protocol instance for testing"""
        protocol = _LanProtocolV3()
        protocol.write = MagicMock()

        yield cast(TestProtocol.MockProtocol, protocol)

    async def test_authenticate_token_key_exception(self) -> None:
        """Test exception handling for authenticate method."""
        with self._mock_protocol() as protocol:
            # Assert that exception is thrown if token and key are invalid
            with self.assertRaisesRegex(AuthenticationError, "Token and key must be supplied."):
                await protocol.authenticate(key=None, token=None)

    async def test_authenticate_write_exception(self) -> None:
        """Test write exception handling for authenticate method."""
        with self._mock_protocol() as protocol:
            protocol.write.side_effect = ProtocolError

            # Assert that a protocol error bubbles up as AuthenticationError
            with self.assertRaises(AuthenticationError):
                await protocol.authenticate(key=bytes(10), token=bytes(10))

    async def test_authenticate_read_exception(self) -> None:
        """Test read exception handling for authenticate method."""
        with self._mock_protocol() as protocol:
            protocol.read = AsyncMock(side_effect=ProtocolError)

            # Assert that a protocol error bubbles up as AuthenticationError
            with self.assertRaises(AuthenticationError):
                await protocol.authenticate(key=bytes(10), token=bytes(10))

            # Assert write/read calls were made
            protocol.write.assert_called_once()
            protocol.read.assert_awaited_once()

    async def test_read_connection_lost_exception(self) -> None:
        """Test that connection lose will raise an exception."""
        with self._mock_protocol() as protocol:
            with self.assertLogs("msmart.lan", logging.ERROR):
                protocol.connection_lost(ConnectionResetError())

            with self.assertRaises(ProtocolError):
                await protocol.read()


if __name__ == "__main__":
    unittest.main()
