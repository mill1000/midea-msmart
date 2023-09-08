import unittest

from .device import AirConditioner as AC


class TestDeviceEnums(unittest.TestCase):
    """Test device specific enum handling."""

    def _test_enum_members(self, enum_cls):
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

    def test_fan_speed(self) -> None:
        """Test FanSpeed enum conversion from value/name."""

        # Test enum members
        self._test_enum_members(AC.FanSpeed)

        # Test fall back behavior to "AUTO"
        enum = AC.FanSpeed.get_from_name("THIS_IS_FAKE")
        self.assertEqual(enum, AC.FanSpeed.AUTO)
        self.assertIsInstance(enum, AC.FanSpeed)

        # Test fall back behavior to "AUTO"
        enum = AC.FanSpeed.get_from_value(77777)
        self.assertEqual(enum, AC.FanSpeed.AUTO)
        self.assertIsInstance(enum, AC.FanSpeed)

    def test_operational_mode(self) -> None:
        """Test OperationalMode enum conversion from value/name."""

        # Test enum members
        self._test_enum_members(AC.OperationalMode)

        # Test fall back behavior to "FAN_ONLY"
        enum = AC.OperationalMode.get_from_name("SOME_BOGUS_NAME")
        self.assertEqual(enum, AC.OperationalMode.FAN_ONLY)
        self.assertIsInstance(enum, AC.OperationalMode)

        # Test fall back behavior to "FAN_ONLY"
        enum = AC.OperationalMode.get_from_value(0xDEADBEAF)
        self.assertEqual(enum, AC.OperationalMode.FAN_ONLY)
        self.assertIsInstance(enum, AC.OperationalMode)

    def test_swing_mode(self) -> None:
        """Test SwingMode enum conversion from value/name."""

        # Test enum members
        self._test_enum_members(AC.SwingMode)

        # Test fall back behavior to "OFF"
        enum = AC.SwingMode.get_from_name("NOT_A_SWING_MODE")
        self.assertEqual(enum, AC.SwingMode.OFF)
        self.assertIsInstance(enum, AC.SwingMode)

        # Test fall back behavior to "OFF"
        enum = AC.SwingMode.get_from_value(1234567)
        self.assertEqual(enum, AC.SwingMode.OFF)
        self.assertIsInstance(enum, AC.SwingMode)


if __name__ == "__main__":
    unittest.main()
