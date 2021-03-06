/// Main package containing all neccesarry functions
/// See_Also: <a href="aliases.html">`settings.aliases`</a> for shorter UDAs
module webconfig;

import vibe.http.server;
import vibe.inet.webform;
import vibe.inet.url;
import vibe.web.web;

import std.algorithm;
import std.array;
import std.ascii;
import std.conv;
import std.datetime;
import std.format;
import std.math;
import std.meta;
import std.range;
import std.regex;
import std.string;
import std.traits;
import std.typecons;
import std.xml : encode;

///
unittest
{
	enum FavoriteFood
	{
		// enum UDAs require at least dmd 2.082.0
		//dfmt off
		@settingTranslation(null, "Fish") @settingTranslation("de", "Fisch") @settingTranslation("ja", "魚")
		fish,
		@settingTranslation(null, "Meat") @settingTranslation("de", "Fleisch") @settingTranslation("ja", "肉")
		meat,
		@settingTranslation(null, "Vegetables") @settingTranslation("de", "Gemüse") @settingTranslation("ja", "野菜")
		vegetables,
		@settingTranslation(null, "Fruits") @settingTranslation("de", "Obst") @settingTranslation("ja", "フルーツ")
		fruit
		//dfmt on
	}

	//dfmt off
	enum Country
	{
		none, AF, AX, AL, DZ, AS, AD, AO, AI, AQ, AG, AR, AM, AW, AC, AU, AT, AZ, BS, BH, BD, BB, BY, BE, BZ, BJ, BM,
		BT, BO, BA, BW, BR, IO, VG, BN, BG, BF, BI, KH, CM, CA, IC, CV, BQ, KY, CF, EA, TD, CL, CN, CX, CC, CO, KM,
		CG, CD, CK, CR, CI, HR, CU, CW, CY, CZ, DK, DG, DJ, DM, DO, EC, EG, SV, GQ, ER, EE, ET, FK, FO, FJ, FI, FR,
		GF, PF, TF, GA, GM, GE, DE, GH, GI, GR, GL, GD, GP, GU, GT, GG, GN, GW, GY, HT, HN, HK, HU, IS, IN, ID, IR,
		IQ, IE, IM, IL, IT, JM, JP, JE, JO, KZ, KE, KI, XK, KW, KG, LA, LV, LB, LS, LR, LY, LI, LT, LU, MO, MK, MG,
		MW, MY, MV, ML, MT, MH, MQ, MR, MU, YT, MX, FM, MD, MC, MN, ME, MS, MA, MZ, MM, NA, NR, NP, NL, NC, NZ, NI,
		NE, NG, NU, NF, KP, MP, NO, OM, PK, PW, PS, PA, PG, PY, PE, PH, PN, PL, PT, PR, QA, RE, RO, RU, RW, WS, SM,
		ST, SA, SN, RS, SC, SL, SG, SX, SK, SI, SB, SO, ZA, GS, KR, SS, ES, LK, BL, SH, KN, LC, MF, PM, VC, SD, SR,
		SJ, SZ, SE, CH, SY, TW, TJ, TZ, TH, TL, TG, TK, TO, TT, TA, TN, TR, TM, TC, TV, UM, VI, UG, UA, AE, GB, US,
		UY, UZ, VU, VA, VE, VN, WF, EH, YE, ZM, ZW
	}
	//dfmt on

	enum SocialMedia
	{
		twitter = 1 << 0,
		facebook = 1 << 1,
		myspace = 1 << 2,
	}

	struct Config
	{
		@requiredSetting // Must be filled out
		@nonAutomaticSetting // Don't auto sync when typing
		@emailSetting @settingPlaceholder("you@example.com") string userEmail;
		bool married;
		@urlSetting @settingLength(64) string resourceURI;
		// OR
		@settingLength(64) URL myWebsite;
		@multilineSetting @settingLength(1000) string aboutMe;
		@rangeSetting @settingRange(0, 10) int rating;
		@timeSetting string favoriteTimeOfDay;
		// OR
		TimeOfDay leastFavoriteTimeOfDay;
		@weekSetting string bestWeekYouHad;
		@monthSetting string firstMonthOfWork;
		// Timezone-less
		@datetimeLocalSetting string birthdayTimeAndDate;
		// OR
		DateTime myChildsBirthdayTimeAndDate;
		@dateSetting string myMothersBirthday;
		// OR
		Date myFathersBirthday;

		// inserts some html before some element
		@settingHTML("<hr/><p>Some cooler information now follows.</p>")

		@colorSetting @settingClass("wide") string favoriteColor;
		@disabledSetting string someInformation = "Just a hint, nothing changable";
		Country favoriteCountry;
		@settingTranslation("de", "Lieblingsessen")  // Translation of labels (only in translation contexts inside web interfaces)
		@settingTranslation("ja", "好きな食べ物")  // translations require at least vibe.d 0.8.1-alpha.3 to work
		@optionsSetting FavoriteFood favoriteFood;
		BitFlags!SocialMedia usedSocialMedia;
		@settingTitle("If you don't have any you can still say 1 because you have yourself.")  // Hover & validation text
		@settingMin(1) int numberOfFriends;
		@settingRange(0, 100) @settingStep(0.1) double englishSkillLevelPercentage;
		@settingMax(10) ubyte orderedProductCount;
		@settingLabel("Accept terms of service") @requiredSetting bool acceptTOS;
		@settingPattern(`(ISBN\s+)?\d{3}-\d-\d{5}-\d{3}-\d`) string favoriteBookISBN;
		@settingRows(8) string[] someStrings;
	}

	import vibe.vibe;

	auto router = new URLRouter;
	router.get("/style.css", serveStaticFile("styles/material.css"));
	router.get("/", staticRedirect("/settings"));

	enum html = `<html>
		<head>
			<title>Settings</title>
			<meta charset="utf-8"/>
			<link rel="stylesheet" href="/style.css"/>
			<style>
				body,html{background:#efefef;color:rgba(0,0,0,0.87);font-family:Roboto,"Segoe UI",sans-serif;}
				.settings{background:white;border-radius:2px;padding:16px;margin:32px auto;box-shadow:0 2px 5px rgba(0,0,0,0.3);max-width:600px;}
			</style>
		</head>
		<body>
			<div class="settings">
				<h2>Settings</h2>
				%s
			</div>
		</body>
	</html>`;

	struct TranslationContext
	{
		import std.meta;

		alias languages = AliasSeq!("en", "de", "ja");
	}

	Config settingsInstance; // You might fetch & save this per user, web-config only changes the struct

	@translationContext!TranslationContext class SettingsInterface
	{
		@safe void getSettings(scope HTTPServerRequest req, scope HTTPServerResponse res)
		{
			string settings = renderSettings(settingsInstance);
			res.writeBody(html.format(settings), "text/html");
		}

		@safe void postSettings(scope HTTPServerRequest req, scope HTTPServerResponse res)
		{
			// no-js & nonautomatic setting route
			auto ret = req.processSettings(settingsInstance);
			string settings = renderSettings(settingsInstance, ret);
			if (ret)
			{
				// Something changed, you can save here
			}
			res.writeBody(html.format(settings), "text/html");
		}

		@path("/api/setting") @safe void postJsSettings(scope HTTPServerRequest req,
				scope HTTPServerResponse res)
		{
			// js route called for each individual setting
			if (req.processSettings(settingsInstance))
			{
				// Save settings
				res.writeBody("", 204); // Send 200 or 204
			}
			else
				res.writeBody("", HTTPStatus.badRequest);
		}
	}

	router.registerWebInterface(new SettingsInterface);
	auto httpSettings = new HTTPServerSettings;
	httpSettings.port = 8080;
	listenHTTP(httpSettings, router);
	runApplication();
}

