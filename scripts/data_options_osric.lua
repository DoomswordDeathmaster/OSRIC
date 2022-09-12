function onInit()
    registerOptions()
end

function registerOptions()
    -- Changed to a threshold to account for differences between 1e and OSRIC
    -- OptionsManager.registerOption2(
    --     "HouseRule_DeathsDoor",
    --     false,
    --     "option_header_adnd_options",
    --     "option_label_ADND_DEATHSDOOR",
    --     "option_entry_cycler",
    --     {
    --         labels = "option_val_zero|option_val_minus_three",
    --         values = "exactlyZero|zeroToMinusThree",
    --         baselabel = "option_val_zero_or_less",
    --         baseval = "zeroOrLess",
    --         default = "zeroOrLess"
    --     }
    -- )
end