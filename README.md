# msmart-ng
A Python library for local control of Midea (and associated brands) smart air conditioners. Designed for ease of integration, with async support and minimal dependencies.

[![Code Quality Checks](https://github.com/mill1000/midea-msmart/actions/workflows/checks.yml/badge.svg)](https://github.com/mill1000/midea-msmart/actions/workflows/checks.yml)
[![PyPI](https://img.shields.io/pypi/v/msmart-ng?logo=PYPI)](https://pypi.org/project/msmart-ng/)

## Supported Devices
This library supports air conditioners from Midea and several associated brands that use the following Android apps or their iOS equivalents:
* Artic King (com.arcticking.ac)
* Midea Air (com.midea.aircondition.obm)
* NetHome Plus (com.midea.aircondition)
* SmartHome/MSmartHome (com.midea.ai.overseas)
* Toshiba AC NA (com.midea.toshiba)
* 美的美居 (com.midea.ai.appliances)
  
__Note: Only air conditioners (type 0xAC) are supported. See the [usage](#usage) section for how to check compatibility.__ 

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

Add `--capabilities` to list available capabilities of the device.

**Note:** Version 3 devices need to specify either the `--auto` argument or the `--token`, `--key` and `--id` arguments to make a connection.

#### Control
Control a device with the `msmart-ng control` subcommand. The command takes key-value pairs of settings to control.

Enumerated settings like `operational_mode`, `fan_speed`, and `swing_mode` can accept integer or string values. e.g. `operational_mode=cool`, `fan_speed=100` or `swing_mode=both`.

Number settings like `target_temperature` can accept floating point or integer values. e.g. `target_temperature=20.5`.

Boolean settings like `display_on` and `beep` can accept integer or string values. e.g. `display_on=True` or `beep=0`.

```shell
$ msmart-ng control <HOST> operational_mode=cool target_temperature=20.5 fan_speed=100 display_on=True beep=0
```

**Note:** Version 3 devices need to specify either the `--auto` argument or the `--token`, `--key` and `--id` arguments to make a connection.

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
