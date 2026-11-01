from __future__ import annotations

import base64
import binascii

from app.error import EmptyImageError, ImageTooLargeError, InvalidImageEncodingError, TooManyImagesError


class ImageRequestValidator:
    def __init__(
        self,
        max_image_bytes: int,
        max_images: int,
    ) -> None:
        self._max_image_bytes = max_image_bytes
        self._max_images = max_images

    def validate(
        self,
        images: list[str],
    ) -> None:
        if (
            len(
                images,
            )
            > self._max_images
        ):
            raise TooManyImagesError()
        for data in images:
            if len(
                data,
            ) > 4 * ((self._max_image_bytes + 2) // 3):
                raise ImageTooLargeError()
            try:
                decoded = base64.b64decode(
                    data,
                    validate=True,
                )
            except (ValueError, binascii.Error) as error:
                raise InvalidImageEncodingError() from error
            if not decoded:
                raise EmptyImageError()
            if (
                len(
                    decoded,
                )
                > self._max_image_bytes
            ):
                raise ImageTooLargeError()
