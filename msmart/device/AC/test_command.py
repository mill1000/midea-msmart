import logging
import unittest
from typing import Union, cast

from msmart.const import DeviceType, FrameType
from msmart.frame import Frame, InvalidFrameException

from .command import (CapabilitiesResponse, CapabilityId, Command,
                      GetPropertiesCommand, GetStateCommand,
                      InvalidResponseException, PropertiesResponse, PropertyId,
                      Response, SetPropertiesCommand, StateResponse)


class _TestResponseBase(unittest.TestCase):
    """Base class that provides some common methods for derived classes."""

    def assertHasAttr(self, obj, attr) -> None:
        """Assert that an object has an attribute."""
        self.assertTrue(hasattr(obj, attr),
                        msg=f"Object {obj} lacks attribute '{attr}'.")

    def _test_build_response(self, msg) -> Union[StateResponse, CapabilitiesResponse, PropertiesResponse, Response]:
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
            "418100ff03ff00020000000000000000000000000311f4")

        # Override message id to match test data
        Command._message_id = 0x10

        # Build frame from command
        command = GetStateCommand()
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
    EXPECTED_ATTRS = ["power_on", "target_temperature", "operational_mode",
                      "fan_speed", "swing_mode", "turbo_mode", "eco_mode",
                      "sleep_mode", "fahrenheit", "indoor_temperature",
                      "outdoor_temperature", "filter_alert", "display_on",
                      "freeze_protection_mode"]

    def _test_response(self, msg) -> StateResponse:
        resp = self._test_build_response(msg)
        self._test_check_attributes(resp, self.EXPECTED_ATTRS)
        return cast(StateResponse, resp)

    def test_message_checksum(self) -> None:
        # https://github.com/mill1000/midea-ac-py/issues/11#issuecomment-1650647625
        # V3 state response with checksum as CRC, and shorter than expected
        TEST_MESSAGE_CHECKSUM_AS_CRC = bytes.fromhex(
            "aa1eac00000000000003c0004b1e7f7f000000000069630000000000000d33")
        resp = self._test_response(TEST_MESSAGE_CHECKSUM_AS_CRC)

        # Assert response is a state response
        self.assertEqual(type(resp), StateResponse)

        # Suppress type errors
        resp = cast(StateResponse, resp)

        self.assertEqual(resp.target_temperature, 27.0)
        self.assertEqual(resp.indoor_temperature, 27.5)
        self.assertEqual(resp.outdoor_temperature, 24.5)

    def test_message_v2(self) -> None:
        # V2 state response
        TEST_MESSAGE_V2 = bytes.fromhex(
            "aa22ac00000000000303c0014566000000300010045eff00000000000000000069fdb9")
        resp = self._test_response(TEST_MESSAGE_V2)

        # Assert response is a state response
        self.assertEqual(type(resp), StateResponse)

        # Suppress type errors
        resp = cast(StateResponse, resp)

        self.assertEqual(resp.target_temperature, 21.0)
        self.assertEqual(resp.indoor_temperature, 22.0)
        self.assertEqual(resp.outdoor_temperature, None)

    def test_message_v3(self) -> None:
        # V3 state response
        TEST_MESSAGE_V3 = bytes.fromhex(
            "aa23ac00000000000303c00145660000003c0010045c6b20000000000000000000020d79")
        resp = self._test_response(TEST_MESSAGE_V3)

        # Assert response is a state response
        self.assertEqual(type(resp), StateResponse)

        # Suppress type errors
        resp = cast(StateResponse, resp)

        self.assertEqual(resp.target_temperature, 21.0)
        self.assertEqual(resp.indoor_temperature, 21.0)
        self.assertEqual(resp.outdoor_temperature, 28.5)

    def test_message_additional_precision(self) -> None:
        """Test decoding of temperatures with higher precision."""
        # Messages with additional temperature precision bits
        TEST_MESSAGES = {
            # https://github.com/mill1000/midea-msmart/issues/89#issuecomment-1783316836
            (24.0, 25.1, 10.0): bytes.fromhex(
                "aa23ac00000000000203c00188647f7f000000000063450c0056190000000000000497c3"),
            # https://github.com/mill1000/midea-msmart/issues/89#issuecomment-1782352164
            (24.0, 27.0, 10.2): bytes.fromhex(
                "aa23ac00000000000203c00188647f7f000000000067450c00750000000000000001a3b0"),
            (24.0, 25.0, 10.0): bytes.fromhex(
                "aa23ac00000000000203c00188647f7f000080000064450c00501d00000000000001508e"),
        }

        for targets, message in TEST_MESSAGES.items():
            # Create response from the message
            resp = self._test_response(message)

            # Assert response is a state response
            self.assertEqual(type(resp), StateResponse)

            # Suppress type errors
            resp = cast(StateResponse, resp)

            target, indoor, outdoor = targets

            self.assertEqual(resp.target_temperature, target)
            self.assertEqual(resp.indoor_temperature, indoor)
            self.assertEqual(resp.outdoor_temperature, outdoor)

        # Raw responses with additional temperature precision bits
        TEST_RESPONSES = {
            # https://github.com/mill1000/midea-ac-py/issues/39#issuecomment-1729884851
            # Corrected target values from user reported values
            (16.0, 23.2, 18.4): bytes.fromhex("c00181667f7f003c00000060560400420000000000000048"),
            (16.5, 23.4, 18.4): bytes.fromhex("c00191667f7f003c00000060560400440000000000000049"),
            (17.0, 24.1, 18.3): bytes.fromhex("c00181667f7f003c0000006156050036000000000000004a"),
            (17.5, 24.3, 18.2): bytes.fromhex("c00191667f7f003c0000006156050028000000000000004b"),
            (18.0, 24.3, 18.2): bytes.fromhex("c00182667f7f003c0000006156060028000000000000004c"),
            (18.5, 24.3, 18.2): bytes.fromhex("c00192667f7f003c0000006156060028000000000000004d"),
            (19.0, 24.3, 18.2): bytes.fromhex("c00183667f7f003c0000006156070028000000000000004e"),
            (19.5, 24.0, 19.0): bytes.fromhex("c00193667f7f003c00000061570700550000000000000050"),
        }

        for targets, payload in TEST_RESPONSES.items():
            # Create response
            with memoryview(payload) as mv_payload:
                resp = StateResponse(mv_payload)

            # Assert that it exists
            self.assertIsNotNone(resp)

            # Assert response is a state response
            self.assertEqual(type(resp), StateResponse)

            # Suppress type errors
            resp = cast(StateResponse, resp)

            target, indoor, outdoor = targets

            self.assertEqual(resp.target_temperature, target)
            self.assertEqual(resp.indoor_temperature, indoor)
            self.assertEqual(resp.outdoor_temperature, outdoor)

    def test_target_temperature(self) -> None:
        """Test decoding of target temperature from a variety of state responses."""
        TEST_PAYLOADS = {
            # https://github.com/mill1000/midea-ac-py/issues/39#issuecomment-1729884851
            # Corrected target values from user reported values
            16.0: bytes.fromhex("c00181667f7f003c00000060560400420000000000000048"),
            16.5: bytes.fromhex("c00191667f7f003c00000060560400440000000000000049"),
            17.0: bytes.fromhex("c00181667f7f003c0000006156050036000000000000004a"),
            17.5: bytes.fromhex("c00191667f7f003c0000006156050028000000000000004b"),
            18.0: bytes.fromhex("c00182667f7f003c0000006156060028000000000000004c"),
            18.5: bytes.fromhex("c00192667f7f003c0000006156060028000000000000004d"),
            19.0: bytes.fromhex("c00183667f7f003c0000006156070028000000000000004e"),
            19.5: bytes.fromhex("c00193667f7f003c00000061570700550000000000000050"),

            # Midea U-Shaped
            16.0: bytes.fromhex("c00040660000003c00000062680400000000000000000004"),
            16.5: bytes.fromhex("c00050660000003c00000062670400000000000000000004"),
        }

        for target, payload in TEST_PAYLOADS.items():
            # Create response
            with memoryview(payload) as mv_payload:
                resp = StateResponse(mv_payload)

            # Assert that it exists
            self.assertIsNotNone(resp)

            # Assert response is a state response
            self.assertEqual(type(resp), StateResponse)

            # Suppress type errors
            resp = cast(StateResponse, resp)

            # Assert that expected target temperature matches
            self.assertEqual(resp.target_temperature, target)


