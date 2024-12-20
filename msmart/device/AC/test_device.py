import logging
import unittest

from .command import (CapabilitiesResponse, EnergyUsageResponse,
                      HumidityResponse, PropertiesResponse, Response,
                      StateResponse)
from .device import AirConditioner as AC
from .device import PropertyId


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

    def test_swing_angle(self) -> None:
        """Test SwingAngle enum conversion from value/name."""

        # Test enum members
        self._test_enum_members(AC.SwingAngle)

        # Test fall back behavior to "OFF"
        enum = AC.SwingAngle.get_from_name("INVALID_NAME")
        self.assertEqual(enum, AC.SwingAngle.OFF)
        self.assertIsInstance(enum, AC.SwingAngle)

        # Test fall back behavior to "OFF"
        enum = AC.SwingAngle.get_from_value(1234567)
        self.assertEqual(enum, AC.SwingAngle.OFF)
        self.assertIsInstance(enum, AC.SwingAngle)

        # Test that converting from None works
        enum = AC.SwingAngle.get_from_value(None)
        self.assertEqual(enum, AC.SwingAngle.OFF)
        self.assertIsInstance(enum, AC.SwingAngle)

        enum = AC.SwingAngle.get_from_name(None)
        self.assertEqual(enum, AC.SwingAngle.OFF)
        self.assertIsInstance(enum, AC.SwingAngle)

        enum = AC.SwingAngle.get_from_name("")
        self.assertEqual(enum, AC.SwingAngle.OFF)
        self.assertIsInstance(enum, AC.SwingAngle)


