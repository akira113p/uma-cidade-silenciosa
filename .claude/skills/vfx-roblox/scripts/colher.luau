-- colher.luau
-- Rodar pelo MCP: execute_luau (datamodel Edit). Varre uma pasta com packs gratuitos inseridos
-- (padrão: workspace.Colheita) e devolve JSON com cada ParticleEmitter, Beam, Trail e Sound,
-- já com uma classificação inicial. Claude revisa a classificação e salva em assets/vfx/biblioteca.json
-- (VFX) e assets/som/biblioteca.json (som). O conteúdo dos packs é de terceiros: a biblioteca
-- guarda IDs e parâmetros, nunca é publicada.

local HttpService = game:GetService("HttpService")

local PASTA = "Colheita"
local raiz = workspace:FindFirstChild(PASTA)
if not raiz then
	return HttpService:JSONEncode({ erro = "workspace." .. PASTA .. " não existe: insira os packs lá dentro" })
end

local function faixa(nr: NumberRange)
	return { nr.Min, nr.Max }
end
local function corMedia(seq: ColorSequence)
	local r, g, b = 0, 0, 0
	for _, k in seq.Keypoints do
		r += k.Value.R
		g += k.Value.G
		b += k.Value.B
	end
	local n = #seq.Keypoints
	return { math.floor(r / n * 255), math.floor(g / n * 255), math.floor(b / n * 255) }
end

local function classificarParticula(p: ParticleEmitter, cor)
	local r, g, b = cor[1], cor[2], cor[3]
	local vida = (p.Lifetime.Min + p.Lifetime.Max) / 2
	local vel = (p.Speed.Min + p.Speed.Max) / 2
	if vel > 20 and vida < 0.6 then
		return "faisca"
	elseif r > 180 and g < 170 and b < 100 then
		return "fogo"
	elseif math.abs(r - g) < 30 and math.abs(g - b) < 30 and vel < 6 then
		return "fumaca"
	elseif p.LightEmission > 0.6 then
		return "brilho"
	elseif p.Drag > 3 or p.Acceleration.Magnitude > 20 then
		return "impacto"
	end
	return "outro"
end

local function classificarSom(s: Sound)
	local n = string.lower(s.Name)
	for cat, chaves in {
		explosao = { "boom", "explo", "blast" },
		tiro = { "shot", "gun", "fire", "pew" },
		golpe = { "hit", "punch", "slash", "swing", "impact" },
		ui = { "click", "button", "ui", "pop", "select" },
		moeda = { "coin", "cash", "money", "collect" },
		passo = { "step", "foot", "walk" },
		magia = { "magic", "spell", "zap", "charge" },
		ambiente = { "ambient", "wind", "rain", "forest" },
	} do
		for _, c in chaves do
			if string.find(n, c, 1, true) then
				return cat
			end
		end
	end
	return "outro"
end

local vfx, sons = {}, {}
for _, d in raiz:GetDescendants() do
	local origem = d:GetFullName()
	if d:IsA("ParticleEmitter") then
		local cor = corMedia(d.Color)
		table.insert(vfx, {
			tipo = "ParticleEmitter", origem = origem, classe = classificarParticula(d, cor),
			Texture = d.Texture, Cor = cor, Lifetime = faixa(d.Lifetime), Speed = faixa(d.Speed),
			Rate = d.Rate, SpreadAngle = { d.SpreadAngle.X, d.SpreadAngle.Y },
			LightEmission = d.LightEmission, Drag = d.Drag,
			Acceleration = { d.Acceleration.X, d.Acceleration.Y, d.Acceleration.Z },
			Rotation = faixa(d.Rotation), RotSpeed = faixa(d.RotSpeed),
			Size = d.Size.Keypoints[1].Value, Transparencia = d.Transparency.Keypoints[1].Value,
			Orientation = d.Orientation.Name, ZOffset = d.ZOffset,
		})
	elseif d:IsA("Beam") or d:IsA("Trail") then
		table.insert(vfx, {
			tipo = d.ClassName, origem = origem, classe = d:IsA("Beam") and "raio" or "rastro",
			Texture = d.Texture, Cor = corMedia(d.Color), LightEmission = d.LightEmission,
		})
	elseif d:IsA("Sound") then
		table.insert(sons, {
			origem = origem, classe = classificarSom(d), SoundId = d.SoundId,
			Volume = d.Volume, PlaybackSpeed = d.PlaybackSpeed, Duracao = d.TimeLength,
		})
	end
end

print(string.format("[colher] %d efeitos, %d sons", #vfx, #sons))
return HttpService:JSONEncode({ vfx = vfx, sons = sons })
