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
            Frame.validate(frame_mv)

        # Check frame payload to ensure it matches expected
        self.assertEqual(frame[10:-1], EXPECTED_PAYLOAD)

        # Check length byte
        self.assertEqual(frame[1], len(
            EXPECTED_PAYLOAD) + Frame._HEADER_LENGTH)

        # Check device type
        self.assertEqual(frame[2], DeviceType.COMMERCIAL_AC)

        # Check frame type
        self.assertEqual(frame[9], FrameType.QUERY)


class TestStateResponse(_TestResponseBase):
    """Test device state response messages."""

    # Attributes expected in state response objects
    EXPECTED_ATTRS = [
        "power_on",
        "target_temperature",
        "indoor_temperature",
        "operational_mode",
        "fan_speed",
        "swing_ud_angle",
        "swing_lr_angle",
        "soft",
        "eco",
        "silent",
        "sleep",
        "purifier",
        "aux_mode",
    ]

    def _test_response(self, msg) -> StateResponse:
        resp = self._test_build_response(msg)
        self._test_check_attributes(resp, self.EXPECTED_ATTRS)
        return cast(StateResponse, resp)

    def test_message(self) -> None:
        # https://github.com/mill1000/midea-msmart/pull/233#issuecomment-3268766672
        TEST_MESSAGE = bytes.fromhex(
            "aa63cc0000000000000301fe00000043005001728c79010100728c728c797900010141ff010203000603010000000300000001030103010000000000000000000001000100010000000000000000000000000001000200000100000101000102ff02ff6a")
        resp = self._test_response(TEST_MESSAGE)

        # Assert response is a state response
        self.assertEqual(type(resp), StateResponse)

        # Suppress type errors
        resp = cast(StateResponse, resp)

        # Check basic state
        self.assertEqual(resp.power_on, True)
        self.assertEqual(resp.target_temperature, 20.5)
        self.assertEqual(resp.indoor_temperature, 25.7)
        self.assertEqual(resp.operational_mode, 3)  # Heat
        self.assertEqual(resp.fan_speed, 0)
        self.assertEqual(resp.swing_ud_angle, 3)
        self.assertEqual(resp.swing_lr_angle, 3)

    def _test_payload(self, payload: bytes) -> StateResponse:
        """Create a response from a test payload."""
        # Create response
        with memoryview(payload) as mv_payload:
            resp = StateResponse(mv_payload)

        # Assert that it exists
        self.assertIsNotNone(resp)

        # Assert response is a state response
        self.assertEqual(type(resp), StateResponse)

        return resp

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
            self.assertEqual(resp.swing_ud_angle, ud_angle)
            self.assertEqual(resp.swing_lr_angle, lr_angle)

    def test_misc_properties(self) -> None:
        """Test parsing of miscalenous properties from payloads."""
        TEST_PAYLOADS = [
            # https://github.com/mill1000/midea-msmart/pull/233#issuecomment-3272675291
            [{"sleep": True, "silent": False, "purifier": False, "eco": False, "soft": False},
             bytes.fromhex("01fe00000043005001728c78010900728c728c787800010141ff010203000603010008000100000001010103010000000000000000000001000100010100000000000000000000000001000200000100000101000102ff02")],
            [{"sleep": False, "silent": True, "purifier": False, "eco": False, "soft": False},
             bytes.fromhex("01fe00000043005001728c78010700728c728c787800010141ff010203000603010008000100000001010103010000000000000000000001000101010000000000000000000000000001000200000100000101000102ff02")],
            [{"sleep": False, "silent": False, "purifier": True, "eco": False, "soft": False},
             bytes.fromhex("01fe00000043005001728c78010600728c728c787800010141ff010203000603010008000100000001010103010000000000000000000001000100010000000000000000000000000001000100000100000101000102ff02")],
            [{"sleep": False, "silent": False, "purifier": False, "eco": True, "soft": False},
             bytes.fromhex("01fe00000043005001728c78010600728c728c787800010141ff010203000603010008000100000001010103010000000000000000000001010100010000000000000000000000000001000200000100000101000102ff02")],
            [{"sleep": False, "silent": False, "purifier": False, "eco": False, "soft": True},
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
            self.assertEqual(resp.soft, props["soft"])

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


if __name__ == "__main__":
    unittest.main()
