module praxo.errors;

class PraxoError : Exception {
    string code;

    this(string code, string message) {
        super(message);
        this.code = code;
    }
}

string errorCode(Throwable error) {
    auto praxo = cast(PraxoError) error;
    return praxo is null ? "" : praxo.code;
}
