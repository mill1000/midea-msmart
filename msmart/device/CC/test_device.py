import logging
import unittest
from typing import cast
from unittest.mock import patch

from .command import *
from .device import CommercialAirConditioner as CC


class TestDeviceEnums(unittest.TestCase):
    """Test device specific enum handling."""

    def _test_enum_members(self, enum_cls) -> None:
        """Check each enum member can be converted back to itself."""

        # Test each member of the enum
        for enum in enum_cls.list():
            # Test that fetching enum from name returns the same enum
            e_from_name = enum_cls.get_from_name(enum.name)
            self.assertEqual(e_from_name, enum)
            self.assertIsInstance(e_from_name, enum_cls)

            # Test that fetching enum from value returns the same enum
            e_from_value = enum_cls.get_from_value(enum.value)
            self.assertEqual(e_from_value, enum)
            self.assertIsInstance(e_from_value, enum_cls)

    def _test_enum_fallback(self, enum_cls) -> None:
        """Test enum fallback behavior"""

        # Test fall back behavior to "OFF"
        enum = enum_cls.get_from_name("INVALID_NAME")
        self.assertEqual(enum, enum_cls.DEFAULT)
        self.assertIsInstance(enum, enum_cls)

        # Test fall back behavior to "OFF"
        enum = enum_cls.get_from_value(1234567)
        self.assertEqual(enum, enum_cls.DEFAULT)
        self.assertIsInstance(enum, enum_cls)

        # Test that converting from None works
        enum = enum_cls.get_from_value(None)
        self.assertEqual(enum, enum_cls.DEFAULT)
        self.assertIsInstance(enum, enum_cls)

        enum = enum_cls.get_from_name(None)
        self.assertEqual(enum, enum_cls.DEFAULT)
        self.assertIsInstance(enum, enum_cls)

        enum = enum_cls.get_from_name("")
        self.assertEqual(enum, enum_cls.DEFAULT)
        self.assertIsInstance(enum, enum_cls)

    def test_device_enums(self) -> None:
        """Test enum conversion from value/name."""

        ENUM_CLASSES = [
            CC.AuxHeatMode,
            CC.FanSpeed,
            CC.OperationalMode,
            CC.PurifierMode,
            CC.SwingAngle,
            CC.SwingMode,
        ]

        for enum_cls in ENUM_CLASSES:
            # Test conversion to/from enum members
            self._test_enum_members(enum_cls)

            # Test default fallback
            self._test_enum_fallback(enum_cls)


class TestSwingMode(unittest.TestCase):
    """Test swing mode handling of device class."""

    def test_swing_mode_decode(self) -> None:
        """Test decoding swing angle into swing modes."""
        # Create a dummy device
        device = CC(0, 0, 0)

        # Assert defaults to off
        self.assertEqual(device.swing_mode, CC.SwingMode.OFF)

        # Assert auto horizontal swing angle decodes to swing mode horizontal
        device._horizontal_swing_angle = CC.SwingAngle.AUTO
        device._vertical_swing_angle = CC.SwingAngle.CLOSE
        self.assertEqual(device.swing_mode, CC.SwingMode.HORIZONTAL)

        # Assert auto vertical swing angle decodes to swing mode vertical
        device._horizontal_swing_angle = CC.SwingAngle.CLOSE
        device._vertical_swing_angle = CC.SwingAngle.AUTO
        self.assertEqual(device.swing_mode, CC.SwingMode.VERTICAL)

        # Assert auto both swing angles decode to swing mode both
        device._horizontal_swing_angle = CC.SwingAngle.AUTO
        device._vertical_swing_angle = CC.SwingAngle.AUTO
        self.assertEqual(device.swing_mode, CC.SwingMode.BOTH)

    def test_swing_mode_encode(self) -> None:
        """Test encoding swing mode into swing angle."""
        # Create a dummy device
        device = CC(0, 0, 0)

        device.swing_mode = CC.SwingMode.OFF
        self.assertEqual(device._horizontal_swing_angle, CC.SwingAngle.DEFAULT)
        self.assertEqual(device._vertical_swing_angle, CC.SwingAngle.DEFAULT)

        device.swing_mode = CC.SwingMode.HORIZONTAL
        self.assertEqual(device._horizontal_swing_angle, CC.SwingAngle.AUTO)
        self.assertEqual(device._vertical_swing_angle, CC.SwingAngle.DEFAULT)

        device.swing_mode = CC.SwingMode.VERTICAL
        self.assertEqual(device._horizontal_swing_angle, CC.SwingAngle.DEFAULT)
        self.assertEqual(device._vertical_swing_angle, CC.SwingAngle.AUTO)

        device.swing_mode = CC.SwingMode.BOTH
        self.assertEqual(device._horizontal_swing_angle, CC.SwingAngle.AUTO)
        self.assertEqual(device._vertical_swing_angle, CC.SwingAngle.AUTO)


