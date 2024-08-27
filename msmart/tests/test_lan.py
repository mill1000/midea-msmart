import asyncio
import logging
import unittest
import unittest.mock as mock

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


class TestProtocol(unittest.IsolatedAsyncioTestCase):
    # pylint: disable=protected-access

    async def test_send_exceptions(self) -> None:
        """Test exception handling for send method."""
        # Create a dummy LAN object to test
        lan = LAN("0.0.0.0", 0, 0)

        # Mock the protocol object
        lan._protocol = mock.MagicMock(spec=_LanProtocol)

        # Mock the read_available method so call to send() will be reached
        lan._read_available = mock.MagicMock()
        lan._read_available.__aiter__.return_value = None

        # Mock the disconnect method to ensure it's called
        lan._disconnect = mock.MagicMock()

        # Test that both types of timeouts bubble up as TimeoutError
        # Test asyncio.TimeoutError
        lan._protocol.read.side_effect = asyncio.TimeoutError
        lan._disconnect.reset_mock()
        with self.assertRaisesRegex(TimeoutError, "No response from host."):
            await lan.send(bytes(0))

        # Assert disconnect was called
        lan._disconnect.assert_called_once()

        # Test TimeoutError
        lan._protocol.read.side_effect = TimeoutError
        lan._disconnect.reset_mock()
        with self.assertRaisesRegex(TimeoutError, "No response from host."):
            await lan.send(bytes(0))

        lan._disconnect.assert_called_once()

        # Test cancelled exceptions log a warning and bubble up as TimeoutError
        with self.assertLogs("msmart", logging.WARNING) as log:

            lan._protocol.read.side_effect = asyncio.CancelledError
            lan._disconnect.reset_mock()
            with self.assertRaisesRegex(TimeoutError, "Read cancelled."):
                await lan.send(bytes(0))

            # Assert disconnect was called
            lan._disconnect.assert_called_once()

            # Assert timeouts were logged
            self.assertRegex(" ".join(log.output),
                             ".*Read cancelled. Disconnecting.*")

        # Test ProtocolErrors bubbled up with a disconnect
        lan._protocol.read.side_effect = ProtocolError
        lan._disconnect.reset_mock()
        with self.assertRaises(ProtocolError):
            await lan.send(bytes(0))

        # Assert disconnect was called
        lan._disconnect.assert_called_once()

    async def test_authenticate_exceptions(self) -> None:
        """Test exception handling for authenticate method."""
        # Create a dummy LAN object to test
        lan = LAN("0.0.0.0", 0, 0)

        # Mock connect method to create a protocol
        def _mock_connect() -> None:
            lan._protocol = _LanProtocolV3()

        # Mock connect/disconnect methods to check that they're called
        lan._connect = mock.AsyncMock(side_effect=_mock_connect)
        lan._disconnect = mock.MagicMock()

        # Assert that exception is thrown is token and key are invalid
        with self.assertRaisesRegex(AuthenticationError, "Token and key must be supplied."):
            await lan.authenticate(key=None, token=None)

        # Assert a disconnect->connect cycle occurred
        lan._disconnect.assert_called_once()
        lan._connect.assert_awaited_once()

        # Assert that the expected protocol class was created
        self.assertEqual(lan._protocol_version, 3)
        self.assertIsInstance(lan._protocol, _LanProtocolV3)

        # Mock connect method to create a protocol that throws
        def _mock_connect_write_error() -> None:
            lan._protocol = _LanProtocolV3()
            lan._protocol.write = mock.MagicMock(side_effect=ProtocolError)

        # Assert that a protocol error bubbles up as AuthenticationError
        lan._connect.side_effect = _mock_connect_write_error
        with self.assertRaises(AuthenticationError):
            await lan.authenticate(key=bytes(10), token=bytes(10))

        # Mock connect method to create a protocol that timeouts
        def _mock_connect_timeout() -> None:
            lan._protocol = _LanProtocolV3()
            lan._protocol.authenticate = mock.MagicMock(
                side_effect=TimeoutError)

        # Assert that timeouts bubble up
        lan._connect.side_effect = _mock_connect_timeout
        with self.assertRaisesRegex(TimeoutError, "No response from host."):
            await lan.authenticate(key=bytes(10), token=bytes(10))


if __name__ == "__main__":
    unittest.main()
