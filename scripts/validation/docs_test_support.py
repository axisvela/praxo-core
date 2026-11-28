from html.parser import HTMLParser
import json
from pathlib import Path
import re
import tomllib
import unittest
import xml.etree.ElementTree as ElementTree
from types import SimpleNamespace
from urllib.parse import unquote, urljoin, urlsplit

import yaml

from scripts.discovery import docs_hooks


ROOT = docs_hooks.ROOT


class Links(HTMLParser):
    def __init__(self):
        super().__init__()
        self.targets = []
        self.alternates = []
        self.text = []

    def handle_data(self, data):
        self.text.append(data)

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag == "a" and "href" in attrs:
            self.targets.append(attrs["href"])
        if tag == "link" and attrs.get("rel") == "alternate":
            self.alternates.append(attrs)

class Links(HTMLParser):
    def __init__(self):
        super().__init__()
        self.targets = []
        self.alternates = []
        self.text = []

    def handle_data(self, data):
        self.text.append(data)

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag == "a" and "href" in attrs:
            self.targets.append(attrs["href"])
        if tag == "link" and attrs.get("rel") == "alternate":
            self.alternates.append(attrs)

__all__ = [
    "HTMLParser", "json", "Path", "re", "tomllib", "unittest", "ElementTree",
    "SimpleNamespace", "unquote", "urljoin", "urlsplit", "yaml", "docs_hooks",
    "ROOT", "Links",
]
