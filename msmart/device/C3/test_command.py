import logging
import unittest
from typing import Union, cast

from .command import QueryBasicResponse, Response


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

if __name__ == "__main__":
    unittest.main()
