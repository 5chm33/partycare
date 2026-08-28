local Spellbook = {};

local unpack_args = table.unpack or unpack;

-- FFXI job IDs used by Ashita's player interface.
local JOB_WHITEMAGE = 3;
local JOB_SCHOLAR = 20;

-- The dedicated PartyCare remedy spells have stable spell IDs and job-level
-- requirements.  These values are used only as a fallback when an Ashita
-- resource object is incomplete or indexed differently by a client build.
-- The player spellbook remains the authority on whether the spell is learned.
local REMEDY_SPELLS = {
    ['Poisona'] = {id = 14, levels = {[JOB_WHITEMAGE] = 6, [JOB_SCHOLAR] = 10}},
    ['Paralyna'] = {id = 15, levels = {[JOB_WHITEMAGE] = 9, [JOB_SCHOLAR] = 12}},
    ['Blindna'] = {id = 16, levels = {[JOB_WHITEMAGE] = 14, [JOB_SCHOLAR] = 17}},
    ['Silena'] = {id = 17, levels = {[JOB_WHITEMAGE] = 19, [JOB_SCHOLAR] = 22}},
    ['Stona'] = {id = 18, levels = {[JOB_WHITEMAGE] = 39, [JOB_SCHOLAR] = 50}},
    ['Viruna'] = {id = 19, levels = {[JOB_WHITEMAGE] = 34, [JOB_SCHOLAR] = 46}},
    ['Cursna'] = {id = 20, levels = {[JOB_WHITEMAGE] = 29, [JOB_SCHOLAR] = 32}},
    ['Erase'] = {id = 143, levels = {[JOB_WHITEMAGE] = 32, [JOB_SCHOLAR] = 39}},
    ['Dispel'] = {id = 260, levels = {[5] = 32, [20] = 32}},
    ['Haste'] = {id = 57, levels = {[JOB_WHITEMAGE] = 40, [5] = 48}},
    ['Refresh'] = {id = 109, levels = {[5] = 41}},
};

local function call(object, method, ...)
    if not object then return nil; end
    local args, count = {...}, select('#', ...);
    local ok, value = pcall(function()
        local fn = object[method];
        if type(fn) ~= 'function' then return nil; end
        return fn(object, unpack_args(args, 1, count));
    end);
    if ok then return value; end
    return nil;
end

local function field(object, key)
    local ok, value = pcall(function() return object and object[key]; end);
    if ok then return value; end
    return nil;
end

local function has_spell(player, spell_id)
    local value = call(player, 'HasSpell', spell_id);
    if type(value) == 'boolean' then return value; end
    if type(value) == 'number' then return value ~= 0; end
    return nil;
end

local function read_number(primary, fallback)
    local value = tonumber(primary);
    if value ~= nil then return value; end
    return tonumber(fallback);
end

local function current_jobs(player)
    local raw = call(player, 'GetRawStructure');
    local main_job = read_number(call(player, 'GetMainJob'), field(raw, 'MainJob'));
    local main_level = read_number(call(player, 'GetMainJobLevel'), field(raw, 'MainJobLevel'));
    local sub_job = read_number(call(player, 'GetSubJob'), field(raw, 'SubJob'));
    local sub_level = read_number(call(player, 'GetSubJobLevel'), field(raw, 'SubJobLevel')) or 0;
    if main_job == nil or main_level == nil then return nil; end
    return {
        main_job = main_job,
        main_level = main_level,
        sub_job = sub_job,
        sub_level = sub_level,
    };
end

local function level_for_job(levels, job_id)
    if type(levels) ~= 'table' or type(job_id) ~= 'number' then return nil; end
    return tonumber(levels[job_id]);
end

