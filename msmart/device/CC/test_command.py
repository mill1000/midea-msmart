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
            "0100000000000000000000000000000000000000000001cc")

        # Override message id to match test data
        Command._message_id = 0x00

        # Build frame from command
        command = QueryCommand()
        frame = command.tobytes()
        self.assertIsNotNone(frame)

        # Assert that frame is valid
        with memoryview(frame) as frame_mv:
            Frame.validate(frame_mv, DeviceType.COMMERCIAL_AC)

        # Check frame payload to ensure it matches expected
        self.assertEqual(frame[10:-1], EXPECTED_PAYLOAD)

        # Check length byte
        self.assertEqual(frame[1], len(
            EXPECTED_PAYLOAD) + Frame._HEADER_LENGTH)

        # Check device type
        self.assertEqual(frame[2], DeviceType.COMMERCIAL_AC)

        # Check frame type
        self.assertEqual(frame[9], FrameType.QUERY)


class TestQueryResponse(_TestResponseBase):
    """Test device query response messages."""

    # Attributes expected in query response objects
    EXPECTED_ATTRS = [
        "power_on",
        "target_temperature",
        "indoor_temperature",
        "outdoor_temperature",
        "fahrenheit",
        "target_humidity",
        "indoor_humidity",
        "operational_mode",
        "fan_speed",
        "vert_swing_angle",
        "horz_swing_angle",
        "wind_sense",
        "eco",
        "silent",
        "sleep",
        "purifier",
        "beep",
        "display",
        "aux_mode",
        # Capabilities
        "target_temperature_min",
        "target_temperature_max",
        "supports_humidity",
        "supported_op_modes",
        "supports_fan_speed",
        "supports_vert_swing_angle",
        "supports_horz_swing_angle",
        "supports_wind_sense",
        "supports_co2_level",
        "supports_eco",
        "supports_silent",
        "supports_sleep",
        "supports_self_clean",
        "supports_purifier",
        "supports_purifier_auto",
        "supports_filter_level",
        "supported_aux_modes",
    ]

    def _test_response(self, msg) -> QueryResponse:
        resp = self._test_build_response(msg)
        self._test_check_attributes(resp, self.EXPECTED_ATTRS)
        return cast(QueryResponse, resp)

    def test_message(self) -> None:
        # https://github.com/mill1000/midea-msmart/pull/233#issuecomment-3268766672
        TEST_MESSAGE = bytes.fromhex(
            "aa63cc0000000000000301fe00000043005001728c79010100728c728c797900010141ff010203000603010000000300000001030103010000000000000000000001000100010000000000000000000000000001000200000100000101000102ff02ff6a")
        resp = self._test_response(TEST_MESSAGE)

        # Assert response is a state response
        self.assertEqual(type(resp), QueryResponse)

        # Suppress type errors
        resp = cast(QueryResponse, resp)

        # Check basic state
        self.assertEqual(resp.power_on, True)
        self.assertEqual(resp.target_temperature, 20.5)
        self.assertEqual(resp.indoor_temperature, 25.7)
        self.assertEqual(resp.operational_mode, 3)  # Heat
        self.assertEqual(resp.fan_speed, 0)
        self.assertEqual(resp.vert_swing_angle, 3)
        self.assertEqual(resp.horz_swing_angle, 3)

    def _test_payload(self, payload: bytes) -> QueryResponse:
        """Create a response from a test payload."""
        # Create response
        with memoryview(payload) as mv_payload:
            resp = QueryResponse(mv_payload)

        # Assert that it exists
        self.assertIsNotNone(resp)

        # Assert response is a state response
        self.assertEqual(type(resp), QueryResponse)

        return resp

    def test_invalid_header(self) -> None:
        """Test exceptions are raised when payload lacks header."""
        TEST_PAYLOADS = [
            bytes.fromhex(
                "01ff0000000000000000000000000000000000000000000000000000000000"),
            bytes.fromhex(
                "00fe0000000000000000000000000000000000000000000000000000000000")
        ]
        for payload in TEST_PAYLOADS:
            with self.assertRaises(InvalidResponseException):
                self._test_payload(payload)

    def test_target_temperature(self) -> None:
        """Test parsing of target temperature from payloads."""
        TEST_PAYLOADS = {
            # https://github.com/mill1000/midea-msmart/pull/233#issuecomment-3268885233
            17.0: bytes.fromhex("01fe00000043005001728c7200dd00728c728c727200010141ff010203000603010008000300000001030103010000000000000000000001000100010000000000000000000000000001000200000100000101000102ff02"),
            30.0: bytes.fromhex("01fe00000043005001728c8c00e100728c728c8c8c00010141ff010203000603010008000300000001030103010000000000000000000001000100010000000000000000000000000001000200000100000101000102ff02"),
            # https://github.com/mill1000/midea-msmart/pull/233#issuecomment-3268766672
            20.5: bytes.fromhex("01fe00000043005001728c79010000728c728c797900010141ff010203000603010000000300000001030103010000000000000000000001000100010000000000000000000000000001000200000100000101000102ff02"),
        }
        for value, payload in TEST_PAYLOADS.items():
            resp = self._test_payload(payload)

            # Assert that expected target temperature matches
            self.assertEqual(resp.target_temperature, value)

    def test_indoor_temperature(self) -> None:
        """Test parsing of indoor temperature from payloads."""
        TEST_PAYLOADS = {
            # https://github.com/mill1000/midea-msmart/pull/233#issuecomment-3273394865
            20.7: bytes.fromhex("01fe00000043005000728c7800cf00728c728c787800010141ff010203000603010008000000000001000103010000000000000000000001000100010000000000000000000000000001000200000100000101000102ff02ff"),
            20.3: bytes.fromhex("01fe00000043005000728c7800cb00728c728c787800010141ff010203000603010008000000000001000103010000000000000000000001000100010000000000000000000000000001000200000100000101000102ff02ff"),
            19.2: bytes.fromhex("01fe00000043005000728c7800c000728c728c787800010141ff010203000603010008000000000001000103010000000000000000000001000100010000000000000000000000000001000200000100000101000102ff02ff"),
            23.9: bytes.fromhex("01fe00000043005001728c8c00ef00728c728c8c8c00010141ff010203000603010008000500000001050106010000000000000000000001000100010000000000000000000000000001000200000100000101000102ff02ff"),
            # https://github.com/mill1000/midea-msmart/pull/233#issuecomment-3272675291
            # Samples with data in MSB
            26.4: bytes.fromhex("01fe00000043005001728c78010800728c728c787800010141ff010203000602010008000100000001010103010300000000000000000001000100010000000000000000000000000001000200000100000101000102ff02"),
            25.6: bytes.fromhex("01fe00000043005001728c78010000728c728c787800010141ff010203000603010008000600000001060106010000000000000000000001000100010000000000000000000000000001000200000100000101000102ff02")
        }
        for temperature, payload in TEST_PAYLOADS.items():
            resp = self._test_payload(payload)

            # Assert that expected indoor temperature matches
            self.assertEqual(resp.indoor_temperature, temperature)

    def test_operational_mode(self) -> None:
        """Test parsing of mode from payloads."""
        TEST_PAYLOADS = {
            # https://github.com/mill1000/midea-msmart/pull/233#issuecomment-3268885233
            # Fan
            1: bytes.fromhex("01fe00000043005001728c7800eb00728c728c787800010141ff010203000601010008000300000001030103010000000000000000000001000100010000000000000000000000000001000200000100000101000102ff02"),
            # Cool
            2: bytes.fromhex("01fe00000043005001728c7800f100728c728c787800010141ff010203000602010008000300000001030103010000000000000000000001000100010000000000000000000000000001000200000100000101000102ff02"),
            # Heat
            3: bytes.fromhex("01fe00000043005001728c7800e700728c728c787800010141ff010203000603010008000100000001010103010000000000000000000001000100010000000000000000000000000001000200000100000101000102ff02"),
            # Dry
            6: bytes.fromhex("01fe00000043005001728c7800f000728c728c787800010141ff010203000606010008000300000001030103010000000000000000000001000100010000000000000000000000000001000200000100000101000102ff02"),

        }
        for value, payload in TEST_PAYLOADS.items():
            resp = self._test_payload(payload)

            # Assert that expected mode matches
            self.assertEqual(resp.operational_mode, value)

    def test_fan_speed(self) -> None:
        """Test parsing of fan speed from payloads."""
        TEST_PAYLOADS = {
            # https://github.com/mill1000/midea-msmart/pull/233#issuecomment-3268885233
            1: bytes.fromhex("01fe00000043005001728c7900e500728c728c797900010141ff010203000603010001000300000001030103010000000000000000000001000100010000000000000000000000000001000200000100000101000102ff02"),
            2: bytes.fromhex("01fe00000043005001728c7900da00728c728c797900010141ff010203000603010002000300000001030103010000000000000000000001000100010000000000000000000000000001000200000100000101000102ff02"),
            3: bytes.fromhex("01fe00000043005001728c7900d600728c728c797900010141ff010203000603010003000300000001030103010000000000000000000001000100010000000000000000000000000001000200000100000101000102ff02"),
            7: bytes.fromhex("01fe00000043005001728c7900d500728c728c797900010141ff010203000603010007000300000001030103010000000000000000000001000100010000000000000000000000000001000200000100000101000102ff02"),
            8: bytes.fromhex("01fe00000043005001728c7900d900728c728c797900010141ff010203000603010008000300000001030103010000000000000000000001000100010000000000000000000000000001000200000100000101000102ff02"),
        }
        for speed, payload in TEST_PAYLOADS.items():
            resp = self._test_payload(payload)

            # Assert that expected fan speed matches
            self.assertEqual(resp.fan_speed, speed)

    def test_swing_angle(self) -> None:
        """Test parsing of swing angle from payloads."""
        TEST_PAYLOADS = {
            # https://github.com/mill1000/midea-msmart/pull/233#issuecomment-3272351798
            # Vert
            (1, 3): bytes.fromhex("01fe00000043005001728c7800e700728c728c787800010141ff010203000603010008000100000001010103010000000000000000000001000100010000000000000000000000000001000200000100000101000102ff02"),
            (2, 3): bytes.fromhex("01fe00000043005001728c7800eb00728c728c787800010141ff010203000603010008000200000001020103010000000000000000000001000100010000000000000000000000000001000200000100000101000102ff02"),
            (5, 3): bytes.fromhex("01fe00000043005001728c7800ed00728c728c787800010141ff010203000603010008000500000001050103010000000000000000000001000100010000000000000000000000000001000200000100000101000102ff02"),
            # TODO Auto but it's 0?
            (0, 3): bytes.fromhex("01fe00000043005001728c7800ee00728c728c787800010141ff010203000603010008000000000001000103010000000000000000000001000100010000000000000000000000000001000200000100000101000102ff02"),
            # Horz
            (1, 1): bytes.fromhex("01fe00000043005001728c7800e100728c728c787800010141ff010203000603010008000100000001010101010000000000000000000001000100010000000000000000000000000001000200000100000101000102ff02"),
            (1, 2): bytes.fromhex("01fe00000043005001728c7800db00728c728c787800010141ff010203000603010008000100000001010102010000000000000000000001000100010000000000000000000000000001000200000100000101000102ff02"),
            (1, 5): bytes.fromhex("01fe00000043005001728c7800db00728c728c787800010141ff010203000603010008000100000001010105010000000000000000000001000100010000000000000000000000000001000200000100000101000102ff02"),
            (1, 6): bytes.fromhex("01fe00000043005001728c7800e100728c728c787800010141ff010203000603010008000100000001010106010000000000000000000001000100010000000000000000000000000001000200000100000101000102ff02"),
            # https://github.com/mill1000/midea-msmart/pull/233#issuecomment-3272675291
            # Both auto
            (6, 6): bytes.fromhex("01fe00000043005001728c7800ff00728c728c787800010141ff010203000603010008000600000001060106010000000000000000000001000100010000000000000000000000000001000200000100000101000102ff02"),
        }
        for angles, payload in TEST_PAYLOADS.items():
            resp = self._test_payload(payload)

            ud_angle, lr_angle = angles

            # Assert that expected angles match
            self.assertEqual(resp.vert_swing_angle, ud_angle)
            self.assertEqual(resp.horz_swing_angle, lr_angle)

    def test_misc_properties(self) -> None:
        """Test parsing of miscalenous properties from payloads."""
        TEST_PAYLOADS = [
            # https://github.com/mill1000/midea-msmart/pull/233#issuecomment-3272675291
            [{"sleep": True, "silent": False, "purifier": 2, "eco": False, "soft": False},
             bytes.fromhex("01fe00000043005001728c78010900728c728c787800010141ff010203000603010008000100000001010103010000000000000000000001000100010100000000000000000000000001000200000100000101000102ff02")],
            [{"sleep": False, "silent": True, "purifier": 2, "eco": False, "soft": False},
             bytes.fromhex("01fe00000043005001728c78010700728c728c787800010141ff010203000603010008000100000001010103010000000000000000000001000101010000000000000000000000000001000200000100000101000102ff02")],
            [{"sleep": False, "silent": False, "purifier": 1, "eco": False, "soft": False},
             bytes.fromhex("01fe00000043005001728c78010600728c728c787800010141ff010203000603010008000100000001010103010000000000000000000001000100010000000000000000000000000001000100000100000101000102ff02")],
            [{"sleep": False, "silent": False, "purifier": 2, "eco": True, "soft": False},
             bytes.fromhex("01fe00000043005001728c78010600728c728c787800010141ff010203000603010008000100000001010103010000000000000000000001010100010000000000000000000000000001000200000100000101000102ff02")],
            [{"sleep": False, "silent": False, "purifier": 2, "eco": False, "soft": True},
             bytes.fromhex("01fe00000043005001728c78010800728c728c787800010141ff010203000602010008000100000001010103010300000000000000000001000100010000000000000000000000000001000200000100000101000102ff02")],
        ]
        for data in TEST_PAYLOADS:
            props, payload = data
            resp = self._test_payload(payload)

            # Assert that expected properties match
            self.assertEqual(resp.sleep, props["sleep"])
            self.assertEqual(resp.silent, props["silent"])
            self.assertEqual(resp.purifier, props["purifier"])
            self.assertEqual(resp.eco, props["eco"])
            # self.assertEqual(resp.soft, props["soft"]) # TODO wind sense

    def test_aux_mode(self) -> None:
        """Test parsing of aux mode from payloads."""
        TEST_PAYLOADS = {
            # https://github.com/mill1000/midea-msmart/pull/233#issuecomment-3272675291
            # Forced on
            1: bytes.fromhex("01fe00000043005001728c78010600728c728c787800010141ff010203000603010008000100000001010103010000000000000000000001000100010000000000000000000000000001000200000100000101000102ff01"),
            # Auto
            0: bytes.fromhex("01fe00000043005001728c78010600728c728c787800010141ff010203000603010008000100000001010103010000000000000000000001000100010000000000000000000000000001000200000100000101000102ff00"),
            # Forced off
            2: bytes.fromhex("01fe00000043005001728c78010600728c728c787800010141ff010203000603010008000100000001010103010000000000000000000001010100010000000000000000000000000001000200000100000101000102ff02"),
        }
        for value, payload in TEST_PAYLOADS.items():
            resp = self._test_payload(payload)

            # Assert that expected aux mode matches
            self.assertEqual(resp.aux_mode, value)

    def test_capabilities(self) -> None:
        """Test parsing of capabilities from payloads."""
        # https://github.com/mill1000/midea-msmart/pull/233#issuecomment-3268885233
        TEST_PAYLOAD = bytes.fromhex(
            "01fe00000043005001728c7800eb00728c728c787800010141ff010203000601010008000300000001030103010000000000000000000001000100010000000000000000000000000001000200000100000101000102ff02")

        resp = self._test_payload(TEST_PAYLOAD)
        resp.parse_capabilities()

        self.assertEqual(resp.target_temperature_min, 17.0)
        self.assertEqual(resp.target_temperature_max, 30.0)

        self.assertEqual(resp.supports_humidity, True)

        # Check for supported modes
        self.assertIsNotNone(resp.supported_op_modes)
        assert resp.supported_op_modes
        self.assertIn(1, resp.supported_op_modes)
        self.assertIn(2, resp.supported_op_modes)
        self.assertIn(3, resp.supported_op_modes)
        self.assertIn(6, resp.supported_op_modes)

        self.assertEqual(resp.supports_fan_speed, True)

        self.assertEqual(resp.supports_vert_swing_angle, True)
        self.assertEqual(resp.supports_horz_swing_angle, True)

        self.assertEqual(resp.supports_wind_sense, True)

        self.assertEqual(resp.supports_co2_level, False)

        self.assertEqual(resp.supports_eco, True)
        self.assertEqual(resp.supports_silent, True)
        self.assertEqual(resp.supports_sleep, True)

        self.assertEqual(resp.supports_self_clean, False)

        self.assertEqual(resp.supports_purifier, True)
        self.assertEqual(resp.supports_purifier_auto, False)

        self.assertEqual(resp.supports_filter_level, True)

        # Check for supported aux modes
        self.assertIsNotNone(resp.supported_aux_modes)
        assert resp.supported_aux_modes

        self.assertIn(0, resp.supported_aux_modes)
        self.assertIn(1, resp.supported_aux_modes)
        self.assertIn(2, resp.supported_aux_modes)


