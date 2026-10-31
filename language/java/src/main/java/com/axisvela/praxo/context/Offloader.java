package com.axisvela.praxo.context;

@FunctionalInterface
public interface Offloader {
    String offload(String toolName, String toolCallId, byte[] data)
            throws Exception;
}
