import logging
import unittest
from typing import cast
from unittest.mock import MagicMock, patch

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

        # Verify that axis are taken out of auto mode when disabling the swing
        device.horizontal_swing_angle = CC.SwingAngle.AUTO
        device.vertical_swing_angle = CC.SwingAngle.AUTO
        device.swing_mode = CC.SwingMode.OFF
        self.assertEqual(device._horizontal_swing_angle, CC.SwingAngle.DEFAULT)
        self.assertEqual(device._vertical_swing_angle, CC.SwingAngle.DEFAULT)

        # Verify that setting swing mode on one axis doesn't effect the other if it's not swinging
        device.horizontal_swing_angle = CC.SwingAngle.POS_1
        device.vertical_swing_angle = CC.SwingAngle.POS_1
        device.swing_mode = CC.SwingMode.VERTICAL
        self.assertEqual(device._horizontal_swing_angle, CC.SwingAngle.POS_1)
        self.assertEqual(device._vertical_swing_angle, CC.SwingAngle.AUTO)

        device.horizontal_swing_angle = CC.SwingAngle.POS_1
        device.vertical_swing_angle = CC.SwingAngle.POS_5
        device.swing_mode = CC.SwingMode.HORIZONTAL
        self.assertEqual(device._horizontal_swing_angle, CC.SwingAngle.AUTO)
        self.assertEqual(device._vertical_swing_angle, CC.SwingAngle.POS_5)


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

    def test_swing_mode(self) -> None:
        """Test swing mode/angle capabilities."""

        # Test with only vertical swing angle control
        resp = MagicMock()
        resp.supports_horz_swing_angle = False
        resp.supports_vert_swing_angle = True

        # Create a dummy device and process the response
        device = CC(0, 0, 0)
        device._update_capabilities(resp)

        self.assertCountEqual(device.supported_swing_modes, [
            CC.SwingMode.OFF,
            CC.SwingMode.VERTICAL
        ])

        self.assertEqual(device.supports_horizontal_swing_angle, False)
        self.assertEqual(device.supports_vertical_swing_angle, True)

        # Test with only horizontal swing angle control
        resp.supports_horz_swing_angle = True
        resp.supports_vert_swing_angle = False

        # Update capabilities
        device._update_capabilities(resp)

        self.assertCountEqual(device.supported_swing_modes, [
            CC.SwingMode.OFF,
            CC.SwingMode.HORIZONTAL
        ])

        self.assertEqual(device.supports_horizontal_swing_angle, True)
        self.assertEqual(device.supports_vertical_swing_angle, False)

        # Test with both controls
        resp.supports_horz_swing_angle = True
        resp.supports_vert_swing_angle = True

        # Update capabilities
        device._update_capabilities(resp)

        self.assertCountEqual(device.supported_swing_modes, [
            CC.SwingMode.OFF,
            CC.SwingMode.HORIZONTAL,
            CC.SwingMode.VERTICAL,
            CC.SwingMode.BOTH,
        ])

        self.assertEqual(device.supports_horizontal_swing_angle, True)
        self.assertEqual(device.supports_vertical_swing_angle, True)

    def test_aux_modes(self) -> None:
        """Test aux mode capabilities."""

        # Test with invalid mode
        resp = MagicMock()
        resp.supported_aux_modes = [0xFF]

        # Create a dummy device and process the response
        device = CC(0, 0, 0)
        device._update_capabilities(resp)

        self.assertCountEqual(device.supported_aux_modes, [])

        # Test with valid mode
        resp.supported_aux_modes = [0]

        # Update capabilities
        device._update_capabilities(resp)

        self.assertCountEqual(device.supported_aux_modes, [
            CC.AuxHeatMode.AUTO
        ])


