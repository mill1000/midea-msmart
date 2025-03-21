import unittest
from typing import Optional, cast

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
        client = await super()._login(NetHomePlusCloud, *args, **kwargs)
        return cast(NetHomePlusCloud, client)

    async def test_login(self) -> None:
        """Test that we can login to the cloud."""

        client = await self._login()

        self.assertIsNotNone(client._session)
        self.assertIsNotNone(client._session_id)

    async def test_login_exception(self) -> None:
        """Test that bad credentials raise an exception."""

        with self.assertRaises(ApiError):
            await self._login(account="bad@account.com", password="not_a_password")

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
        token, key = await client.get_token(DUMMY_UDPID)

        self.assertIsNotNone(token)
        self.assertIsNotNone(key)

    async def test_get_token_exception(self) -> None:
        """Test that an exception is thrown when a token and key 
        can't be obtained from the cloud."""

        BAD_UDPID = "NOT_A_UDPID"

        client = await self._login()

        with self.assertRaises(CloudError):
            await client.get_token(BAD_UDPID)

    async def test_connect_exception(self) -> None:
        """Test that an exception is thrown when the cloud connection fails."""

        client = NetHomePlusCloud(DEFAULT_CLOUD_REGION)

        # Override URL to an invalid domain
        client._base_url = "https://fake_server.invalid."

        with self.assertRaises(CloudError):
            await client.login()


class TestSmartHomeCloud(TestCloud):
    # pylint: disable=protected-access

    async def _login(self, *args, **kwargs) -> SmartHomeCloud:
        client = await super()._login(SmartHomeCloud, *args, **kwargs)
        return cast(SmartHomeCloud, client)

    async def test_login(self) -> None:
        """Test that we can login to the cloud."""

        client = await self._login()

        self.assertIsNotNone(client._session)
        self.assertIsNotNone(client._access_token)

    async def test_login_exception(self) -> None:
        """Test that bad credentials raise an exception."""

        with self.assertRaises(ApiError):
            await self._login(account="bad@account.com", password="not_a_password")

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
        # Get token tests disabled until we can solve the broken API
        # DUMMY_UDPID = "4fbe0d4139de99dd88a0285e14657045"

        # client = await self._login()
        # token, key = await client.get_token(DUMMY_UDPID)

        # self.assertIsNotNone(token)
        # self.assertIsNotNone(key)

    async def test_get_token_exception(self) -> None:
        """Test that an exception is thrown when a token and key
        can't be obtained from the cloud."""
        # Get token tests disabled until we can solve the broken API
        # BAD_UDPID = "NOT_A_UDPID"

        # client = await self._login()

        # with self.assertRaises(CloudError):
        #     await client.get_token(BAD_UDPID)

    async def test_connect_exception(self) -> None:
        """Test that an exception is thrown when the cloud connection fails."""

        client = SmartHomeCloud(DEFAULT_CLOUD_REGION)

        # Override URL to an invalid domain
        client._base_url = "https://fake_server.invalid."

        with self.assertRaises(CloudError):
            await client.login()


if __name__ == "__main__":
    unittest.main()
