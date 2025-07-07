import unittest
from typing import Optional, cast
from unittest.mock import MagicMock, patch

from httpx import AsyncClient

from msmart.cloud import (ApiError, BaseCloud, CloudError, NetHomePlusCloud,
                          SmartHomeCloud)
from msmart.const import DEFAULT_CLOUD_REGION


class TestCloud(unittest.IsolatedAsyncioTestCase):
    # pylint: disable=protected-access

    async def _login(self,
                     class_name,
                     *,
                     region: str = DEFAULT_CLOUD_REGION,
                     account: Optional[str] = None,
                     password: Optional[str] = None
                     ) -> BaseCloud:
        client = class_name(region, account=account, password=password)
        await client.login()
        return client


class TestNetHomePlusCloud(TestCloud):
    # pylint: disable=protected-access

    async def _login(self, *args, **kwargs) -> NetHomePlusCloud:
        """Construct a cloud instance and pretend to login to it."""

        with patch.object(NetHomePlusCloud, "login", autospec=True) as mock_login:
            client = await super()._login(NetHomePlusCloud, *args, **kwargs)
            mock_login.assert_awaited_once()

        return cast(NetHomePlusCloud, client)

    async def test_login_api_requests(self) -> None:
        """Test that login() makes the expected API calls to the cloud."""

        # Mocked API request function that returns dummy responses
        def mock_api_request_side_effect(self, endpoint, body):
            if endpoint == "/v1/user/login/id/get":
                return {"loginId": "dummy_login_id"}

            if endpoint == "/v1/user/login":
                return {"sessionId": "dummy_session_id"}

            self.fail("Unexpected API endpoint.")

        with patch.object(NetHomePlusCloud, "_api_request", autospec=True, side_effect=mock_api_request_side_effect) as mock_api_request:
            client = NetHomePlusCloud()
            await client.login()

            # Assert 2 API calls occurred
            self.assertEqual(mock_api_request.await_count, 2)

            # Validate arguments of each API call
            get_login_id_call, login_call = mock_api_request.await_args_list

            # Validate _get_login_id API request args
            _inst, endpoint, body = get_login_id_call.args
            self.assertEqual(endpoint, "/v1/user/login/id/get")

            self.assertIn("loginAccount", body)
            self.assertEqual(
                body["loginAccount"], NetHomePlusCloud.CLOUD_CREDENTIALS[DEFAULT_CLOUD_REGION][0])

            # Validate login API request args
            _inst, endpoint, body = login_call.args
            self.assertEqual(endpoint, "/v1/user/login")

            self.assertIn("loginAccount", body)
            self.assertEqual(
                body["loginAccount"], NetHomePlusCloud.CLOUD_CREDENTIALS[DEFAULT_CLOUD_REGION][0])
            self.assertIn("password", body)

        self.assertIsNotNone(client._session)
        self.assertIsNotNone(client._session_id)

    async def test_login_exception(self) -> None:
        """Test that bad credentials raise an exception."""

        with patch.object(NetHomePlusCloud, "login", autospec=True, side_effect=ApiError("")) as mock_login:
            with self.assertRaises(ApiError):
                client = NetHomePlusCloud(
                    DEFAULT_CLOUD_REGION, account="bad@account.com", password="not_a_password")
                await client.login()

                mock_login.assert_awaited_once()

    async def test_invalid_region(self) -> None:
        """Test that an invalid region raise an exception."""

        with self.assertRaises(ValueError):
            await self._login(region="NOT_A_REGION")

    async def test_invalid_credentials(self) -> None:
        """Test that invalid credentials raise an exception."""

        # Check that specifying only an account or password raises an error
        with self.assertRaises(ValueError):
            await self._login(account=None, password="some_password")

        with self.assertRaises(ValueError):
            await self._login(account="some_account", password=None)

    async def test_get_token(self) -> None:
        """Test that a token and key can be obtained from the cloud."""

        DUMMY_UDPID = "4fbe0d4139de99dd88a0285e14657045"

        client = await self._login()

        # Mocked API request function that returns dummy responses
        def mock_api_request_side_effect(inst, endpoint, body):
            if endpoint == "/v1/iot/secure/getToken":
                return {"tokenlist": [{"udpId": DUMMY_UDPID, "token": "dummy_token", "key": "dummy_key"}]}

            self.fail("Unexpected API endpoint.")

        with patch.object(NetHomePlusCloud, "_api_request", autospec=True, side_effect=mock_api_request_side_effect) as mock_api_request:
            token, key = await client.get_token(DUMMY_UDPID)

            # Assert 1 API calls occurred
            self.assertEqual(mock_api_request.await_count, 1)

            # Validate arguments of each API call
            get_token_call = mock_api_request.await_args_list[0]

            # Validate API request args
            _inst, endpoint, body = get_token_call.args
            self.assertEqual(endpoint, "/v1/iot/secure/getToken")

            self.assertIn("udpid", body)
            self.assertEqual(body["udpid"], DUMMY_UDPID)

        self.assertIsNotNone(token)
        self.assertIsNotNone(key)

    async def test_get_token_exception(self) -> None:
        """Test that an exception is thrown when a token and key
        can't be obtained from the cloud."""

        BAD_UDPID = "NOT_A_UDPID"

        client = await self._login()

        with patch.object(AsyncClient, "post") as mock_post:
            mock_response = MagicMock(autospec=True)
            mock_response.status_code = 404
            mock_response.text = '{"errorCode": "3004", "msg": "value is illegal"}'

            mock_post.return_value = mock_response
            with self.assertRaises(CloudError):
                await client.get_token(BAD_UDPID)

                mock_post.assert_awaited_once()

    async def test_connect_exception(self) -> None:
        """Test that an exception is thrown when the cloud connection fails."""

        client = NetHomePlusCloud(DEFAULT_CLOUD_REGION)

        # Override URL to an invalid domain
        client._base_url = "https://fake_server.invalid."

        with self.assertRaises(CloudError):
            await client.login()