/// Generates a HTML form for a configuration struct `T` with automatic instant updates using AJAX.
/// The fields can be annotated with the various UDAs found in this module. (setting enums + structs) $(BR)
/// Supported types: `enum` (drop down lists or radio box lists), `std.typecons.BitFlags` (checkbox lists),
/// `bool` (checkbox), string types (text, email, url, etc.), numeric types (number), `std.datetime.DateTime`
/// (datetime-local), `std.datetime.Date` (date), `std.datetime.TimeOfDay` (time), `vibe.inet.URL` (url),
/// `string[]` (textarea taking each line)
/// Params:
///   T = the config struct type.
///   InputGenerator = the input generator to use.
///   javascript = the javascript code to embed including script tag.
///   value = an existing config value to prefill the inputs.
///   set = a bitflag field which settings have been set properly. Any bit set to 0 will show an error string for the given field. Defaults to all success.
///   formAttributes = extra HTML to put into the form.
///   action = Path to the form submit HTTP endpoint.
///   method = Method to use for the submit HTTP endpoint. Also replaces {method} inside the javascript template.
///   jsAction = Path to the javascript form submit HTTP endpoint. Replaces {action} inside the javascript template. If empty then no js will be emitted.
string renderSettings(T, InputGenerator = DefaultInputGenerator,
		string javascript = DefaultJavascriptCode)(T value, string formAttributes = "",
		string action = "/settings", string method = "POST", string jsAction = "/api/setting") @safe
{
	return renderSettings!(T, InputGenerator, javascript)(value, ulong.max,
			formAttributes, action, method, jsAction);
}

/// ditto
string renderSettings(T, InputGenerator = DefaultInputGenerator,
		string javascript = DefaultJavascriptCode)(T value, ulong set, string formAttributes = "",
		string action = "/settings", string method = "POST", string jsAction = "/api/setting") @safe
{
	method = method.toUpper;
	string[] settings;
	foreach (i, member; __traits(allMembers, T))
	{
		bool success = (set & (1 << cast(ulong) i)) != 0;
		settings ~= renderSetting!(InputGenerator, member)(value, success);
	}
	enum templates = getUDAs!(T, formTemplate);
	static if (templates.length)
	{
		static assert(templates.length == 1, "Can only have 1 formTemplate");
		enum formTemplate = templates[0].code;
	}
	else
		enum formTemplate = DefaultFormTemplate;
	string ret = formTemplate.format(action.encode, method.encode,
			formAttributes.length ? " " ~ formAttributes : "", settings.join());
	static if (javascript.length)
		if (jsAction.length)
			return ret ~ javascript.replace("{action}", jsAction).replace("{method}", method);
	return ret;
}

