-- tools/check_lua50.lua
-- Prueft, ob die Addon-Dateien nur Sprachmittel nutzen, die es in Lua 5.0
-- (WoW 1.12) gibt. luac5.1 allein reicht dafuer nicht: der Laengenoperator
-- "#", der Modulo-Operator "%", string.gmatch und string.match sind fuer
-- Lua 5.1 gueltig, brechen im Spiel aber mit einem Lua-Fehler ab.
--
-- Kommentare und Zeichenketten werden vorher entfernt, damit Text wie
-- "Item #ID" oder ein Musterzeichen "%d" keinen Fehlalarm ausloest.
--
-- Nutzung:  lua5.1 tools/check_lua50.lua Datei1.lua Datei2.lua ...

-- Ersetzt Kommentare und Zeichenketten durch Leerraum, Zeilenumbrueche
-- bleiben erhalten (damit die Zeilennummern stimmen).
local function strip(src)
    local out, i, n = {}, 1, string.len(src)
    local function blank(s) return (string.gsub(s, "[^\n]", " ")) end
    while i <= n do
        local c = string.sub(src, i, i)
        local two = string.sub(src, i, i + 1)
        if two == "--" then
            local eq = string.match(src, "^%[(=*)%[", i + 2)
            local stop
            if eq then
                local _, e = string.find(src, "]" .. eq .. "]", i + 2, true)
                stop = e or n
            else
                stop = (string.find(src, "\n", i, true) or (n + 1)) - 1
            end
            table.insert(out, blank(string.sub(src, i, stop)))
            i = stop + 1
        elseif c == "[" and string.match(src, "^%[=*%[", i) then
            local eq = string.match(src, "^%[(=*)%[", i)
            local _, e = string.find(src, "]" .. eq .. "]", i, true)
            e = e or n
            table.insert(out, blank(string.sub(src, i, e)))
            i = e + 1
        elseif c == '"' or c == "'" then
            local j = i + 1
            while j <= n do
                local d = string.sub(src, j, j)
                if d == "\\" then j = j + 2
                elseif d == c or d == "\n" then break
                else j = j + 1 end
            end
            table.insert(out, blank(string.sub(src, i, j)))
            i = j + 1
        else
            table.insert(out, c)
            i = i + 1
        end
    end
    return table.concat(out)
end

local checks = {
    { pat = "#",                       msg = "Laengenoperator # (in Lua 5.0: table.getn / string.len)" },
    { pat = "%%",                      msg = "Modulo-Operator % (in Lua 5.0: math.mod)" },
    { pat = "gmatch",                  msg = "gmatch (in Lua 5.0: string.gfind)" },
    { pat = "[%.:]match%s*%(",         msg = "string.match (gibt es erst ab Lua 5.1)" },
    { pat = "[^%w_%.:]select%s*%(",    msg = "select() (gibt es erst ab Lua 5.1)" },
    { pat = "^select%s*%(",            msg = "select() (gibt es erst ab Lua 5.1)" },
}

local problems = 0
for _, path in ipairs(arg) do
    local f = assert(io.open(path, "rb"))
    local code = strip(f:read("*a"))
    f:close()
    local lineNo = 0
    for line in string.gmatch(code .. "\n", "([^\n]*)\n") do
        lineNo = lineNo + 1
        for _, chk in ipairs(checks) do
            if string.find(line, chk.pat) then
                print(string.format("%s:%d: %s", path, lineNo, chk.msg))
                problems = problems + 1
            end
        end
    end
end

if problems > 0 then
    print(problems .. " Stelle(n) nicht Lua-5.0-kompatibel")
    os.exit(1)
end
print("ALLE TESTS OK")
