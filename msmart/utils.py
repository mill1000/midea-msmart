"""Utility classes and methods for Midea AC."""
from __future__ import annotations

import functools
import logging
from enum import IntEnum
from typing import Any, Callable, Optional, cast

_LOGGER = logging.getLogger(__name__)


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


def deprecated(replacement: str) -> Callable[[Callable], Callable]:
    """Mark function as deprecated and recommend a replacement."""

    def deprecated_decorator(func: Callable) -> Callable:
        """Decorate function as deprecated."""

        @functools.wraps(func)
        def deprecated_func(*args, **kwargs) -> Any:
            """Wrap for the original function."""

            # Check if already warned
            if not getattr(func, "_warn_deprecate", False):
                logger = logging.getLogger(func.__module__)
                logger.warning("'%s' is deprecated. Please use '%s' instead.",
                               func.__name__,
                               replacement,
                               )
                setattr(func, "_warn_deprecate", True)

            return func(*args, **kwargs)

        return deprecated_func

    return deprecated_decorator