class TestCapabilitiesResponse(_TestResponseBase):
    """Test device capabilities response messages."""

    # Properties expected in capabilities responses
    EXPECTED_PROPERTIES = ["swing_horizontal", "swing_vertical", "swing_both",
                           "fan_silent", "fan_low", "fan_medium", "fan_high", "fan_auto", "fan_custom",
                           "dry_mode", "cool_mode", "heat_mode", "auto_mode",
                           "eco_mode", "turbo_mode", "freeze_protection_mode",
                           "min_temperature", "max_temperature",
                           "display_control", "filter_reminder"]

    def test_properties(self) -> None:
        """Test that the capabilities response has the expected properties."""

        # Construct a response from a dummy payload with no caps
        with memoryview(b"\xb5\x00") as data:
            resp = CapabilitiesResponse(data)
        self.assertIsNotNone(resp)

        # Check that the object has all the expected properties
        self._test_check_attributes(resp, self.EXPECTED_PROPERTIES)

    def test_capabilities_parsers(self) -> None:
        """Test the generic capabilities parsers. e.g. bool, get_value"""

        def _build_capability_response(cap, value) -> CapabilitiesResponse:
            data = b"\xBA\x01" + \
                cap.to_bytes(2, "little") + b"\x01" + bytes([value])
            with memoryview(data) as mv_data:
                resp = CapabilitiesResponse(mv_data)
            self.assertIsNotNone(resp)
            return resp

        # Test SILKY_COOL capability which uses a get_value parser. e.g. X == 1
        self.assertEqual(_build_capability_response(
            CapabilityId.SILKY_COOL, 0)._capabilities["silky_cool"], False)
        self.assertEqual(_build_capability_response(
            CapabilityId.SILKY_COOL, 1)._capabilities["silky_cool"], True)
        self.assertEqual(_build_capability_response(
            CapabilityId.SILKY_COOL, 100)._capabilities["silky_cool"], False)

        # Test PRESET_ECO capability which uses 2 get_value parsers.
        # e.g. eco_mode -> X == 1, eco_mode2 -> X == 2
        resp = _build_capability_response(CapabilityId.PRESET_ECO, 0)
        self.assertEqual(resp._capabilities["eco_mode"], False)
        self.assertEqual(resp._capabilities["eco_mode_2"], False)

        resp = _build_capability_response(CapabilityId.PRESET_ECO, 1)
        self.assertEqual(resp._capabilities["eco_mode"], True)
        self.assertEqual(resp._capabilities["eco_mode_2"], False)

        resp = _build_capability_response(CapabilityId.PRESET_ECO, 2)
        self.assertEqual(resp._capabilities["eco_mode"], False)
        self.assertEqual(resp._capabilities["eco_mode_2"], True)

        # Test PRESET_TURBO capability which uses 2 custom parsers.
        # e.g. turbo_heat -> X == 1 or X == 3, turbo_cool -> X < 2
        resp = _build_capability_response(CapabilityId.PRESET_TURBO, 0)
        self.assertEqual(resp._capabilities["turbo_heat"], False)
        self.assertEqual(resp._capabilities["turbo_cool"], True)

        resp = _build_capability_response(CapabilityId.PRESET_TURBO, 1)
        self.assertEqual(resp._capabilities["turbo_heat"], True)
        self.assertEqual(resp._capabilities["turbo_cool"], True)

        resp = _build_capability_response(CapabilityId.PRESET_TURBO, 3)
        self.assertEqual(resp._capabilities["turbo_heat"], True)
        self.assertEqual(resp._capabilities["turbo_cool"], False)

        resp = _build_capability_response(CapabilityId.PRESET_TURBO, 4)
        self.assertEqual(resp._capabilities["turbo_heat"], False)
        self.assertEqual(resp._capabilities["turbo_cool"], False)

    def test_capabilities(self) -> None:
        """Test that we decode capabilities responses as expected."""
        # https://github.com/mill1000/midea-ac-py/issues/13#issuecomment-1657485359
        # Identical payload received in https://github.com/mill1000/midea-msmart/issues/88#issuecomment-1781972832

        TEST_CAPABILITIES_RESPONSE = bytes.fromhex(
            "aa29ac00000000000303b5071202010113020101140201011502010116020101170201001a020101dedb")
        resp = self._test_build_response(TEST_CAPABILITIES_RESPONSE)
        resp = cast(CapabilitiesResponse, resp)

        EXPECTED_RAW_CAPABILITIES = {
            "eco_mode": True, "eco_mode_2": False,
            "freeze_protection": True, "heat_mode": True,
            "cool_mode": True, "dry_mode": True,
            "auto_mode": True,
            "swing_horizontal": True, "swing_vertical": True,
            "power_stats": False, "power_setting": False, "power_bcd": False,
            "filter_notice": False, "filter_clean": False,
            "turbo_heat": True, "turbo_cool": True
        }
        # Ensure raw decoded capabilities match
        self.assertEqual(resp._capabilities, EXPECTED_RAW_CAPABILITIES)

        EXPECTED_CAPABILITIES = {
            "swing_horizontal": True, "swing_vertical": True, "swing_both": True,
            "dry_mode": True, "heat_mode": True, "cool_mode": True, "auto_mode": True,
            "eco_mode": True, "turbo_mode": True, "freeze_protection_mode": True,
            "fan_custom": False, "fan_silent": False, "fan_low": True,
            "fan_medium": True,  "fan_high": True, "fan_auto": True,
            "min_temperature": 16, "max_temperature": 30,
            "display_control": False, "filter_reminder": False
        }
        # Check capabilities properties match
        for prop in self.EXPECTED_PROPERTIES:
            self.assertEqual(getattr(resp, prop),
                             EXPECTED_CAPABILITIES[prop], prop)

        # Check if there are additional capabilities
        self.assertEqual(resp.additional_capabilities, False)

    def test_capabilities_2(self) -> None:
        """Test that we decode capabilities responses as expected."""
        # https://github.com/mac-zhou/midea-ac-py/pull/177#issuecomment-1259772244
        TEST_CAPABILITIES_RESPONSE = bytes.fromhex(
            "aa3dac00000000000203b50a12020101180001001402010115020101160201001a020101100201011f020100250207203c203c203c00400001000100c83a")

        # Test case includes an unknown capability 0x40 that generates a warning
        with self.assertLogs("msmart") as log:
            resp = self._test_build_response(TEST_CAPABILITIES_RESPONSE)
            resp = cast(CapabilitiesResponse, resp)

            # Check warning is generated for ID 0x0040
            self.assertRegex(log.output[0], "Unknown capability. ID: 0x0040")

        EXPECTED_RAW_CAPABILITIES = {
            "eco_mode": True, "eco_mode_2": False, "silky_cool": False,
            "heat_mode": True, "cool_mode": True, "dry_mode": True,
            "auto_mode": True, "swing_horizontal": True, "swing_vertical": True,
            "power_stats": False, "power_setting": False, "power_bcd": False,
            "turbo_heat": True, "turbo_cool": True,
            "fan_custom": True, "fan_silent": False, "fan_low": False,
            "fan_medium": False,  "fan_high": False, "fan_auto": False,
            "humidity_auto_set": False, "humidity_manual_set": False,
            "cool_min_temperature": 16.0, "cool_max_temperature": 30.0,
            "auto_min_temperature": 16.0, "auto_max_temperature": 30.0,
            "heat_min_temperature": 16.0, "heat_max_temperature": 30.0,
            "decimals": False
        }
        # Ensure raw decoded capabilities match
        self.assertEqual(resp._capabilities, EXPECTED_RAW_CAPABILITIES)

        EXPECTED_CAPABILITIES = {
            "swing_horizontal": True, "swing_vertical": True, "swing_both": True,
            "dry_mode": True, "heat_mode": True, "cool_mode": True, "auto_mode": True,
            "eco_mode": True, "turbo_mode": True, "freeze_protection_mode": False,
            "fan_custom": True, "fan_silent": True, "fan_low": True,
            "fan_medium": True,  "fan_high": True, "fan_auto": True,
            "min_temperature": 16, "max_temperature": 30,
            "display_control": False, "filter_reminder": False
        }
        # Check capabilities properties match
        for prop in self.EXPECTED_PROPERTIES:
            self.assertEqual(getattr(resp, prop),
                             EXPECTED_CAPABILITIES[prop], prop)

        # Check if there are additional capabilities
        self.assertEqual(resp.additional_capabilities, True)

    def test_capabilities_3(self) -> None:
        """Test that we decode capabilities responses as expected."""
        # Toshiba Smart Window Unit (2019)
        TEST_CAPABILITIES_RESPONSE = bytes.fromhex(
            "aa29ac00000000000303b507120201021402010015020102170201021a0201021002010524020101990d")
        resp = self._test_build_response(TEST_CAPABILITIES_RESPONSE)
        resp = cast(CapabilitiesResponse, resp)

        EXPECTED_RAW_CAPABILITIES = {
            "eco_mode": False, "eco_mode_2": True, "heat_mode": False,
            "cool_mode": True, "dry_mode": True, "auto_mode": True,
            "swing_horizontal": False, "swing_vertical": False,
            "filter_notice": True, "filter_clean": False, "turbo_heat": False,
            "turbo_cool": False,
            "fan_custom": False, "fan_silent": False, "fan_low": True,
            "fan_medium": True,  "fan_high": True, "fan_auto": True,
            "display_control": True
        }
        # Ensure raw decoded capabilities match
        self.assertEqual(resp._capabilities, EXPECTED_RAW_CAPABILITIES)

        EXPECTED_CAPABILITIES = {
            "swing_horizontal": False, "swing_vertical": False, "swing_both": False,
            "dry_mode": True, "heat_mode": False, "cool_mode": True, "auto_mode": True,
            "eco_mode": True, "turbo_mode": False, "freeze_protection_mode": False,
            "fan_custom": False, "fan_silent": False, "fan_low": True,
            "fan_medium": True,  "fan_high": True, "fan_auto": True,
            "min_temperature": 16, "max_temperature": 30,
            "display_control": True, "filter_reminder": True
        }
        # Check capabilities properties match
        for prop in self.EXPECTED_PROPERTIES:
            self.assertEqual(getattr(resp, prop),
                             EXPECTED_CAPABILITIES[prop], prop)

        # Check if there are additional capabilities
        self.assertEqual(resp.additional_capabilities, False)

    def test_capabilities_4(self) -> None:
        """Test that we decode capabilities responses as expected."""
        # Midea U-shaped Window Unit (2022)
        TEST_CAPABILITIES_RESPONSE = bytes.fromhex(
            "aa39ac00000000000303b50912020102130201001402010015020100170201021a02010010020101250207203c203c203c00240201010102a1a0")
        resp = self._test_build_response(TEST_CAPABILITIES_RESPONSE)
        resp = cast(CapabilitiesResponse, resp)

        EXPECTED_RAW_CAPABILITIES = {
            "eco_mode": False, "eco_mode_2": True, "freeze_protection": False,
            "heat_mode": False, "cool_mode": True, "dry_mode": True, "auto_mode": True,
            "swing_horizontal": False, "swing_vertical": True, "filter_notice": True,
            "filter_clean": False, "turbo_heat": False, "turbo_cool": True,
            "fan_custom": True, "fan_silent": False, "fan_low": False,
            "fan_medium": False,  "fan_high": False, "fan_auto": False,
            "cool_min_temperature": 16.0, "cool_max_temperature": 30.0,
            "auto_min_temperature": 16.0, "auto_max_temperature": 30.0,
            "heat_min_temperature": 16.0, "heat_max_temperature": 30.0,
            "decimals": False, "display_control": True
        }
        # Ensure raw decoded capabilities match
        self.assertEqual(resp._capabilities, EXPECTED_RAW_CAPABILITIES)

        EXPECTED_CAPABILITIES = {
            "swing_horizontal": False, "swing_vertical": True, "swing_both": False,
            "dry_mode": True, "heat_mode": False, "cool_mode": True, "auto_mode": True,
            "eco_mode": True, "turbo_mode": True, "freeze_protection_mode": False,
            "fan_custom": True, "fan_silent": True, "fan_low": True,
            "fan_medium": True,  "fan_high": True, "fan_auto": True,
            "min_temperature": 16, "max_temperature": 30,
            "display_control": True, "filter_reminder": True
        }
        # Check capabilities properties match
        for prop in self.EXPECTED_PROPERTIES:
            self.assertEqual(getattr(resp, prop),
                             EXPECTED_CAPABILITIES[prop], prop)

        # Check if there are additional capabilities
        self.assertEqual(resp.additional_capabilities, True)

    def test_additional_capabilities(self) -> None:
        self.maxDiff = None
        """Test that we decode capabilities and additional capabilities responses as expected."""
        # https://github.com/mill1000/midea-ac-py/issues/60#issuecomment-1867498321
        TEST_CAPABILITIES_RESPONSE = bytes.fromhex(
            "aa3dac00000000000303b50a12020101430001011402010115020101160201001a020101100201011f020103250207203c203c203c05400001000100c805")

        # Test case includes an unknown capability 0x40 that generates a warning
        with self.assertLogs("msmart") as log:
            resp = self._test_build_response(TEST_CAPABILITIES_RESPONSE)
            resp = cast(CapabilitiesResponse, resp)

            # Check warning is generated for ID 0x0040
            self.assertRegex(log.output[0], "Unknown capability. ID: 0x0040")

        EXPECTED_RAW_CAPABILITIES = {
            "eco_mode": True, "eco_mode_2": False,
            "breeze_control": True,
            "heat_mode": True, "cool_mode": True, "dry_mode": True, "auto_mode": True,
            "swing_horizontal": True, "swing_vertical": True,
            "power_stats": False, "power_setting": False, "power_bcd": False,
            "turbo_heat": True, "turbo_cool": True,
            "fan_silent": False, "fan_low": False, "fan_medium": False, "fan_high": False, "fan_auto": False, "fan_custom": True,
            "humidity_auto_set": False, "humidity_manual_set": True,
            "cool_min_temperature": 16.0, "cool_max_temperature": 30.0,
            "auto_min_temperature": 16.0, "auto_max_temperature": 30.0,
            "heat_min_temperature": 16.0, "heat_max_temperature": 30.0,
            "decimals": True
        }
        # Ensure raw decoded capabilities match
        self.assertEqual(resp._capabilities, EXPECTED_RAW_CAPABILITIES)

        # Check if there are additional capabilities
        self.assertEqual(resp.additional_capabilities, True)

        # Additional capabilities response
        TEST_ADDITIONAL_CAPABILITIES_RESPONSE = bytes.fromhex(
            "aa23ac00000000000303b5051e020101130201012202010019020100390001010000febe")
        additional_resp = self._test_build_response(
            TEST_ADDITIONAL_CAPABILITIES_RESPONSE)
        additional_resp = cast(CapabilitiesResponse, additional_resp)

        EXPECTED_ADDITIONAL_RAW_CAPABILITIES = {
            "freeze_protection": True,
            "fahrenheit": True,
            "aux_electric_heat": False,
            "self_clean": True,
            "anion": True
        }
        # Ensure raw decoded capabilities match
        self.assertEqual(additional_resp._capabilities,
                         EXPECTED_ADDITIONAL_RAW_CAPABILITIES)

        # Ensure the additional capabilities response doesn't also want more capabilities
        self.assertEqual(additional_resp.additional_capabilities, False)

        # Check that merging the capabilities produced expected results
        resp.merge(additional_resp)

        EXPECTED_MERGED_RAW_CAPABILITIES = {
            "eco_mode": True, "eco_mode_2": False,
            "breeze_control": True,
            "heat_mode": True, "cool_mode": True, "dry_mode": True, "auto_mode": True,
            "swing_horizontal": True, "swing_vertical": True,
            "power_stats": False, "power_setting": False, "power_bcd": False,
            "turbo_heat": True, "turbo_cool": True,
            "fan_silent": False, "fan_low": False, "fan_medium": False, "fan_high": False, "fan_auto": False, "fan_custom": True,
            "humidity_auto_set": False, "humidity_manual_set": True,
            "cool_min_temperature": 16.0, "cool_max_temperature": 30.0,
            "auto_min_temperature": 16.0, "auto_max_temperature": 30.0,
            "heat_min_temperature": 16.0, "heat_max_temperature": 30.0,
            "decimals": True,
            "freeze_protection": True,
            "fahrenheit": True,
            "aux_electric_heat": False,
            "self_clean": True,
            "anion": True
        }
        # Ensure raw decoded capabilities match
        self.assertEqual(resp._capabilities, EXPECTED_MERGED_RAW_CAPABILITIES)

        EXPECTED_CAPABILITIES = {
            "swing_horizontal": True, "swing_vertical": True, "swing_both": True,
            "dry_mode": True, "heat_mode": True, "cool_mode": True, "auto_mode": True,
            "eco_mode": True, "turbo_mode": True, "freeze_protection_mode": True,
            "fan_custom": True, "fan_silent": True, "fan_low": True,
            "fan_medium": True,  "fan_high": True, "fan_auto": True,
            "min_temperature": 16, "max_temperature": 30,
            "display_control": False, "filter_reminder": False
        }
        # Check capabilities properties match
        for prop in self.EXPECTED_PROPERTIES:
            self.assertEqual(getattr(resp, prop),
                             EXPECTED_CAPABILITIES[prop], prop)


