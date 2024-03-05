"""Utility classes and methods for Midea AC."""
from __future__ import annotations

import logging
from enum import IntEnum
from typing import List, Optional, cast

_LOGGER = logging.getLogger(__name__)


class MideaIntEnum(IntEnum):
    """Helper class to convert IntEnums to/from strings."""

    @classmethod
    def list(cls) -> List[MideaIntEnum]:
        return list(cls)

    @classmethod
    def get_from_value(cls, value: Optional[int], default: Optional[MideaIntEnum] = None) -> MideaIntEnum:
        try:
            return cls(cast(int, value))
        except ValueError:
            _LOGGER.debug("Unknown %s: %s", cls, value)
            if default is None:
                default = cls.DEFAULT  # pyright: ignore[reportAttributeAccessIssue] # nopep8
            return cls(default)

    @classmethod
    def get_from_name(cls, name: Optional[str], default: Optional[MideaIntEnum] = None) -> MideaIntEnum:
        try:
            return cls[cast(str, name)]
        except KeyError:
            _LOGGER.debug("Unknown %s: %s", cls, name)
            if default is None:
                default = cls.DEFAULT  # pyright: ignore[reportAttributeAccessIssue] # nopep8
            return cls(default)
