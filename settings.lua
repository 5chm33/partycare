-- PartyCare Settings
-- Open /partycare config in game to customize bindings, layout, and remedy priorities.

return {
    version = 16,
    ui = {
        visible = true,
        locked = false,
        settings_open = false,
        x = 24,
        y = 180,
        settings_x = 360,
        settings_y = 180,
        width = 420,
        height = 0,
        member_height = 24,
        layout = 'grid',
        grid_columns = 2,
        card_width = 200,
        card_height = 74,
        background_alpha = 0.28,
        minimal_mode = true,
        adaptive_scale = true,
        font_scale = 1.00,
        show_mp = true,
        show_status = true,
        show_action_bar = false,
        show_remedy_button = true,
        show_alliance_2 = false,
        show_alliance_3 = false,
        full_alliance_preview = false, -- Display-only 18-card layout preview for arranging the panel.
    },
    thresholds = {warning_hp = 55, critical_hp = 30},
    actions = {
        primary = {label = 'Cure IV', spell = 'Cure IV', enabled = true},
        secondary = {label = 'Regen', spell = 'Regen', enabled = true},
        emergency = {label = 'Cure V', spell = 'Cure V', enabled = true},
        refresh = {label = 'Refresh', spell = 'Refresh', enabled = false},
    },
    remedies = {
        -- Dedicated status-removal spells.
        paralyze = {spell = 'Paralyna', enabled = true, priority = 100},
        doom = {spell = 'Cursna', enabled = true, priority = 97},
        petrify = {spell = 'Stona', enabled = true, priority = 96},
        curse = {spell = 'Cursna', enabled = true, priority = 95},
        plague = {spell = 'Viruna', enabled = true, priority = 94},
        disease = {spell = 'Viruna', enabled = true, priority = 93},
        silence = {spell = 'Silena', enabled = true, priority = 70},
        blind = {spell = 'Blindna', enabled = true, priority = 60},
        poison = {spell = 'Poisona', enabled = true, priority = 50},

        -- Erase removes one enabled matching effect per deliberate Remedy click.
        gravity = {spell = 'Erase', enabled = true, priority = 90},
        bind = {spell = 'Erase', enabled = true, priority = 89},
        slow = {spell = 'Erase', enabled = true, priority = 85},
        bio = {spell = 'Erase', enabled = true, priority = 45},
        dia = {spell = 'Erase', enabled = true, priority = 45},
        addle = {spell = 'Erase', enabled = true, priority = 44},
        flash = {spell = 'Erase', enabled = true, priority = 43},
        stun = {spell = 'Erase', enabled = true, priority = 42},
        elegy = {spell = 'Erase', enabled = true, priority = 40},
        requiem = {spell = 'Erase', enabled = true, priority = 39},
        helix = {spell = 'Erase', enabled = true, priority = 38},
        elemental_dot = {spell = 'Erase', enabled = true, priority = 10}, -- Burn, Frost, Choke, Rasp, Shock, Drown
        stat_down = {spell = 'Erase', enabled = true, priority = 5},
    },
    review = {review_click_cast_enabled = false, approval_status = 'PENDING_HORIZONXI_REVIEW'},
    live_test = {manual_dispatch_enabled = true, emergency_stop = false},
    direct_click = {
        enabled = true,
        left = {spell = 'Cure IV', enabled = true},
        right = {spell = 'Regen', enabled = false},
        middle = {spell = 'Cure V', enabled = false},
        mouse4 = {spell = 'Cure III', enabled = false}, -- First mouse side button.
        mouse5 = {spell = 'Cure V', enabled = false}, -- Second mouse side button.
        wheel_up = {spell = 'Regen', enabled = false}, -- Scroll upward while hovering a card.
        wheel_down = {spell = 'Cure III', enabled = false}, -- Scroll downward while hovering a card.
    },
    colors = {
        healthy = {0.15, 0.70, 0.35, 1.00},
        warning = {0.92, 0.63, 0.12, 1.00},
        critical = {0.86, 0.22, 0.22, 1.00},
        inactive = {0.32, 0.34, 0.38, 1.00},
    },
};
