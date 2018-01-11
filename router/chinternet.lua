module("luci.controller.chinternet", package.seeall)

function index()
	if not nixio.fs.access("/etc/ss.json") then
		return
	end

	entry({"admin", "services", "chinternet"},
		alias("admin", "services", "chinternet", "general"),
		_("Chinternet"), 10)

	entry({"admin", "services", "chinternet", "general"},
		cbi("chinternet/general"),
		_("General Settings"), 10).leaf = true

	entry({"admin", "services", "chinternet", "auto"},
		cbi("chinternet/auto"),
		_("Auto Rule"), 30).leaf = true

	entry({"admin", "services", "chinternet", "custom"},
		cbi("chinternet/custom"),
		_("Custom Rule"), 30).leaf = true
end
