from typing import Literal
from ._typing import *
from .transforms import Affine2D, Transform
from .path import Path
from ._enums import CapStyle, JoinStyle

class MarkerStyle:

    markers: list = ...
    filled_markers: list = ...
    fillstyles: list = ...

    def __init__(
        self,
        marker: str | ArrayLike | Path | MarkerStyle | None = ...,
        fillstyle: Literal["full", "left", "right", "bottom", "top", "none"] = ...,
        transform: Transform = ...,
        capstyle: CapStyle = ...,
        joinstyle: JoinStyle = ...,
    ) -> None: ...
    def __bool__(self) -> bool: ...
    def is_filled(self) -> bool: ...
    def get_fillstyle(self) -> str: ...
    def get_joinstyle(self) -> JoinStyle: ...
    def get_capstyle(self) -> CapStyle: ...
    def get_marker(self): ...
    def get_path(self) -> Path: ...
    def get_transform(self) -> Transform: ...
    def get_alt_path(self) -> Path: ...
    def get_alt_transform(self) -> Transform: ...
    def get_snap_threshold(self): ...
    def get_user_transform(self): ...
    def transformed(self, transform: Affine2D | None = ...): ...
    def rotated(self, *, deg: float = ..., rad: float = ...): ...
    def scaled(self, sx: float, sy: float = ...): ...