class TestGetPropertiesCommand(unittest.TestCase):

    def test_payload(self) -> None:
        """Test that we encode properties payloads correctly."""
        # TODO this test is not based on a real world sample
        PROPS = [PropertyId.INDOOR_HUMIDITY, PropertyId.SWING_UD_ANGLE]

        # Build command
        command = GetPropertiesCommand(PROPS)

        # Fetch payload
        payload = command.tobytes()[10:-1]

        # Assert payload header looks correct
        self.assertEqual(payload[0], 0xB1)
        self.assertEqual(payload[1], len(PROPS))

        # Assert that property ID was packed correctly
        self.assertEqual(payload[2], PropertyId.INDOOR_HUMIDITY & 0xFF)
        self.assertEqual(payload[3], PropertyId.INDOOR_HUMIDITY >> 8 & 0xFF)


class TestSetPropertiesCommand(unittest.TestCase):

    def test_payload(self) -> None:
        """Test that we encode set properties payloads correctly."""
        # TODO this test is not based on a real world sample
        PROPS = {PropertyId.SWING_UD_ANGLE: bytes(
            [25]), PropertyId.SWING_LR_ANGLE: bytes([75])}

        # Build command
        command = SetPropertiesCommand(PROPS)

        # Fetch payload
        payload = command.tobytes()[10:-1]

        # Assert payload header looks correct
        self.assertEqual(payload[0], 0xB0)
        self.assertEqual(payload[1], len(PROPS))

        # Assert that property ID was packed correctly
        self.assertEqual(payload[2], PropertyId.SWING_UD_ANGLE & 0xFF)
        self.assertEqual(payload[3], PropertyId.SWING_UD_ANGLE >> 8 & 0xFF)

        # Assert length is correct
        self.assertEqual(payload[4], len(PROPS[PropertyId.SWING_UD_ANGLE]))

        # Assert data is correct
        self.assertEqual(payload[5], PROPS[PropertyId.SWING_UD_ANGLE][0])


