import logging
import unittest
from enum import Enum, Flag, auto
from unittest.mock import patch

from msmart.base_device import Device
from msmart.const import DeviceType, FrameType
from msmart.device import AirConditioner as AC
from msmart.device import CommercialAirConditioner as CC
from msmart.frame import Frame
from msmart.lan import ProtocolError
from msmart.utils import CapabilityManager


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

            # Assert empty list was returned
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

            # Assert empty list was returned
            self.assertEqual(responses, [])


class TestOverrideCapabilities(unittest.TestCase):
    """Test overriding capabilities via a serialized dict."""

    def test_unsupported_override(self) -> None:
        """Test an unsupported overrides throw a ValueError."""

        # Create dummy device which defaults to no overrides
        device = Device(
            device_type=DeviceType.AIR_CONDITIONER,
            device_id=0,
            ip="0",
            port=0
        )

        with self.assertRaisesRegex(ValueError, "Unsupported capabilities override .*"):
            device.override_capabilities({"supports_eco": True})

    def test_numeric_invalid(self) -> None:
        """Test invalid numeric values throw a ValueError."""

        # Create dummy device
        device = Device(
            device_type=DeviceType.AIR_CONDITIONER,
            device_id=0,
            ip="0",
            port=0
        )

        # Allow some numeric overrides
        device._SUPPORTED_CAPABILITY_OVERRIDES = {
            "min_target_temperature": ("_dummy_attr", float),
            "max_target_temperature": ("_dummy_attr", float)
        }

        with self.assertRaisesRegex(ValueError, "'min_target_temperature' must be a number"):
            device.override_capabilities({"min_target_temperature": "apple"})

        with self.assertRaisesRegex(ValueError, "'max_target_temperature' must be a number"):
            device.override_capabilities({"max_target_temperature": [20, 50]})

    def test_enums_invalid_name(self) -> None:
        """Test invalid enum names throw a ValueError."""

        # Create dummy device
        device = Device(
            device_type=DeviceType.AIR_CONDITIONER,
            device_id=0,
            ip="0",
            port=0
        )

        # Create dummy enum for test
        class TestEnum(Enum):
            VALUE = 1

        # Allow override for TestEnum
        device._SUPPORTED_CAPABILITY_OVERRIDES = {
            "supported_modes": ("_dummy_attr", TestEnum),
        }

        # Expect value errors for invalid enum name
        with self.assertRaisesRegex(ValueError, "Invalid value .*? for .*"):
            device.override_capabilities(
                {"supported_modes": ["bad_enum_name"]})

    def test_enums_invalid_format(self) -> None:
        """Test invalid enum values throw a ValueError."""
        TEST_OVERRIDES = [
            {"supported_aux_modes": "HEAT"},
            {"supported_aux_modes": 1.0},
        ]

        # Create dummy device
        device = Device(
            device_type=DeviceType.AIR_CONDITIONER,
            device_id=0,
            ip="0",
            port=0
        )

        # Create dummy enum for test
        class TestEnum(Enum):
            VALUE = 1

        # Allow override for TestEnum
        device._SUPPORTED_CAPABILITY_OVERRIDES = {
            "supported_aux_modes": ("_dummy_attr", TestEnum),
        }

        # Expect value errors for each invalid enum value
        for override in TEST_OVERRIDES:
            with self.assertRaisesRegex(ValueError, ".* must be a list"):
                device.override_capabilities(override)

    def test_enum(self) -> None:
        """Test overrides with basic enums"""
        # Create dummy device
        device = Device(
            device_type=DeviceType.AIR_CONDITIONER,
            device_id=0,
            ip="0",
            port=0
        )

        # Create dummy enum for test
        class TestEnum(Enum):
            ONE = 1
            TWO = 2
            THREE = 3

        # Allow override for TestEnum
        device._dummy_attr = [TestEnum.ONE]
        device._SUPPORTED_CAPABILITY_OVERRIDES = {
            "supported_modes": ("_dummy_attr", TestEnum),
        }

        # Test merging
        device.override_capabilities(
            {"supported_modes": ["THREE"]}, merge=True)
        self.assertCountEqual(device._dummy_attr, [
                              TestEnum.ONE, TestEnum.THREE])

        # Test merging doesn't duplicate
        device.override_capabilities(
            {"supported_modes": ["TWO", "THREE"]}, merge=True)
        self.assertCountEqual(device._dummy_attr, [
                              TestEnum.ONE, TestEnum.TWO, TestEnum.THREE])

        # Test override
        device.override_capabilities(
            {"supported_modes": ["TWO"]}, merge=False)
        self.assertCountEqual(device._dummy_attr, [TestEnum.TWO])

    def test_capability_manager(self) -> None:
        """Test overrides with capability manager flags"""
        # Create dummy device
        device = Device(
            device_type=DeviceType.AIR_CONDITIONER,
            device_id=0,
            ip="0",
            port=0
        )

        # Create dummy enum for test
        class TestEnum(Flag):
            ONE = auto()
            TWO = auto()
            THREE = auto()

        # Allow override for TestEnum
        device._dummy_attr = CapabilityManager(TestEnum.ONE)
        device._SUPPORTED_CAPABILITY_OVERRIDES = {
            "additional_capabilities": ("_dummy_attr", TestEnum),
        }

        # Test merging
        device.override_capabilities(
            {"additional_capabilities": ["THREE"]}, merge=True)
        self.assertEqual(device._dummy_attr.flags,
                         TestEnum.ONE | TestEnum.THREE)

        # Test merging doesn't duplicate
        device.override_capabilities(
            {"additional_capabilities": ["TWO", "THREE"]}, merge=True)
        self.assertEqual(device._dummy_attr.flags,
                         TestEnum.ONE | TestEnum.TWO | TestEnum.THREE)

        # Test override
        device.override_capabilities(
            {"additional_capabilities": ["TWO"]}, merge=False)
        self.assertEqual(device._dummy_attr.flags, TestEnum.TWO)

    def test_flags(self) -> None:
        """Test overrides with bare flags"""
        # Create dummy device
        device = Device(
            device_type=DeviceType.AIR_CONDITIONER,
            device_id=0,
            ip="0",
            port=0
        )

        # Create dummy enum for test
        class TestEnum(Flag):
            ONE = auto()
            TWO = auto()
            THREE = auto()

        # Allow override for TestEnum
        device._dummy_attr = TestEnum.ONE
        device._SUPPORTED_CAPABILITY_OVERRIDES = {
            "additional_capabilities": ("_dummy_attr", TestEnum),
        }

        # Test merging
        device.override_capabilities(
            {"additional_capabilities": ["THREE"]}, merge=True)
        self.assertEqual(device._dummy_attr,
                         TestEnum.ONE | TestEnum.THREE)

        # Test merging doesn't duplicate
        device.override_capabilities(
            {"additional_capabilities": ["TWO", "THREE"]}, merge=True)
        self.assertEqual(device._dummy_attr,
                         TestEnum.ONE | TestEnum.TWO | TestEnum.THREE)

        # Test override
        device.override_capabilities(
            {"additional_capabilities": ["TWO"]}, merge=False)
        self.assertEqual(device._dummy_attr, TestEnum.TWO)