class TestControlResponse(_TestResponseBase):
    """Test device control response messages."""

    def _test_response(self, msg) -> ControlResponse:
        resp = self._test_build_response(msg)
        return cast(ControlResponse, resp)

    def test_message(self) -> None:
        # https://github.com/mill1000/midea-msmart/pull/233#issuecomment-3530709294
        TEST_MESSAGE = bytes.fromhex(
            "aa16cc0000000000000200000101ff00120102ff000007")
        resp = self._test_response(TEST_MESSAGE)

        # Assert response is a control response
        self.assertEqual(type(resp), ControlResponse)

        # Suppress type errors
        resp = cast(ControlResponse, resp)

        # Check basic state
        self.assertEqual(len(resp._states), 2)
        self.assertEqual(resp.get_control_state(ControlId.MODE), 2)
        self.assertEqual(resp.get_control_state(ControlId.POWER), True)

    def _test_payload(self, payload: bytes) -> ControlResponse:
        """Create a response from a test payload."""
        # Create response
        with memoryview(payload) as mv_payload:
            resp = ControlResponse(mv_payload)

        # Assert that it exists
        self.assertIsNotNone(resp)

        # Assert response is a state response
        self.assertEqual(type(resp), ControlResponse)

        return resp

    def test_payload_too_short(self) -> None:
        """Test exceptions are raised when payload is too short."""
        TEST_PAYLOAD = bytes.fromhex("00000101")

        with self.assertRaises(InvalidResponseException):
            self._test_payload(TEST_PAYLOAD)

    def test_unknown_command_id(self) -> None:
        """Test we warn when decoding an unknown command ID."""
        # https://github.com/mill1000/midea-msmart/pull/233#issuecomment-3530709294
        # Modified 2nd ID
        TEST_PAYLOAD = bytes.fromhex(
            "00000101ffaa030180ff0000")

        with self.assertLogs("msmart", logging.WARNING) as log:
            resp = self._test_payload(TEST_PAYLOAD)

            # Check warning is generated for ID 0x001E
            self.assertRegex(log.output[0], "Unknown control ID 0xAA03")

    def test_zero_length_entry(self) -> None:
        """Test we ignore entries with a length of zero."""
        # Response to malformed request, 4 entries, 2 of zero length
        # https://github.com/mill1000/midea-msmart/pull/233#issuecomment-3332107433
        TEST_PAYLOAD = bytes.fromhex(
            "00000000ff00200100ff00000000ff00000100ff00000000")

        resp = self._test_payload(TEST_PAYLOAD)

        self.assertEqual(len(resp._states), 2)


