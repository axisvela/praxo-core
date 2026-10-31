package com.axisvela.praxo.tool;

import java.util.Map;

public interface Tool {
    String name();

    String description();

    Object invoke(Map<String, Object> args) throws Exception;
}
