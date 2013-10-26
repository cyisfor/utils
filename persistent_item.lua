local getPath = minetest.require("utils","getpath")
local serialize,deserialize = minetest.require("utils","serialize")

maxId = (function() 
    local idfile, err = io.open(getPath(minetest.get_modpath('utils'),'maxId.dat'),"r")
    if err then return 1 end
    local number = tonumber(idfile:read("*all"))
    idfile:close()
    return number
end)()

local function saveMax()
    local idfile = assert(io.open(getPath(minetest.get_modpath('utils'),'maxId.dat'),"w"))
    idfile:write(tostring(maxId))
    idfile:close()
end

local function makeId()
    id = maxId
    maxId = maxId + 1
    saveMax()
    return id
end

local function transferId(src,dest)
    if src == nil then
        get = makeId
    elseif src.id ~= nil then
        function get() 
            if src == nil or src.id == nil then
                return makeId
            else
                return src.id
            end
        end
    else
        function get()
            id = src:get_int('id')
            if id == 0 then
                return makeId()
            end
        end
    end
    if type(dest) == 'table' then        
        dest.id = get()
    else
        dest:set_int(get())
    end
end

return {
    on_activate = function(self, id)
        self.id = tonumber(id)
    end,
    get_staticdata = function(self)
        return tostring(self.id)
    end,
    on_place = function(item, placer, pointed)
        if not minetest.check_player_privs(placer:get_player_name(),{books=true}) then
            -- needs to tell them?
            return item
        end
        return minetest.item_place(item, placer, pointed)
    end,
    after_place_node = function(place, placer, item)    
        itemmeta = item:get_metadata()
        if itemmeta then
            itemmeta = minetest.deserialize(itemmeta)
        end
        transferId(itemmeta,minetest.get_meta(place))
    end,
    -- item_drop transfers the item metadata to the entity already
    
    on_dig = function(pos, node, digger)
        -- we have to copy minetest.node_dig because it throws away metadata when going
        -- from node -> drops
        -- since drops are often not even the same item

        local def = ItemStack({name=node.name}):get_definition()
        -- Check if def ~= 0 because we always want to be able to remove unknown nodes
        if #def ~= 0 and not def.diggable or (def.can_dig and not def.can_dig(pos,digger)) then
                minetest.log("info", digger:get_player_name() .. " tried to dig "
                        .. node.name .. " which is not diggable "
                        .. minetest.pos_to_string(pos))
                return
        end

        minetest.log('action', digger:get_player_name() .. " digs "
                .. node.name .. " at " .. minetest.pos_to_string(pos))

        local wielded = digger:get_wielded_item()
        local drops = minetest.get_node_drops(node.name, wielded:get_name())        

        -- Wear out tool
        if not minetest.setting_getbool("creative_mode") then
                local tp = wielded:get_tool_capabilities()
                local dp = minetest.get_dig_params(def.groups, tp)
                wielded:add_wear(dp.wear)
                digger:set_wielded_item(wielded)
        end

        -- this is our inserted metadata preservation
        
        itemmeta = {}
        transferId(minetest.get_meta(node),itemmeta)
        itemmeta = minetest.serialize(itemmeta)
        for i,drop in ipairs(drops) do
            drop = ItemStack(drop)
            -- twiddles moustache
            drop:set_metadata(itemmeta)
            drops[i] = drop
        end

        -- end our stuff

        minetest.handle_node_drops(pos, drops, digger)

        local oldmetadata = nil
        if def.after_dig_node then
                oldmetadata = minetest.get_meta(pos):to_table()
        end        

        -- Remove node and update
        minetest.remove_node(pos)

        -- Run callback
        if def.after_dig_node then
                -- Copy pos and node because callback can modify them
                local pos_copy = {x=pos.x, y=pos.y, z=pos.z}
                local node_copy = {name=node.name, param1=node.param1, param2=node.param2}
                def.after_dig_node(pos_copy, node_copy, oldmetadata, digger)
        end        

        -- Run script hook
        local _, callback
        for _, callback in ipairs(minetest.registered_on_dignodes) do
                -- Copy pos and node because callback can modify them
                local pos_copy = {x=pos.x, y=pos.y, z=pos.z}
                local node_copy = {name=node.name, param1=node.param1, param2=node.param2}
                callback(pos_copy, node_copy, digger)
        end
    end
}
