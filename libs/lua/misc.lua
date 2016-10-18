table.is_empty = function (t)
    if t and next(t) then
        return false;
    else
        return true;
    end
end


string.is_empty = function (s)
    if nil == s or '' == s then
        return true;
    else
        return false;
    end
end