class TestSetState(unittest.IsolatedAsyncioTestCase):
    """Test setting device state."""

    async def test_controls(self) -> None:
        """Test that apply() sends the appropriate changed controls"""

        # Create dummy device
        device = CC(0, 0, 0)

        # Set some controls
        device.power_state = True
        device.operational_mode = CC.OperationalMode.HEAT
        device.fan_speed = CC.FanSpeed.AUTO
        device.target_temperature = 24
        device.eco = True

        # Assert correct controls are being updated
        self.assertIn(ControlId.POWER, device._updated_controls)
        self.assertIn(ControlId.MODE, device._updated_controls)
        self.assertIn(ControlId.FAN_SPEED, device._updated_controls)
        self.assertIn(ControlId.TARGET_TEMPERATURE, device._updated_controls)
        self.assertIn(ControlId.ECO, device._updated_controls)

        self.assertEqual(len(device._updated_controls), 5)

        # Patch to prevent network access
        with patch("msmart.device.CC.device.CommercialAirConditioner._send_commands_get_responses", return_value=[]) as patched_method:

            # Apply changed settings
            await device.apply()

            # Assert patched method was awaited
            patched_method.assert_awaited_once()

            # Get call arguments
            args, kwargs = patched_method.call_args
            commands = args[0]

            # Only 1 command should be sent
            self.assertEqual(len(commands), 1)

        # Ensure no controls remain
        self.assertEqual(len(device._updated_controls), 0)

    async def test_controls_with_power_off(self) -> None:
        """Test that a power off state is sent alone, and other controls are dropped."""

        # Create dummy device
        device = CC(0, 0, 0)

        # Set some controls
        device.power_state = False
        device.operational_mode = CC.OperationalMode.HEAT
        device.target_temperature = 24

        # Assert correct controls are being updated
        self.assertIn(ControlId.POWER, device._updated_controls)
        self.assertIn(ControlId.MODE, device._updated_controls)
        self.assertIn(ControlId.TARGET_TEMPERATURE, device._updated_controls)

        self.assertEqual(len(device._updated_controls), 3)

        # Patch to prevent network access
        with patch("msmart.device.CC.device.CommercialAirConditioner._send_commands_get_responses", return_value=[]) as patched_method:

            # Apply changed settings
            with self.assertLogs("msmart", logging.WARNING) as log:
                await device.apply()

                # Check log for warning about dropped controls
                self.assertRegex("\n".join(log.output),
                                 "Device.*powering off.*Dropped.*control.*MODE.*TARGET_TEMPERATURE.*")

            # Assert patched method was awaited
            patched_method.assert_awaited_once()

            # Get call arguments
            args, kwargs = patched_method.call_args
            commands = args[0]

            # Verify only 1 commands sent
            self.assertEqual(len(commands), 1)

            # Assert power control present
            controls = commands[0]._controls
            self.assertEqual(len(controls), 1)
            self.assertIn(ControlId.POWER, controls)

            # Assert no other controls preset
            self.assertNotIn(ControlId.MODE, controls)
            self.assertNotIn(ControlId.TARGET_TEMPERATURE, controls)

        # Ensure no controls remain
        self.assertEqual(len(device._updated_controls), 0)

    async def test_controls_power_off_only(self) -> None:
        """Test that a power off state is sent alone."""

        # Create dummy device
        device = CC(0, 0, 0)

        # Only set power off
        device.power_state = False

        # Assert correct controls are being updated
        self.assertIn(ControlId.POWER, device._updated_controls)

        self.assertEqual(len(device._updated_controls), 1)

        # Patch to prevent network access
        with patch("msmart.device.CC.device.CommercialAirConditioner._send_commands_get_responses", return_value=[]) as patched_method:

            # Apply changed settings
            await device.apply()

            # Assert patched method was awaited
            patched_method.assert_awaited_once()

            # Get call arguments
            args, kwargs = patched_method.call_args
            commands = args[0]

            # Verify only 1 commands sent
            self.assertEqual(len(commands), 1)

        # Ensure no controls remain
        self.assertEqual(len(device._updated_controls), 0)


