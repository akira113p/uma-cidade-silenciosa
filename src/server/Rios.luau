-- Rios: enche o Terrain de água a partir das Parts invisíveis `Agua` de workspace.Mapa.Rios (geradas por
-- ferramentas/mapa/relevo.luau) e ajusta a água para um rio escuro e turvo de floresta boreal. Dono: T1 (mapa v2).
local Rios = {}

local LOTE = 40 -- FillBlock por task.wait(), para não travar o servidor ao iniciar
local ESPERA_MAPA = 30 -- s esperando o Mapa aparecer (Rojo sincroniza no início)

local function ajustarAgua(terreno: Terrain)
	terreno.WaterColor = Color3.fromRGB(26, 42, 38)
	terreno.WaterTransparency = 0.35
	terreno.WaterReflectance = 0.15
	terreno.WaterWaveSize = 0.12
	terreno.WaterWaveSpeed = 6
end

function Rios.iniciar()
	local terreno = workspace.Terrain
	ajustarAgua(terreno)

	task.spawn(function()
		local mapa = workspace:WaitForChild("Mapa", ESPERA_MAPA)
		local pasta = mapa and mapa:WaitForChild("Rios", ESPERA_MAPA)
		if not pasta then
			warn("[Rios] workspace.Mapa.Rios não apareceu; sem água")
			return
		end

		local n = 0
		for _, parte in pasta:GetChildren() do
			if parte:IsA("BasePart") and parte.Name == "Agua" then
				terreno:FillBlock(parte.CFrame, parte.Size, Enum.Material.Water)
				n += 1
				if n % LOTE == 0 then
					task.wait()
				end
			end
		end
		workspace:SetAttribute("RiosProntos", true)
		print(string.format("[Rios] %d trechos de água preenchidos", n))
	end)
end

return Rios
