<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
<meta http-equiv="X-UA-Compatible" content="IE=Edge" />
<meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
<meta HTTP-EQUIV="Pragma" CONTENT="no-cache" />
<meta HTTP-EQUIV="Expires" CONTENT="-1" />
<link rel="shortcut icon" href="images/favicon.png" />
<link rel="icon" href="images/favicon.png" />
<title>RealityChain</title>
<link rel="stylesheet" type="text/css" href="index_style.css" />
<link rel="stylesheet" type="text/css" href="form_style.css" />
<script language="JavaScript" type="text/javascript" src="/state.js"></script>
<script language="JavaScript" type="text/javascript" src="/general.js"></script>
<script language="JavaScript" type="text/javascript" src="/popup.js"></script>
<script language="JavaScript" type="text/javascript" src="/help.js"></script>
<script language="JavaScript" type="text/javascript" src="/validator.js"></script>
<script>
var custom_settings = <% get_custom_settings(); %>;

function setting(name, fallback) {
	if (custom_settings[name] == undefined || custom_settings[name] === "")
		return fallback;
	return custom_settings[name];
}

function fieldValue(id) {
	return document.getElementById(id).value.replace(/[\r\n]/g, "");
}

function setField(id, value) {
	document.getElementById(id).value = value;
}

function initial() {
	SetCurrentPage();
	show_menu();

	document.getElementById("realitychain_enabled").checked = setting("rch_enabled", "1") !== "0";
	setField("realitychain_server_address", setting("rch_server_address", "vpn.example.net"));
	setField("realitychain_server_port", setting("rch_server_port", "443"));
	setField("realitychain_vless_uuid", setting("rch_vless_uuid", "00000000-0000-4000-8000-000000000000"));
	setField("realitychain_reality_public_key", setting("rch_reality_public_key", ""));
	setField("realitychain_reality_short_id", setting("rch_reality_short_id", ""));
	setField("realitychain_reality_server_name", setting("rch_reality_server_name", "www.microsoft.com"));
	setField("realitychain_reality_fingerprint", setting("rch_reality_fingerprint", "chrome"));
	setField("realitychain_anchor_rpc_url", setting("rch_anchor_rpc_url", ""));
	setField("realitychain_anchor_contract", setting("rch_anchor_contract", ""));
	setField("realitychain_anchor_storage_slot", setting("rch_anchor_storage_slot", ""));
	setField("realitychain_policy_file", setting("rch_policy_file", "/jffs/addons/realitychain/policy.json"));

	document.getElementById("realitychain_status").innerHTML = setting("rch_status", "unknown");
	document.getElementById("realitychain_anchor_status").innerHTML = setting("rch_anchor_status", "not checked");
	document.getElementById("realitychain_policy_hash").innerHTML = setting("rch_policy_hash", "not calculated");
	document.getElementById("realitychain_updated_at").innerHTML = setting("rch_updated_at", "never");
}

function SetCurrentPage() {
	document.form.next_page.value = window.location.pathname.substring(1);
	document.form.current_page.value = window.location.pathname.substring(1);
}

function storeSettings() {
	custom_settings.rch_enabled = document.getElementById("realitychain_enabled").checked ? "1" : "0";
	custom_settings.rch_server_address = fieldValue("realitychain_server_address");
	custom_settings.rch_server_port = fieldValue("realitychain_server_port");
	custom_settings.rch_vless_uuid = fieldValue("realitychain_vless_uuid");
	custom_settings.rch_reality_public_key = fieldValue("realitychain_reality_public_key");
	custom_settings.rch_reality_short_id = fieldValue("realitychain_reality_short_id");
	custom_settings.rch_reality_server_name = fieldValue("realitychain_reality_server_name");
	custom_settings.rch_reality_fingerprint = fieldValue("realitychain_reality_fingerprint");
	custom_settings.rch_anchor_rpc_url = fieldValue("realitychain_anchor_rpc_url");
	custom_settings.rch_anchor_contract = fieldValue("realitychain_anchor_contract");
	custom_settings.rch_anchor_storage_slot = fieldValue("realitychain_anchor_storage_slot");
	custom_settings.rch_policy_file = fieldValue("realitychain_policy_file");
	document.getElementById("amng_custom").value = JSON.stringify(custom_settings);
}

function applySettings(actionScript) {
	storeSettings();
	document.form.action_script.value = actionScript;
	showLoading();
	document.form.submit();
}
</script>
</head>
<body onload="initial();" class="bg">
<div id="TopBanner"></div>
<div id="Loading" class="popup_bg"></div>
<iframe name="hidden_frame" id="hidden_frame" src="" width="0" height="0" frameborder="0"></iframe>

<form method="post" name="form" action="start_apply.htm" target="hidden_frame">
<input type="hidden" name="current_page" value="RealityChain.asp" />
<input type="hidden" name="next_page" value="RealityChain.asp" />
<input type="hidden" name="group_id" value="" />
<input type="hidden" name="modified" value="0" />
<input type="hidden" name="action_mode" value="apply" />
<input type="hidden" name="action_wait" value="5" />
<input type="hidden" name="first_time" value="" />
<input type="hidden" name="action_script" value="restart_realitychain" />
<input type="hidden" name="preferred_lang" id="preferred_lang" value="<% nvram_get("preferred_lang"); %>" />
<input type="hidden" name="firmver" value="<% nvram_get("firmver"); %>" />
<input type="hidden" name="amng_custom" id="amng_custom" value="" />

