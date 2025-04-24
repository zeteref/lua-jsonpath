package = "jsonpath"
version = "1.0-3"
source = {
    url = "git://github.com/zeteref/lua-jsonpath",
    tag = "master",
}
description = {
    summary = "Query Lua data structures with JsonPath expressions. Robust and safe JsonPath engine for Lua.",
    detailed = [[
This library implements Stefan Goessner's JsonPath syntax (http://goessner.net/articles/JsonPath/) in Lua.

Lua JsonPath is compatible with David Chester's Javascript implementation (https://github.com/dchester/jsonpath).

The Lua JsonPath library was written from scratch by Frank Edelhaeuser. It's a pure Lua implementation based on a PEG grammer handled by Roberto Ierusalimschy's fabulous LPeg pattern-matching library (http://www.inf.puc-rio.br/~roberto/lpeg/lpeg.html).
    ]],
    homepage = "https://github.com/zeteref/lua-jsonpath",
    license = "MIT",
}
dependencies = {
    "lua >= 5.1",
    "lpeg >= 1.0.0",
}
build = {
    type = "builtin",
    modules = {
        jsonpath = "jsonpath.lua",
    },
    copy_directories = {
        "test",
    },
}