# class TestSmartHomeCloud(TestCloud):
#     # pylint: disable=protected-access

#     async def _login(self, *args, **kwargs) -> SmartHomeCloud:
#         client = await super()._login(SmartHomeCloud, *args, **kwargs)
#         return cast(SmartHomeCloud, client)

#     async def test_login(self) -> None:
#         """Test that we can login to the cloud."""

#         client = await self._login()

#         self.assertIsNotNone(client._session)
#         self.assertIsNotNone(client._access_token)

#     async def test_login_exception(self) -> None:
#         """Test that bad credentials raise an exception."""

#         with self.assertRaises(ApiError):
#             await self._login(account="bad@account.com", password="not_a_password")

#     async def test_invalid_region(self) -> None:
#         """Test that an invalid region raise an exception."""

#         with self.assertRaises(ValueError):
#             await self._login(region="NOT_A_REGION")

#     async def test_invalid_credentials(self) -> None:
#         """Test that invalid credentials raise an exception."""

#         # Check that specifying only an account or password raises an error
#         with self.assertRaises(ValueError):
#             await self._login(account=None, password="some_password")

#         with self.assertRaises(ValueError):
#             await self._login(account="some_account", password=None)

#     async def test_get_token(self) -> None:
#         """Test that a token and key can be obtained from the cloud."""
#         # Get token tests disabled until we can solve the broken API
#         # DUMMY_UDPID = "4fbe0d4139de99dd88a0285e14657045"

#         # client = await self._login()
#         # token, key = await client.get_token(DUMMY_UDPID)

#         # self.assertIsNotNone(token)
#         # self.assertIsNotNone(key)

#     async def test_get_token_exception(self) -> None:
#         """Test that an exception is thrown when a token and key
#         can't be obtained from the cloud."""
#         # Get token tests disabled until we can solve the broken API
#         # BAD_UDPID = "NOT_A_UDPID"

#         # client = await self._login()

#         # with self.assertRaises(CloudError):
#         #     await client.get_token(BAD_UDPID)

#     async def test_connect_exception(self) -> None:
#         """Test that an exception is thrown when the cloud connection fails."""

#         client = SmartHomeCloud(DEFAULT_CLOUD_REGION)

#         # Override URL to an invalid domain
#         client._base_url = "https://fake_server.invalid."

#         with self.assertRaises(CloudError):
#             await client.login()


if __name__ == "__main__":
    unittest.main()
