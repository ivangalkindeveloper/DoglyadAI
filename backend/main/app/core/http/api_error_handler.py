from __future__ import annotations

import logging
import re
import traceback
from typing import Any
from uuid import uuid4

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from starlette.exceptions import HTTPException
from starlette.responses import JSONResponse

from app.core.http.http_header import HttpHeader
from app.core.logging.request_id_log_filter import current_request_id
from app.error import (
    ApiError,
    HttpRequestError,
    InternalServerError,
    InvalidRequestError,
    MethodNotAllowedError,
    ResourceNotFoundError,
)
from app.model.api_error_response import ApiErrorResponse
from app.model.api_validation_issue_response import ApiValidationIssueResponse


class ApiErrorHandler:
    def __init__(
        self,
    ) -> None:
        self._logger = logging.getLogger(
            __name__,
        )

    @staticmethod
    def responses() -> dict[int | str, dict[str, Any]]:
        return {
            status: {"model": ApiErrorResponse}
            for status in (400, 401, 403, 404, 405, 409, 413, 422, 429, 500, 502, 503, 504)
        }

    def register(
        self,
        app: FastAPI,
    ) -> None:
        for error_type in (ApiError, RequestValidationError, HTTPException):
            app.add_exception_handler(
                error_type,
                self.handle,
            )

    async def handle(
        self,
        request: Request,
        error: Exception,
    ) -> JSONResponse:
        if isinstance(
            error,
            ApiError,
        ):
            return self.response(
                error,
                request,
                fields=error.fields,
            )
        if isinstance(
            error,
            RequestValidationError,
        ):
            fields = [
                self._validation_issue(
                    issue,
                )
                for issue in error.errors()
            ]
            return self.response(
                InvalidRequestError(),
                request,
                fields=fields,
            )
        if isinstance(
            error,
            HTTPException,
        ):
            if error.status_code == 404:
                return self.response(
                    ResourceNotFoundError(),
                    request,
                )
            if error.status_code == 405:
                headers = {"Allow": error.headers["Allow"]} if error.headers and "Allow" in error.headers else None
                return self.response(
                    MethodNotAllowedError(),
                    request,
                    headers=headers,
                )
            return self.response(
                HttpRequestError(
                    error.status_code,
                ),
                request,
            )
        return self.response(
            InternalServerError(),
            request,
            cause=error,
            is_unexpected=True,
        )

    def response(
        self,
        error: ApiError,
        request: Request,
        *,
        fields: list[ApiValidationIssueResponse] | None = None,
        headers: dict[str, str] | None = None,
        cause: Exception | None = None,
        is_unexpected: bool = False,
    ) -> JSONResponse:
        request_id = self._request_id(
            request,
        )
        token = current_request_id.set(
            request_id,
        )
        try:
            source = cause if cause is not None else error.__cause__
            # Never render an exception, its arguments, validation input or local variables.
            # Traceback locations retain useful diagnostics without exception text or source lines.
            locations = (
                [
                    f"{frame.filename}:{frame.lineno}:{frame.name}"
                    for frame in traceback.extract_tb(
                        source.__traceback__,
                    )
                ]
                if is_unexpected and source is not None
                else []
            )
            self._logger.log(
                logging.ERROR if is_unexpected else logging.WARNING,
                "API error: code=%s status=%d cause=%s locations=%s",
                error.code,
                error.status_code,
                type(
                    source,
                ).__name__
                if source is not None
                else "-",
                locations,
            )
        finally:
            current_request_id.reset(
                token,
            )
        body = ApiErrorResponse(
            code=error.code,
            detail=error.description,
            requestId=request_id,
            fields=fields,
        )
        return JSONResponse(
            body.model_dump(
                exclude_none=True,
            ),
            status_code=error.status_code,
            headers={**(error.headers or {}), **(headers or {}), HttpHeader.REQUEST_ID.value: request_id},
        )

    @staticmethod
    def _request_id(
        request: Request,
    ) -> str:
        value = getattr(
            request.state,
            "request_id",
            None,
        )
        if isinstance(
            value,
            str,
        ) and re.fullmatch(
            r"[0-9a-f]{32}",
            value,
        ):
            return value
        request_id = uuid4().hex
        request.state.request_id = request_id
        return request_id

    @staticmethod
    def _validation_issue(
        issue: Any,
    ) -> ApiValidationIssueResponse:
        code: str = issue["type"]
        location: list[str | int] = list(
            issue["loc"],
        )
        if code == "extra_forbidden":
            # An unknown key is arbitrary client text, rather than a declared field name.
            location = location[:-1]
        return ApiValidationIssueResponse(
            location=location,
            code=code,
            description=InvalidRequestError.field_description(
                code,
            ),
        )