class TestUpdateStateFromResponse(unittest.TestCase):
    """Test updating device state from responses."""

    def test_state_response(self) -> None:
        """Test parsing of StateResponses into device state."""
        # https://github.com/mill1000/midea-msmart/pull/233#issuecomment-3272675291
        TEST_RESPONSE = bytes.fromhex(
            "aa63cc0000000000000301fe00000043005001728c7800ff00728c728c787800010141ff010203000603010008000600000001060106010000000000000000000001000100010000000000000000000000000001000200000100000101000102ff02ff5f")

        resp = Response.construct(TEST_RESPONSE)
        self.assertIsNotNone(resp)

        # Assert response is a query response
        self.assertEqual(type(resp), QueryResponse)

        # Create a dummy device and process the response
        device = CC(0, 0, 0)
        device._update_state(resp)

        # Assert state is expected
        self.assertEqual(device.target_temperature, 20.0)
        self.assertEqual(device.indoor_temperature, 25.5)

        self.assertEqual(device.eco, False)
        self.assertEqual(device.silent, False)
        self.assertEqual(device.sleep, False)
        self.assertEqual(device.purifier, CC.PurifierMode.OFF)
        # self.assertEqual(device.soft, False)

        self.assertEqual(device.operational_mode, CC.OperationalMode.HEAT)
        self.assertEqual(device.fan_speed, CC.FanSpeed.AUTO)
        self.assertEqual(device.swing_mode, CC.SwingMode.BOTH)

    def test_aux_mode(self) -> None:
        """Test parsing of aux mode into device state."""
        # https://github.com/mill1000/midea-msmart/pull/233#issuecomment-3272675291
        TEST_RESPONSES = {
            CC.AuxHeatMode.ON: bytes.fromhex("aa63cc0000000000000301fe00000043005001728c78010600728c728c787800010141ff010203000603010008000100000001010103010000000000000000000001000100010000000000000000000000000001000200000100000101000102ff01ff65"),
            CC.AuxHeatMode.AUTO: bytes.fromhex("aa63cc0000000000000301fe00000043005001728c78010600728c728c787800010141ff010203000603010008000100000001010103010000000000000000000001000100010000000000000000000000000001000200000100000101000102ff00ff66"),
            CC.AuxHeatMode.OFF: bytes.fromhex("aa63cc0000000000000301fe00000043005001728c78010600728c728c787800010141ff010203000603010008000100000001010103010000000000000000000001010100010000000000000000000000000001000200000100000101000102ff02ff63"),
        }

        # Create a dummy device
        device = CC(0, 0, 0)

        for value, response in TEST_RESPONSES.items():
            resp = Response.construct(response)
            self.assertIsNotNone(resp)

            # Assert response is a query response
            self.assertEqual(type(resp), QueryResponse)

            # Process the response
            device._update_state(resp)

            # Assert that expected aux mode matches
            self.assertEqual(device.aux_mode, value)

    def test_purifier_mode(self) -> None:
        """Test parsing of purifier mode into device state."""
        # https://github.com/mill1000/midea-msmart/pull/233#issuecomment-3272675291
        TEST_RESPONSES = {
            CC.PurifierMode.ON: bytes.fromhex("aa63cc0000000000000301fe00000043005001728c78010600728c728c787800010141ff010203000603010008000100000001010103010000000000000000000001000100010000000000000000000000000001000100000100000101000102ff02ff65"),
            CC.PurifierMode.OFF: bytes.fromhex("aa63cc0000000000000301fe00000043005001728c78010700728c728c787800010141ff010203000603010008000100000001010103010000000000000000000001000101010000000000000000000000000001000200000100000101000102ff02ff62"),
            # CC.AuxHeatMode.AUTO: bytes.fromhex(""), # TODO
        }

        # Create a dummy device
        device = CC(0, 0, 0)

        for value, response in TEST_RESPONSES.items():
            resp = Response.construct(response)
            self.assertIsNotNone(resp)

            # Assert response is a query response
            self.assertEqual(type(resp), QueryResponse)

            # Process the response
            device._update_state(resp)

            # Assert that expected mode matches
            self.assertEqual(device.purifier, value)