/// Generates a single input
string renderSetting(InputGenerator = DefaultInputGenerator, string name, Config)(
		ref Config config, bool success = true) @safe
{
	alias Member = AliasSeq!(__traits(getMember, config, name));
	auto value = __traits(getMember, config, name);
	alias T = Unqual!(typeof(value));
	enum isStringArray = isDynamicArray!T && isSomeString!(ElementType!T);
	enum isEmail = hasUDA!(Member[0], emailSetting);
	enum isUrl = hasUDA!(Member[0], urlSetting);
	enum isPassword = hasUDA!(Member[0], passwordSetting);
	enum isMultiline = hasUDA!(Member[0], multilineSetting) || isStringArray;
	enum isRange = hasUDA!(Member[0], rangeSetting);
	enum isTime = hasUDA!(Member[0], timeSetting) || is(T == TimeOfDay);
	enum isWeek = hasUDA!(Member[0], weekSetting);
	enum isMonth = hasUDA!(Member[0], monthSetting);
	enum isDatetimeLocal = hasUDA!(Member[0], datetimeLocalSetting) || is(T == DateTime);
	enum isDate = hasUDA!(Member[0], dateSetting) || is(T == Date);
	enum isColor = hasUDA!(Member[0], colorSetting);
	enum isDisabled = hasUDA!(Member[0], disabledSetting);
	enum isRequired = hasUDA!(Member[0], requiredSetting);
	enum isNoJS = hasUDA!(Member[0], nonAutomaticSetting);
	enum isOptions = hasUDA!(Member[0], optionsSetting);
	enum mins = getUDAs!(Member[0], settingMin);
	enum maxs = getUDAs!(Member[0], settingMax);
	enum ranges = getUDAs!(Member[0], settingRange);
	enum lengths = getUDAs!(Member[0], settingLength);
	enum steps = getUDAs!(Member[0], settingStep);
	enum patterns = getUDAs!(Member[0], settingPattern);
	enum titles = getUDAs!(Member[0], settingTitle);
	enum labels = getUDAs!(Member[0], settingLabel);
	enum rows = getUDAs!(Member[0], settingRows);
	enum translations = getUDAs!(Member[0], settingTranslation);
	enum enumTranslations = getUDAs!(Member[0], enumTranslation);
	enum html = getUDAs!(Member[0], settingHTML);
	enum classNames = getUDAs!(Member[0], settingClass);
	enum placeholder = getUDAs!(Member[0], settingPlaceholder);
	static if (labels.length)
		string uiName = labels[0].label;
	else
		string uiName = name.makeHumanName;
	static if (translations.length && is(typeof(language) == string))
	{
		auto lang = (() @trusted => language)();
		if (lang !is null)
			foreach (translation; translations)
				if (translation.language == lang)
					uiName = translation.label;
	}
	string raw = ` name="` ~ name ~ `"`;

	static if (classNames.length)
		enum string[] classes = [classNames].map!"a.className".array;
	else
		enum string[] classes = null;

	static if (isDisabled)
		raw ~= " disabled";
	else static if (!isNoJS)
		raw ~= ` onchange="updateSetting(this)"`;
	else
		raw ~= ` onchange="unlockForm(this)"`;
	static if (lengths.length)
	{
		auto minlength = lengths[0].min;
		auto maxlength = lengths[0].max;
		if (minlength > 0)
			raw ~= " minlength=\"" ~ minlength.to!string ~ "\"";
		if (maxlength > 0)
			raw ~= " maxlength=\"" ~ maxlength.to!string ~ "\"";
	}
	static if (patterns.length)
		raw ~= " pattern=\"" ~ patterns[0].regex.encode ~ "\"";
	else static if (isDatetimeLocal) // if browser doesn't support datetime-local
		raw ~= ` pattern="[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}"`;
	else static if (isTime) // if browser doesn't support time
		raw ~= ` pattern="[0-9]{2}:[0-9]{2}"`;
	else static if (isDate) // if browser doesn't support date
		raw ~= ` pattern="[0-9]{4}-[0-9]{2}-[0-9]{2}"`;
	static if (titles.length)
		raw ~= " title=\"" ~ titles[0].title.encode ~ "\"";
	static if (rows.length)
		raw ~= " rows=\"" ~ rows[0].count.to!string ~ "\"";
	static if (isRequired)
		raw ~= " required";
	static if (placeholder.length)
		raw ~= " placeholder=\"" ~ placeholder[0].placeholder.encode ~ "\"";

	static if (html.length > 0)
		enum string pre = [html].map!"a.raw".join("\n");
	else
		enum string pre = null;

	static if (is(T == enum))
	{
		static if (isOptions)
			return pre ~ InputGenerator.optionList!(T, enumTranslations)(uiName,
					value, raw, success, classes);
		else
			return pre ~ InputGenerator.dropdownList!(T, enumTranslations)(uiName,
					value, raw, success, classes);
	}
	else static if (is(T == BitFlags!Enum, Enum))
		return pre ~ InputGenerator.checkboxList!(Enum, enumTranslations)(uiName,
				value, raw, success, classes);
	else static if (is(T == bool))
		return pre ~ InputGenerator.checkbox(uiName, value, raw, success, classes);
	else static if (isSomeString!T || isStringArray)
	{
		static if (
			isEmail + isUrl + isMultiline + isTime + isWeek + isMonth + isDatetimeLocal
				+ isDate + isColor + isPassword > 1)
			static assert(false, "string setting " ~ name ~ " has multiple type related attributes");
		static if (isMultiline)
		{
			static if (isStringArray)
				return pre ~ InputGenerator.textarea(uiName, value.to!(string[])
						.join("\n"), raw, success, classes);
			else
				return pre ~ InputGenerator.textarea(uiName, value.to!string, raw, success, classes);
		}
		else
			return pre ~ InputGenerator.textfield(uiName, isEmail ? "email" : isUrl ? "url" : isTime ? "time"
					: isWeek ? "week" : isMonth ? "month" : isDatetimeLocal ? "datetime-local" : isDate ? "date" : isColor
					? "color" : isPassword ? "password" : "text", value.to!string, raw, success, classes);
	}
	else static if (is(T == DateTime))
		return pre ~ InputGenerator.textfield(uiName, "datetime-local",
				value.toISOExtString[0 .. 16], raw, success, classes);
	else static if (is(T == Date))
		return pre ~ InputGenerator.textfield(uiName, "date", value.toISOExtString,
				raw, success, classes);
	else static if (is(T == TimeOfDay))
		return pre ~ InputGenerator.textfield(uiName, "time",
				value.toISOExtString[0 .. 5], raw, success, classes);
	else static if (is(T == URL))
		return pre ~ InputGenerator.textfield(uiName, "url", value.toString, raw, success, classes);
	else static if (isNumeric!T)
	{
		double min, max;
		static if (mins.length)
			min = mins[0].min;
		static if (maxs.length)
			max = maxs[0].max;
		static if (ranges.length)
		{
			min = ranges[0].min;
			max = ranges[0].max;
		}
		if (min == min) // !isNaN
			raw ~= " min=\"" ~ min.to!string ~ "\"";
		if (max == max) // !isNaN
			raw ~= " max=\"" ~ max.to!string ~ "\"";
		static if (steps.length)
			raw ~= " step=\"" ~ steps[0].step.to!string ~ "\"";
		return pre ~ InputGenerator.textfield(uiName, isRange ? "range" : "number",
				value.to!string, raw, success, classes);
	}
	else
		static assert(false, "No setting generator for type " ~ T.stringof);
}

