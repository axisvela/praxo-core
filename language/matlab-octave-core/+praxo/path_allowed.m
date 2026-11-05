function result = path_allowed(checker, target, need)
try
    decision = praxo.path_check(checker, target, need);
    result = decision.allowed;
catch
    result = false;
end
end
