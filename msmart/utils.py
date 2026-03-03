"""Utility classes and methods for Midea AC."""
from __future__ import annotations

import functools
import logging
from enum import Flag, IntEnum
from typing import Any, Callable, Generic, Optional, TypeVar, cast

_LOGGER = logging.getLogger(__name__)


CapabilityFlag = TypeVar("CapabilityFlag", bound=Flag)


class CapabilityManager(Generic[CapabilityFlag]):
    """Minimal wrapper class to make mutable capability flags."""

    def __init__(self, default: CapabilityFlag) -> None:
        self._flags: CapabilityFlag = default

    @property
    def value(self) -> int:
        return self._flags.value

    @property
    def flags(self) -> list[CapabilityFlag]:
        return list(self._flags)

    def has(self, flag: CapabilityFlag) -> bool:
        return bool(self._flags & flag)

    def set(self, flag: CapabilityFlag, enable: bool = True) -> None:
        if enable:
            self._flags |= flag
        else:
            self._flags &= ~flag


class MideaIntEnum(IntEnum):
    """Helper class to convert IntEnums to/from strings."""

    @classmethod
    def list(cls) -> list[MideaIntEnum]:
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


def deprecated(replacement: str, msg: Optional[str] = None) -> Callable[[Callable], Callable]:
    """Mark function as deprecated and recommend a replacement."""

    def deprecated_decorator(func: Callable) -> Callable:
        """Decorate function as deprecated."""

        @functools.wraps(func)
        def deprecated_func(*args, **kwargs) -> Any:
            """Wrap for the original function."""

            # Check if already warned
            if not getattr(func, "_warn_deprecate", False):
                logger = logging.getLogger(func.__module__)
                logger.warning("'%s' is deprecated. %s", func.__name__,
                               (msg or f"Please use '{replacement}' instead."))
                setattr(func, "_warn_deprecate", True)

            return func(*args, **kwargs)

        return deprecated_func

    return deprecated_decorator
