package com.axisvela.praxo.application.commerce;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;

@Component
public final class TenantFilter extends OncePerRequestFilter {
    private final CommerceSettings settings;

    public TenantFilter(CommerceSettings settings) {
        this.settings = settings;
    }

    @Override
    protected boolean shouldNotFilter(HttpServletRequest request) {
        return !request.getRequestURI().startsWith("/api/commerce/");
    }

    @Override
    protected void doFilterInternal(
            HttpServletRequest request,
            HttpServletResponse response,
            FilterChain filterChain) throws ServletException, IOException {
        String actual = request.getHeader("X-Tenant-Id");
        if (actual == null || actual.isBlank()) {
            write(response, 401, "TENANT_REQUIRED");
            return;
        }
        byte[] expectedBytes = settings.tenant().getBytes(StandardCharsets.UTF_8);
        byte[] actualBytes = actual.getBytes(StandardCharsets.UTF_8);
        if (!MessageDigest.isEqual(expectedBytes, actualBytes)) {
            write(response, 403, "TENANT_DENIED");
            return;
        }
        request.setAttribute("tenant", actual);
        filterChain.doFilter(request, response);
    }

    private static void write(HttpServletResponse response, int status, String code)
            throws IOException {
        response.setStatus(status);
        response.setContentType("application/json");
        response.setCharacterEncoding("UTF-8");
        response.getWriter().write("{\"error\":\"" + code + "\"}");
    }
}
