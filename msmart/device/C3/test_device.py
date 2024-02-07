import unittest
from typing import Union, cast

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


if __name__ == "__main__":
    unittest.main()
