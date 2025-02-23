import logging
import unittest
from unittest.mock import patch

from msmart.base_device import Device
from msmart.const import DeviceType, FrameType
from msmart.frame import Frame
from msmart.lan import ProtocolError


class TestSendCommand(unittest.IsolatedAsyncioTestCase):
    # pylint: disable=protected-access

    async def test_timeout(self) -> None:
        """Test that _send_command with a timeout returns any empty list."""

        # Create a dummy device
        device = Device(ip=0, port=0, device_id=0,
                        device_type=DeviceType.AIR_CONDITIONER)

        # Patch send to timeout
        with patch("msmart.lan.LAN.send", side_effect=TimeoutError) as patched_method:
            with self.assertLogs("msmart", logging.WARNING) as log:
                # Send dummy command
                cmd = Frame(device_type=DeviceType.AIR_CONDITIONER,
                            frame_type=FrameType.CONTROL)
                responses = await device._send_command(cmd)

                # Check warning message is generated for timeout
                self.assertRegex("\n".join(log.output), "Network timeout .*")

            # Assert patched method was awaited
            patched_method.assert_awaited()

            # Assrt empty list was returned
            self.assertEqual(responses, [])

    async def test_protocol_error(self) -> None:
        """Test that _send_command with a protocol error returns any empty list."""

        # Create a dummy device
        device = Device(ip=0, port=0, device_id=0,
                        device_type=DeviceType.AIR_CONDITIONER)

        # Patch send to throw protocol error
        with patch("msmart.lan.LAN.send", side_effect=ProtocolError) as patched_method:
            with self.assertLogs("msmart", logging.ERROR) as log:
                # Send dummy command
                cmd = Frame(device_type=DeviceType.AIR_CONDITIONER,
                            frame_type=FrameType.CONTROL)
                responses = await device._send_command(cmd)

                # Check warning message is generated for timeout
                self.assertRegex("\n".join(log.output), "Network error .*")

            # Assert patched method was awaited
            patched_method.assert_awaited()

            # Assrt empty list was returned
            self.assertEqual(responses, [])


if __name__ == "__main__":
    unittest.main()
