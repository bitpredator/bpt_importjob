local lastPlayerSuccess = {}

if Config.MaxInService ~= -1 then
    TriggerEvent('esx_service:activateService', 'import', Config.MaxInService)
end

TriggerEvent('esx_phone:registerNumber', 'import', _U('import_client'), true, true)
TriggerEvent('esx_society:registerSociety', 'import', 'Import', 'society_import', 'society_import', 'society_import', {
    type = 'public'
})

RegisterNetEvent('bpt_importjob:getStockItem')
AddEventHandler('bpt_importjob:getStockItem', function(itemName, count)
    local xPlayer = ESX.GetPlayerFromId(source)

    if xPlayer.job.name == 'import' then
        TriggerEvent('esx_addoninventory:getSharedInventory', 'society_import', function(inventory)
            local item = inventory.getItem(itemName)

            -- is there enough in the society?
            if count > 0 and item.count >= count then
                -- can the player carry the said amount of x item?
                if xPlayer.canCarryItem(itemName, count) then
                    inventory.removeItem(itemName, count)
                    xPlayer.addInventoryItem(itemName, count)
                    xPlayer.showNotification(_U('have_withdrawn', count, item.label))
                else
                    xPlayer.showNotification(_U('player_cannot_hold'))
                end
            else
                xPlayer.showNotification(_U('quantity_invalid'))
            end
        end)
    else
        print(('[bpt_importjob] [^3WARNING^7] %s attempted to trigger getStockItem'):format(xPlayer.identifier))
    end
end)

ESX.RegisterServerCallback('bpt_importjob:getStockItems', function(source, cb)
    TriggerEvent('esx_addoninventory:getSharedInventory', 'society_import', function(inventory)
        cb(inventory.items)
    end)
end)

RegisterNetEvent('bpt_importjob:putStockItems')
AddEventHandler('bpt_importjob:putStockItems', function(itemName, count)
    local xPlayer = ESX.GetPlayerFromId(source)

    if xPlayer.job.name == 'import' then
        TriggerEvent('esx_addoninventory:getSharedInventory', 'society_import', function(inventory)
            local item = inventory.getItem(itemName)

            if item.count > 0 then
                xPlayer.removeInventoryItem(itemName, count)
                inventory.addItem(itemName, count)
                xPlayer.showNotification(_U('have_deposited', count, item.label))
            else
                xPlayer.showNotification(_U('quantity_invalid'))
            end
        end)
    else
        print(('[bpt_importjob] [^3WARNING^7] %s attempted to trigger putStockItems'):format(xPlayer.identifier))
    end
end)

ESX.RegisterServerCallback('bpt_importjob:getPlayerInventory', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    local items = xPlayer.inventory

    cb({
        items = items
    })
end)
