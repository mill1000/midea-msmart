import argparse
import ast
import asyncio
import logging
from typing import NoReturn

from msmart import __version__
from msmart.cloud import Cloud, CloudError
from msmart.const import OPEN_MIDEA_APP_ACCOUNT, OPEN_MIDEA_APP_PASSWORD
from msmart.device import AirConditioner as AC
from msmart.discover import Discover
from msmart.lan import AuthenticationError
from msmart.utils import MideaIntEnum

_LOGGER = logging.getLogger(__name__)


async def _discover(args) -> None:
    """Discover Midea devices and print configuration information."""

    devices = []
    if args.host is None:
        _LOGGER.info("Discovering all devices on local network.")
        devices = await Discover.discover(account=args.account, password=args.password, discovery_packets=args.count)
    else:
        _LOGGER.info("Discovering %s on local network.", args.host)
        dev = await Discover.discover_single(args.host, account=args.account, password=args.password, discovery_packets=args.count)
        if dev:
            devices.append(dev)

    if len(devices) == 0:
        _LOGGER.error("No devices found.")
        return

    # Dump only basic device info from the base class
    _LOGGER.info("Found %d devices.", len(devices))
    for device in devices:

        if isinstance(device, AC):
            device = super(AC, device)

        _LOGGER.info("Found device:\n%s", device.to_dict())


async def _connect(args) -> AC:
    """Connect to a device directly or via discovery."""

    if args.auto and (args.token or args.key or args.device_id):
        _LOGGER.warning(
            "--token, --key and --id are ignored with --auto option.")

    if args.auto:
        # Use discovery to automatically connect and authenticate with device
        _LOGGER.info("Discovering %s on local network.", args.host)
        device = await Discover.discover_single(args.host, account=args.account, password=args.password)

        if device is None:
            _LOGGER.error("Device not found.")
            exit(1)
    else:
        # Manually create device and authenticate
        device = AC(ip=args.host, port=6444, device_id=args.device_id)
        if args.token and args.key:
            try:
                await device.authenticate(args.token, args.key)
            except AuthenticationError as e:
                _LOGGER.error("Authentication failed. Error: %s", e)
                exit(1)

    if not isinstance(device, AC):
        _LOGGER.error("Device is not supported.")
        exit(1)

    return device


async def _query(args) -> None:
    """Query device state or capabilities."""

    # Connect to the device
    device = await _connect(args)

    if args.capabilities:
        _LOGGER.info("Querying device capabilities.")
        await device.get_capabilities()

        if not device.online:
            _LOGGER.error("Device is not online.")
            exit(1)

        # TODO method to get caps in string format
        _LOGGER.info("%s", str({
            "supported_modes": device.supported_operation_modes,
            "supported_swing_modes": device.supported_swing_modes,
            "supported_fan_speeds": device.supported_fan_speeds,
            "supports_custom_fan_speed": device.supports_custom_fan_speed,
            "supports_eco_mode": device.supports_eco_mode,
            "supports_turbo_mode": device.supports_turbo_mode,
            "supports_freeze_protection_mode": device.supports_freeze_protection_mode,
            "supports_display_control": device.supports_display_control,
            "supports_filter_reminder": device.supports_filter_reminder,
            "max_target_temperature": device.max_target_temperature,
            "min_target_temperature": device.min_target_temperature,
        }))
    else:
        _LOGGER.info("Querying device state.")
        await device.refresh()

        if not device.online:
            _LOGGER.error("Device is not online.")
            exit(1)

        _LOGGER.info("%s", device)