/**
	Function processing user input and validating for correctness. $(BR)$(BR)
	The following validations are done: $(BR)
	If the setting is a  `disabledSetting`, it will always skip this field. $(BR)
	If the setting has a `settingPattern`, it will validate the raw value (no matter what type) against this regex. $(BR)
	If the setting is a number, std.conv.to will be used to try to convert it to a double and then it will be cast to the type after checking min/max/step. $(BR)
	If the setting is a `BitFlags!T` every passed argument will be checked if it is contained inside the enum `T` or when submitted via JS only the one specified argument will get validated and inverted if starting with `!` $(BR)
	If the setting is an enum the value will be checked if it is contained inside the enum. $(BR)
	Additionally if the setting is a floating point number and there hasn't been a min/max setup but it is a `rangeSetting`, the number will be finite. $(BR)
	Integral numbers will always be checked if finite & if no range is given they will be clamped. $(BR)$(BR)
	Attributes for strings: $(BR)
		`emailSetting` is validated using `std.net.isemail.isEmail(CheckDns.no, EmailStatusCode.any)` $(BR)
		`urlSetting` is validated using `vibe.inet.url.URL` $(BR)
		`timeSetting` is checked against pattern `00:00` + checking if 0 <= hour < 24 && 0 <= minute < 60 $(BR)
		`weekSetting` is checked against pattern `0{4,6}-W00` + checking if 1 <= year <= 200000 && 1 <= week <= 52 $(BR)
		`monthSetting` is checked against pattern `0{4,6}-00` + checking if 1 <= year <= 200000 && 1 <= month <= 12 $(BR)
		`datetimeLocalSetting` is checked against pattern `0000-00-00T00:00` + passing into `std.datetime.SysTime.fromISOExtString`` $(BR)
		`dateSetting` is checked against pattern `0000-00-00` + checking the date using `std.datetime.Date` $(BR)
		`colorSetting` is checked against pattern `#FFFFFF` $(BR)
	Values using these attributes can be used without the need to validate the input.
	Params:
		strict = if false, values will be fixed to conform to the input instead of discarding them.
		Currently only fixing numbers and string lengths and new lines in single line strings is implemented.
	Returns: a bit array where each bit represents an input and is set to 1 if valid
	*/
ulong processSettings(T)(scope HTTPServerRequest req, ref T config,
		bool strict = false, bool post = true) @safe
{
	ulong valid;
	auto field = (post ? req.form : req.query).get("_field", "");
	foreach (i, member; __traits(allMembers, T))
	{
		if (field.length && field != member)
			continue;
		valid |= req.processSetting!member(config, strict, post) << cast(ulong) i;
	}
	return valid;
}