local function usable_from_level_table(levels, jobs)
    if type(levels) ~= 'table' or not jobs then return nil; end
    local main_required = level_for_job(levels, jobs.main_job);
    local sub_required = level_for_job(levels, jobs.sub_job);
    if main_required and main_required > 0 and jobs.main_level >= main_required then return true; end
    if sub_required and sub_required > 0 and jobs.sub_level >= sub_required then return true; end
    if main_required ~= nil or sub_required ~= nil then return false; end
    return nil;
end

local function resource_level_table(resource)
    local requirements = field(resource, 'LevelRequired');
    if not requirements then return nil; end
    local levels = {};
    for job_id = 1, 24 do
        -- Ashita's documented resource array reserves slot 1 for job ID 0.
        local required = tonumber(field(requirements, job_id + 1));
        if required ~= nil then levels[job_id] = required; end
    end
    return next(levels) and levels or nil;
end

local function find_resource(resources, spell_name, spell_info)
    if not resources then return nil; end
    -- A stable ID avoids localization/name lookup differences.  Name lookup
    -- remains a fallback for user-configured valid spells outside the table.
    local resource = spell_info and call(resources, 'GetSpellById', spell_info.id) or nil;
    if resource then return resource; end
    return call(resources, 'GetSpellByName', spell_name, 0);
end

local function resolve_spell_id(resource, spell_info)
    return tonumber(field(resource, 'Id') or field(resource, 'id') or field(resource, 'Index'))
        or (spell_info and spell_info.id)
        or nil;
end

-- Returns a map whose false values mean the spell is definitively unavailable.
-- Missing map values deliberately preserve the existing manual-button behavior
-- while player or resource data is still loading.
function Spellbook.availability(memory, rules)
    local availability = {};
    local player = call(memory, 'GetPlayer');
    local spell_data_ready = player and call(player, 'HasSpellData') or nil;
    if type(spell_data_ready) == 'number' then spell_data_ready = spell_data_ready ~= 0; end
    local jobs = current_jobs(player);
    -- Ashita's spell-resource view can briefly report not-ready after a job,
    -- zone, or Level Sync change. Standard PartyCare spells have audited IDs
    -- and level tables, so continue using HasSpell plus live job levels for
    -- them instead of silently removing valid alerts during that interval.
    if not player or not jobs then return availability; end
    local resources = spell_data_ready == true and AshitaCore and call(AshitaCore, 'GetResourceManager') or nil;

    for _, rule in pairs(rules or {}) do
        local spell_name = type(rule) == 'table' and rule.spell or nil;
        if type(spell_name) == 'string' and availability[spell_name] == nil then
            local spell_info = REMEDY_SPELLS[spell_name];
            local resource = find_resource(resources, spell_name, spell_info);
            local spell_id = resolve_spell_id(resource, spell_info);
            -- Preserve false here as well. Lua's `id and value or nil`
            -- pattern turns a legitimate false HasSpell result into nil,
            -- which would incorrectly leave the remedy eligible.
            local learned = nil;
            if spell_id then learned = has_spell(player, spell_id); end

            if learned == false then
                availability[spell_name] = false;
            elseif learned == true then
                -- Do not use `condition and value or nil` here: in Lua that
                -- converts an explicit false eligibility result into nil and
                -- lets a learned but level-locked spell leak into the remedy
                -- list. Preserve false as a definitive unavailable result.
                local fallback_usable = nil;
                if spell_info then
                    fallback_usable = usable_from_level_table(spell_info.levels, jobs);
                end
                local resource_usable = usable_from_level_table(resource_level_table(resource), jobs);

                -- For PartyCare's standard remedy spells, the audited table
                -- is authoritative.  Some Ashita/HorizonXI resource views
                -- expose LevelRequired with an incompatible index layout; an
                -- affirmative value from that view must never override the
                -- player's actual dynamic main/subjob level.  User-configured
                -- spells outside this table continue to use resource data.
                if spell_info then
                    availability[spell_name] = fallback_usable;
                elseif resource_usable ~= nil then
                    availability[spell_name] = resource_usable;
                end
            end
        end
    end
    return availability;
end

return Spellbook;