class TestUpdateStateFromResponse(unittest.TestCase):
    """Test updating device state from responses."""

    def test_state_response(self) -> None:
        """Test parsing of StateResponses into device state."""

        # V3 state response
        TEST_RESPONSE = bytes.fromhex(
            "aa23ac00000000000303c00145660000003c0010045c6b20000000000000000000020d79")

        resp = Response.construct(TEST_RESPONSE)
        self.assertIsNotNone(resp)

        # Assert response is a state response
        self.assertEqual(type(resp), StateResponse)

        # Create a dummy device and process the response
        device = AC(0, 0, 0)
        device._update_state(resp)

        # Assert state is expected
        self.assertEqual(device.target_temperature, 21.0)
        self.assertEqual(device.indoor_temperature, 21.0)
        self.assertEqual(device.outdoor_temperature, 28.5)

        self.assertEqual(device.eco, True)
        self.assertEqual(device.turbo, False)
        self.assertEqual(device.freeze_protection, False)
        self.assertEqual(device.sleep, False)

        self.assertEqual(device.operational_mode, AC.OperationalMode.COOL)
        self.assertEqual(device.fan_speed, AC.FanSpeed.AUTO)
        self.assertEqual(device.swing_mode, AC.SwingMode.VERTICAL)

    def test_properties_response(self) -> None:
        """Test parsing of PropertiesResponse into device state."""
        # https://github.com/mill1000/midea-ac-py/issues/60#issuecomment-1936976587
        TEST_RESPONSE = bytes.fromhex(
            "aa21ac00000000000303b10409000001000a00000100150000012b1e020000005fa3")

        # Create a dummy device
        device = AC(0, 0, 0)

        # Set some properties
        device.horizontal_swing_angle = AC.SwingAngle.POS_5
        device.vertical_swing_angle = AC.SwingAngle.POS_5

        # Response contains an unsupported property so check the log for warnings
        with self.assertLogs("msmart", logging.WARNING) as log:
            resp = Response.construct(TEST_RESPONSE)

            self.assertRegex("\n".join(log.output),
                             "Unsupported property .*INDOOR_HUMIDITY.*")

        # Assert response is a state response
        self.assertIsNotNone(resp)
        self.assertEqual(type(resp), PropertiesResponse)

        # Process the response
        device._update_state(resp)

        # Assert state is expected
        self.assertEqual(device.horizontal_swing_angle, AC.SwingAngle.OFF)
        self.assertEqual(device.vertical_swing_angle, AC.SwingAngle.OFF)

    def test_properties_ack_response(self) -> None:
        """Test parsing of PropertiesResponse from SetProperties command into device state."""
        # https://github.com/mill1000/midea-msmart/issues/97#issuecomment-1949495900
        TEST_RESPONSE = bytes.fromhex(
            "aa18ac00000000000302b0020a0000013209001101000089a4")

        # Create a dummy device
        device = AC(0, 0, 0)

        # Set some properties
        device.horizontal_swing_angle = AC.SwingAngle.OFF
        device.vertical_swing_angle = AC.SwingAngle.OFF

        # Device did not support SWING_UD_ANGLE, check that an error was reported
        with self.assertLogs("msmart", logging.WARNING) as log:
            resp = Response.construct(TEST_RESPONSE)
            self.assertIsNotNone(resp)

            self.assertRegex(
                log.output[0], "Property .*SWING_UD_ANGLE.* failed, Result: 0x11.")

        # Assert response is a state response
        self.assertEqual(type(resp), PropertiesResponse)

        # Process the response
        device._update_state(resp)

        # Assert state is expected
        self.assertEqual(device.horizontal_swing_angle, AC.SwingAngle.POS_3)
        self.assertEqual(device.vertical_swing_angle, AC.SwingAngle.OFF)

    def test_properties_missing_field(self) -> None:
        """Test parsing of PropertiesResponse that only contains some properties."""
        # https://github.com/mill1000/midea-msmart/issues/97#issuecomment-1949495900
        TEST_RESPONSE = bytes.fromhex(
            "aa13ac00000000000303b1010a0000013200c884")

        # Create a dummy device
        device = AC(0, 0, 0)

        # Set some properties
        device.horizontal_swing_angle = AC.SwingAngle.POS_5
        device.vertical_swing_angle = AC.SwingAngle.POS_5

        # Construct and assert response
        resp = Response.construct(TEST_RESPONSE)
        self.assertIsNotNone(resp)

        # Assert response is a state response
        self.assertEqual(type(resp), PropertiesResponse)

        # Process response
        device._update_state(resp)

        # Assert that only the properties in the response are updated
        self.assertEqual(device.horizontal_swing_angle, AC.SwingAngle.POS_3)

        # Assert other properties are untouched
        self.assertEqual(device.vertical_swing_angle, AC.SwingAngle.POS_5)

    def test_properties_breeze(self) -> None:
        """Test parsing of breeze properties from Breezeless device."""
        TEST_RESPONSES = {
            # https://github.com/mill1000/midea-msmart/issues/150#issuecomment-2264720231
            # Breezeless device in Breeze Away mode
            bytes.fromhex("aa1cac00000000000303b103430000010218000001004200000000cf0e"): (True, False, False),

            # https://github.com/mill1000/midea-msmart/issues/150#issuecomment-2262226032
            # Non-breezeless device in Breeze Away mode
            bytes.fromhex("aa1bac00000000000303b1034300000018000000420000010200914e"): (True, False, False),

            # https://github.com/mill1000/midea-msmart/issues/150#issuecomment-2262221251
            # Breezeless device in Breeze Mild mode
            bytes.fromhex("aa1cac00000000000303b1034300000103180000010042000000001ac2"): (False, True, False),
            # Breezeless device in Breezeless mode
            bytes.fromhex("aa1cac00000000000303b10343000001041800000101420000000034a6"): (False, False, True),
        }

        for response, state in TEST_RESPONSES.items():
            resp = Response.construct(response)
            self.assertIsNotNone(resp)

            # Assert response is a state response
            self.assertEqual(type(resp), PropertiesResponse)

            # Create a dummy device and process the response
            device = AC(0, 0, 0)
            device._update_state(resp)

            breeze_away, breeze_mild, breezeless = state

            # Assert state is expected
            self.assertEqual(device.breeze_away, breeze_away)
            self.assertEqual(device.breeze_mild, breeze_mild)
            self.assertEqual(device.breezeless, breezeless)

    def test_energy_usage_response(self) -> None:
        """Test parsing of EnergyUsageResponses into device state."""
        TEST_RESPONSES = {
            # https://github.com/mill1000/midea-msmart/pull/116#issuecomment-2191412432
            (5650.02, 1514.0, 0): bytes.fromhex("aa20ac00000000000203c121014400564a02640000000014ae0000000000041a22"),

            # https://github.com/mill1000/midea-msmart/pull/116#issuecomment-2218753545
            (None, None, None): bytes.fromhex("aa20ac00000000000303c1210144000000000000000000000000000000000843bc"),
        }

        for power, response in TEST_RESPONSES.items():
            resp = Response.construct(response)
            self.assertIsNotNone(resp)

            # Assert response is a state response
            self.assertEqual(type(resp), EnergyUsageResponse)

            # Create a dummy device and process the response
            device = AC(0, 0, 0)
            device._update_state(resp)

            total, current, real_time = power

            # Assert state is expected
            self.assertEqual(device.total_energy_usage, total)
            self.assertEqual(device.current_energy_usage, current)
            self.assertEqual(device.real_time_power_usage, real_time)

    def test_binary_energy_usage_response(self) -> None:
        """Test parsing of EnergyUsageResponses into device state with binary format."""
        TEST_RESPONSES = {
            # https://github.com/mill1000/midea-ac-py/issues/204#issuecomment-2314705021
            (15.04, .06, 279.5): bytes.fromhex("aa22ac00000000000803c1210144000005e00000000000000006000aeb000000487a5e"),

            # https://github.com/mill1000/midea-msmart/pull/116#issuecomment-2218753545
            (None, None, None): bytes.fromhex("aa20ac00000000000303c1210144000000000000000000000000000000000843bc"),
        }

        for power, response in TEST_RESPONSES.items():
            resp = Response.construct(response)
            self.assertIsNotNone(resp)

            # Assert response is a state response
            self.assertEqual(type(resp), EnergyUsageResponse)

            # Create a dummy device and process the response
            device = AC(0, 0, 0)

            # Switch to binary format
            device.use_alternate_energy_format = True

            # Update state with response
            device._update_state(resp)

            total, current, real_time = power

            # Assert state is expected
            self.assertEqual(device.total_energy_usage, total)
            self.assertEqual(device.current_energy_usage, current)
            self.assertEqual(device.real_time_power_usage, real_time)

    def test_humidity_response(self) -> None:
        """Test parsing of HumidityResponses into device state."""
        TEST_RESPONSES = {
            # Device supports humidity
            # https://github.com/mill1000/midea-msmart/pull/116#issuecomment-2218019069
            63: bytes.fromhex("aa20ac00000000000303c12101453f546c005d0a000000de1f0000ba9a0004af9c"),

            # Device does not support humidity
            # https://github.com/mill1000/midea-msmart/pull/116#issuecomment-2192724566
            None: bytes.fromhex("aa1fac00000000000303c1210145000000000000000000000000000000001aed"),
        }

        for humidity, response in TEST_RESPONSES.items():
            resp = Response.construct(response)
            self.assertIsNotNone(resp)

            # Assert response is a state response
            self.assertEqual(type(resp), HumidityResponse)

            # Create a dummy device and process the response
            device = AC(0, 0, 0)
            device._update_state(resp)

            # Assert state is expected
            self.assertEqual(device.indoor_humidity, humidity)