/// ditto
bool processSetting(string name, Config)(HTTPServerRequest req, ref Config config,
		bool strict = false, bool post = true) @safe
{
	alias Member = AliasSeq!(__traits(getMember, config, name));
	auto member = __traits(getMember, config, name);
	alias T = typeof(member);
	enum isStringArray = isDynamicArray!T && isSomeString!(ElementType!T);
	enum isEmail = hasUDA!(Member[0], emailSetting);
	enum isUrl = hasUDA!(Member[0], urlSetting);
	enum isPassword = hasUDA!(Member[0], passwordSetting);
	enum isMultiline = hasUDA!(Member[0], multilineSetting) || isStringArray;
	enum isRange = hasUDA!(Member[0], rangeSetting);
	enum isTime = hasUDA!(Member[0], timeSetting);
	enum isWeek = hasUDA!(Member[0], weekSetting);
	enum isMonth = hasUDA!(Member[0], monthSetting);
	enum isDatetimeLocal = hasUDA!(Member[0], datetimeLocalSetting);
	enum isDate = hasUDA!(Member[0], dateSetting);
	enum isColor = hasUDA!(Member[0], colorSetting);
	enum isDisabled = hasUDA!(Member[0], disabledSetting);
	enum isRequired = hasUDA!(Member[0], requiredSetting);
	enum mins = getUDAs!(Member[0], settingMin);
	enum maxs = getUDAs!(Member[0], settingMax);
	enum ranges = getUDAs!(Member[0], settingRange);
	enum lengths = getUDAs!(Member[0], settingLength);
	enum steps = getUDAs!(Member[0], settingStep);
	enum patterns = getUDAs!(Member[0], settingPattern);
	static if (isDisabled)
		return true;
	else
	{
		int minlength = int.min, maxlength = int.max;
		static if (lengths.length)
		{
			minlength = lengths[0].min;
			maxlength = lengths[0].max;
		}
		T oldval = member;
		T newval = oldval;
		FormFields form = post ? req.form : req.query;
		auto allvals = form.getAll(name);
		bool isJS = form.get("_field", "").length != 0;
		string rawval = allvals.length ? allvals[0] : "";
		static if (patterns.length)
			if (!matchFirst(rawval, ctRegex!(patterns[0].regex)))
				return false;
		static if (isRequired)
			if (!allvals.length)
				return false;
		if (minlength != int.min && rawval.length < minlength)
			return false;
		if (maxlength != int.max && rawval.length > maxlength)
		{
			if (strict)
				return false;
			else
				rawval.length = maxlength;
		}
		static if (is(T == enum))
		{
			try
			{
				newval = cast(T) rawval.to!(OriginalType!T);
				bool exists = false;
				foreach (val; EnumMembers!T)
					if (val == newval)
					{
						exists = true;
						break;
					}
				if (!exists)
					return false;
			}
			catch (ConvException)
			{
				return false;
			}
		}
		else static if (is(T : BitFlags!Enum, Enum))
		{
			try
			{
				if (!rawval.length)
					return false;
				if (isJS)
				{
					bool negate = rawval[0] == '!';
					if (negate)
						rawval = rawval[1 .. $];
					auto enumType = cast(Enum) rawval.to!(OriginalType!Enum);
					bool exists = false;
					foreach (val; EnumMembers!Enum)
						if (val == enumType)
						{
							exists = true;
							break;
						}
					if (!exists)
						return false;
					if (negate)
						newval = oldval & ~T(enumType);
					else
						newval = oldval | enumType;
				}
				else
				{
					newval = T.init;
					foreach (rawval1; allvals)
					{
						auto enumType = cast(Enum) rawval1.to!(OriginalType!Enum);
						bool exists = false;
						foreach (val; EnumMembers!Enum)
							if (val == enumType)
							{
								exists = true;
								break;
							}
						if (!exists)
							return false;
						newval |= enumType;
					}
				}
			}
			catch (ConvException)
			{
				return false;
			}
		}
		else static if (is(T == bool))
			newval = allvals.length > 0;
		else static if (isSomeString!T || isStringArray)
		{
			static if (
				isEmail + isUrl + isMultiline + isTime + isWeek + isMonth + isDatetimeLocal
					+ isDate + isColor + isPassword > 1)
				static assert(false, "string setting " ~ name ~ " has multiple type related attributes");
			static if (isMultiline)
			{
				static if (isStringArray)
				{
					static if (__traits(compiles, newval = rawval.lineSplitter.filter!"a.length".array))
						newval = rawval.lineSplitter.filter!"a.length".array;
					else
						newval = rawval.lineSplitter
							.filter!"a.length"
							.map!(to!(ElementType!T))
							.array;
				}
				else
					newval = rawval;
			}
			else
			{
				if (rawval.length)
				{
					if (strict && rawval.indexOfAny("\r\n") != -1)
						return false;
					else
						rawval = rawval.tr("\r\n", "  ");
					static if (isEmail)
					{
						rawval = rawval.strip;
						import std.net.isemail;

						if ((()@trusted => !rawval.isEmail(CheckDns.no, EmailStatusCode.any))())
							return false;
						newval = rawval;
					}
					else static if (isUrl)
					{
						try
						{
							newval = URL(rawval.strip).toString;
						}
						catch (Exception)
						{
							return false;
						}
					}
					else static if (isTime)
					{
						rawval = rawval.strip;
						if (!validateTimeString(rawval))
							return false;
						newval = rawval;
					}
					else static if (isWeek)
					{
						rawval = rawval.strip;
						if (!validateWeekString(rawval))
							return false;
						newval = rawval;
					}
					else static if (isMonth)
					{
						rawval = rawval.strip;
						if (!validateMonthString(rawval))
							return false;
						newval = rawval;
					}
					else static if (isDatetimeLocal)
					{
						rawval = rawval.strip;
						if (!validateDatetimeLocalString(rawval))
							return false;
						newval = rawval;
					}
					else static if (isDate)
					{
						rawval = rawval.strip;
						if (!validateDateString(rawval))
							return false;
						newval = rawval;
					}
					else static if (isColor)
					{
						rawval = rawval.strip;
						if (!validateColorString(rawval))
							return false;
						newval = rawval;
					}
					else
						newval = rawval;
				}
				else
				{
					newval = "";
				}
			}
		}
		else static if (is(T == DateTime))
		{
			rawval = rawval.strip;
			if (!validateDatetimeLocalString(rawval))
				return false;
			newval = DateTime.fromISOExtString(rawval ~ ":00");
		}
		else static if (is(T == Date))
		{
			rawval = rawval.strip;
			if (!validateDateString(rawval))
				return false;
			newval = Date.fromISOExtString(rawval);
		}
		else static if (is(T == TimeOfDay))
		{
			rawval = rawval.strip;
			if (!validateTimeString(rawval))
				return false;
			newval = TimeOfDay.fromISOExtString(rawval ~ ":00");
		}
		else static if (is(T == URL))
		{
			try
			{
				newval = URL(rawval.strip);
			}
			catch (Exception)
			{
				return false;
			}
		}
		else static if (isNumeric!T)
		{
			double min, max;
			static if (isIntegral!T)
			{
				min = T.min;
				max = T.max;
			}
			static if (mins.length)
				min = mins[0].min;
			static if (maxs.length)
				max = maxs[0].max;
			static if (ranges.length)
			{
				min = ranges[0].min;
				max = ranges[0].max;
			}
			double step = 1;
			static if (steps.length)
				step = steps[0].step;
			try
			{
				double val = rawval.to!double;
				if (min == min && val < min)
				{
					if (strict)
						return false;
					else
						val = min;
				}
				if (max == max && val > max)
				{
					if (strict)
						return false;
					else
						val = max;
				}
				val = floor(val / step) * step;
				bool isFinite = val == val && val != double.infinity && val != -double.infinity;
				static if (isRange && isFloatingPoint!T)
				{
					if (!isFinite)
						return false;
				}
				static if (!isFloatingPoint!T)
					if (!isFinite)
						return false;
				newval = cast(T) val;
			}
			catch (ConvException)
			{
				return false;
			}
		}
		else
			static assert(false, "No setting parser for type " ~ T.stringof);
		__traits(getMember, config, name) = newval;
		return true;
	}
}

