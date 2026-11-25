package com.axisvela.praxo.application.commerce;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record CheckoutDraftRequest(
        @NotBlank @Size(max = 500) String intent) {
}