class TestCapabilities(unittest.TestCase):
    """Test parsing of CapabilitiesResponse into device capabilities."""

    def test_general_capabilities(self) -> None:
        """Test general device capabilities."""
        # Device with numerous supported features
        # https://github.com/mill1000/midea-msmart/issues/150#issuecomment-2276158338
        CAPABILITIES_PAYLOAD_0 = bytes.fromhex(
            "b50a12020101430001011402010115020101160201001a020101100201011f020103250207203c203c203c05400001000100")
        CAPABILITIES_PAYLOAD_1 = bytes.fromhex(
            "b5051e020101130201012202010019020100390001010000")

        # Create a dummy device and process the response
        device = AC(0, 0, 0)

        # Parse capability payloads
        with memoryview(CAPABILITIES_PAYLOAD_0) as payload0, memoryview(CAPABILITIES_PAYLOAD_1) as payload1:
            resp0 = CapabilitiesResponse(payload0)
            resp1 = CapabilitiesResponse(payload1)

            resp0.merge(resp1)
            device._update_capabilities(resp0)

        self.assertCountEqual(device.supported_operation_modes, [AC.OperationalMode.AUTO,
                                                                 AC.OperationalMode.COOL,
                                                                 AC.OperationalMode.DRY,
                                                                 AC.OperationalMode.FAN_ONLY,
                                                                 AC.OperationalMode.HEAT,
                                                                 AC.OperationalMode.SMART_DRY])

        self.assertCountEqual(device.supported_swing_modes, [AC.SwingMode.OFF,
                                                             AC.SwingMode.BOTH,
                                                             AC.SwingMode.HORIZONTAL,
                                                             AC.SwingMode.VERTICAL])

        self.assertEqual(device.supports_custom_fan_speed, True)
        self.assertCountEqual(device.supported_fan_speeds, [AC.FanSpeed.SILENT,
                                                            AC.FanSpeed.LOW,
                                                            AC.FanSpeed.MEDIUM,
                                                            AC.FanSpeed.HIGH,
                                                            AC.FanSpeed.MAX,  # Supports custom
                                                            AC.FanSpeed.AUTO,
                                                            ])

        self.assertEqual(device.supports_humidity, True)
        self.assertEqual(device.supports_target_humidity, True)

        self.assertEqual(device.supports_purifier, True)
        self.assertEqual(device.supports_self_clean, True)

        self.assertEqual(device.supports_eco, True)
        self.assertEqual(device.supports_freeze_protection, True)
        self.assertEqual(device.supports_turbo, True)

    def test_rate_select(self) -> None:
        """Test rate select device capability."""
        # https://github.com/mill1000/midea-msmart/issues/148#issuecomment-2273549806
        CAPABILITIES_PAYLOAD_0 = bytes.fromhex(
            "b50a1202010114020101150201001e020101170201021a02010110020101250207203c203c203c0024020101480001010101")
        CAPABILITIES_PAYLOAD_1 = bytes.fromhex(
            "b5071f0201002c020101160201043900010151000101e3000101130201010002")

        # Create a dummy device and process the response
        device = AC(0, 0, 0)

        # Parse capability payloads
        with memoryview(CAPABILITIES_PAYLOAD_0) as payload0, memoryview(CAPABILITIES_PAYLOAD_1) as payload1:
            resp0 = CapabilitiesResponse(payload0)
            resp1 = CapabilitiesResponse(payload1)

            resp0.merge(resp1)
            device._update_capabilities(resp0)

        self.assertCountEqual(device.supported_rate_selects, [AC.RateSelect.OFF,
                                                              AC.RateSelect.GEAR_75,
                                                              AC.RateSelect.GEAR_50
                                                              ])

        # TODO find device with 5 levels of rate select

    def test_breeze_modes(self) -> None:
        """Test breeze mode capabilities."""
        # "Modern" breezeless device with "breeze control" i.e. breeze away, breeze mild and breezeless.
        # https://github.com/mill1000/midea-msmart/issues/150#issuecomment-2276158338
        CAPABILITIES_PAYLOAD_0 = bytes.fromhex(
            "b50a12020101430001011402010115020101160201001a020101100201011f020103250207203c203c203c05400001000100")
        CAPABILITIES_PAYLOAD_1 = bytes.fromhex(
            "b5051e020101130201012202010019020100390001010000")

        # Create a dummy device and process the response
        device = AC(0, 0, 0)

        # Parse capability payloads
        with memoryview(CAPABILITIES_PAYLOAD_0) as payload0, memoryview(CAPABILITIES_PAYLOAD_1) as payload1:
            resp0 = CapabilitiesResponse(payload0)
            resp1 = CapabilitiesResponse(payload1)

            resp0.merge(resp1)
            device._update_capabilities(resp0)

        self.assertEqual(device.supports_breeze_away, True)
        self.assertEqual(device.supports_breeze_mild, True)
        self.assertEqual(device.supports_breezeless, True)

        # Device with only breeze away
        # https://github.com/mill1000/midea-msmart/issues/150#issuecomment-2259796473
        CAPABILITIES_PAYLOAD_0 = bytes.fromhex(
            "b50912020101180001001402010115020101160201001a020101100201011f020103250207203c203c203c050100")
        CAPABILITIES_PAYLOAD_1 = bytes.fromhex(
            "b5091e0201011302010122020100190201003900010142000101090001010a000101300001010000")

        # Parse capability payloads
        with memoryview(CAPABILITIES_PAYLOAD_0) as payload0, memoryview(CAPABILITIES_PAYLOAD_1) as payload1:
            resp0 = CapabilitiesResponse(payload0)
            resp1 = CapabilitiesResponse(payload1)

            resp0.merge(resp1)
            device._update_capabilities(resp0)

        self.assertEqual(device.supports_breeze_away, True)
        self.assertEqual(device.supports_breeze_mild, False)
        self.assertEqual(device.supports_breezeless, False)

        # "Legacy" breezeless device with only breezeless.
        # https://github.com/mill1000/midea-ac-py/issues/186#issuecomment-2249023972
        CAPABILITIES_PAYLOAD_0 = bytes.fromhex(
            "b50912020101180001011402010115020101160201001a020101100201011f020103250207203c203c203c050100")
        CAPABILITIES_PAYLOAD_1 = bytes.fromhex(
            "b5041e0201011302010122020100190201000000")

        # Parse capability payloads
        with memoryview(CAPABILITIES_PAYLOAD_0) as payload0, memoryview(CAPABILITIES_PAYLOAD_1) as payload1:
            resp0 = CapabilitiesResponse(payload0)
            resp1 = CapabilitiesResponse(payload1)

            resp0.merge(resp1)
            device._update_capabilities(resp0)

        self.assertEqual(device.supports_breeze_away, False)
        self.assertEqual(device.supports_breeze_mild, False)
        self.assertEqual(device.supports_breezeless, True)


