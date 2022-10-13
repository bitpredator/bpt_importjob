local HasAlreadyEnteredMarker, OnJob, IsNearCustomer, CustomerIsEnteringVehicle, CustomerEnteredVehicle,
    CurrentActionData = false, false, false, false, false, {}
local CurrentCustomer, CurrentCustomerBlip, DestinationBlip, targetCoords, LastZone, CurrentAction, CurrentActionMsg

RegisterNetEvent('esx:playerLoaded')
AddEventHandler('esx:playerLoaded', function(xPlayer)
    ESX.PlayerData = xPlayer
    ESX.PlayerLoaded = true
end)

RegisterNetEvent('esx:onPlayerLogout')
AddEventHandler('esx:onPlayerLogout', function()
    ESX.PlayerLoaded = false
    ESX.PlayerData = {}
end)

RegisterNetEvent('esx:setJob')
AddEventHandler('esx:setJob', function(job)
    ESX.PlayerData.job = job
end)

function DrawSub(msg, time)
    ClearPrints()
    BeginTextCommandPrint('STRING')
    AddTextComponentSubstringPlayerName(msg)
    EndTextCommandPrint(time, 1)
end

function ShowLoadingPromt(msg, time, type)
    CreateThread(function()
        Wait(0)

        BeginTextCommandBusyspinnerOn('STRING')
        AddTextComponentSubstringPlayerName(msg)
        EndTextCommandBusyspinnerOn(type)
        Wait(time)

        BusyspinnerOff()
    end)
end

function GetRandomWalkingNPC()
        local search = {}
        local peds = GetGamePool("CPed")
    
        for i = 1, #peds, 1 do
            if IsPedHuman(peds[i]) and IsPedWalking(peds[i]) and not IsPedAPlayer(peds[i]) then
                search[#search+1] = peds[i]
            end
        end
    
        if #search > 0 then
            return search[math.random(#search)]
        end
end

function OpenCloakroom()
    ESX.UI.Menu.CloseAll()

    ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'import_cloakroom', {
        title = _U('cloakroom_menu'),
        align = 'top-left',
        elements = {{
            label = _U('wear_citizen'),
            value = 'wear_citizen'
        }, {
            label = _U('wear_work'),
            value = 'wear_work'
        }}
    }, function(data, menu)
        if data.current.value == 'wear_citizen' then
            ESX.TriggerServerCallback('esx_skin:getPlayerSkin', function(skin)
                TriggerEvent('skinchanger:loadSkin', skin)
            end)
        elseif data.current.value == 'wear_work' then
            ESX.TriggerServerCallback('esx_skin:getPlayerSkin', function(skin, jobSkin)
                if skin.sex == 0 then
                    TriggerEvent('skinchanger:loadClothes', skin, jobSkin.skin_male)
                else
                    TriggerEvent('skinchanger:loadClothes', skin, jobSkin.skin_female)
                end
            end)
        end
    end, function(data, menu)
        menu.close()

        CurrentAction = 'cloakroom'
        CurrentActionMsg = _U('cloakroom_prompt')
        CurrentActionData = {}
    end)
end

function OpenVehicleSpawnerMenu()
    ESX.UI.Menu.CloseAll()

    local elements = {}

    if Config.EnableSocietyOwnedVehicles then

        ESX.TriggerServerCallback('esx_society:getVehiclesInGarage', function(vehicles)

            for i = 1, #vehicles, 1 do
                table.insert(elements, {
                    label = GetDisplayNameFromVehicleModel(vehicles[i].model) .. ' [' .. vehicles[i].plate .. ']',
                    value = vehicles[i]
                })
            end

            ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'vehicle_spawner', {
                title = _U('spawn_veh'),
                align = 'top-left',
                elements = elements
            }, function(data, menu)
                if not ESX.Game.IsSpawnPointClear(Config.Zones.VehicleSpawnPoint.Pos, 5.0) then
                    ESX.ShowNotification(_U('spawnpoint_blocked'))
                    return
                end

                menu.close()

                local vehicleProps = data.current.value
                ESX.TriggerServerCallback("bpt_importjob:SpawnVehicle", function()
                    return
                end, vehicleProps.model, vehicleProps)
                TriggerServerEvent('esx_society:removeVehicleFromGarage', 'import', vehicleProps)
            end, function(data, menu)
                CurrentAction = 'vehicle_spawner'
                CurrentActionMsg = _U('spawner_prompt')
                CurrentActionData = {}

                menu.close()
            end)
        end, 'import')

    else -- not society vehicles

        ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'vehicle_spawner', {
            title = _U('spawn_veh'),
            align = 'top-left',
            elements = Config.AuthorizedVehicles
        }, function(data, menu)
            if not ESX.Game.IsSpawnPointClear(Config.Zones.VehicleSpawnPoint.Pos, 5.0) then
                ESX.ShowNotification(_U('spawnpoint_blocked'))
                return
            end
            ESX.TriggerServerCallback("bpt_importjob:SpawnVehicle", function()
                ESX.ShowNotification(_U('vehicle_spawned'), "success")
            end, "rumpo", {plate = "BPT IMPORT"})
            menu.close()
        end, function(data, menu)
            CurrentAction = 'vehicle_spawner'
            CurrentActionMsg = _U('spawner_prompt')
            CurrentActionData = {}

            menu.close()
        end)
    end
