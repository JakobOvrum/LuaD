local cpuid = require "dmodule"

for name, value in pairs(cpuid) do
	if name ~= "datacache" then
		print(name .. ":", value())
	end
end

for i, cache in ipairs(cpuid.datacache) do
	print(("cache #%d: %dkB"):format(i, cache.size))
end
