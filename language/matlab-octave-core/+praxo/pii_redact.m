function text = pii_redact(text)
text = regexprep(text, '[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}', '[REDACTED:email]');
text = regexprep(text, '\<\d{3}-\d{2}-\d{4}\>', '[REDACTED:ssn]');
text = regexprep(text, '\<(?:\d{4}[ -]?){3}\d{4}\>', '[REDACTED:credit_card]');
text = regexprep(text, '\<(?:\+?1[-. ]?)?\(?\d{3}\)?[-. ]?\d{3}[-. ]?\d{4}\>', '[REDACTED:phone]');
end