async def _control(args) -> None:
    """Control device state."""

    KEY_DISPLAY_ON = "display_on"

    # Local function to attempt to parse and covert the value to the supplied type
    def convert(v, t):
        try:
            return t(ast.literal_eval(v))
        except (ValueError, SyntaxError):
            _LOGGER.error("Value '%s' is not a valid %s",
                          v, t.__qualname__)
            exit(1)

    # Parse each setting, checking if the property exists and the supplied value is valid
    new_properties = {}
    for name, value in (s.split("=") for s in args.settings):
        # Check if property exists
        prop = getattr(AC, name, None)
        if prop is None or not isinstance(prop, property):
            _LOGGER.error("'%s' is not a valid device property.", name)
            exit(1)

        # Check if property has a setter, with special handling for the display
        if name != KEY_DISPLAY_ON and prop.fset is None:
            _LOGGER.error("'%s' property is not writable.", name)
            exit(1)

        # Get the default value of the property and its type
        attr_value = getattr(AC("0.0.0.0", 0, 0), name)
        attr_type = type(attr_value)

        if isinstance(attr_value, MideaIntEnum):
            # Attempt to parse input as a number
            try:
                value = ast.literal_eval(value)
            except ValueError:
                pass

            if isinstance(value, (int, float)):
                # Try to convert number to enum
                try:
                    new_properties[name] = attr_type(value)
                except ValueError:
                    # Allow raw integers for AC.FanSpeed
                    if attr_type == AC.FanSpeed:
                        new_properties[name] = int(value)
                    else:
                        _LOGGER.error("Value '%d' is not a valid %s",
                                      value, attr_type.__qualname__)
                        exit(1)
            else:
                # Try to convert string to enum
                try:
                    new_properties[name] = attr_type[value.upper()]
                except KeyError:
                    _LOGGER.error("Value '%s' is not a valid %s",
                                  value, attr_type.__qualname__)
                    exit(1)
        elif isinstance(attr_value, bool):
            new_properties[name] = convert(value.capitalize(), bool)
        else:
            new_properties[name] = convert(value, attr_type)

    # Connect to the device
    device = await _connect(args)

    # Get current state
    _LOGGER.info("Querying device state.")
    await device.refresh()

    if not device.online:
        _LOGGER.error("Device is not online.")
        exit(1)

    if args.capabilities:
        _LOGGER.info("Querying device capabilities.")
        await device.get_capabilities()

    # Handle display which is unique
    if (display := new_properties.pop(KEY_DISPLAY_ON, None)) is not None:
        if display != device.display_on:
            _LOGGER.info("Setting '%s' to %s.", KEY_DISPLAY_ON, display)
            await device.toggle_display()

    # Don't apply if there's not new settings
    if not new_properties:
        return

    # Set remaining properties
    for prop, value in new_properties.items():
        _LOGGER.info("Setting '%s' to %s.", prop, repr(value))
        setattr(device, prop, value)

    # Apply to device
    await device.apply()


async def _download(args) -> None:
    """Download a device's protocol implementation from the cloud."""

    # Use discovery to to find device information
    _LOGGER.info("Discovering %s on local network.", args.host)
    device = await Discover.discover_single(args.host, account=args.account, password=args.password, auto_connect=False)

    if device is None:
        _LOGGER.error("Device not found.")
        exit(1)

    if isinstance(device, AC):
        device = super(AC, device)

    _LOGGER.info("Found device:\n%s", device.to_dict())

    if device.sn is None:
        _LOGGER.error("A device SN is required to download the protocol.")
        exit(1)

    # Get cloud connection
    cloud = Cloud(args.account, args.password)
    try:
        await cloud.login()
    except CloudError as e:
        _LOGGER.error("Failed to establish cloud connection. Error: %s", e)
        exit(1)

    _LOGGER.info("Downloading protocol from cloud.")
    lua_name, lua_file = await cloud.get_protocol_lua(device.type, device.sn)

    _LOGGER.info("Writing protocol to '%s'.", lua_name)
    with open(lua_name, "w") as f:
        f.write(lua_file)

    _LOGGER.info("Downloading plugin from cloud.")
    plugin_name, plugin_file = await cloud.get_plugin(device.type, device.sn)

    _LOGGER.info("Writing plugin to '%s'.", plugin_name)
    with open(plugin_name, "wb") as f:
        f.write(plugin_file)


def _run(args) -> NoReturn:
    """Helper method to setup logging, validate args and execute the desired function."""

    # Configure logging
    if args.debug:
        logging.basicConfig(level=logging.DEBUG)
        # Keep httpx as info level
        logging.getLogger("httpx").setLevel(logging.INFO)
        logging.getLogger("httpcore").setLevel(logging.INFO)
    else:
        logging.basicConfig(level=logging.INFO)
        # Set httpx to warning level
        logging.getLogger("httpx").setLevel(logging.WARNING)
        logging.getLogger("httpcore").setLevel(logging.WARNING)

    # Validate common arguments
    if args.china and (args.account == OPEN_MIDEA_APP_ACCOUNT or args.password == OPEN_MIDEA_APP_PASSWORD):
        _LOGGER.error(
            "Account (phone number) and password of 美的美居 is required to use --china option.")
        exit(1)

    try:
        asyncio.run(args.func(args))
    except KeyboardInterrupt:
        pass

    exit(0)