class TestCapabilities(unittest.TestCase):
    """Test parsing of CapabilitiesResponse into device capabilities."""

    def test_capability_parsing(self) -> None:
        """Test parsing device capabilities."""
        # https://github.com/mill1000/midea-msmart/pull/233#issuecomment-3272675291
        TEST_RESPONSE = bytes.fromhex(
            "aa63cc0000000000000301fe00000043005001728c7800ff00728c728c787800010141ff010203000603010008000600000001060106010000000000000000000001000100010000000000000000000000000001000200000100000101000102ff02ff5f")

        resp = Response.construct(TEST_RESPONSE)
        self.assertIsNotNone(resp)

        # Assert response is a query response
        self.assertEqual(type(resp), QueryResponse)

        # Suppress type errors
        resp = cast(QueryResponse, resp)

        # Parse capabilities
        resp.parse_capabilities()

        # Create a dummy device and process the response
        device = CC(0, 0, 0)
        device._update_capabilities(resp)

        self.assertCountEqual(device.supported_operation_modes, [
            CC.OperationalMode.HEAT,
            CC.OperationalMode.COOL,
            CC.OperationalMode.FAN,
            CC.OperationalMode.DRY,
        ])

        self.assertCountEqual(device.supported_swing_modes, [
            CC.SwingMode.OFF,
            CC.SwingMode.BOTH,
            CC.SwingMode.HORIZONTAL,
            CC.SwingMode.VERTICAL
        ])

        self.assertCountEqual(device.supported_fan_speeds, [
            CC.FanSpeed.L1,
            CC.FanSpeed.L2,
            CC.FanSpeed.L3,
            CC.FanSpeed.L4,
            CC.FanSpeed.L5,
            CC.FanSpeed.L6,
            CC.FanSpeed.L7,
            CC.FanSpeed.AUTO,
        ])

        self.assertEqual(device.supports_humidity, True)

        self.assertEqual(device.supports_eco, True)
        self.assertEqual(device.supports_silent, True)
        self.assertEqual(device.supports_sleep, True)

        self.assertCountEqual(device.supported_purifier_modes, [
            CC.PurifierMode.OFF, CC.PurifierMode.ON])
        self.assertCountEqual(device.supported_aux_modes, [
            CC.AuxHeatMode.OFF, CC.AuxHeatMode.ON, CC.AuxHeatMode.AUTO])


class TestSendCommandGetResponse(unittest.IsolatedAsyncioTestCase):
    # pylint: disable=protected-access

    async def test_refresh_no_response(self) -> None:
        """Test that a refresh() with no response marks a device as offline."""

        # Create a dummy device
        device = CC(0, 0, 0)

        # Patch _send_command to return no responses
        with patch("msmart.base_device.Device._send_command", return_value=[]) as patched_method:

            # Force device online
            device._online = True
            self.assertEqual(device.online, True)

            # Refresh device
            await device.refresh()

            # Assert patch method was awaited
            patched_method.assert_awaited()

            # Assert device is now offline
            self.assertEqual(device.online, False)

    async def test_refresh_valid_response(self) -> None:
        """Test that a refresh() with any response marks a device as online."""
        TEST_RESPONSE = bytes.fromhex(
            "aa63cc0000000000000301fe00000043005001728c79010100728c728c797900010141ff010203000603010000000300000001030103010000000000000000000001000100010000000000000000000000000001000200000100000101000102ff02ff6a")

        # Create a dummy device
        device = CC(0, 0, 0)

        # Patch _send_command to return a valid state response
        with patch("msmart.base_device.Device._send_command", return_value=[TEST_RESPONSE]) as patched_method:

            # Assert device is offline and unsupported
            self.assertEqual(device.online, False)
            self.assertEqual(device.supported, False)

            # Refresh device
            await device.refresh()

            # Assert patch method was awaited
            patched_method.assert_awaited()

            # Assert device is now online and supported
            self.assertEqual(device.online, True)
            self.assertEqual(device.supported, True)


if __name__ == "__main__":
    unittest.main()