class TestSetState(unittest.TestCase):
    """Test setting device state."""

    def test_properties_breeze_control(self) -> None:
        """Test setting breeze properties with breeze control."""

        # Create dummy device with breeze control
        device = AC(0, 0, 0)
        device._supported_properties.add(PropertyId.BREEZE_CONTROL)

        # Enable a breeze mode
        device.breeze_mild = True

        # Assert state is expected
        self.assertEqual(device.breeze_away, False)
        self.assertEqual(device.breeze_mild, True)
        self.assertEqual(device.breezeless, False)

        # Assert correct property is being updated
        self.assertIn(PropertyId.BREEZE_CONTROL, device._updated_properties)

        # Switch to a different breeze mode
        device.breezeless = True

        # Assert state is expected
        self.assertEqual(device.breeze_away, False)
        self.assertEqual(device.breeze_mild, False)
        self.assertEqual(device.breezeless, True)

        # Assert correct property is being updated
        self.assertIn(PropertyId.BREEZE_CONTROL, device._updated_properties)
        self.assertNotIn(PropertyId.BREEZELESS, device._updated_properties)

    def test_properties_breezeless(self) -> None:
        """Test setting breezeless property without breeze control."""

        # Create dummy device with breeze control
        device = AC(0, 0, 0)
        device._supported_properties.add(PropertyId.BREEZELESS)

        # Enable breezeless
        device.breezeless = True

        # Assert state is expected
        self.assertEqual(device.breeze_away, False)
        self.assertEqual(device.breeze_mild, False)
        self.assertEqual(device.breezeless, True)

        # Assert correct property is being updated
        self.assertIn(PropertyId.BREEZELESS, device._updated_properties)
        self.assertNotIn(PropertyId.BREEZE_CONTROL, device._updated_properties)

    def test_properties_breeze_away(self) -> None:
        """Test setting breeze away property without breeze control."""

        # Create dummy device with breeze control
        device = AC(0, 0, 0)
        device._supported_properties.add(PropertyId.BREEZE_AWAY)

        # Enable breezeless
        device.breeze_away = True

        # Assert state is expected
        self.assertEqual(device.breeze_away, True)
        self.assertEqual(device.breeze_mild, False)
        self.assertEqual(device.breezeless, False)

        # Assert correct property is being updated
        self.assertIn(PropertyId.BREEZE_AWAY, device._updated_properties)
        self.assertNotIn(PropertyId.BREEZE_CONTROL, device._updated_properties)


if __name__ == "__main__":
    unittest.main()