def main() -> NoReturn:
    """Main entry point for msmart-ng command."""

    # Define the main parser to select subcommands
    parser = argparse.ArgumentParser(
        description="Command line utility for msmart-ng."
    )
    parser.add_argument("-v", "--version",
                        action="version", version=f"msmart version: {__version__}")
    subparsers = parser.add_subparsers(title="Command", dest="command",
                                       required=True)

    # Define some common arguments
    common_parser = argparse.ArgumentParser(add_help=False)
    common_parser.add_argument("-d", "--debug",
                               help="Enable debug logging.", action="store_true")
    common_parser.add_argument("--account",
                               help="MSmartHome or 美的美居 username for discovery and automatic authentication",
                               default=OPEN_MIDEA_APP_ACCOUNT)
    common_parser.add_argument("--password",
                               help="MSmartHome or 美的美居 password for discovery and automatic authentication.",
                               default=OPEN_MIDEA_APP_PASSWORD)
    common_parser.add_argument("--china",
                               help="Use China server for discovery and automatic authentication.",
                               action="store_true")

    # Setup discover parser
    discover_parser = subparsers.add_parser("discover",
                                            description="Discover device(s) on the local network.",
                                            parents=[common_parser])
    discover_parser.add_argument("host",
                                 help="Hostname or IP address of a single device to discover.",
                                 nargs="?", default=None)
    discover_parser.add_argument("--count",
                                 help="Number of broadcast packets to send.",
                                 default=3, type=int)
    discover_parser.set_defaults(func=_discover)

    # Setup query parser
    query_parser = subparsers.add_parser("query",
                                         description="Query information from a device on the local network.",
                                         parents=[common_parser])
    query_parser.add_argument("host",
                              help="Hostname or IP address of device.")
    query_parser.add_argument("--capabilities",
                              help="Query device capabilities instead of state.",
                              action="store_true")
    query_parser.add_argument("--auto",
                              help="Automatically authenticate V3 devices.",
                              action="store_true")
    query_parser.add_argument("--id",
                              help="Device ID for V3 devices.",
                              dest="device_id", type=int, default=0)
    query_parser.add_argument("--token",
                              help="Authentication token for V3 devices.",
                              type=bytes.fromhex)
    query_parser.add_argument("--key",
                              help="Authentication key for V3 devices.",
                              type=bytes.fromhex)
    query_parser.set_defaults(func=_query)

    # Setup control parser
    control_parser = subparsers.add_parser("control",
                                           description="Control a device on the local network.",
                                           parents=[common_parser])
    control_parser.add_argument("host",
                                help="Hostname or IP address of device.")
    control_parser.add_argument("--capabilities",
                                help="Query device capabilities before sending commands.",
                                action="store_true")
    control_parser.add_argument("--auto",
                                help="Automatically authenticate V3 devices.",
                                action="store_true")
    control_parser.add_argument("--id",
                                help="Device ID for V3 devices.",
                                dest="device_id", type=int, default=0)
    control_parser.add_argument("--token",
                                help="Authentication token for V3 devices.",
                                type=bytes.fromhex)
    control_parser.add_argument("--key",
                                help="Authentication key for V3 devices.",
                                type=bytes.fromhex)
    control_parser.add_argument("settings",
                                nargs="+",
                                metavar="setting=value",
                                help="Space separated key-value pairs of settings to control.")
    control_parser.set_defaults(func=_control)

    # Setup download parser
    download = subparsers.add_parser("download",
                                     description="Download a device's plugin and protocol implementation from the cloud.",
                                     parents=[common_parser])
    download.add_argument("host",
                          help="Hostname or IP address of device.")
    download.set_defaults(func=_download)

    # Run with args
    _run(parser.parse_args())


def _legacy_main() -> NoReturn:
    """Main entry point for legacy midea-discover command."""

    async def _wrap_discover(args) -> None:
        """Wrapper method to mimic legacy behavior."""
        # Map old args to new names as needed
        args.host = args.ip

        # Output legacy information
        _LOGGER.info("msmart version: %s", __version__)
        _LOGGER.info(
            "Only supports AC devices. Only supports MSmartHome and 美的美居.")

        await _discover(args)

    parser = argparse.ArgumentParser(
        description="Discover Midea devices and print device information.",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter)
    parser.add_argument(
        "-d", "--debug", help="Enable debug logging.", action="store_true")
    parser.add_argument(
        "-a", "--account", help="MSmartHome or 美的美居 account username.", default=OPEN_MIDEA_APP_ACCOUNT)
    parser.add_argument(
        "-p", "--password", help="MSmartHome or 美的美居 account password.", default=OPEN_MIDEA_APP_PASSWORD)
    parser.add_argument(
        "-i", "--ip", help="IP address of a device. Useful if broadcasts don't work, or to query a single device.")
    parser.add_argument(
        "-c", "--count", help="Number of broadcast packets to send.", default=3, type=int)
    parser.add_argument("--china", help="Use China server.",
                        action="store_true")
    parser.set_defaults(func=_wrap_discover)

    # Run with args
    _run(parser.parse_args())


if __name__ == "__main__":
    main()
