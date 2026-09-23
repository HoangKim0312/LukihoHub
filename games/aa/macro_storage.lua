--!strict
-- games/aa/macro_storage.lua
-- Macro save / load / import / export.
-- Storage layers (in priority order):
--   1. writefile / readfile (Synapse/Fluxus/Arceus X)
--   2. httpservice.JSONEncode → SharedTable (best-effort)
-- We expose a flat table so the UI doesn't care about the backend.

local HttpService = game:GetService("HttpService")

local M = {}

M.store = {} -- name -> { steps = {...}, created = epoch }

local STEPS: { [string]: any } = {}

function M.appendStep(step: { [string]: any })
	table.insert(STEPS, step)
end

function M.clearSteps()
	table.clear(STEPS)
end

function M.getSteps(): { [string]: any }
	return STEPS
end

----------------------------------------------------------------
-- WRITE / READ FILES (executor feature)
----------------------------------------------------------------
local function writeFile(path: string, content: string): boolean
	if type(writefile) == "function" then
		local ok, err = pcall(writefile, path, content)
		return ok
	end
	return false
end

local function readFile(path: string): string?
	if type(readfile) == "function" then
		local ok, content = pcall(readfile, path)
		if ok then return content end
	end
	return nil
end

local function listFiles(path: string): { string }
	if type(listfiles) == "function" then
		local ok, list = pcall(listfiles, path)
		if ok and type(list) == "table" then return list end
	end
	return {}
end

local FOLDER = "LukihoHub/macros"

local function ensureFolder()
	if type(makefolder) == "function" then
		pcall(makefolder, "LukihoHub")
		pcall(makefolder, FOLDER)
	end
end

function M.save(name: string, steps: { [string]: any })
	ensureFolder()
	M.store[name] = { steps = steps, created = os.time() }
	local ok = writeFile(FOLDER .. "/" .. name .. ".json", HttpService:JSONEncode(M.store[name]))
	return ok
end

function M.load(name: string): { [string]: any }?
	if M.store[name] then return M.store[name] end
	local raw = readFile(FOLDER .. "/" .. name .. ".json")
	if not raw then return nil end
	local ok, parsed = pcall(function() return HttpService:JSONDecode(raw) end)
	if ok and parsed then
		M.store[name] = parsed
		return parsed
	end
	return nil
end

function M.list(): { string }
	local set = {}
	for name in M.store do set[name] = true end
	for _, path in listFiles(FOLDER) do
		local base = path:match("([^/\\]+)%.json$")
		if base then set[base] = true end
	end
	local out = {}
	for name in set do table.insert(out, name) end
	table.sort(out)
	return out
end

function M.delete(name: string)
	M.store[name] = nil
	if type(delfile) == "function" then
		pcall(delfile, FOLDER .. "/" .. name .. ".json")
	end
end

----------------------------------------------------------------
-- IMPORT / EXPORT
----------------------------------------------------------------
function M.import(name: string, source: string, mode: string): boolean
	mode = mode or "Link"
	local content: string? = nil
	if mode == "Link" then
		if type(request) == "function" or type(HttpService.GetAsync) == "function" then
			local ok, r = pcall(function()
				return (HttpService :: any):GetAsync(source)
			end)
			if ok then content = r end
		elseif type(game.HttpGet) == "function" then
			local ok, r = pcall(function() return (game :: any):HttpGet(source) end)
			if ok then content = r end
		end
	elseif mode == "Text" then
		content = source
	end
	if not content then return false end
	local ok, parsed = pcall(function() return HttpService:JSONDecode(content) end)
	if not ok or not parsed or not parsed.steps then return false end
	M.save(name, parsed.steps)
	return true
end

function M.export(name: string): string?
	local entry = M.load(name)
	if not entry then return nil end
	return HttpService:JSONEncode(entry)
end

return M