/// Validates s == pattern "00:00"
bool validateTimeString(string s) @safe
{
	if (s.length != 5)
		return false;
	if (!s[0].isDigit || !s[1].isDigit || s[2] != ':' || !s[3].isDigit || !s[4].isDigit)
		return false;
	ubyte h = s[0 .. 2].to!ubyte;
	ubyte m = s[3 .. 5].to!ubyte;
	if (h >= 24)
		return false;
	if (m >= 60)
		return false;
	return true;
}

/// Validates s == pattern "0{4,6}-W00"
bool validateWeekString(string s) @safe
{
	if (s.length < 8 || s.length > 10)
		return false;
	auto dash = s.indexOf('-');
	if (dash == -1 || dash != s.length - 4)
		return false;
	if (s[dash + 1] != 'W' || !s[dash + 2].isDigit || !s[dash + 3].isDigit)
		return false;
	auto y = s[0 .. dash];
	auto w = s[dash + 2 .. $].to!ubyte;
	if (w < 1 || w > 52)
		return false;
	try
	{
		auto yi = y.to!uint;
		if (yi < 1 || yi > 200_000)
			return false;
		return true;
	}
	catch (ConvException)
	{
		return false;
	}
}

/// Validates s == pattern "0{4,6}-00"
bool validateMonthString(string s) @safe
{
	if (s.length < 7 || s.length > 9)
		return false;
	auto dash = s.indexOf('-');
	if (dash == -1 || dash != s.length - 3)
		return false;
	if (!s[dash + 1].isDigit || !s[dash + 2].isDigit)
		return false;
	auto y = s[0 .. dash];
	auto m = s[dash + 1 .. $].to!ubyte;
	if (m < 1 || m > 12)
		return false;
	try
	{
		auto yi = y.to!uint;
		if (yi < 1 || yi > 200_000)
			return false;
		return true;
	}
	catch (ConvException)
	{
		return false;
	}
}

/// Validates s == pattern "0000-00-00T00:00"
bool validateDatetimeLocalString(string s) @safe
{
	if (s.length != 16)
		return false;
	if (!s[0].isDigit || !s[1].isDigit || !s[2].isDigit || !s[3].isDigit
			|| s[4] != '-' || !s[5].isDigit || !s[6].isDigit || s[7] != '-'
			|| !s[8].isDigit || !s[9].isDigit || s[10] != 'T' || !s[11].isDigit
			|| !s[12].isDigit || s[13] != ':' || !s[14].isDigit || !s[15].isDigit)
		return false;
	try
	{
		return SysTime.fromISOExtString(s ~ ":00") != SysTime.init;
	}
	catch (DateTimeException)
	{
		return false;
	}
}

/// Validates s == pattern "0000-00-00"
bool validateDateString(string s) @safe
{
	if (s.length != 10)
		return false;
	if (!s[0].isDigit || !s[1].isDigit || !s[2].isDigit || !s[3].isDigit
			|| s[4] != '-' || !s[5].isDigit || !s[6].isDigit || s[7] != '-'
			|| !s[8].isDigit || !s[9].isDigit)
		return false;
	try
	{
		return Date(s[0 .. 4].to!int, s[5 .. 7].to!int, s[8 .. 10].to!int) != Date.init;
	}
	catch (DateTimeException)
	{
		return false;
	}
}

/// Validates s == pattern "#xxxxxx"
bool validateColorString(string s) @safe
{
	if (s.length != 7)
		return false;
	if (s[0] != '#' || !s[1].isHexDigit || !s[2].isHexDigit || !s[3].isHexDigit
			|| !s[4].isHexDigit || !s[5].isHexDigit || !s[6].isHexDigit)
		return false;
	return true;
}

/// Converts correctBookISBN_number to "Correct Book ISBN Number"
string makeHumanName(string identifier) @safe
{
	string humanName;
	bool wasUpper = true;
	bool wasSpace = true;
	foreach (c; identifier)
	{
		if (c >= 'A' && c <= 'Z')
		{
			if (!wasUpper)
			{
				wasUpper = true;
				humanName ~= ' ';
			}
		}
		else
			wasUpper = false;
		if (c == '_')
		{
			wasSpace = true;
			humanName ~= ' ';
		}
		else if (wasSpace)
		{
			humanName ~= [c].toUpper;
			wasSpace = false;
		}
		else
			humanName ~= c;
	}
	return humanName.strip;
}

/// Controls how the input HTML is generated
struct DefaultInputGenerator
{
@safe:
	private static string errorString(bool success)
	{
		if (success)
			return "";
		else
			return `<span class="error">Please fill out this field correctly.</span>`;
	}

	/// Called for single line input types
	static string textfield(string name, string type, string value, string raw,
			bool success, string[] classes)
	{
		if (!success)
			classes ~= "error";
		const className = classes.length ? ` class="` ~ classes.join(" ") ~ `"` : "";
		return `<label` ~ className ~ `><span>%s</span><input type="%s" value="%s"%s/></label>`.format(name.encode,
				type.encode, value.encode, raw) ~ errorString(success);
	}

