import logging
import unittest
from typing import cast

from msmart.const import DeviceType, FrameType
from msmart.frame import Frame, InvalidFrameException

from .command import *


class _TestResponseBase(unittest.TestCase):
    """Base class that provides some common methods for derived classes."""

    def assertHasAttr(self, obj, attr) -> None:
        """Assert that an object has an attribute."""
        self.assertTrue(hasattr(obj, attr),
                        msg=f"Object {obj} lacks attribute '{attr}'.")

    def _test_build_response(self, msg) -> Response:
        """Build a response from the frame and assert it exists."""
        resp = Response.construct(msg)
        self.assertIsNotNone(resp)
        return resp

    def _test_check_attributes(self, obj, expected_attrs) -> None:
        """Assert that an object has all expected attributes."""
        for attr in expected_attrs:
            self.assertHasAttr(obj, attr)


class TestCommand(unittest.TestCase):

    def test_frame(self) -> None:
        """Test that we frame a command properly."""

        EXPECTED_PAYLOAD = bytes.fromhex(
            "0100000000000000000000000000000000000000000001")

        # Override message id to match test data
        Command._message_id = 0x10

        # Build frame from command
        command = QueryCommand()
        frame = command.tobytes()
        self.assertIsNotNone(frame)

        # Assert that frame is valid
        with memoryview(frame) as frame_mv:
            Frame.validate(frame_mv)

        # Check frame payload to ensure it matches expected
        self.assertEqual(frame[10:-1], EXPECTED_PAYLOAD)

        # Check length byte
        self.assertEqual(frame[1], len(
            EXPECTED_PAYLOAD) + Frame._HEADER_LENGTH)

        # Check device type
        self.assertEqual(frame[2], DeviceType.AIR_CONDITIONER)

        # Check frame type
        self.assertEqual(frame[9], FrameType.QUERY)


class TestStateResponse(_TestResponseBase):
    """Test device state response messages."""

    # Attributes expected in state response objects
    EXPECTED_ATTRS = [
    ]

    def _test_response(self, msg) -> StateResponse:
        resp = self._test_build_response(msg)
        self._test_check_attributes(resp, self.EXPECTED_ATTRS)
        return cast(StateResponse, resp)


if __name__ == "__main__":
    unittest.main()
