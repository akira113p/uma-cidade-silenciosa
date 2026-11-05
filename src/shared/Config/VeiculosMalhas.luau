-- Malhas dos veículos (visual; a física e os alvos continuam em blocos). Contrato: docs/veiculos-modelos.md.
-- GERADO por ferramentas/modelos/gerar_config.py (manifesto.json + enviados.json). Não editar à mão.
-- Sem `modelo` (assetId) o jogo segue em blocos.
return {
	tipos = {
		compacto = {
			escala = 1.9566,
			inteiro = {
				modelo = 81412098464236,
				texturas = {
					"rbxassetid://137766488911684",
					"rbxassetid://123071738764865",
					"rbxassetid://73157680917217",
					"rbxassetid://136091748777432",
				},
				pecas = {
					Capo = { tamanho = { x = 5.832, y = 0.744, z = 3.786 }, centro = { x = 0, y = 2.679, z = -4.825 } },
					Carroceria = {
						tamanho = { x = 6.178, y = 4.914, z = 14.611 },
						centro = { x = 0, y = 2.457, z = 0.093 },
					},
					ParaChoque = {
						tamanho = { x = 5.836, y = 1.883, z = 1.202 },
						centro = { x = 0, y = 1.431, z = -6.965 },
					},
					PortaD = {
						tamanho = { x = 1.797, y = 4.39, z = 4.926 },
						centro = { x = 2.823, y = 2.635, z = -0.071 },
					},
					PortaE = {
						tamanho = { x = 1.812, y = 4.39, z = 4.926 },
						centro = { x = -2.816, y = 2.635, z = -0.071 },
					},
					PortaMalas = {
						tamanho = { x = 5.932, y = 2.49, z = 0.617 },
						centro = { x = 0, y = 1.844, z = 7.258 },
					},
					Vidro_JanelaD = {
						tamanho = { x = 1.058, y = 2.005, z = 9.277 },
						centro = { x = 2.454, y = 3.828, z = 2.141 },
					},
					Vidro_JanelaE = {
						tamanho = { x = 1.003, y = 2.005, z = 9.277 },
						centro = { x = -2.481, y = 3.828, z = 2.141 },
					},
					Vidro_ParaBrisa = {
						tamanho = { x = 5.832, y = 1.803, z = 3.384 },
						centro = { x = 0, y = 3.931, z = -1.816 },
					},
					Vidro_Traseiro = {
						tamanho = { x = 5.497, y = 1.587, z = 1.93 },
						centro = { x = 0, y = 3.85, z = 6.211 },
					},
					Volante = {
						tamanho = { x = 1.758, y = 0.748, z = 0.401 },
						centro = { x = -1.276, y = 2.191, z = -1.427 },
					},
				},
			},
			queimado = {
				modelo = 105895375185946,
				textura = "rbxassetid://113702681297550",
				pecas = {
					Carroceria = {
						tamanho = { x = 8.202, y = 5.035, z = 15.577 },
						centro = { x = 0, y = 2.517, z = 0 },
					},
				},
			},
			dimensoes = { x = 7.443, y = 4.914, z = 15.132 },
			raioRoda = 1.234,
			folgaRoda = 0.37,
			bancoTopo = 0.8,
			tetoInterno = 4.7,
			olho = { x = -1.276, y = 3.5, z = 0.373 },
			bancos = {
				{ x = -1.276, z = 0.373 },
				{ x = 1.276, z = 0.373 },
				{ x = -1.276, z = 2.973 },
				{ x = 1.276, z = 2.973 },
			},
			rodas = {
				FE = { x = -2.35, y = 0.37, z = -4.203 },
				FD = { x = 2.35, y = 0.37, z = -4.203 },
				TE = { x = -2.35, y = 0.37, z = 4.564 },
				TD = { x = 2.35, y = 0.37, z = 4.564 },
			},
		},
		esportivo = {
			escala = 2.264,
			inteiro = {
				modelo = 112468357542412,
				texturas = {
					"rbxassetid://80527580572327",
					"rbxassetid://85193720192689",
					"rbxassetid://136200775653529",
					"rbxassetid://96803588651808",
				},
				pecas = {
					Capo = { tamanho = { x = 6.575, y = 1.292, z = 7.341 }, centro = { x = 0, y = 2.511, z = -6.199 } },
					Carroceria = {
						tamanho = { x = 7.601, y = 4.945, z = 19.889 },
						centro = { x = 0, y = 2.473, z = 0 },
					},
					ParaChoque = {
						tamanho = { x = 6.419, y = 1.299, z = 0.255 },
						centro = { x = 0.001, y = 1.224, z = -9.817 },
					},
					PortaD = {
						tamanho = { x = 1.835, y = 4.121, z = 6.556 },
						centro = { x = 3.094, y = 2.745, z = 0.726 },
					},
					PortaE = {
						tamanho = { x = 1.835, y = 4.121, z = 6.558 },
						centro = { x = -3.094, y = 2.745, z = 0.725 },
					},
					PortaMalas = {
						tamanho = { x = 6.581, y = 2.861, z = 18.424 },
						centro = { x = 0, y = 3.507, z = 0.724 },
					},
					Vidro_JanelaD = {
						tamanho = { x = 1.036, y = 1.836, z = 5.841 },
						centro = { x = 2.77, y = 3.887, z = 1.084 },
					},
					Vidro_JanelaE = {
						tamanho = { x = 1.061, y = 1.851, z = 5.841 },
						centro = { x = -2.757, y = 3.88, z = 1.083 },
					},
					Vidro_ParaBrisa = {
						tamanho = { x = 6.302, y = 1.903, z = 3.398 },
						centro = { x = 0, y = 3.994, z = -1.334 },
					},
					Vidro_Traseiro = {
						tamanho = { x = 6.581, y = 1.837, z = 4.257 },
						centro = { x = 0, y = 4.019, z = 6.353 },
					},
					Volante = {
						tamanho = { x = 1.995, y = 1.62, z = 0.703 },
						centro = { x = -1.434, y = 2.796, z = -0.502 },
					},
				},
			},
			queimado = {
				modelo = 83156786040814,
				textura = "rbxassetid://110262405120088",
				pecas = {
					Carroceria = { tamanho = { x = 8.605, y = 5.149, z = 19.87 }, centro = { x = 0, y = 2.575, z = 0 } },
				},
			},
			dimensoes = { x = 8.022, y = 4.945, z = 19.889 },
			raioRoda = 1.427,
			folgaRoda = 0.428,
			bancoTopo = 0.8,
			tetoInterno = 4.7,
			olho = { x = -1.434, y = 3.5, z = 1.298 },
			bancos = { { x = -1.434, z = 1.298 }, { x = 1.434, z = 1.298 } },
			rodas = {
				FE = { x = -3.085, y = 0.428, z = -5.595 },
				FD = { x = 3.085, y = 0.428, z = -5.595 },
				TE = { x = -3.19, y = 0.428, z = 5.385 },
				TD = { x = 3.19, y = 0.428, z = 5.385 },
			},
		},
		pickup = {
			escala = 1.6233,
			inteiro = {
				modelo = 90307409293756,
				texturas = {
					"rbxassetid://99870213081688",
					"rbxassetid://131447588119739",
					"rbxassetid://124939090081368",
					"rbxassetid://124274950653398",
				},
				pecas = {
					Capo = { tamanho = { x = 5.533, y = 2.425, z = 4.683 }, centro = { x = 0, y = 2.053, z = -5.161 } },
					Carroceria = {
						tamanho = { x = 6.667, y = 4.825, z = 15.167 },
						centro = { x = 0, y = 2.412, z = 0.127 },
					},
					ParaChoque = {
						tamanho = { x = 5.886, y = 1.514, z = 0.699 },
						centro = { x = 0, y = 1.362, z = -7.361 },
					},
					PortaD = {
						tamanho = { x = 0.248, y = 2.629, z = 3.051 },
						centro = { x = 2.598, y = 1.768, z = -1.062 },
					},
					PortaE = {
						tamanho = { x = 0.246, y = 2.525, z = 3.042 },
						centro = { x = -2.643, y = 1.82, z = -1.058 },
					},
					PortaMalas = {
						tamanho = { x = 5.444, y = 2.29, z = 0.13 },
						centro = { x = 0, y = 2.014, z = 7.396 },
					},
					Vidro_JanelaD = {
						tamanho = { x = 0.608, y = 1.414, z = 3.048 },
						centro = { x = 2.214, y = 3.772, z = -1.063 },
					},
					Vidro_JanelaE = {
						tamanho = { x = 0.595, y = 1.409, z = 3.034 },
						centro = { x = -2.222, y = 3.774, z = -1.056 },
					},
					Vidro_ParaBrisa = {
						tamanho = { x = 5.034, y = 1.762, z = 1.778 },
						centro = { x = 0, y = 3.944, z = -2.549 },
					},
					Vidro_Traseiro = {
						tamanho = { x = 4.788, y = 1.724, z = 0.461 },
						centro = { x = -0.045, y = 3.963, z = 0.501 },
					},
					Volante = {
						tamanho = { x = 1.43, y = 1.161, z = 0.504 },
						centro = { x = -1.213, y = 2.772, z = -1.915 },
					},
				},
			},
			queimado = {
				modelo = 91694666224831,
				textura = "rbxassetid://125430831695751",
				pecas = {
					Carroceria = { tamanho = { x = 6.392, y = 4.785, z = 16 }, centro = { x = 0, y = 2.392, z = 0 } },
				},
			},
			dimensoes = { x = 6.667, y = 4.825, z = 15.42 },
			raioRoda = 1.023,
			folgaRoda = 0.307,
			bancoTopo = 0.8,
			tetoInterno = 4.7,
			olho = { x = -1.213, y = 3.5, z = -0.115 },
			bancos = { { x = -1.213, z = -0.115 }, { x = 1.213, z = -0.115 } },
			rodas = {
				FE = { x = -2.362, y = 0.307, z = -5.173 },
				FD = { x = 2.362, y = 0.307, z = -5.173 },
				TE = { x = -2.362, y = 0.307, z = 4.011 },
				TD = { x = 2.362, y = 0.307, z = 4.011 },
			},
		},
		sedan = {
			escala = 1.8028,
			inteiro = {
				modelo = 109708623528859,
				texturas = {
					"rbxassetid://82410002485143",
					"rbxassetid://116315460969827",
					"rbxassetid://93695894413292",
					"rbxassetid://112717271606023",
				},
				pecas = {
					Capo = { tamanho = { x = 6.073, y = 0.441, z = 6.085 }, centro = { x = 0, y = 2.782, z = -6.536 } },
					Carroceria = {
						tamanho = { x = 6.876, y = 4.965, z = 19.596 },
						centro = { x = 0, y = 2.483, z = 0.117 },
					},
					ParaChoque = {
						tamanho = { x = 6.876, y = 2.342, z = 1.275 },
						centro = { x = 0, y = 1.504, z = -9.278 },
					},
					PortaD = {
						tamanho = { x = 1.017, y = 3.026, z = 4.289 },
						centro = { x = 3.517, y = 1.767, z = -1.555 },
					},
					PortaE = {
						tamanho = { x = 1.038, y = 3.026, z = 4.289 },
						centro = { x = -3.507, y = 1.767, z = -1.555 },
					},
					PortaMalas = {
						tamanho = { x = 5.79, y = 1.447, z = 4.396 },
						centro = { x = 0, y = 2.508, z = 7.381 },
					},
					Vidro_JanelaD = {
						tamanho = { x = 0.865, y = 1.847, z = 7.119 },
						centro = { x = 2.604, y = 3.826, z = 0.065 },
					},
					Vidro_JanelaE = {
						tamanho = { x = 0.879, y = 1.855, z = 7.119 },
						centro = { x = -2.597, y = 3.822, z = 0.065 },
					},
					Vidro_ParaBrisa = {
						tamanho = { x = 6.073, y = 1.856, z = 2.29 },
						centro = { x = 0, y = 3.816, z = -2.604 },
					},
					Vidro_Traseiro = {
						tamanho = { x = 5.725, y = 1.394, z = 1.643 },
						centro = { x = 0, y = 3.901, z = 4.736 },
					},
					Volante = {
						tamanho = { x = 1.588, y = 1.294, z = 0.56 },
						centro = { x = -1.347, y = 2.591, z = -2.194 },
					},
				},
			},
			queimado = {
				modelo = 127389176173872,
				textura = "rbxassetid://97143492639823",
				pecas = {
					Carroceria = {
						tamanho = { x = 8.014, y = 5.056, z = 19.929 },
						centro = { x = 0, y = 2.528, z = 0 },
					},
				},
			},
			dimensoes = { x = 8.052, y = 4.965, z = 19.831 },
			raioRoda = 1.137,
			folgaRoda = 0.341,
			bancoTopo = 0.8,
			tetoInterno = 4.7,
			olho = { x = -1.347, y = 3.5, z = -0.394 },
			bancos = {
				{ x = -1.347, z = -0.394 },
				{ x = 1.347, z = -0.394 },
				{ x = -1.347, z = 2.206 },
				{ x = 1.347, z = 2.206 },
			},
			rodas = {
				FE = { x = -2.748, y = 0.341, z = -6.453 },
				FD = { x = 2.748, y = 0.341, z = -6.453 },
				TE = { x = -2.748, y = 0.341, z = 4.622 },
				TD = { x = 2.748, y = 0.341, z = 4.622 },
			},
		},
		suv = {
			escala = 1.8572,
			inteiro = {
				modelo = 114544943857926,
				texturas = {
					"rbxassetid://104187763756646",
					"rbxassetid://120552553730048",
					"rbxassetid://72838268017210",
					"rbxassetid://138456669333314",
				},
				pecas = {
					Capo = { tamanho = { x = 6.754, y = 0.47, z = 3.808 }, centro = { x = 0, y = 2.733, z = -5.954 } },
					Carroceria = {
						tamanho = { x = 7.363, y = 4.972, z = 15.957 },
						centro = { x = 0, y = 2.486, z = -0.191 },
					},
					ParaChoque = {
						tamanho = { x = 7.363, y = 1.341, z = 0.486 },
						centro = { x = 0, y = 1.886, z = -7.926 },
					},
					PortaD = {
						tamanho = { x = 1.401, y = 3.208, z = 3.716 },
						centro = { x = 3.472, y = 2.87, z = -1.596 },
					},
					PortaE = {
						tamanho = { x = 1.416, y = 3.208, z = 3.716 },
						centro = { x = -3.464, y = 2.87, z = -1.596 },
					},
					PortaMalas = {
						tamanho = { x = 7.363, y = 4.447, z = 1.694 },
						centro = { x = 0, y = 2.636, z = 7.322 },
					},
					Vidro_JanelaD = {
						tamanho = { x = 0.56, y = 1.522, z = 5.815 },
						centro = { x = 3.051, y = 3.714, z = 0.744 },
					},
					Vidro_JanelaE = {
						tamanho = { x = 0.575, y = 1.527, z = 5.815 },
						centro = { x = -3.043, y = 3.711, z = 0.744 },
					},
					Vidro_ParaBrisa = {
						tamanho = { x = 6.662, y = 1.82, z = 2.278 },
						centro = { x = 0, y = 3.839, z = -2.91 },
					},
					Vidro_Traseiro = {
						tamanho = { x = 6.662, y = 1.669, z = 4.752 },
						centro = { x = 0, y = 3.763, z = 5.347 },
					},
					Volante = {
						tamanho = { x = 1.636, y = 1.328, z = 0.576 },
						centro = { x = -1.387, y = 2.525, z = -2.585 },
					},
				},
			},
			queimado = {
				modelo = 136251773834668,
				textura = "rbxassetid://94680033689964",
				pecas = {
					Carroceria = {
						tamanho = { x = 8.449, y = 5.181, z = 17.541 },
						centro = { x = 0, y = 2.591, z = 0 },
					},
				},
			},
			dimensoes = { x = 8.345, y = 4.972, z = 16.339 },
			raioRoda = 1.171,
			folgaRoda = 0.351,
			bancoTopo = 0.8,
			tetoInterno = 4.7,
			olho = { x = -1.387, y = 3.5, z = -0.785 },
			bancos = {
				{ x = -1.387, z = -0.785 },
				{ x = 1.387, z = -0.785 },
				{ x = -1.387, z = 1.815 },
				{ x = 1.387, z = 1.815 },
			},
			rodas = {
				FE = { x = -2.959, y = 0.351, z = -5.447 },
				FD = { x = 2.959, y = 0.351, z = -5.447 },
				TE = { x = -2.959, y = 0.351, z = 4.546 },
				TD = { x = 2.959, y = 0.351, z = 4.546 },
			},
		},
		van = {
			escala = 1.4808,
			inteiro = {
				modelo = 86395690129847,
				texturas = {
					"rbxassetid://117812243972438",
					"rbxassetid://139711740849075",
					"rbxassetid://92929660426244",
					"rbxassetid://127636506666532",
				},
				pecas = {
					Capo = {
						tamanho = { x = 5.465, y = 1.09, z = 2.106 },
						centro = { x = 0.001, y = 2.811, z = -5.871 },
					},
					Carroceria = {
						tamanho = { x = 5.694, y = 4.873, z = 14.181 },
						centro = { x = 0, y = 2.436, z = -0.031 },
					},
					ParaChoque = {
						tamanho = { x = 5.474, y = 2.164, z = 0.882 },
						centro = { x = 0.001, y = 1.244, z = -6.869 },
					},
					PortaD = {
						tamanho = { x = 0.568, y = 3.263, z = 2.723 },
						centro = { x = 2.99, y = 2.222, z = -3.189 },
					},
					PortaE = {
						tamanho = { x = 0.568, y = 3.263, z = 2.723 },
						centro = { x = -2.99, y = 2.222, z = -3.189 },
					},
					PortaMalas = {
						tamanho = { x = 5.934, y = 4.614, z = 0.989 },
						centro = { x = 0.014, y = 2.491, z = 6.816 },
					},
					Vidro_JanelaD = {
						tamanho = { x = 0.423, y = 1.373, z = 2.722 },
						centro = { x = 2.522, y = 3.839, z = -3.19 },
					},
					Vidro_JanelaE = {
						tamanho = { x = 0.411, y = 1.369, z = 2.722 },
						centro = { x = -2.528, y = 3.841, z = -3.19 },
					},
					Vidro_ParaBrisa = {
						tamanho = { x = 4.959, y = 1.675, z = 1.388 },
						centro = { x = 0.254, y = 4.025, z = -4.406 },
					},
					Vidro_Traseiro = {
						tamanho = { x = 5.009, y = 1.651, z = 0.739 },
						centro = { x = 0, y = 3.973, z = 6.691 },
					},
					Volante = {
						tamanho = { x = 1.304, y = 1.059, z = 0.46 },
						centro = { x = -1.186, y = 2.845, z = -3.972 },
					},
				},
			},
			queimado = {
				modelo = 77862408465986,
				textura = "rbxassetid://84879456488512",
				pecas = {
					Carroceria = {
						tamanho = { x = 6.282, y = 5.046, z = 15.287 },
						centro = { x = 0, y = 2.523, z = 0 },
					},
				},
			},
			dimensoes = { x = 6.547, y = 4.873, z = 14.621 },
			raioRoda = 0.934,
			folgaRoda = 0.28,
			bancoTopo = 0.8,
			tetoInterno = 4.7,
			olho = { x = -1.186, y = 3.5, z = -2.172 },
			bancos = { { x = -1.186, z = -2.172 }, { x = 1.186, z = -2.172 }, { x = -1.186, z = 0.428 } },
			rodas = {
				FE = { x = -2.36, y = 0.28, z = -5.403 },
				FD = { x = 2.36, y = 0.28, z = -5.403 },
				TE = { x = -2.36, y = 0.28, z = 3.352 },
				TD = { x = 2.36, y = 0.28, z = 3.352 },
			},
		},
	},
	roda = {
		modelo = 126204957640066,
		textura = "rbxassetid://116704527314799",
		pecas = {
			roda = { tamanho = { x = 0.9, y = 2, z = 2 }, centro = { x = -0.002, y = 0, z = 0 } },
		},
	},
}
