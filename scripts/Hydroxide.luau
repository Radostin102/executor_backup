local owner: string = "Upbolt"
local branch: string = "revision"

local function webImport(file)
    return loadstring(
        game:HttpGetAsync(
            string.format("https://raw.githubusercontent.com/%s/Hydroxide/%s/%s.lua", owner, branch, file),
            string.format("%s.lua", file)
        )
    )()
end

webImport("init")
webImport("ui/main")