class TestConstruct(unittest.TestCase):
    """Test construction of device instances."""

    def test_construct_ac(self) -> None:
        """Test construction of an AC device."""

        DEVICE_INFO = {
            "ip": "127.0.0.1",
            "port": 6444,
            "device_id": 147334558165565,
            "device_type": DeviceType.AIR_CONDITIONER,
            "name": "net_ac_63BA",
            "sn": "000000P0000000Q1B88C29C963BA0000"
        }
        device = Device.construct(
            type=DeviceType.AIR_CONDITIONER, **DEVICE_INFO)

        self.assertIsNotNone(device)
        self.assertIsInstance(device, AC)

        self.assertEqual(device.ip, "127.0.0.1")
        self.assertEqual(device.port, 6444)
        self.assertEqual(device.id, 147334558165565)
        self.assertEqual(device.sn, "000000P0000000Q1B88C29C963BA0000")

    def test_construct_cc(self) -> None:
        """Test construction of a CC device."""

        DEVICE_INFO = {
            "ip": "127.0.0.11",
            "port": 6444,
            "device_id": 123456,
            "device_type": DeviceType.COMMERCIAL_AC,
            "sn": "000000"
        }
        device = Device.construct(type=DeviceType.COMMERCIAL_AC, **DEVICE_INFO)

        self.assertIsNotNone(device)
        self.assertIsInstance(device, CC)

        self.assertEqual(device.ip, "127.0.0.11")
        self.assertEqual(device.port, 6444)
        self.assertEqual(device.id, 123456)
        self.assertEqual(device.sn, "000000")

    def test_construct_unsupported(self) -> None:
        """Test construction of an unsupported device."""

        DEVICE_INFO = {
            "ip": "127.0.0.22",
            "port": 6666,
            "device_id": 987654,
            "device_type": 0xBD,
            "sn": "12345"
        }
        device = Device.construct(type=0xBD, **DEVICE_INFO)

        self.assertIsNotNone(device)
        self.assertIsInstance(device, Device)

        self.assertEqual(device.ip, "127.0.0.22")
        self.assertEqual(device.port, 6666)
        self.assertEqual(device.id, 987654)
        self.assertEqual(device.sn, "12345")


if __name__ == "__main__":
    unittest.main()
