function onInit()
	registerOptions()
end

function registerOptions()
	-- Allow Ability Checks
	-- nothing in OSRIC or 1e for this
	-- Set this to deprecating/use options and house rules extension instead
	OptionsManager.registerOption2(
		"abilityCheckAllow",
		false,
		"option_header_osric",
		"option_label_osric_ability_check_allow",
		"option_entry_cycler",
		{labels = "option_val_off", values = "off", baselabel = "option_val_on", baseval = "on", default = "on"}
	)

	-- OSRIC Initiative Delay
	-- delay is counter to AD&D text, so call it an OSRIC option
	-- TODO: set initiative to 7 on click
	OptionsManager.registerOption2(
		"useOsricInitiativeDelay",
		false,
		"option_header_osric",
		"option_label_osric_initiative_delay_allow",
		"option_entry_cycler",
		{labels = "option_val_off", values = "off", baselabel = "option_val_on", baseval = "on", default = "on"}
	)

	-- OSRIC Initiative Grouping Swap
	-- Available in OSRIC, set as an AD&D/OSRIC option, rename to something else with AD&D/OSRIC terms
	OptionsManager.registerOption2(
		"useOsricInitiativeSwap",
		false,
		"option_header_osric",
		"option_label_osric_initiative_osric_swap",
		"option_entry_cycler",
		{labels = "option_val_on", values = "on", baselabel = "option_val_off", baseval = "off", default = "off"}
	)

	-- 1e/OSRIC matrices, saves and ability properties
	-- keep
	OptionsManager.registerOption2(
		"useOsricMonsterMatrix",
		false,
		"option_header_osric",
		"option_label_osric_osric_monster_matrices",
		"option_entry_cycler",
		{labels = "option_val_on", values = "on", baselabel = "option_val_off", baseval = "off", default = "off"}
	)

	-- Allow Initiative Modifiers
	-- modify only for ranged (which will have to be manually done). Don't allow
	-- OptionsManager.registerOption2("initiativeModifiersAllow", false, "option_header_osric", "option_label_adnd_op_hr_initiative_modifiers_allow", "option_entry_cycler",
	-- 	{ labels = "option_val_off", values = "off", baselabel = "option_val_on", baseval = "on", default = "on" });

	-- Allow Tied Group Initiative
	-- tied initiative is part of OSRIC/AD&D
	-- force allow tied
	-- OptionsManager.registerOption2("initiativeTiesAllow", false, "option_header_osric", "option_label_adnd_op_hr_initiative_ties_allow", "option_entry_cycler",
	-- { labels = "option_val_on", values = "on", baselabel = "option_val_off", baseval = "off", default = "off" });

	-- Initiative Die
	-- d6 only - Let's make the die always be d6
	-- OptionsManager.registerOption2("initiativeDie", false, "option_header_osric", "option_label_adnd_op_hr_initiative_die", "option_entry_cycler",
	-- 	{ labels = "option_val_d6", values = "d6", baselabel = "option_val_d10", baseval = "d10", default = "d10" });

	-- Initiative Ordering
	-- only one way to handle it raw, remove
	-- OptionsManager.registerOption2("initiativeOrdering", false, "option_header_osric", "option_label_adnd_op_hr_initiative_ordering", "option_entry_cycler",
	-- 	{ labels = "option_val_descending", values = "descending", baselabel = "option_val_ascending", baseval = "ascending", default = "ascending" });

	-- Initiative Grouping
	-- All grouped, per AD&D and OSRIC, make both the default
	-- OptionsManager.registerOption2("initiativeGrouping", false, "option_header_osric", "option_label_adnd_op_hr_initiative_grouping", "option_entry_cycler",
	-- 	{ labels = "option_val_pc|option_val_both|option_val_neither", values = "pc|both|neither", baselabel = "option_val_npc", baseval = "npc", default = "npc" });

	-- Surprise Die
	-- d6 only, remove other options by default
	-- OptionsManager.registerOption2("surpriseDie", false, "option_header_osric", "option_label_adnd_op_hr_surprise_die", "option_entry_cycler",
	-- 	{ labels = "option_val_d6|option_val_d12", values = "d6|d12", baselabel = "option_val_d10", baseval = "d10", default = "d10" })

	-- Use 2e Kits
	-- always off, remove kits by deafult
	-- OptionsManager.registerOption2("use2eKits", false, "option_header_osric", "option_label_adnd_op_hr_use_2e_kits", "option_entry_cycler",
	-- 	{ labels = "option_val_off", values = "off", baselabel = "option_val_on", baseval = "on", default = "on" });

	-- Round Start Reset Init
	-- always do this, keep
	-- OptionsManager.registerOption2("roundStartResetInit", false, "option_header_osric", "option_label_adnd_op_hr_round_start_reset_init", "option_entry_cycler",
	-- 	{ labels = "option_val_on", values = "on", baselabel = "option_val_off", baseval = "off", default = "off" });

	-- 1e matrices, saves and ability properties
	-- keep
	-- OptionsManager.registerOption2("add1eProperties", false, "option_header_osric", "option_label_adnd_op_hr_add1e_properties", "option_entry_cycler",
	-- 	{ labels = "option_val_on", values = "on", baselabel = "option_val_off", baseval = "off", default = "off" });
end
