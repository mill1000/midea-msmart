import unittest
from typing import Union, cast
from unittest.mock import patch

from .command import QueryBasicResponse, Response
from .device import HeatPump as HP


class TestUpdateStateFromResponse(unittest.TestCase):
    """Test updating device state from responses."""

    def test_message(self) -> None:
        """Test parsing of QueryBasicResponse into device state."""

        # https://github.com/mill1000/midea-msmart/issues/107#issuecomment-1925457917
        # Response from basic query command
        TEST_MESSAGE = bytes.fromhex(
            "aa23c300000000000003010517a10303191e143037191905371919053c223c142200002c")

        resp = Response.construct(TEST_MESSAGE)
        self.assertIsNotNone(resp)

        # Assert response is a state response
        self.assertEqual(type(resp), QueryBasicResponse)

        # Create a dummy device and update the state
        device = HP(0, 0, 0)
        device._update_state(cast(QueryBasicResponse, resp))

        # Assert on some properties here


class TestRefresh(unittest.IsolatedAsyncioTestCase):
    """Test refreshing device state."""

    # Response from basic query command
    BASIC_RESPONSE = bytes.fromhex(
        "aa23c300000000000003010517a10303191e143037191905371919053c223c142200002c")

    async def test_refresh_no_response(self) -> None:
        """Test that a refresh() with no response marks a device as offline."""

        device = HP(0, 0, 0)
        device._online = True

        with patch("msmart.base_device.Device._send_command", return_value=[]) as patched_method:
            await device.refresh()

            # Unit parameters are not queried when the basic query fails
            patched_method.assert_awaited_once()

        self.assertEqual(device.online, False)

    async def test_refresh_no_unit_parameters(self) -> None:
        """Test that an unanswered unit parameters query keeps the device online and isn't repeated."""

        device = HP(0, 0, 0)

        with patch("msmart.base_device.Device._send_command",
                   side_effect=[[self.BASIC_RESPONSE], []]) as patched_method:
            await device.refresh()
            self.assertEqual(patched_method.await_count, 2)

        self.assertEqual(device.online, True)
        self.assertEqual(device.supported, True)

        with patch("msmart.base_device.Device._send_command",
                   return_value=[self.BASIC_RESPONSE]) as patched_method:
            await device.refresh()

            # Only the basic query is sent once unit parameters went unanswered
            patched_method.assert_awaited_once()

        self.assertEqual(device.online, True)


if __name__ == "__main__":
    unittest.main()