end

function DeleteJobVehicle()
    local playerPed = PlayerPedId()

    if Config.EnableSocietyOwnedVehicles then
        local vehicleProps = ESX.Game.GetVehicleProperties(CurrentActionData.vehicle)
        TriggerServerEvent('esx_society:putVehicleInGarage', 'import', vehicleProps)
        ESX.Game.DeleteVehicle(CurrentActionData.vehicle)
    else
        if IsInAuthorizedVehicle() then
            ESX.Game.DeleteVehicle(CurrentActionData.vehicle)

            if Config.MaxInService ~= -1 then
                TriggerServerEvent('esx_service:disableService', 'import')
            end
        else
            ESX.ShowNotification(_U('only_import'))
        end
    end
end

function OpenImportActionsMenu()
    local elements = {{
        label = _U('deposit_stock'),
        value = 'put_stock'
    }, {
        label = _U('take_stock'),
        value = 'get_stock'
    }}

    if Config.EnablePlayerManagement and ESX.PlayerData.job ~= nil and ESX.PlayerData.job.grade_name == 'boss' then
        table.insert(elements, {
            label = _U('boss_actions'),
            value = 'boss_actions'
        })
    end

    ESX.UI.Menu.CloseAll()

    ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'import_actions', {
        title = _U('import'),
        align = 'top-left',
        elements = elements
    }, function(data, menu)

        if Config.OxInventory and (data.current.value == 'put_stock' or data.current.value == 'get_stock') then
            exports.ox_inventory:openInventory('stash', 'society_import')
            return ESX.UI.Menu.CloseAll()
        elseif data.current.value == 'put_stock' then
            OpenPutStocksMenu()
        elseif data.current.value == 'get_stock' then
            OpenGetStocksMenu()
        elseif data.current.value == 'boss_actions' then
            TriggerEvent('esx_society:openBossMenu', 'import', function(data, menu)
                menu.close()
            end)
        end

    end, function(data, menu)
        menu.close()

        CurrentAction = 'import_actions_menu'
        CurrentActionMsg = _U('press_to_open')
        CurrentActionData = {}
    end)
end

function OpenMobileImportActionsMenu()
    ESX.UI.Menu.CloseAll()

    ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'mobile_import_actions', {
        title = _U('import'),
        align = 'top-left',
        elements = {{
            label = _U('billing'),
            value = 'billing'
        }}
    }, function(data, menu)
        if data.current.value == 'billing' then

            ESX.UI.Menu.Open('dialog', GetCurrentResourceName(), 'billing', {
                title = _U('invoice_amount')
            }, function(data, menu)

                local amount = tonumber(data.value)
                if amount == nil then
                    ESX.ShowNotification(_U('amount_invalid'))
                else
                    menu.close()
                    local closestPlayer, closestDistance = ESX.Game.GetClosestPlayer()
                    if closestPlayer == -1 or closestDistance > 3.0 then
                        ESX.ShowNotification(_U('no_players_near'))
                    else
                        TriggerServerEvent('esx_billing:sendBill', GetPlayerServerId(closestPlayer), 'society_import',
                            'import', amount)
                        ESX.ShowNotification(_U('billing_sent'))
                    end

                end

            end, function(data, menu)
                menu.close()
            end)
        end
    end, function(data, menu)
        menu.close()
    end)
