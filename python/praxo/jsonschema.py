from __future__ import annotations

import json
import re
from dataclasses import dataclass, field
from typing import Any


@dataclass
class ValidationError:
    path: str
    message: str


@dataclass
class Schema:
    type: str = ""
    properties: dict[str, Schema] = field(default_factory=dict)
    required: list[str] = field(default_factory=list)
    items: Schema | None = None
    enum: list[Any] = field(default_factory=list)
    min_length: int = 0
    max_length: int = 0
    minimum: float = 0
    maximum: float = 0
    pattern: str = ""
    description: str = ""

    @classmethod
    def from_dict(cls, raw: dict[str, Any] | None) -> Schema:
        raw = raw or {}
        items = raw.get("items")
        return cls(
            type=raw.get("type", ""),
            properties={
                key: cls.from_dict(value)
                for key, value in (raw.get("properties") or {}).items()
            },
            required=list(raw.get("required") or []),
            items=cls.from_dict(items) if isinstance(items, dict) else None,
            enum=list(raw.get("enum") or []),
            min_length=int(raw.get("minLength") or 0),
            max_length=int(raw.get("maxLength") or 0),
            minimum=float(raw.get("minimum") or 0),
            maximum=float(raw.get("maximum") or 0),
            pattern=raw.get("pattern", ""),
            description=raw.get("description", ""),
        )

    def validate(self, data: Any) -> list[ValidationError]:
        errors: list[ValidationError] = []
        self._validate(data, "$", errors)
        return errors

    def _validate(
        self, data: Any, path: str, errors: list[ValidationError]
    ) -> None:
        if data is None:
            if self.type:
                errors.append(ValidationError(path, f"expected {self.type}, got null"))
            return

        if self.type == "object":
            if not isinstance(data, dict):
                errors.append(ValidationError(path, "expected object"))
                return
            for name in self.required:
                if name not in data:
                    errors.append(
                        ValidationError(f"{path}.{name}", "required field missing")
                    )
            for key, schema in self.properties.items():
                if key in data:
                    schema._validate(data[key], f"{path}.{key}", errors)
            return

        if self.type == "array":
            if not isinstance(data, list):
                errors.append(ValidationError(path, "expected array"))
                return
            if self.items is not None:
                for index, item in enumerate(data):
                    self.items._validate(item, f"{path}[{index}]", errors)
            return

        if self.type == "string":
            if not isinstance(data, str):
                errors.append(ValidationError(path, "expected string"))
                return
            length = len(data)
            if self.min_length > 0 and length < self.min_length:
                errors.append(
                    ValidationError(
                        path,
                        f"min length {self.min_length}, got {length}",
                    )
                )
            if self.max_length > 0 and length > self.max_length:
                errors.append(
                    ValidationError(
                        path,
                        f"max length {self.max_length}, got {length}",
                    )
                )
            if self.pattern:
                try:
                    matched = re.search(self.pattern, data) is not None
                except re.error as exc:
                    errors.append(
                        ValidationError(
                            path, f"invalid pattern '{self.pattern}': {exc}"
                        )
                    )
                else:
                    if not matched:
                        errors.append(
                            ValidationError(
                                path, f"pattern '{self.pattern}' not matched"
                            )
                        )
            if self.enum and data not in self.enum:
                errors.append(
                    ValidationError(path, f"value not in enum: {self.enum}")
                )
            return

        if self.type in ("number", "integer"):
            if isinstance(data, bool) or not isinstance(data, (int, float)):
                errors.append(ValidationError(path, "expected number"))
                return
            if self.type == "integer" and isinstance(data, float) and not data.is_integer():
                errors.append(ValidationError(path, f"expected integer, got {data}"))
                return
            if self.enum and data not in self.enum:
                errors.append(
                    ValidationError(path, f"value not in enum: {self.enum}")
                )
            if self.minimum != 0 and data < self.minimum:
                errors.append(
                    ValidationError(
                        path, f"value {data} below minimum {self.minimum}"
                    )
                )
            if self.maximum != 0 and data > self.maximum:
                errors.append(
                    ValidationError(
                        path, f"value {data} above maximum {self.maximum}"
                    )
                )
            return

        if self.type == "boolean":
            if not isinstance(data, bool):
                errors.append(ValidationError(path, "expected boolean"))
                return
            if self.enum and data not in self.enum:
                errors.append(
                    ValidationError(path, f"value not in enum: {self.enum}")
                )


def from_json(raw: str | bytes) -> Schema:
    if isinstance(raw, bytes):
        raw = raw.decode("utf-8")
    return Schema.from_dict(json.loads(raw))


def validate(schema: Schema | dict[str, Any], data: Any) -> list[ValidationError]:
    if isinstance(schema, dict):
        schema = Schema.from_dict(schema)
    return schema.validate(data)
