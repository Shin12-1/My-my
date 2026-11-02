-- Load the UI library safely
local okLoad, Library = pcall(function()
    local loadFn = loadstring or (getgenv and getgenv().loadstring)
    assert(type(loadFn) == "function", "loadstring is not available in this executor")

    local source = fetch("igkii_lib.lua")
    assert(type(source) == "string" and source ~= "", "the library download came back empty")

    -- ADDED CHECK: Make sure we actually downloaded the library and not the loader
    if string.find(source, "igkii loader", 1, true) then
        error("You accidentally put the loader.lua code inside igkii_lib.lua on GitHub!")
    end

    -- Strip invisible BOMs and null bytes
    source = source:gsub("^\239\187\191", "")
    source = source:gsub("^\255\254", "")
    source = source:gsub("^\254\255", "")
    source = source:gsub("%z", "")

    local chunk, compileErr = loadFn(source, "igkii_lib")
    assert(chunk, "igkii_lib.lua failed to compile: " .. tostring(compileErr))

    return chunk()
end)

if not okLoad or type(Library) ~= "table" then
    warn("[Cast] could not load the UI library: " .. tostring(Library))
    return
end
