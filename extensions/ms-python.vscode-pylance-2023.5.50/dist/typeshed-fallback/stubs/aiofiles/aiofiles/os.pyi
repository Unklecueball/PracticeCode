import sys
from _typeshed import FileDescriptorOrPath, GenericPath, ReadableBuffer, StrOrBytesPath
from asyncio.events import AbstractEventLoop
from collections.abc import Sequence
from os import _ScandirIterator, stat_result
from typing import Any, AnyStr, overload

from aiofiles import ospath

path = ospath

async def stat(
    path: FileDescriptorOrPath,
    *,
    dir_fd: int | None = None,
    follow_symlinks: bool = True,
    loop: AbstractEventLoop | None = ...,
    executor: Any = ...,
) -> stat_result: ...
async def rename(
    src: StrOrBytesPath,
    dst: StrOrBytesPath,
    *,
    src_dir_fd: int | None = None,
    dst_dir_fd: int | None = None,
    loop: AbstractEventLoop | None = ...,
    executor: Any = ...,
) -> None: ...
async def replace(
    src: StrOrBytesPath,
    dst: StrOrBytesPath,
    *,
    src_dir_fd: int | None = None,
    dst_dir_fd: int | None = None,
    loop: AbstractEventLoop | None = ...,
    executor: Any = ...,
) -> None: ...
async def remove(
    path: StrOrBytesPath, *, dir_fd: int | None = None, loop: AbstractEventLoop | None = ..., executor: Any = ...
) -> None: ...
async def mkdir(
    path: StrOrBytesPath, mode: int = 511, *, dir_fd: int | None = None, loop: AbstractEventLoop | None = ..., executor: Any = ...
) -> None: ...
async def makedirs(
    name: StrOrBytesPath, mode: int = 511, exist_ok: bool = False, *, loop: AbstractEventLoop | None = ..., executor: Any = ...
) -> None: ...
async def rmdir(
    path: StrOrBytesPath, *, dir_fd: int | None = None, loop: AbstractEventLoop | None = ..., executor: Any = ...
) -> None: ...
async def removedirs(name: StrOrBytesPath, *, loop: AbstractEventLoop | None = ..., executor: Any = ...) -> None: ...
@overload
async def scandir(path: None = None, *, loop: AbstractEventLoop | None = ..., executor: Any = ...) -> _ScandirIterator[str]: ...
@overload
async def scandir(path: int, *, loop: AbstractEventLoop | None = ..., executor: Any = ...) -> _ScandirIterator[str]: ...
@overload
async def scandir(
    path: GenericPath[AnyStr], *, loop: AbstractEventLoop | None = ..., executor: Any = ...
) -> _ScandirIterator[AnyStr]: ...

if sys.platform != "win32":
    @overload
    async def sendfile(
        out_fd: int, in_fd: int, offset: int | None, count: int, *, loop: AbstractEventLoop | None = ..., executor: Any = ...
    ) -> int: ...
    @overload
    async def sendfile(
        out_fd: int,
        in_fd: int,
        offset: int,
        count: int,
        headers: Sequence[ReadableBuffer] = ...,
        trailers: Sequence[ReadableBuffer] = ...,
        flags: int = ...,
        *,
        loop: AbstractEventLoop | None = ...,
        executor: Any = ...,
    ) -> int: ...  # FreeBSD and Mac OS X only
