import logging
import unittest
from typing import Union, cast

from .command import QueryBasicResponse, ReportPower4Response, Response


class _TestResponseBase(unittest.TestCase):
    """Base class that provides some common methods for derived classes."""

    def assertHasAttr(self, obj, attr) -> None:
        """Assert that an object has an attribute."""
        self.assertTrue(hasattr(obj, attr),
                        msg=f"Object {obj} lacks attribute '{attr}'.")

    def _test_build_response(self, msg) -> Union[QueryBasicResponse, Response]:
        """Build a response from the frame and assert it exists."""
        resp = Response.construct(msg)
        self.assertIsNotNone(resp)
        return resp

    def _test_check_attributes(self, obj, expected_attrs) -> None:
        """Assert that an object has all expected attributes."""
        for attr in expected_attrs:
            self.assertHasAttr(obj, attr)


class TestQueryBasicResponse(_TestResponseBase):
    """Test basic query response messages."""

    # Attributes expected in state response objects
    EXPECTED_ATTRS = []

    def _test_response(self, msg) -> QueryBasicResponse:
        resp = self._test_build_response(msg)
        # self._test_check_attributes(resp, self.EXPECTED_ATTRS)
        return cast(QueryBasicResponse, resp)

    def test_message(self) -> None:
        # https://github.com/mill1000/midea-msmart/issues/107#issuecomment-1925457917
        # Response from basic query command
        TEST_MESSAGE = bytes.fromhex(
            "aa23c300000000000003010517a10303191e143037191905371919053c223c142200002c")
        resp = self._test_response(TEST_MESSAGE)

        # Assert response is a state response
        self.assertEqual(type(resp), QueryBasicResponse)


class TestPower4Response(_TestResponseBase):
    """Test POWER4 report messages."""

    # Attributes expected in state response objects
    EXPECTED_ATTRS = []

    def _test_response(self, msg) -> ReportPower4Response:
        resp = self._test_build_response(msg)
        # self._test_check_attributes(resp, self.EXPECTED_ATTRS)
        return cast(ReportPower4Response, resp)

    def test_message(self) -> None:
        # https://github.com/mill1000/midea-msmart/issues/107#issuecomment-1962036384
        # Unsolicited report with POWER4 payload
        TEST_MESSAGE = bytes.fromhex(
            "aab9c3000000000000040400000012fc000023aa0b201e2930ffff01000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000e10000000000000000000000000000000000140b")
        resp = self._test_response(TEST_MESSAGE)

        # Assert response is a state response
        self.assertEqual(type(resp), ReportPower4Response)

        self.assertEqual(resp.electric_power, 4860)
        self.assertEqual(resp.thermal_power, 9130)

        self.assertEqual(resp.outdoor_air_temperature, 11)
        self.assertEqual(resp.water_tank_temperature, 41)

        self.assertEqual(resp.voltage, 225)


if __name__ == "__main__":
    unittest.main()