	/// Called for textareas
	static string textarea(string name, string value, string raw, bool success, string[] classes)
	{
		if (!success)
			classes ~= "error";
		const className = classes.length ? ` class="` ~ classes.join(" ") ~ `"` : "";
		return `<label` ~ className ~ `><span>%s</span><textarea%s>%s</textarea></label>`.format(name.encode,
				raw, value.encode) ~ errorString(success);
	}

	/// Called for boolean values
	static string checkbox(string name, bool checked, string raw, bool success, string[] classes)
	{
		classes ~= "checkbox";
		if (!success)
			classes ~= "error";
		const className = ` class="` ~ classes.join(" ") ~ `"`;
		return `<label` ~ className ~ `><input type="checkbox" %s%s/><span>%s</span></label>`.format(checked
				? "checked" : "", raw, name.encode) ~ errorString(success);
	}

	/// Called for enums disabled as select (you need to iterate over the enum members)
	static string dropdownList(Enum, translations...)(string name, Enum value,
			string raw, bool success, string[] classes)
	{
		classes ~= "select";
		if (!success)
			classes ~= "error";
		const className = ` class="` ~ classes.join(" ") ~ `"`;
		string ret = `<label` ~ className ~ `><span>` ~ name.encode ~ `</span><select` ~ raw ~ `>`;
		foreach (member; __traits(allMembers, Enum))
			ret ~= `<option value="` ~ (cast(OriginalType!Enum) __traits(getMember,
					Enum, member)).to!string.encode ~ `"` ~ (value == __traits(getMember,
					Enum, member) ? " selected" : "") ~ `>` ~ __traits(getMember, Enum, member)
				.translateEnum!(Enum, translations)(member.makeHumanName) ~ `</option>`;
		return ret ~ "</select></label>" ~ errorString(success);
	}

	/// Called for enums displayed as list of radio boxes (you need to iterate over the enum members)
	static string optionList(Enum, translations...)(string name, Enum value,
			string raw, bool success, string[] classes)
	{
		classes ~= "checkbox options";
		if (!success)
			classes ~= "error";
		const className = ` class="` ~ classes.join(" ") ~ `"`;
		string ret = `<label` ~ className ~ `><span>` ~ name.encode ~ "</span>";
		foreach (member; __traits(allMembers, Enum))
			ret ~= checkbox(__traits(getMember, Enum, member).translateEnum!(Enum,
					translations)(member.makeHumanName), value == __traits(getMember, Enum, member),
					raw ~ ` value="` ~ (cast(OriginalType!Enum) __traits(getMember, Enum,
						member)).to!string.encode ~ `"`, true, classes).replace(`type="checkbox"`,
					`type="radio"`);
		return ret ~ `</label>` ~ errorString(success);
	}

	/// Called for BitFlags displayed as list of checkboxes.
	static string checkboxList(Enum, translations...)(string name,
			BitFlags!Enum value, string raw, bool success, string[] classes)
	{
		classes ~= "checkbox flags";
		if (!success)
			classes ~= "error";
		const className = ` class="` ~ classes.join(" ") ~ `"`;
		string ret = `<label` ~ className ~ `><span>` ~ name.encode ~ "</span>";
		foreach (member; __traits(allMembers, Enum))
			ret ~= checkbox(__traits(getMember, Enum, member).translateEnum!(Enum,
					translations)(member.makeHumanName), !!(value & __traits(getMember, Enum,
					member)), raw ~ ` value="` ~ (cast(OriginalType!Enum) __traits(getMember,
					Enum, member)).to!string.encode ~ `"`, true, classes);
		return ret ~ `</label>` ~ errorString(success);
	}
}

/// Adds type="email" to string types
enum emailSetting;
/// Adds type="url" to string types
enum urlSetting;
/// Adds type="password" to string types
enum passwordSetting;
/// Makes string types textareas
enum multilineSetting;
/// Adds type="range" to numeric types
enum rangeSetting;
/// Adds type="time" to string types
enum timeSetting;
/// Adds type="week" to string types
enum weekSetting;
/// Adds type="month" to string types
enum monthSetting;
/// Adds type="datetime-local" to string types
enum datetimeLocalSetting;
/// Adds type="date" to string types
enum dateSetting;
/// Adds type="color" to string types
enum colorSetting;
/// Adds disabled to any input
enum disabledSetting;
/// Adds required to any input
enum requiredSetting;
/// Disables automatic JS saving when changing the input
enum nonAutomaticSetting;
/// Changes a dropdown to a radio button list
enum optionsSetting;

/// Changes the min="" attribute for numerical values
struct settingMin
{
	///
	double min;
}

/// Changes the max="" attribute for numerical values
struct settingMax
{
	///
	double max;
}

/// Changes the step="" attribute for numerical values
struct settingStep
{
	///
	double step;
}

/// Changes the min="" and max="" attribute for numerical values
struct settingRange
{
	///
	double min, max;
}

/// Changes the minlength="" and maxlength="" attribute for string values
struct settingLength
{
	///
	int max, min;
}

/// Changes the pattern="regex" attribute
struct settingPattern
{
	///
	string regex;
}

/// Changes the title="" attribute for custom error messages & tooltips
struct settingTitle
{
	///
	string title;
}

/// Overrides the label of the input
struct settingLabel
{
	///
	string label;
}

/// Sets the number of rows of a textarea
struct settingRows
{
	///
	int count;
}