end

function IsInAuthorizedVehicle()
    local playerPed = PlayerPedId()
    local vehModel = GetEntityModel(GetVehiclePedIsIn(playerPed, false))

    for i = 1, #Config.AuthorizedVehicles, 1 do
        if vehModel == joaat(Config.AuthorizedVehicles[i].model) then
            return true
        end
    end

    return false
end

function OpenGetStocksMenu()
    ESX.TriggerServerCallback('bpt_importjob:getStockItems', function(items)
        local elements = {}

        for i = 1, #items, 1 do
            table.insert(elements, {
                label = 'x' .. items[i].count .. ' ' .. items[i].label,
                value = items[i].name
            })
        end

        ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'stocks_menu', {
            title = _U('import_stock'),
            align = 'top-left',
            elements = elements
        }, function(data, menu)
            local itemName = data.current.value

            ESX.UI.Menu.Open('dialog', GetCurrentResourceName(), 'stocks_menu_get_item_count', {
                title = _U('quantity')
            }, function(data2, menu2)
                local count = tonumber(data2.value)

                if count == nil then
                    ESX.ShowNotification(_U('quantity_invalid'))
                else
                    menu2.close()
                    menu.close()

                    -- todo: refresh on callback
                    TriggerServerEvent('bpt_importjob:getStockItem', itemName, count)
                    Wait(1000)
                    OpenGetStocksMenu()
                end
            end, function(data2, menu2)
                menu2.close()
            end)
        end, function(data, menu)
            menu.close()
        end)
    end)
end

function OpenPutStocksMenu()
    ESX.TriggerServerCallback('bpt_importjob:getPlayerInventory', function(inventory)
        local elements = {}

        for i = 1, #inventory.items, 1 do
            local item = inventory.items[i]

            if item.count > 0 then
                table.insert(elements, {
                    label = item.label .. ' x' .. item.count,
                    type = 'item_standard',
                    value = item.name
                })
            end
        end

        ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'stocks_menu', {
            title = _U('inventory'),
            align = 'top-left',
            elements = elements
        }, function(data, menu)
            local itemName = data.current.value

            ESX.UI.Menu.Open('dialog', GetCurrentResourceName(), 'stocks_menu_put_item_count', {
                title = _U('quantity')
            }, function(data2, menu2)
                local count = tonumber(data2.value)

                if count == nil then
                    ESX.ShowNotification(_U('quantity_invalid'))
                else
                    menu2.close()
                    menu.close()

                    -- todo: refresh on callback
                    TriggerServerEvent('bpt_importjob:putStockItems', itemName, count)
                    Wait(1000)
                    OpenPutStocksMenu()
                end
            end, function(data2, menu2)
                menu2.close()
            end)
        end, function(data, menu)
            menu.close()
        end)
    end)
end

AddEventHandler('bpt_importjob:hasEnteredMarker', function(zone)
    if zone == 'VehicleSpawner' then
        CurrentAction = 'vehicle_spawner'
        CurrentActionMsg = _U('spawner_prompt')
        CurrentActionData = {}
    elseif zone == 'VehicleDeleter' then
        local playerPed = PlayerPedId()
        local vehicle = GetVehiclePedIsIn(playerPed, false)

        if IsPedInAnyVehicle(playerPed, false) and GetPedInVehicleSeat(vehicle, -1) == playerPed then
            CurrentAction = 'delete_vehicle'
            CurrentActionMsg = _U('store_veh')
            CurrentActionData = {
                vehicle = vehicle
            }
        end
    elseif zone == 'ImportActions' then
        CurrentAction = 'import_actions_menu'
        CurrentActionMsg = _U('press_to_open')
        CurrentActionData = {}

    elseif zone == 'Cloakroom' then
        CurrentAction = 'cloakroom'
        CurrentActionMsg = _U('cloakroom_prompt')
        CurrentActionData = {}
    end
end)

AddEventHandler('bpt_importjob:hasExitedMarker', function(zone)
    ESX.UI.Menu.CloseAll()
    CurrentAction = nil
end)

