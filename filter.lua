module 'rosterfilter.filter'

include 'T'
include 'rosterfilter'

local member_cache = {}
local rank_cache = {}
local total_count = 0
local online_count = 0


function M.index_to_rank(index)
    return rank_cache[index]
end


function M.rank_to_index(rank)
    for i, name in pairs(rank_cache) do
        if strlower(name) == strlower(rank) then return i; end;
    end
end


M.filters = {
    ['class'] = {
        input_type = 'string',
        validator = function(class_name)
            return function(member)
                return strlower(member.class) == strlower(class_name)
            end
        end
    },
    ['rank'] = {
        input_type = 'string',
        validator = function(rank)
            return function(member)
                local modifier_index = strfind(rank, "[+-]", -1)
                if modifier_index ~= nil then
                    local rank_name = strsub(rank, 1, modifier_index - 1)
                    local modifier = strsub(rank, modifier_index)
                    local rank_index = rank_to_index(rank_name);
                    if modifier == "+" then
                        return member.rank_index <= rank_index
                    else
                        return member.rank_index >= rank_index
                    end
                end
                return strlower(member.rank) == strlower(rank)
            end
        end
    },
    ['online'] = {
        input_type = '',
        validator = function()
            return function(member)
                return member.online
            end
        end
    },
    ['raid'] = {
        input_type = '',
        validator = function()
            return function(member)
                if GetNumRaidMembers() == 0 then return false; end;
                for i = 1, 40 do
                    local name,_,_,_,_,_,_,_,_,_,_ = GetRaidRosterInfo(i)
                    if name and strlower(name) == strlower(member.name) then return true; end;
                end
                return false;
            end
        end
    },
    ['zone'] = {
        input_type = 'string',
        validator = function(zone)
            return function(member)
                return strfind(strlower(member.zone), strlower(zone))
            end
        end
    },
    ['offline'] = {
        input_type = 'string',
        validator = function(days)
            return function(member)
                return member.offline and (member.offline / 24) >= (tonumber(days) or 0)
            end
        end
    },
    ['role'] = {
        input_type = 'string',
        validator = function(role)
            return function(member)
                local cls = strlower(member.class);
                local role = strlower(role);
                if role == 'heal' or role == 'healer' then
                    return cls == 'priest' or cls == 'paladin' or cls == 'druid' or cls == 'shaman';
                elseif role == 'dps' then
                    return cls == 'rogue' or cls == 'warrior' or cls == 'mage' or cls == 'warlock' or cls=='hunter';
                elseif role == 'caster' then
                    return cls == 'mage' or cls == 'warlock' or cls == 'shaman' or cls == 'druid';
                elseif role == 'tank' then
                    return cls == 'warrior' or cls == 'druid' or cls == 'paladin';
                elseif role == 'melee' then
                    return cls == 'warrior' or cls == 'rogue' or cls == 'paladin' or cls == 'druid';
                elseif role == 'ranged' then
                    return cls =='mage' or cls == 'hunter' or cls=='warlock';
                end
                return false
            end
        end
    },
    ['lvl'] = {
        input_type == 'string',
        validator = function(str)
            return function(member)
                local min = 1;
                local max = 60;

                local parts = str and map(split(str, '-'), function(part) return trim(part) end) or T

                if parts[1] ~= '' and parts[1] ~= nil then
                    min = tonumber(parts[1]) or 1
                    max = tonumber(parts[2]) or min
                end
                
                return (member.level >= min) and (member.level <= max);
            end
        end
    }
}


function M.parse_filter_string(str)
    local used_filters = {}

    local parts = str and map(split(str, '/'), function(part) return strlower(trim(part)) end) or ''

    local i = 1;
    while parts[i] do
        if filters[parts[i]] then
            local input_type = filters[parts[i]].input_type
            if input_type ~= '' then
                tinsert(used_filters, {filter=parts[i], args=(parts[i + 1] or '')})
                i = i + 1
            else
                tinsert(used_filters, {filter=parts[i], args=''})
            end
        end
        i = i + 1
    end

    return used_filters
end

function M.Query(str)
    local used_filters = parse_filter_string(str)

    UpdateRoster()

    local working_set = {}

    for i = 1, table.getn(member_cache) do
        tinsert(working_set, i)
    end

    for i, filter in pairs(used_filters) do
        if filters[filter.filter] then
            local validator = filters[filter.filter].validator(filter.args)
            local subset = {}
            for _,index in pairs(working_set) do
                local member = member_cache[index]
                if validator(member) then
                    tinsert(subset, index)
                end
            end
            working_set = subset
        end
    end

    if table.getn(used_filters) == 0 and string.len(str) > 0 then
        local subset = {}
        for _,index in pairs(working_set) do
            local member = member_cache[index]
            local qry = strlower(str)
            local search = strlower(member.name..member.rank..member.zone..member.note..member.officer_note)
            if string.find(search, qry) then
                tinsert(subset, index)
            end
        end
        working_set = subset
    end

    local rows = T
    for _,index in pairs(working_set) do
        local member = member_cache[index]
        
        local online_color;
        if member.online then
            online_color = color.green
        else
            online_color = color.red
        end

        local class_color = color.class[strlower(member.class)]

        tinsert(rows, O(
            'cols', A(
                O('value', online_color('*'), 'sort', member.online),
                O('value', class_color(member.name), 'sort', member.name),
                O('value', member.level, 'sort', tonumber(member.level)),
                O('value', member.rank, 'sort', member.rank_index),
                O('value', member.zone, 'sort', member.zone),
                O('value', member.note, 'sort', member.note)
            ),
            'record', member
        ))
    end

    return rows or nil
end


function M.UpdateRoster()
    member_cache = {}
    rank_cache = {}
    total_count = 0
    online_count = 0

    local guild_members = GetNumGuildMembers(true);
    
    for i = 1, guild_members do
        local name, rank, rank_index, level, class, zone, note, officer_note, online = GetGuildRosterInfo(i);
        
        if name then
            local member = {
                name = name,
                rank = rank,
                rank_index = rank_index,
                level = level,
                class = class,
                zone = zone,
                note = note,
                officer_note = officer_note,
                online = online,
                offline = 0
            };
            if not online then
                local years, months, days, hours = GetGuildRosterLastOnline(i);
                local toff = (((years*12)+months)*30.5+days)*24+hours;
                member.offline = toff
            else
                online_count = online_count + 1
            end
            tinsert(member_cache, member)

            total_count = total_count + 1
        end
    end

    for i = 1, GuildControlGetNumRanks() do
        rank_cache[i - 1] = GuildControlGetRankName(i);
    end
end


function M.PlayerCount()
    return online_count, total_count
end