<table class="content" align="center" cellpadding="0" cellspacing="0">
<tr>
<td width="17">&nbsp;</td>
<td valign="top" width="202">
<div id="mainMenu"></div>
<div id="subMenu"></div>
</td>
<td valign="top">
<div id="tabMenu" class="submenuBlock"></div>
<table width="98%" border="0" align="left" cellpadding="0" cellspacing="0">
<tr>
<td align="left" valign="top">
<table width="760px" border="0" cellpadding="5" cellspacing="0" bordercolor="#6b8fa3" class="FormTitle" id="FormTitle">
<tr>
<td bgcolor="#4D595D" colspan="3" valign="top">
<div>&nbsp;</div>
<div class="formfonttitle">RealityChain - VLESS REALITY tunnel</div>
<div style="margin:10px 0 10px 5px;" class="splitLine"></div>
<div class="formfontdesc">
	Manage the router-side RealityChain tunnel profile. Settings are stored in
	Merlin custom addon storage and applied through the RealityChain service
	event handler.
</div>

<table width="100%" border="1" align="center" cellpadding="4" cellspacing="0" bordercolor="#6b8fa3" class="FormTable">
	<thead>
	<tr>
		<td colspan="2">Service status</td>
	</tr>
	</thead>
	<tr>
		<th>Status</th>
		<td><span id="realitychain_status">unknown</span></td>
	</tr>
	<tr>
		<th>Anchor status</th>
		<td><span id="realitychain_anchor_status">not checked</span></td>
	</tr>
	<tr>
		<th>Policy hash</th>
		<td><span id="realitychain_policy_hash">not calculated</span></td>
	</tr>
	<tr>
		<th>Last update</th>
		<td><span id="realitychain_updated_at">never</span></td>
	</tr>
</table>

<div style="margin-top:12px;"></div>

<table width="100%" border="1" align="center" cellpadding="4" cellspacing="0" bordercolor="#6b8fa3" class="FormTable">
	<thead>
	<tr>
		<td colspan="2">Tunnel settings</td>
	</tr>
	</thead>
	<tr>
		<th>Enable at boot</th>
		<td><input type="checkbox" id="realitychain_enabled" /></td>
	</tr>
	<tr>
		<th>Server address</th>
		<td><input type="text" maxlength="255" class="input_32_table" id="realitychain_server_address" autocorrect="off" autocapitalize="off" /></td>
	</tr>
	<tr>
		<th>Server port</th>
		<td><input type="text" maxlength="5" class="input_6_table" id="realitychain_server_port" autocorrect="off" autocapitalize="off" /></td>
	</tr>
	<tr>
		<th>VLESS UUID</th>
		<td><input type="text" maxlength="36" class="input_32_table" id="realitychain_vless_uuid" autocorrect="off" autocapitalize="off" /></td>
	</tr>
	<tr>
		<th>REALITY public key</th>
		<td><input type="text" maxlength="128" class="input_32_table" id="realitychain_reality_public_key" autocorrect="off" autocapitalize="off" /></td>
	</tr>
	<tr>
		<th>REALITY short ID</th>
		<td><input type="text" maxlength="32" class="input_32_table" id="realitychain_reality_short_id" autocorrect="off" autocapitalize="off" /></td>
	</tr>
	<tr>
		<th>REALITY server name</th>
		<td><input type="text" maxlength="255" class="input_32_table" id="realitychain_reality_server_name" autocorrect="off" autocapitalize="off" /></td>
	</tr>
	<tr>
		<th>REALITY fingerprint</th>
		<td><input type="text" maxlength="32" class="input_15_table" id="realitychain_reality_fingerprint" autocorrect="off" autocapitalize="off" /></td>
	</tr>
</table>

<div style="margin-top:12px;"></div>

<table width="100%" border="1" align="center" cellpadding="4" cellspacing="0" bordercolor="#6b8fa3" class="FormTable">
	<thead>
	<tr>
		<td colspan="2">Blockchain anchor</td>
	</tr>
	</thead>
	<tr>
		<th>RPC URL</th>
		<td><input type="text" maxlength="255" class="input_32_table" id="realitychain_anchor_rpc_url" autocorrect="off" autocapitalize="off" /></td>
	</tr>
	<tr>
		<th>Contract address</th>
		<td><input type="text" maxlength="42" class="input_32_table" id="realitychain_anchor_contract" autocorrect="off" autocapitalize="off" /></td>
	</tr>
	<tr>
		<th>Storage slot</th>
		<td><input type="text" maxlength="66" class="input_32_table" id="realitychain_anchor_storage_slot" autocorrect="off" autocapitalize="off" /></td>
	</tr>
	<tr>
		<th>Policy file</th>
		<td><input type="text" maxlength="255" class="input_32_table" id="realitychain_policy_file" autocorrect="off" autocapitalize="off" /></td>
	</tr>
</table>

<div class="apply_gen">
	<input type="button" class="button_gen" onclick="applySettings('restart_realitychain');" value="Apply and restart" />
	<input type="button" class="button_gen" onclick="applySettings('stop_realitychain');" value="Stop tunnel" />
</div>
</td>
</tr>
</table>
</td>
</tr>
</table>
</td>
<td width="10" align="center" valign="top"></td>
</tr>
</table>
</form>
<div id="footer"></div>
</body>
</html>
