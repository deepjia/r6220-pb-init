local fs = require "nixio.fs"
local conffile = "/etc/dnsmasq.d/dnsmasq_glist_ipset.conf" 

f = SimpleForm("custom", translate("Chinternet - Auto Rule"), translate("This is the auto rule file for dnsmasq. Click to regenerate."))
f.reset = false
f.submit = false

m = f:field(Button, "regenerate", "Regenerate Auto Rule")
function m.write(self,section)
	luci.sys.call("/etc/glist2dnsmasq.sh -i -s glist -o /etc/dnsmasq.d/dnsmasq_glist_ipset.conf >/dev/null")
end

t = f:field(TextValue, "conf")
t.rows = 20
function t.cfgvalue()
	return fs.readfile(conffile) or ""
end

return f