/// Changes the label if the current language (using a WebInterface translation context) matches the given one.
/// You need at least vibe-d v0.8.1-alpha.3 to use this UDA.
struct settingTranslation
{
	///
	string language;
	///
	string label;
}

/// Relables all enum member names for a language. Give `null` as first argument to change the default language
struct enumTranslation
{
	///
	string language;
	///
	string[] translations;
}

/// Inserts raw HTML code before an element.
struct settingHTML
{
	///
	string raw;
}

/// Inserts raw CSS class name for an element.
struct settingClass
{
	///
	string className;
}

/// Changes how the form HTML template looks
struct formTemplate
{
	/// Contains the std.format formattable template code. $(BR)
	/// Arguments in order are: string action, string method, string formArguments, string html $(BR)
	/// html is last so you can embed it using %4$s without throwing an orphan arguments exception.
	string code;
}

/// Sets the placeholder attribute for elements that support it
struct settingPlaceholder
{
	///
	string placeholder;
}

string translateEnum(T, translations...)(T value, string fallback) @safe
		if (is(T == enum))
{
	static if (translations.length)
	{
		static if (is(typeof(language) == string))
			auto lang = (() @trusted => language)();
		enum NumEnumMembers = [EnumMembers!T].length;
		foreach (i, other; EnumMembers!T)
		{
			if (other == value)
			{
				string ret = null;
				foreach (translation; translations)
				{
					static assert(translation.translations.length == NumEnumMembers,
							"Translation missing some values. Set them to null to skip");
					if (translation.language is null && ret is null)
						ret = translation.translations[i];
					else static if (is(typeof(language) == string))
					{
						if (translation.language == lang)
							ret = translation.translations[i];
					}
				}
				return ret is null ? fallback : ret;
			}
		}
	}
	else static if (__traits(compiles, __traits(getAttributes,
			__traits(getMember, T, __traits(allMembers, T)[0]))))
	{
		foreach (i, other; __traits(allMembers, T))
		{
			if (__traits(getMember, T, other) == value)
			{
				static if (is(typeof(language) == string))
					auto lang = (() @trusted => language)();
				string ret = null;
				foreach (attr; __traits(getAttributes, __traits(getMember, T, other)))
				{
					static if (is(typeof(attr) == settingTranslation))
					{
						if (attr.language is null && ret is null)
							ret = attr.label;
						else static if (is(typeof(language) == string))
						{
							if (attr.language == lang)
								ret = attr.label;
						}
					}
				}
				return ret is null ? fallback : ret;
			}
		}
	}
	return fallback;
}

/// Contains a updateSetting(input) function which automatically sends changes to the server.
enum DefaultJavascriptCode = q{<script id="_setting_script_">
	var timeouts = {};
	function updateSetting(input) {
		clearTimeout(timeouts[input]);
		timeouts[input] = setTimeout(function() {
			var form = input;
			while (form && form.tagName != "FORM")
				form = form.parentElement;
			var submit = form.querySelector ? form.querySelector("input[type=submit]") : undefined;
			if (submit)
				submit.disabled = false;
			name = input.name;
			function attachError(elem, content) {
				var label = elem;
				while (label && label.tagName != "LABEL")
					label = label.parentElement;
				if (label)
					label.classList.add("error");
				var err = document.createElement("span");
				err.className = "error";
				err.textContent = content;
				err.style.padding = "4px";
				elem.parentElement.insertBefore(err, elem.nextSibling);
				setTimeout(function() { err.parentElement.removeChild(err); }, 2500);
			}
			var label = input;
			while (label && label.tagName != "LABEL")
				label = label.parentElement;
			if (label)
				label.classList.remove("error");
			var isFlags = false;
			var flagLabel = label;
			while (flagLabel) {
				if (flagLabel.classList.contains("flags")) {
					isFlags = true;
					break;
				}
				flagLabel = flagLabel.parentElement;
			}
			var valid = input.checkValidity ? input.checkValidity() : true;
			if (!valid) {
				attachError(input, input.title || "Please fill out this input correctly.");
				return;
			}
			var stillRequesting = true;
			setTimeout(function () {
				if (stillRequesting)
					input.disabled = true;
			}, 100);
			var xhr = new XMLHttpRequest();
			var method = "{method}";
			var action = "{action}";
			var query = "_field=" + encodeURIComponent(name);
			if (input.type != "checkbox" || input.checked)
				query += '&' + encodeURIComponent(name) + '=' + encodeURIComponent(input.value);
			else if (isFlags)
				query += '&' + encodeURIComponent(name) + "=!" + encodeURIComponent(input.value);
			if (method != "POST")
				action += query;
			xhr.onload = function () {
				if (xhr.status != 200 && xhr.status != 204)
					attachError(input, input.title || "Please fill out this field correctly.");
				else {
					submit.value = "Saved!";
					setTimeout(function() { submit.value = "Save"; }, 3000);
				}
				stillRequesting = false;
				input.disabled = false;
			};
			xhr.onerror = function () {
				stillRequesting = false;
				input.disabled = false;
				submit.disabled = false;
			};
			xhr.open(method, action);
			xhr.setRequestHeader("Content-type", "application/x-www-form-urlencoded");
			if (method == "POST")
				xhr.send(query);
			else
				xhr.send();
			submit.disabled = true;
		}, 50);
	}
	function unlockForm(input) {
		var form = input;
		while (form && form.tagName != "FORM")
			form = form.parentElement;
		form.querySelector("input[type=submit]").disabled = false;
	}
	(document.currentScript || document.getElementById("_setting_script_")).previousSibling.querySelector("input[type=submit]").disabled = true;
</script>};

enum DefaultFormTemplate = `<form action="%s" method="%s"%s>%s<input type="submit" value="Save"/></form>`;