class TestPropertiesResponse(_TestResponseBase):
    """Test properties response messages."""

    def test_properties_parsing(self) -> None:
        """Test we decode properties correctly."""
        # https://github.com/mill1000/midea-ac-py/issues/60#issuecomment-1936976587
        TEST_RESPONSE = bytes.fromhex(
            "aa21ac00000000000303b10409000001000a00000100150000012b1e020000005fa3")

        resp = self._test_build_response(TEST_RESPONSE)

        # Assert response is a correct type
        self.assertEqual(type(resp), PropertiesResponse)
        resp = cast(PropertiesResponse, resp)

        EXPECTED_RAW_PROPERTIES = {
            PropertyId.INDOOR_HUMIDITY: 43,
            PropertyId.SWING_LR_ANGLE: 0,
            PropertyId.SWING_UD_ANGLE: 0,
        }
        # Ensure raw decoded properties match
        self.assertEqual(resp._properties, EXPECTED_RAW_PROPERTIES)

        # Check state
        self.assertEqual(resp.get_property(PropertyId.INDOOR_HUMIDITY), 43)
        self.assertEqual(resp.get_property(PropertyId.SWING_LR_ANGLE), 0)
        self.assertEqual(resp.get_property(PropertyId.SWING_UD_ANGLE), 0)

    def test_properties_ack(self) -> None:
        """Test we decode an acknowledgement from a set properties command correctly."""
        # https://github.com/mill1000/midea-msmart/issues/97#issuecomment-1949495900
        TEST_RESPONSE = bytes.fromhex(
            "aa18ac00000000000302b0020a0000013209001101000089a4")

        resp = self._test_build_response(TEST_RESPONSE)
        resp = cast(PropertiesResponse, resp)

        # Assert response is a correct type
        self.assertEqual(type(resp), PropertiesResponse)

        EXPECTED_RAW_PROPERTIES = {
            PropertyId.SWING_LR_ANGLE: 50,
            PropertyId.SWING_UD_ANGLE: 0,
        }
        # Ensure raw decoded properties match
        self.assertEqual(resp._properties, EXPECTED_RAW_PROPERTIES)

        # Check state
        self.assertEqual(resp.get_property(PropertyId.SWING_LR_ANGLE), 50)
        self.assertEqual(resp.get_property(PropertyId.SWING_UD_ANGLE), 0)

    def test_properties_notify(self) -> None:
        """Test we ignore property notifications."""
        # https://github.com/mill1000/midea-msmart/issues/122
        TEST_RESPONSE = bytes.fromhex(
            "aa1aac00000000000205b50310060101090001010a000101dcbcb4")

        resp = self._test_build_response(TEST_RESPONSE)

        # Assert response is generic
        self.assertEqual(type(resp), Response)

    def test_properties_unknown_and_invalid(self) -> None:
        """Test we warn when decoding unknown properties and that invalid properties are not stored."""
        # https://github.com/mill1000/midea-ac-py/issues/128#issuecomment-2098342003
        TEST_RESPONSE = bytes.fromhex(
            "aa1bac00000000000202b0021e001004001000001a00000100000e18")

        with self.assertLogs("msmart", logging.WARNING) as log:
            resp = self._test_build_response(TEST_RESPONSE)
            resp = cast(PropertiesResponse, resp)

            # Check warning is generated for ID 0x001E
            self.assertRegex(log.output[0], "Unknown property. ID: 0x001E")

        # Assert response is a correct type
        self.assertEqual(type(resp), PropertiesResponse)

        # Assert that the buzzer property is not decoded
        self.assertIsNone(resp.get_property(PropertyId.BUZZER))


