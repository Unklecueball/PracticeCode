from _typeshed import Incomplete
from typing import Any

class _EventKey:
    target: Any
    identifier: Any
    fn: Any
    fn_key: Any
    fn_wrap: Any
    dispatch_target: Any
    def __init__(self, target, identifier, fn, dispatch_target, _fn_wrap: Incomplete | None = None) -> None: ...
    def with_wrapper(self, fn_wrap): ...
    def with_dispatch_target(self, dispatch_target): ...
    def listen(self, *args, **kw) -> None: ...
    def remove(self) -> None: ...
    def contains(self): ...
    def base_listen(
        self,
        propagate: bool = False,
        insert: bool = False,
        named: bool = False,
        retval: Incomplete | None = None,
        asyncio: bool = False,
    ) -> None: ...
    def append_to_list(self, owner, list_): ...
    def remove_from_list(self, owner, list_) -> None: ...
    def prepend_to_list(self, owner, list_): ...