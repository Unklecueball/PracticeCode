import datetime
from _typeshed import Incomplete
from typing import Any

ZERO: Any

class FixedOffsetTimezone(datetime.tzinfo):
    def __init__(self, offset: Incomplete | None = None, name: Incomplete | None = None) -> None: ...
    def __new__(cls, offset: Incomplete | None = None, name: Incomplete | None = None): ...
    def __eq__(self, other): ...
    def __ne__(self, other): ...
    def __getinitargs__(self): ...
    def utcoffset(self, dt): ...
    def tzname(self, dt): ...
    def dst(self, dt): ...

STDOFFSET: Any
DSTOFFSET: Any
DSTDIFF: Any

class LocalTimezone(datetime.tzinfo):
    def utcoffset(self, dt): ...
    def dst(self, dt): ...
    def tzname(self, dt): ...

LOCAL: Any
