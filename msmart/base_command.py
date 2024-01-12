import logging

from msmart.const import DeviceType, FrameType

_LOGGER = logging.getLogger(__name__)


class Frame():
    CONTROL_SOURCE = 0x2  # App control

    _HEADER_LENGTH = 10

    def __init__(self, device_type: DeviceType, frame_type: FrameType) -> None:
        self._device_type = device_type
        self._frame_type = frame_type
        self._protocol_version = 0

    def tobytes(self, payload: bytes | bytearray = bytes()) -> bytes:
        # Build frame header
        header = bytearray(self._HEADER_LENGTH)

        # Start byte
        header[0] = 0xAA

        # Length of header, payload and checksum
        header[1] = len(payload) + self._HEADER_LENGTH + 1

        # Device/appliance type
        header[2] = self._device_type

        # Device protocol version
        header[8] = self._protocol_version

        # Frame type
        header[9] = self._frame_type

        # Build frame from header and payload
        frame = bytearray(header + payload)

        # Calculate total frame checksum
        frame.append(Frame.checksum(frame[1:]))

        return bytes(frame)

    @classmethod
    def checksum(cls, frame: bytes) -> int:
        return (~sum(frame) + 1) & 0xFF