class TestResponseConstruct(_TestResponseBase):
    """Test construction of responses from raw data."""

    def test_invalid_checksum(self) -> None:
        """Test that invalid checksums raise exceptions."""
        TEST_RESPONSE_BAD_CHECKSUM = bytes.fromhex(
            "aa1bcc0000000000000200000101ff003a0101ff00000000ff0000FF")

        with self.assertRaises(InvalidFrameException):
            Response.construct(TEST_RESPONSE_BAD_CHECKSUM)

    def test_short_packet(self) -> None:
        """Test that a short frame raise exceptions."""
        # https://github.com/mill1000/midea-msmart/issues/234#issuecomment-3299199631
        TEST_RESPONSE_SHORT_FRAME = bytes.fromhex("01000000")

        with self.assertRaises(InvalidFrameException):
            Response.construct(TEST_RESPONSE_SHORT_FRAME)

    def test_invalid_device_type(self) -> None:
        """Test that responses with an incorrect device type raise exceptions."""
        TEST_RESPONSE_TYPE_CC = bytes.fromhex(
            "aa18ac00000000000302b0020a0000013209001101000089a4")

        with self.assertRaises(InvalidFrameException):
            Response.construct(TEST_RESPONSE_TYPE_CC)


class TestCommandId(unittest.TestCase):
    def test_decode(self) -> None:
        """Test decoding of bytes objects to control values."""
        TEST_DECODES = {
            # Target temperature x / 2 - 40
            (ControlId.TARGET_TEMPERATURE, bytes([0x72])): 17.0,
            (ControlId.TARGET_TEMPERATURE, bytes([0x79])): 20.5,
            (ControlId.TARGET_TEMPERATURE, bytes([0x8c])): 30,

            # Everything else is passthru
            (ControlId.POWER, bytes([0x01])): 0x01,
            (ControlId.POWER, bytes([0x00])): 0x00,
            (ControlId.POWER, bytes([0x02])): 0x02,
        }

        for (prop, data), expected_value in TEST_DECODES.items():
            self.assertEqual(prop.decode(data), expected_value,
                             msg=f"""Decode {repr(prop)}, Data: {data}, Expected: {expected_value}""")

    def test_encode(self) -> None:
        """Test encoding of control values to bytes objects."""
        TEST_ENCODES = {
            # Target temperature 2x + 80
            (ControlId.TARGET_TEMPERATURE, 17.0): bytes([0x72]),
            (ControlId.TARGET_TEMPERATURE, 20.5): bytes([0x79]),
            (ControlId.TARGET_TEMPERATURE, 30): bytes([0x8c]),

            # Everything else is passthru
            (ControlId.AUX_MODE, 0x04): bytes([0x04]),
            (ControlId.AUX_MODE, 0x00): bytes([0x00]),
        }

        for (prop, value), expected_data in TEST_ENCODES.items():
            self.assertEqual(prop.encode(value), expected_data,
                             msg=f"""Encode {repr(prop)}, Value: {value}, Expected: {expected_data}""")


class TestControlCommand(unittest.TestCase):

    def test_payload(self) -> None:
        """Test that we encode control command payloads correctly."""
        # https://github.com/mill1000/midea-msmart/pull/233#issuecomment-3537179647
        PAYLOAD = bytes.fromhex("00000101ff00120102ff001c0104ff028b")
        CONTROLS = {ControlId.POWER: True,
                    ControlId.MODE: 2, ControlId.VERT_SWING_ANGLE: 4}

        # Build command
        command = ControlCommand(CONTROLS)

        # Fetch payload
        payload = command.tobytes()[10:-1]

        # Test against payload that device accepted
        self.assertEqual(payload, PAYLOAD)


if __name__ == "__main__":
    unittest.main()
