import unittest
from .command import response

TEST_MESSAGE_CHECKSUM_AS_CRC = bytes.fromhex("aa1eac00000000000003c0004b1e7f7f000000000069630000000000000d33")
TEST_MESSAGE_V2 = bytes.fromhex("aa22ac00000000000303c0014566000000300010045eff00000000000000000069fdb9")
TEST_MESSAGE_V3 = bytes.fromhex("aa23ac00000000000303c00145660000003c0010045c6b20000000000000000000020d79")

class TestResponse(unittest.TestCase):

    def test_checksum_as_crc(self):
        resp = response.construct(TEST_MESSAGE_CHECKSUM_AS_CRC)
        self.assertIsNotNone(resp)

    def test_v2_response(self):
        resp = response.construct(TEST_MESSAGE_V2)
        self.assertIsNotNone(resp)

    def test_v3_response(self):
        resp = response.construct(TEST_MESSAGE_V3)
        self.assertIsNotNone(resp)

if __name__ == '__main__':
    unittest.main()