class TestSendCommandGetResponse(unittest.IsolatedAsyncioTestCase):
    # pylint: disable=protected-access

    async def test_refresh_no_response(self) -> None:
        """Test that a refresh() with no response marks a device as offline."""

        # Create a dummy device
        device = CC(0, 0, 0)

        # Force device online
        device._online = True
        self.assertEqual(device.online, True)

        # Patch _send_command to return no responses
        with patch("msmart.base_device.Device._send_command", return_value=[]) as patched_method:

            # Refresh device
            await device.refresh()

            # Assert patched method was awaited
            patched_method.assert_awaited()

        # Assert device is now offline
        self.assertEqual(device.online, False)

    async def test_refresh_valid_response(self) -> None:
        """Test that a refresh() with any valid response marks a device as online and supported."""
        TEST_RESPONSE = bytes.fromhex(
            "aa63cc0000000000000301fe00000043005001728c79010100728c728c797900010141ff010203000603010000000300000001030103010000000000000000000001000100010000000000000000000000000001000200000100000101000102ff02ff6a")

        # Create a dummy device
        device = CC(0, 0, 0)

        # Assert device is offline and unsupported
        self.assertEqual(device.online, False)
        self.assertEqual(device.supported, False)

        # Patch _send_command to return a valid state response
        with patch("msmart.base_device.Device._send_command", return_value=[TEST_RESPONSE]) as patched_method:

            # Refresh device
            await device.refresh()

            # Assert patched method was awaited
            patched_method.assert_awaited()

            # Assert device is now online and supported
            self.assertEqual(device.online, True)
            self.assertEqual(device.supported, True)

    async def test_refresh_one_response(self) -> None:
        """Test that a refresh() with only one response stays online."""
        TEST_RESPONSE = bytes.fromhex(
            "aa63cc0000000000000301fe00000043005001728c8000d200728c728c7b7b00010141ff010203000602010008000000000001000103010000000000000000000001000100010000000000000000000000000001000200000100000101000102ff02ff8e")

        # Create a dummy device
        device = CC(0, 0, 0)

        # Force device online
        device._online = True
        self.assertEqual(device.online, True)

        # Dummy method to only respond to state commands
        packet_count = 0

        async def _get_responses_sometimes(self, command) -> list[bytes]:
            nonlocal packet_count

            packet_count += 1
            if isinstance(command, QueryCommand):
                return [TEST_RESPONSE]
            else:
                return []

        # Patch _send_command to return test responses
        with patch("msmart.base_device.Device._send_command", new=_get_responses_sometimes):

            # Refresh device
            await device.refresh()

        # Assert expected number of packets was sent
        self.assertEqual(packet_count, 1)

        # Assert device is still online
        self.assertEqual(device.online, True)
        self.assertEqual(device.supported, True)

    async def test_refresh_supported_sticky(self) -> None:
        """Test that once set, the supported property remains true if the device doesn't respond."""
        TEST_RESPONSE = bytes.fromhex(
            "aa63cc0000000000000301fe00000043005000728c7b00d200728c728c7b7b00010141ff010203000602010008000000000001000103010000000000000000000001000100010000000000000000000000000001000200000100000101000102ff02ff94")

        # Create a dummy device
        device = CC(0, 0, 0)

        # Assert device starts offline and unsupported
        self.assertEqual(device.online, False)
        self.assertEqual(device.supported, False)

        # Patch _send_command to return response
        with patch("msmart.base_device.Device._send_command", return_value=[TEST_RESPONSE]) as patched_method:

            # Refresh device
            await device.refresh()

            # Assert patched method was awaited
            patched_method.assert_awaited()

        # Assert device is online and supported
        self.assertEqual(device.online, True)
        self.assertEqual(device.supported, True)

        # Patch _send_command to return no response
        with patch("msmart.base_device.Device._send_command", return_value=[]) as patched_method:

            # Refresh device again
            await device.refresh()

            # Assert patched method was awaited
            patched_method.assert_awaited()

        # Assert device is now offline and but still supported
        self.assertEqual(device.online, False)
        self.assertEqual(device.supported, True)

    async def test_refresh_incorrect_device_type_response(self) -> None:
        """Test that a refresh() with a response from the wrong device type marks a device as online but unsupported."""
        TEST_RESPONSE = bytes.fromhex(
            "aa23ac00000000000303c00145660000003c0010045c6b20000000000000000000020d79")

        # Create a dummy device
        device = CC(0, 0, 0)

        # Assert device starts offline and unsupported
        self.assertEqual(device.online, False)
        self.assertEqual(device.supported, False)

        # Patch _send_command to return response
        with patch("msmart.base_device.Device._send_command", return_value=[TEST_RESPONSE]) as patched_method:

            with self.assertLogs("msmart", logging.ERROR) as log:
                # Refresh device
                await device.refresh()

                # Check for error message
                self.assertRegex("\n".join(log.output),
                                 "Received device type.*expected device type 0xCC")

            # Assert patch method was awaited
            patched_method.assert_awaited()

            # Assert device is online but unsupported
            self.assertEqual(device.online, True)
            self.assertEqual(device.supported, False)

    async def test_get_capabilities_no_response(self):
        """Test that get_capabilities() with no response outputs an error."""

        # Create a dummy device
        device = CC(0, 0, 0)

        # Patch _send_command to return test response
        with patch("msmart.base_device.Device._send_command", return_value=[]) as patched_method:
            # Get device capabilities
            with self.assertLogs("msmart", logging.DEBUG) as log:
                await device.get_capabilities()

                self.assertRegex("\n".join(log.output),
                                 "Failed to query capabilities from device.*")

            # Assert patch method was awaited
            patched_method.assert_awaited()

    async def test_get_capabilities_bad_response(self):
        """Test that get_capabilities() with an unexpected response outputs an error."""
        WRONG_RESPONSE = bytes.fromhex(
            "aa16cc0000000000000200000101ff00030180ff000098")

        # Create a dummy device
        device = CC(0, 0, 0)

        # Patch _send_command to return test response
        with patch("msmart.base_device.Device._send_command", return_value=[WRONG_RESPONSE]) as patched_method:
            # Get device capabilities
            with self.assertLogs("msmart", logging.DEBUG) as log:
                await device.get_capabilities()

                self.assertRegex("\n".join(log.output),
                                 "Unexpected response from device.*")

            # Assert patch method was awaited
            patched_method.assert_awaited()


if __name__ == "__main__":
    unittest.main()
