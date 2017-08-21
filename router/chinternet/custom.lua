local fs = require "nixio.fs"
local conffile = "/etc/dnsmasq.d/dnsmasq_custom_ipset.conf" 

f = SimpleForm("custom", translate("Chinternet - Custom Rule"), translate("This is the custom rule file for dnsmasq."))

t = f:field(TextValue, "conf")
t.rmempty = true
t.rows = 20
function t.cfgvalue()
	return fs.readfile(conffile) or ""
end

function f.handle(self, state, data)
	if state == FORM_VALID then
		if data.conf then
			fs.writefile(conffile, data.conf:gsub("\r\n", "\n"))
			luci.sys.call("/etc/init.d/dnsmasq restart")
		end
	end
	return true
end

return f