RegisterNetEvent('esx_phone:loaded')
AddEventHandler('esx_phone:loaded', function(phoneNumber, contacts)
    local specialContact = {
        name = _U('phone_import'),
        number = 'import',
        base64Icon = 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAGGElEQVR4XsWWW2gd1xWGv7Vn5pyRj47ut8iOYlmyWxw1KSZN4riOW6eFuCYldaBtIL1Ag4NNmt5ICORCaNKXlF6oCy0hpSoJKW4bp7Sk6YNb01RuLq4d0pQ0kWQrshVJ1uX46HJ0zpy5rCKfQYgjCUs4kA+GtTd786+ftW8jqsqHibB6TLZn2zeq09ZTWAIWCxACoTI1E+6v+eSpXwHRqkVZPcmqlBzCApLQ8dk3IWVKMQlYcHG81OODNmD6D7d9VQrTSbwsH73lFKePtvOxXSfn48U+Xpb58fl5gPmgl6DiR19PZN4+G7iODY4liIAACqiCHyp+AFvb7ML3uot1QP5yDUim292RtIqfU6Lr8wFVDVV8AsPKRDAxzYkKm2kj5sSFuUT3+v2FXkDXakD6f+7c1NGS7Ml0Pkah6jq8mhvwUy7Cyijg5Aoks6/hTp+k7vRjDJ73dmw8WHxlJRM2y5Nsb3GPDuzsZURbGMsUmRkoUPByCMrKCG7SobJiO01X7OKq6utoe3XX34BaoLDaCljj3faTcu3j3z3T+iADwzNYEmKIWcGAIAtqqkKAxZa2Sja/tY+59/7y48aveQ8A4Woq4Fa3bj7Q1/EgwWRAZ52NMTYCWAZEwIhBUEQgUiVQ8IpKvqj4kVJCyGRCRrb+hvap+gPAo0DuUhWQfx2q29u+t/vPmarbCLwII7qQTEQRLbUtBJ2PAkZARBADqkLBV/I+BGrhpoSN577FWz3P3XbTvRMvAlpuwC4crv5jwtK9RAFSu46+G8cRwESxQ+K2gESAgCiIASHuA8YCBdSUohdCKGCF0H6iGc3MgrEphvKi+6Wp24HABioSjuxFARGobyJ5OMXEiGHW6iLR0EmifhPJDddj3CoqtuwEZSkCc73/RAvTeEOvU5w8gz/Zj2TfoLFFibZvQrI5EOFiPqgAZmzApTINKKgPiW20ffkXtPXfA9Ysmf5/kHn/T0z8e5rpCS5JVQNUN1ayfn2a+qvT2JWboOOXMPg0ms6C2IAAWTc2ACPeupdbm5yb8XNQczOM90DOB0uoa01Ttz5FZ6IL3Ctg9DUIg7Lto2DZ0HIDFEbAz4AaiBRyxZJe9U7kQg84KYbH/JeJESANXPXwXdWffvzu1p+x5VE4/ST4EyAOoEAI6WsAhdx/AYulhJDqAgRm/hPPEVAfnAboeAB6v88jTw/f98SzU8eAwbgC5IGRg3vsW3E7YewYzJwF4wAhikJURGqvBO8ouAFIxBI0gqgPEp9B86+ASSAIEEHhbEnX7eTgnrFbn3iW5+K82EAA+M2V+d2EeRj9K/izIBYgJZGwCO4Gzm/uRQOwDEsI41PSfPZ+xJsBKwFo6dOwpJvezMU84Md5sSmRCM51uacGbUKvHWEjAKIelXaGJqePyopjzFTdx6Ef/gDbjo3FKEoQKN+8/yEqRt8jf67IaNDBnF9FZFwERRGspMM20+XC64nym9AMhSE1G7fjbb0bCQsISi6vFCdPMPzuUwR9AcmOKQ7cew+WZcq3IGEYMZeb4p13sjjmU4TX7Cfdtp0oDAFBbZfk/37N0MALAKbcAKaY4yPeuwy3t2J8MAKDIxDVd1Lz8Ts599vb8Wameen532GspRWIQmXPHV8k0BquvPP3TOSgsRmiCFRAHWh9420Gi7nl34JaBen7O7UWRMD740AQ7yEf8nW78TIeN+7+PCIsOYaqMJHxqKtpJ++D+DA5ARsawEmASqzv1Cz7FjRpbt951tUAOcAHdNEUC7C5NAJo7Dws03CAFMxlkdSRZmCMxaq8ejKuVwSqIJfzA61LmyIgBoxZfgmYmQazKLGumHitRso0ZVkD0aE/FI7UrYv2WUYXjo0ihNhEatA1GBEUIxEWAcKCHhHCVMG8AETlda0ENn3hrm+/6Zh47RBCtXn+mZ/sAXzWjnPHV77zkiXBgl6gFkee+em1wBlgdnEF8sCF5moLI7KwlSIMwABwgbVT21htMNjleheAfPkShEBh/PzQccexdxBT9IPjQAYYZ+3o2OjQ8cQiPb+kVwBCliENXA3sAm6Zj3E/zaq4fD07HmwEmuKYXsUFcDl6Hz7/B1RGfEbPim/bAAAAAElFTkSuQmCC'
    }

    TriggerEvent('esx_phone:addSpecialContact', specialContact.name, specialContact.number, specialContact.base64Icon)
end)

