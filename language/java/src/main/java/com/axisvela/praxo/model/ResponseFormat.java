package com.axisvela.praxo.model;

import java.util.Map;

public record ResponseFormat(String name, Map<String, Object> schema) {
}