class TestResponseConstruct(_TestResponseBase):
    """Test construction of responses from raw data."""

    def test_invalid_checksum(self) -> None:
        """Test that invalid checksums raise exceptions."""
        TEST_RESPONSE_BAD_CHECKSUM = bytes.fromhex(
            "aa14ac00000000000303b10109000001003c0000FF")

        with self.assertRaises(InvalidFrameException):
            Response.construct(TEST_RESPONSE_BAD_CHECKSUM)

    def test_properties_response_invalid_crc(self) -> None:
        """Test that PropertiesResponses with invalid CRCs are accepted."""
        # PropertiesResponse with invalid CRC
        # https://github.com/mill1000/midea-ac-py/issues/101#issuecomment-1994824924
        TEST_RESPONSE_PROPERTIES_BAD_CRC = bytes.fromhex(
            "aa14ac00000000000303b10109000001003c000042")
        # Mocked up StateResponse with invalid CRC
        TEST_RESPONSE_STATE_BAD_CRC = bytes.fromhex(
            "aa22ac00000000000303c0014566000000300010045eff00000000000000000069aa0c")

        # Assert that constructing a StateResponse with invalid CRC raises an exception
        with self.assertRaises(InvalidResponseException):
            resp = Response.construct(TEST_RESPONSE_STATE_BAD_CRC)

        # Now construct a PropertiesResponse with an invalid CRC
        resp = Response.construct(TEST_RESPONSE_PROPERTIES_BAD_CRC)

        self.assertIsNotNone(resp)
        self.assertEqual(type(resp), PropertiesResponse)


if __name__ == "__main__":
    unittest.main()
