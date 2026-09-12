from __future__ import annotations

from pydantic import Base64Bytes, BaseModel, Field, field_validator


class ReportEmailAttachment(BaseModel):
    fileName: str = Field(min_length=1, max_length=255)
    mimeType: str
    data: Base64Bytes

    @field_validator("mimeType")
    @classmethod
    def validate_mime_type(cls, value: str) -> str:
        maintype, separator, subtype = value.partition("/")
        if not separator or not maintype or not subtype or "\r" in value or "\n" in value:
            raise ValueError("mimeType must contain a valid MIME type")
        return value