-- Create Blips
CreateThread(function()
    local blip = AddBlipForCoord(Config.Zones.ImportActions.Pos.x, Config.Zones.ImportActions.Pos.y,
        Config.Zones.ImportActions.Pos.z)

        SetBlipSprite(blip, 478)
        SetBlipDisplay(blip, 4)
        SetBlipScale(blip, 1.0)
        SetBlipColour(blip, 21)
        SetBlipAsShortRange(blip, true)

    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(_U('blip_import'))
    EndTextCommandSetBlipName(blip)
end)

-- Enter / Exit marker events, and draw markers
CreateThread(function()
    while true do
        local sleep = 1500
        if ESX.PlayerData.job and ESX.PlayerData.job.name == 'import' then

            local coords = GetEntityCoords(PlayerPedId())
            local isInMarker, currentZone = false

            for k, v in pairs(Config.Zones) do
                local zonePos = vector3(v.Pos.x, v.Pos.y, v.Pos.z)
                local distance = #(coords - zonePos)

                if v.Type ~= -1 and distance < Config.DrawDistance then
                    sleep = 0
                    DrawMarker(v.Type, v.Pos.x, v.Pos.y, v.Pos.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, v.Size.x, v.Size.y,
                        v.Size.z, v.Color.r, v.Color.g, v.Color.b, 100, false, false, 2, v.Rotate, nil, nil, false)
                end

                if distance < v.Size.x then
                    isInMarker, currentZone = true, k
                end
            end

            if (isInMarker and not HasAlreadyEnteredMarker) or (isInMarker and LastZone ~= currentZone) then
                HasAlreadyEnteredMarker, LastZone = true, currentZone
                TriggerEvent('bpt_importjob:hasEnteredMarker', currentZone)
            end

            if not isInMarker and HasAlreadyEnteredMarker then
                HasAlreadyEnteredMarker = false
                TriggerEvent('bpt_importjob:hasExitedMarker', LastZone)
            end
        end
        Wait(sleep)
    end
end)

-- Key Controls
CreateThread(function()
    while true do
        local sleep = 1500
        if CurrentAction and not ESX.PlayerData.dead then
            sleep = 0
            ESX.ShowHelpNotification(CurrentActionMsg)

            if IsControlJustReleased(0, 38) and ESX.PlayerData.job and ESX.PlayerData.job.name == 'import' then
                if CurrentAction == 'import_actions_menu' then
                    OpenImportActionsMenu()
                elseif CurrentAction == 'cloakroom' then
                    OpenCloakroom()
                elseif CurrentAction == 'vehicle_spawner' then
                    OpenVehicleSpawnerMenu()
                elseif CurrentAction == 'delete_vehicle' then
                    DeleteJobVehicle()
                end

                CurrentAction = nil
            end
        end
        Wait(sleep)
    end
end)

RegisterCommand('importmenu', function()
    if not ESX.PlayerData.dead and Config.EnablePlayerManagement and ESX.PlayerData.job and ESX.PlayerData.job.name ==
        'import' then
        OpenMobileImportActionsMenu()
    end
end, false)

RegisterKeyMapping('importmenu', 'Open import Menu', 'keyboard', 'f6')
