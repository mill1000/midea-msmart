import unittest
from typing import Union, cast

from msmart.const import FrameType

from .command import (ControlBasicCommand, ControlType, QueryBasicCommand,
                      QueryBasicResponse, QueryType, ReportPower4Response,
                      Response)


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

    # Attributes expected in query response objects
    EXPECTED_ATTRS = ["zone1_power_state", "zone2_power_state",
                      "dhw_power_state",
                      "zone1_curve_state", "zone2_curve_state",
                      "tbh_state", "dhw_fast_mode",
                      "heat_enable", "cool_enable", "dhw_enable",
                      "zone2_enable",
                      "zone1_temperature_type", "zone2_temperature_type",
                      "room_thermostat_power_state", "room_thermostat_enable",
                      "time_set_state", "silence_on_state", "holiday_on_state", "eco_on_state",
                      "zone1_terminal_type", "zone2_terminal_type",
                      "run_mode", "run_mode_under_auto",
                      "zone1_target_temperature", "zone2_target_temperature",
                      "dhw_target_temperature", "room_target_temperature",
                      "zone1_heat_max_temperature", "zone1_heat_min_temperature",
                      "zone1_cool_max_temperature", "zone1_cool_min_temperature",
                      "zone2_heat_max_temperature", "zone2_heat_min_temperature",
                      "zone2_cool_max_temperature", "zone2_cool_min_temperature",
                      "room_max_temperature", "room_min_temperature",
                      "dhw_max_temperature", "dhw_min_temperature",
                      "tank_temperature", "error_code", "tbh_enable"
                      ]

    def _test_response(self, msg) -> QueryBasicResponse:
        resp = self._test_build_response(msg)
        self._test_check_attributes(resp, self.EXPECTED_ATTRS)
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
    EXPECTED_ATTRS = ["heat_active", "cool_active",
                      "dhw_active", "tbh_active",
                      "electric_power", "thermal_power",
                      "outdoor_air_temperature",
                      "zone1_target_temperature", "zone2_target_temperature",
                      "water_tank_temperature",
                      "online", "voltage"
                      ]

    def _test_response(self, msg) -> ReportPower4Response:
        resp = self._test_build_response(msg)
        self._test_check_attributes(resp, self.EXPECTED_ATTRS)
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


class TestCommands(unittest.TestCase):
    """Test basic command messages."""

    def test_control_basic(self) -> None:
        """Test that basic control fields are correct."""

        # Build command
        command = ControlBasicCommand()

        # Fetch frame
        frame = command.tobytes()

        # Check length
        self.assertEqual(frame[1], 0x14)

        # Check frame type
        self.assertEqual(frame[9], FrameType.CONTROL)

        # Check control type
        self.assertEqual(frame[10], ControlType.CONTROL_BASIC)

    def test_query_basic(self) -> None:
        """Test that basic query fields are correct."""

        # Build command
        command = QueryBasicCommand()

        # Fetch frame
        frame = command.tobytes()

        # Check length
        self.assertEqual(frame[1], 0x0B)

        # Check frame type
        self.assertEqual(frame[9], FrameType.QUERY)

        # Check control type
        self.assertEqual(frame[10], QueryType.QUERY_BASIC)


if __name__ == "__main__":
    unittest.main()
