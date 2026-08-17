# msmart-ng
A Python library for controlling Midea (and associated brands) smart air conditioners over the local network or the Midea cloud. Designed for ease of integration, with async support and minimal dependencies.

[![Code Quality Checks](https://github.com/mill1000/midea-msmart/actions/workflows/checks.yml/badge.svg)](https://github.com/mill1000/midea-msmart/actions/workflows/checks.yml)
[![PyPI](https://img.shields.io/pypi/v/msmart-ng?logo=PYPI)](https://pypi.org/project/msmart-ng/)

## Supported Devices
This library supports air conditioners from Midea and several associated brands that use the following Android apps or their iOS equivalents:
* Artic King (com.arcticking.ac)
* Cooper & Hunter (com.ch.air)
* Midea Air (com.midea.aircondition.obm)
* NetHome Plus (com.midea.aircondition)
* SmartHome/MSmartHome (com.midea.ai.overseas)
* Toshiba AC NA (com.midea.toshiba)
* 美的美居 (com.midea.ai.appliances)
  
__Note: Only air conditioners (type 0xAC and 0xCC) are supported. See the [usage](#usage) section for how to check compatibility.__ 

## Note On Cloud Usage
By default this library (and its Home Assistant integration [midea-ac-py](https://github.com/mill1000/midea-ac-py)) controls devices locally. In that mode no internet connection is required once set up.

For newer "V3" devices, the Midea Cloud is used to acquire a token & key for device authentication. Once retrieved and saved, no further cloud connection is required for local control. Devices are not linked to the library’s built-in accounts and concerned users may supply their own account credentials if they prefer.

There is also an optional cloud control mode for AC devices. It sends commands through the Midea cloud so you can control a unit that is not reachable on your local network, for example one placed on an isolated guest or IoT network. This mode does use the internet for every command. See [Cloud control](#cloud-control-control-over-the-internet).

## Features
#### Async Support
The library fully supports async/await, allowing non-blocking communication with devices.

```python
from msmart.device import AirConditioner as AC

# Build device
device = AC(ip=DEVICE_IP, port=6444, device_id=int(DEVICE_ID))

# Get capabilities
await device.get_capabilities()

# Get current state
await device.refresh()
```

#### Device Discovery
Automatically discover devices on the local network or an individual device by IP or hostname.

```python
from msmart.discover import Discover

# Discover all devices on the network
devices = await Discover.discover()

# Discover a single device by IP
device = await Discover.discover_single(DEVICE_IP)
```

__Note: V3 devices are automatically authenticated via the NetHome Plus cloud.__

#### Reduced Dependencies
Many external dependencies have been replaced with standard Python modules.

#### Code Quality Improvements
- Type annotated for clarity.
- Code style and import sorting enforced by autopep8 and isort.
- Unit tests validated by Github Actions.
- Naming conventions follow PEP8.

## Installing
To install, use pip to install `msmart-ng`, and remove the old `msmart` package if necessary.

```shell
pip uninstall msmart
pip install msmart-ng
```

## Usage
### Command Line Interface (CLI)
Interact with devices using a simple command-line tool that supports device discovery, querying, and control.

```shell
$ msmart-ng --help
usage: msmart-ng [-h] [-v] {discover,query,control,download} ...
```

For more details on each subcommand and its available options, run `msmart-ng <command> --help`

#### Discover
Discover devices on the local network with the `msmart-ng discover` subcommand. 

```shell
$ msmart-ng discover
INFO:msmart.cli:Discovering all devices on local network.
...
INFO:msmart.cli:Found 1 devices.
INFO:msmart.cli:Found device:
{'ip': '10.100.1.140', 'port': 6444, 'id': 15393162840672, 'online': True, 'supported': True, 'type': <DeviceType.AIR_CONDITIONER: 172>, 'name': 'net_ac_F7B4', 'sn': '000000P0000000Q1F0C9D153F7B40000', 'key': None, 'token': None}
```

Ensure the device type is 0xAC and the `supported` property is True.

Save the device ID, IP address, and port. Version 3 devices will also require the `token` and `key` fields to control the device.

#### Warning: V3 Device Users
For V3 devices, it's highly recommended to save your token and key values in a secure place. In the event that the cloud become unavailable, having these on hand will allow you to continue controlling your device locally.

##### Note: V1 Device Owners
Owners of V1 devices might encounter the following error:

```
ERROR:msmart.discover:V1 device not supported yet.
```

Please report this error with the output of `msmart-ng discover --debug` to help improve support.

#### Query
Query device state and capabilities with the `msmart-ng query` subcommand.

```shell
$ msmart-ng query <HOST>
```

Add `--capabilities` to query capabilities of the device before requesting the state.

**Note:** Version 3 devices need to specify either the `--auto` argument or the `--token`, `--key` and `--id` arguments to make a connection.

**Note:** For CC devices, either the `--auto` argument or the `--device_type` argument must be specified.

#### Control
Control a device with the `msmart-ng control` subcommand. The command takes key-value pairs of settings to control.

Enumerated settings like `operational_mode`, `fan_speed`, and `swing_mode` can accept integer or string values. e.g. `operational_mode=cool`, `fan_speed=100` or `swing_mode=both`.

Number settings like `target_temperature` can accept floating point or integer values. e.g. `target_temperature=20.5`.

Boolean settings like `display_on` and `beep` can accept integer or string values. e.g. `display_on=True` or `beep=0`.

```shell
$ msmart-ng control <HOST> operational_mode=cool target_temperature=20.5 fan_speed=100 display_on=True beep=0
```

**Note:** Version 3 devices need to specify either the `--auto` argument or the `--token`, `--key` and `--id` arguments to make a connection.

**Note:** For CC devices, either the `--auto` argument or the `--device_type` argument must be specified.

#### Cloud control (control over the internet)
Add `--cloud` to `query` or `control` to reach the device through the Midea cloud instead of the local network. This works from anywhere with internet access, so you do not need to be on the same network as the unit.

The main reason to use this is network isolation. You can put the air conditioner on a guest or IoT WiFi network, away from your computers and phones, and still control it. The unit does not need to be reachable from your LAN at all.

With `--cloud`, the host argument is the numeric appliance id (not an IP). Get the id from `msmart-ng discover` (the `id` field) while the device is still reachable locally, or from your Midea account. You also need `--account` and `--password`.

```shell
$ msmart-ng query 151732606158606 --cloud --account you@example.com --password secret
$ msmart-ng control 151732606158606 --cloud --account you@example.com --password secret operational_mode=cool target_temperature=24
```

Notes:
* Cloud control is currently supported for AC (0xAC) devices.
* Cloud set commands take a few seconds to reach the unit.
* Logging in for cloud access uses one session per account. If you run cloud commands while the phone app is open, one of them may get signed out. Use the config file below so you are not passing credentials on every command.

#### Config file
To avoid repeating `--account`, `--password`, and other options on every command, put them in a config file. Keys match the flag names.

msmart-ng looks for a config file in this order:
1. the path in the `MSMART_CONFIG` environment variable
2. `.msmart-ng.env` in the current directory
3. `~/.config/msmart-ng/config`

Example config file:

```ini
account = you@example.com
password = secret
host = 151732606158606
cloud = true
```

With that file in place you can just run:

```shell
$ msmart-ng query
$ msmart-ng control operational_mode=cool target_temperature=24
```

Command line flags always override the config file. Supported keys are `account`, `password`, `region`, `host`, `cloud`, `app_id`, and `app_key`.

### Home Assistant
To control your Midea AC units via Home Assistant, use this [midea-ac-py](https://github.com/mill1000/midea-ac-py) fork.

### Python
To control devices programmatically, see the included Python [example](example.py).

## Docker
A docker image is available on ghcr.io at `ghcr.io/mill1000/msmart-ng`. Ensure the container is run with `--network=host` to allow device discovery on the local network via broadcast.

```shell
$ docker run --network=host ghcr.io/mill1000/msmart-ng:latest --help
usage: msmart-ng [-h] [-v] {discover,query,control,download} ...
```

## Troubleshooting
* If devices are not being discovered, ensure your devices are on the same subnet as your computer.
* If a cloud connection can not be made, try using a credentials from a different region with the `--region` argument or manually specifying a NetHome Plus account.

## Gratitude
This project is a fork of [mac-zhou/midea-msmart](https://github.com/mac-zhou/midea-msmart), and builds upon the work of
* [dudanov/MideaUART](https://github.com/dudanov/MideaUART)
* [NeoAcheron/midea-ac-py](https://github.com/NeoAcheron/midea-ac-py)
* [andersonshatch/midea-ac-py](https://github.com/andersonshatch/midea-ac-py)
* [yitsushi/midea-air-condition](https://github.com/yitsushi/midea-air-condition)



